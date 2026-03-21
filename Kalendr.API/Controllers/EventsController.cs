using System.Security.Claims;
using Kalendr.API.Data;
using Kalendr.API.Models;
using Kalendr.API.Hubs;
using Kalendr.Shared.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace Kalendr.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class EventsController(AppDbContext db, IHubContext<CalendarHub> hub) : ControllerBase
{
    private Guid CurrentUserId =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private async Task<bool> CanAccessEventAsync(CalendarEvent ev)
    {
        if (ev.GroupId.HasValue)
            return await db.GroupMembers.AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (ev.CreatedByUserId == CurrentUserId) return true;
        return await db.EventGroupShares.AnyAsync(s => s.EventId == ev.Id &&
            db.GroupMembers.Any(gm => gm.GroupId == s.GroupId && gm.UserId == CurrentUserId));
    }

    [HttpGet("group/{groupId}")]
    public async Task<ActionResult<List<EventDto>>> GetGroupEvents(
        Guid groupId,
        [FromQuery] Guid? userId = null,
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null)
    {
        var isMember = await db.GroupMembers
            .AnyAsync(gm => gm.GroupId == groupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

        var query = db.Events
            .Include(e => e.CreatedBy)
            .Include(e => e.Group).ThenInclude(g => g.Members)
            .Include(e => e.SharedWith)
            .Where(e => e.GroupId == groupId || e.SharedWith.Any(s => s.GroupId == groupId));

        if (userId.HasValue)
            query = query.Where(e => e.CreatedByUserId == userId.Value);

        if (from.HasValue)
            query = query.Where(e => e.StartTime >= from.Value);

        if (to.HasValue)
            query = query.Where(e => e.StartTime < to.Value);

        var events = await query.OrderBy(e => e.StartTime).ToListAsync();
        return Ok(events.Select(e => ToDto(e)).ToList());
    }

    [HttpGet("personal")]
    public async Task<ActionResult<List<EventDto>>> GetPersonalEvents(
        [FromQuery] DateTime? from = null,
        [FromQuery] DateTime? to = null)
    {
        var query = db.Events
            .Include(e => e.CreatedBy)
            .Include(e => e.SharedWith)
            .Where(e => e.GroupId == null && e.CreatedByUserId == CurrentUserId);

        if (from.HasValue)
            query = query.Where(e => e.StartTime >= from.Value);
        if (to.HasValue)
            query = query.Where(e => e.StartTime < to.Value);

        var events = await query.OrderBy(e => e.StartTime).ToListAsync();
        return Ok(events.Select(e => ToDto(e)).ToList());
    }

    [HttpPost]
    public async Task<ActionResult<EventDto>> CreateEvent(CreateEventRequest req)
    {
        if (!req.IsWorkHours && req.EndTime <= req.StartTime)
            return BadRequest(new { message = "End time must be after start time." });

        if (req.GroupId.HasValue)
        {
            var isMember = await db.GroupMembers
                .AnyAsync(gm => gm.GroupId == req.GroupId && gm.UserId == CurrentUserId);
            if (!isMember) return Forbid();
        }

        var ev = new CalendarEvent
        {
            Title = req.Title,
            Description = req.Description,
            StartTime = req.StartTime,
            EndTime = req.EndTime,
            IsWorkHours = req.IsWorkHours,
            GroupId = req.GroupId,
            CreatedByUserId = CurrentUserId
        };

        db.Events.Add(ev);

        ev.Color = req.Color;
        if (req.SharedGroupIds != null && req.GroupId == null) // only personal events can be shared
        {
            foreach (var gid in req.SharedGroupIds)
            {
                var isMemberOfGroup = await db.GroupMembers.AnyAsync(gm => gm.GroupId == gid && gm.UserId == CurrentUserId);
                if (isMemberOfGroup)
                    db.EventGroupShares.Add(new EventGroupShare { Event = ev, GroupId = gid });
            }
        }

        await db.SaveChangesAsync();

        await db.Entry(ev).Reference(e => e.CreatedBy).LoadAsync();
        await db.Entry(ev).Collection(e => e.SharedWith).LoadAsync();

        if (req.GroupId.HasValue)
        {
            await db.Entry(ev).Reference(e => e.Group).Query()
                .Include(g => g.Members).LoadAsync();

            var dto = ToDto(ev);
            await hub.Clients.Group($"group-{req.GroupId}").SendAsync("EventCreated", dto);

            var groupMembers = await db.GroupMembers
                .Where(gm => gm.GroupId == req.GroupId && gm.UserId != CurrentUserId)
                .ToListAsync();

            var since = DateTime.UtcNow.AddHours(-1);
            var notifs = new List<Notification>();
            foreach (var gm in groupMembers)
            {
                // For work schedules, only notify once per hour per title to avoid spam
                if (ev.IsWorkHours)
                {
                    var alreadyNotified = await db.Notifications.AnyAsync(n =>
                        n.UserId == gm.UserId &&
                        n.Message.Contains($"\"{ev.Title}\"") &&
                        n.CreatedAt >= since);
                    if (alreadyNotified) continue;
                }
                notifs.Add(new Notification
                {
                    UserId = gm.UserId,
                    Message = ev.IsWorkHours
                        ? $"{ev.CreatedBy.Username} added their work schedule"
                        : $"{ev.CreatedBy.Username} added \"{ev.Title}\" on {ev.StartTime:MMM d}",
                    EventId = ev.Id,
                });
            }
            db.Notifications.AddRange(notifs);
            await db.SaveChangesAsync();

            return CreatedAtAction(nameof(GetEvent), new { id = ev.Id }, dto);
        }

        return CreatedAtAction(nameof(GetEvent), new { id = ev.Id }, ToDto(ev));
    }

    [HttpPost("batch")]
    public async Task<ActionResult<List<EventDto>>> CreateEventsBatch(BatchCreateEventRequest req)
    {
        if (req.Events == null || req.Events.Count == 0) return BadRequest("No events provided.");

        // Validate group membership once (all events share the same groupId)
        var groupId = req.Events[0].GroupId;
        if (groupId.HasValue)
        {
            var isMember = await db.GroupMembers
                .AnyAsync(gm => gm.GroupId == groupId && gm.UserId == CurrentUserId);
            if (!isMember) return Forbid();
        }

        var createdBy = await db.Users.FindAsync(CurrentUserId);
        var events = new List<CalendarEvent>();

        foreach (var r in req.Events)
        {
            var ev = new CalendarEvent
            {
                Title = r.Title,
                Description = r.Description,
                StartTime = r.StartTime,
                EndTime = r.EndTime,
                IsWorkHours = r.IsWorkHours,
                GroupId = r.GroupId,
                CreatedByUserId = CurrentUserId,
                Color = r.Color,
            };
            db.Events.Add(ev);
            events.Add(ev);

            if (r.SharedGroupIds != null && !r.GroupId.HasValue)
            {
                foreach (var gid in r.SharedGroupIds)
                {
                    var isMemberOfGroup = await db.GroupMembers.AnyAsync(gm => gm.GroupId == gid && gm.UserId == CurrentUserId);
                    if (isMemberOfGroup)
                        db.EventGroupShares.Add(new EventGroupShare { Event = ev, GroupId = gid });
                }
            }
        }

        await db.SaveChangesAsync();

        // Load navigation properties for all events
        foreach (var ev in events)
        {
            await db.Entry(ev).Reference(e => e.CreatedBy).LoadAsync();
            await db.Entry(ev).Collection(e => e.SharedWith).LoadAsync();
        }

        var dtos = new List<EventDto>();
        if (groupId.HasValue)
        {
            await db.Entry(events[0]).Reference(e => e.Group).Query()
                .Include(g => g.Members).LoadAsync();
            var group = events[0].Group;

            foreach (var ev in events)
            {
                ev.Group = group;
                var dto = ToDto(ev);
                dtos.Add(dto);
                await hub.Clients.Group($"group-{groupId}").SendAsync("EventCreated", dto);
            }

            // Single notification per group (not one per event)
            var groupMembers = await db.GroupMembers
                .Where(gm => gm.GroupId == groupId && gm.UserId != CurrentUserId)
                .ToListAsync();

            var since = DateTime.UtcNow.AddHours(-1);
            var notifs = new List<Notification>();
            var firstEv = events[0];
            foreach (var gm in groupMembers)
            {
                var alreadyNotified = firstEv.IsWorkHours && await db.Notifications.AnyAsync(n =>
                    n.UserId == gm.UserId &&
                    n.Message.Contains($"\"{firstEv.Title}\"") &&
                    n.CreatedAt >= since);
                if (alreadyNotified) continue;

                notifs.Add(new Notification
                {
                    UserId = gm.UserId,
                    Message = firstEv.IsWorkHours
                        ? $"{createdBy!.Username} added their work schedule"
                        : $"{createdBy!.Username} added \"{firstEv.Title}\"",
                    EventId = firstEv.Id,
                });
            }
            db.Notifications.AddRange(notifs);
            await db.SaveChangesAsync();
        }
        else
        {
            dtos = events.Select(ToDto).ToList();
        }

        return Ok(dtos);
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<EventDto>> UpdateEvent(Guid id, UpdateEventRequest req)
    {
        var ev = await db.Events
            .Include(e => e.CreatedBy)
            .Include(e => e.Group).ThenInclude(g => g.Members)
            .Include(e => e.SharedWith)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (ev is null) return NotFound();
        if (ev.CreatedByUserId != CurrentUserId) return Forbid();
        if (!req.IsWorkHours && req.EndTime <= req.StartTime)
            return BadRequest(new { message = "End time must be after start time." });

        ev.Title = req.Title;
        ev.Description = req.Description;
        ev.StartTime = req.StartTime;
        ev.EndTime = req.EndTime;
        ev.IsWorkHours = req.IsWorkHours;
        ev.Color = req.Color;

        // Update shared groups for personal events
        if (!ev.GroupId.HasValue && req.SharedGroupIds != null)
        {
            var existing = await db.EventGroupShares.Where(s => s.EventId == ev.Id).ToListAsync();
            db.EventGroupShares.RemoveRange(existing);
            foreach (var gid in req.SharedGroupIds)
            {
                var isMemberOfGroup = await db.GroupMembers.AnyAsync(gm => gm.GroupId == gid && gm.UserId == CurrentUserId);
                if (isMemberOfGroup)
                    db.EventGroupShares.Add(new EventGroupShare { EventId = ev.Id, GroupId = gid });
            }
        }

        await db.SaveChangesAsync();

        // Reload SharedWith after save
        await db.Entry(ev).Collection(e => e.SharedWith).LoadAsync();

        var dto = ToDto(ev);
        await hub.Clients.Group($"group-{ev.GroupId}").SendAsync("EventUpdated", dto);

        return Ok(dto);
    }

    [HttpPatch("{id}/metadata")]
    public async Task<IActionResult> PatchEventMetadata(Guid id, PatchEventMetadataRequest req)
    {
        var ev = await db.Events
            .Include(e => e.SharedWith)
            .FirstOrDefaultAsync(e => e.Id == id);
        if (ev is null) return NotFound();
        if (ev.CreatedByUserId != CurrentUserId) return Forbid();

        ev.Title = req.Title;
        ev.Description = req.Description;
        ev.Color = req.Color;

        if (req.SharedGroupIds != null && ev.GroupId == null)
        {
            db.EventGroupShares.RemoveRange(ev.SharedWith);
            foreach (var gid in req.SharedGroupIds)
            {
                var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == gid && gm.UserId == CurrentUserId);
                if (isMember) db.EventGroupShares.Add(new EventGroupShare { EventId = ev.Id, GroupId = gid });
            }
        }

        await db.SaveChangesAsync();
        return Ok();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEvent(Guid id)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        if (ev.CreatedByUserId != CurrentUserId) return Forbid();

        db.Events.Remove(ev);
        await db.SaveChangesAsync();

        if (ev.GroupId.HasValue)
            await hub.Clients.Group($"group-{ev.GroupId}").SendAsync("EventDeleted", id);

        return NoContent();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<EventDto>> GetEvent(Guid id)
    {
        var ev = await db.Events
            .Include(e => e.CreatedBy)
            .Include(e => e.Group).ThenInclude(g => g.Members)
            .Include(e => e.SharedWith)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (ev is null) return NotFound();

        if (ev.GroupId.HasValue)
        {
            var isMember = await db.GroupMembers
                .AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
            if (!isMember) return Forbid();
        }
        else
        {
            var canView = ev.CreatedByUserId == CurrentUserId ||
                await db.EventGroupShares.AnyAsync(s => s.EventId == ev.Id &&
                    db.GroupMembers.Any(gm => gm.GroupId == s.GroupId && gm.UserId == CurrentUserId));
            if (!canView) return Forbid();
        }

        return Ok(ToDto(ev));
    }

    [HttpGet("{id}/reactions")]
    public async Task<ActionResult<List<ReactionDto>>> GetReactions(Guid id)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        if (!await CanAccessEventAsync(ev)) return Forbid();

        var reactions = await db.Reactions
            .Include(r => r.User)
            .Where(r => r.EventId == id)
            .ToListAsync();

        return Ok(reactions.Select(r => new ReactionDto(r.Id, r.UserId, r.User.Username, r.Emoji)).ToList());
    }

    [HttpPost("{id}/reactions")]
    public async Task<ActionResult<ReactionDto>> ToggleReaction(Guid id, AddReactionRequest req)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        if (!await CanAccessEventAsync(ev)) return Forbid();

        // Toggle: if same user already reacted with same emoji, remove it
        var existing = await db.Reactions.FirstOrDefaultAsync(
            r => r.EventId == id && r.UserId == CurrentUserId && r.Emoji == req.Emoji);

        if (existing is not null)
        {
            db.Reactions.Remove(existing);
            await db.SaveChangesAsync();
            await hub.Clients.Group($"group-{ev.GroupId}").SendAsync("ReactionRemoved", id, existing.Id);
            return NoContent();
        }

        var reaction = new EventReaction { EventId = id, UserId = CurrentUserId, Emoji = req.Emoji };
        db.Reactions.Add(reaction);
        await db.SaveChangesAsync();
        await db.Entry(reaction).Reference(r => r.User).LoadAsync();

        var dto = new ReactionDto(reaction.Id, reaction.UserId, reaction.User.Username, reaction.Emoji);
        await hub.Clients.Group($"group-{ev.GroupId}").SendAsync("ReactionAdded", id, dto);
        return Ok(dto);
    }

    [HttpGet("{id}/comments")]
    public async Task<ActionResult<List<CommentDto>>> GetComments(Guid id)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        if (!await CanAccessEventAsync(ev)) return Forbid();

        var comments = await db.Comments
            .Include(c => c.User)
            .Where(c => c.EventId == id)
            .OrderBy(c => c.CreatedAt)
            .ToListAsync();

        return Ok(comments.Select(c => new CommentDto(c.Id, c.UserId, c.User.Username, c.Content, c.CreatedAt)).ToList());
    }

    [HttpPost("{id}/comments")]
    public async Task<ActionResult<CommentDto>> AddComment(Guid id, AddCommentRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Content)) return BadRequest("Content is required.");

        var ev = await db.Events.Include(e => e.CreatedBy).FirstOrDefaultAsync(e => e.Id == id);
        if (ev is null) return NotFound();
        if (!await CanAccessEventAsync(ev)) return Forbid();

        var comment = new EventComment { EventId = id, UserId = CurrentUserId, Content = req.Content.Trim() };
        db.Comments.Add(comment);

        // Notify event owner if they didn't comment themselves
        if (ev.CreatedByUserId != CurrentUserId)
        {
            var commenter = await db.Users.FindAsync(CurrentUserId);
            db.Notifications.Add(new Notification
            {
                UserId = ev.CreatedByUserId,
                Message = $"{commenter!.Username} commented on \"{ev.Title}\"",
                EventId = id,
            });
        }

        await db.SaveChangesAsync();
        await db.Entry(comment).Reference(c => c.User).LoadAsync();

        return Ok(new CommentDto(comment.Id, comment.UserId, comment.User.Username, comment.Content, comment.CreatedAt));
    }

    [HttpDelete("comments/{id}")]
    public async Task<IActionResult> DeleteComment(Guid id)
    {
        var comment = await db.Comments.FindAsync(id);
        if (comment is null) return NotFound();
        if (comment.UserId != CurrentUserId) return Forbid();
        db.Comments.Remove(comment);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpGet("{id}/rsvps")]
    public async Task<ActionResult<List<RsvpDto>>> GetRsvps(Guid id)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        if (!await CanAccessEventAsync(ev)) return Forbid();

        var rsvps = await db.Rsvps
            .Include(r => r.User)
            .Where(r => r.EventId == id)
            .ToListAsync();

        return Ok(rsvps.Select(r => new RsvpDto(r.UserId, r.User.Username, r.Status.ToString().ToLower())).ToList());
    }

    [HttpPost("{id}/rsvp")]
    public async Task<ActionResult<RsvpDto>> SetRsvp(Guid id, SetRsvpRequest req)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        if (!await CanAccessEventAsync(ev)) return Forbid();

        if (!Enum.TryParse<RsvpStatus>(req.Status, ignoreCase: true, out var status))
            return BadRequest("Invalid status. Use: going, maybe, or declined.");

        var existing = await db.Rsvps.FirstOrDefaultAsync(r => r.EventId == id && r.UserId == CurrentUserId);

        // Toggle off if same status
        if (existing is not null && existing.Status == status)
        {
            db.Rsvps.Remove(existing);
            await db.SaveChangesAsync();
            return NoContent();
        }

        if (existing is not null)
        {
            existing.Status = status;
        }
        else
        {
            existing = new EventRsvp { EventId = id, UserId = CurrentUserId, Status = status };
            db.Rsvps.Add(existing);
        }

        await db.SaveChangesAsync();
        await db.Entry(existing).Reference(r => r.User).LoadAsync();

        return Ok(new RsvpDto(existing.UserId, existing.User.Username, existing.Status.ToString().ToLower()));
    }

    [HttpDelete("delete-series")]
    public async Task<IActionResult> DeleteSeries([FromQuery] string title, [FromQuery] Guid? groupId)
    {
        var titleLower = title.ToLower();
        var events = await db.Events
            .Where(e => e.CreatedByUserId == CurrentUserId &&
                        (groupId == null ? e.GroupId == null : e.GroupId == groupId) &&
                        e.Title.ToLower() == titleLower)
            .ToListAsync();

        db.Events.RemoveRange(events);
        await db.SaveChangesAsync();
        return Ok(new { deleted = events.Count });
    }

    [HttpPost("update-series")]
    public async Task<IActionResult> UpdateSeries(UpdateSeriesRequest req)
    {
        var titleLower = req.Title.ToLower();
        var events = await db.Events
            .Include(e => e.SharedWith)
            .Where(e => e.CreatedByUserId == CurrentUserId &&
                        (req.GroupId == null ? e.GroupId == null : e.GroupId == req.GroupId) &&
                        e.Title.ToLower() == titleLower)
            .ToListAsync();

        foreach (var ev in events)
        {
            var newStart = new DateTime(ev.StartTime.Year, ev.StartTime.Month, ev.StartTime.Day,
                req.StartHour, req.StartMinute, 0);
            var newEnd = newStart.AddMinutes(req.DurationMinutes);

            ev.StartTime = newStart;
            ev.EndTime = newEnd;
            ev.IsWorkHours = req.IsAllDay;
            ev.Color = req.Color;
            ev.Description = req.Description;

            if (!ev.GroupId.HasValue && req.SharedGroupIds != null)
            {
                db.EventGroupShares.RemoveRange(ev.SharedWith);
                foreach (var gid in req.SharedGroupIds)
                {
                    var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == gid && gm.UserId == CurrentUserId);
                    if (isMember) db.EventGroupShares.Add(new EventGroupShare { EventId = ev.Id, GroupId = gid });
                }
            }
        }

        await db.SaveChangesAsync();
        return Ok(new { updated = events.Count });
    }

    private static EventDto ToDto(CalendarEvent e)
    {
        var member = e.Group?.Members.FirstOrDefault(m => m.UserId == e.CreatedByUserId);
        return new EventDto(
            e.Id,
            e.GroupId,
            e.CreatedByUserId,
            e.CreatedBy.Username,
            member?.Color ?? e.Color ?? "#FF6B6B",
            e.Title,
            e.Description,
            e.StartTime,
            e.EndTime,
            e.IsWorkHours,
            e.Color,
            e.SharedWith.Select(s => s.GroupId).ToList()
        );
    }
}
