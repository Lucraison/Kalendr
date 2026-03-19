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
            .Where(e => e.GroupId == groupId);

        if (userId.HasValue)
            query = query.Where(e => e.CreatedByUserId == userId.Value);

        if (from.HasValue)
            query = query.Where(e => e.StartTime >= from.Value.ToUniversalTime());

        if (to.HasValue)
            query = query.Where(e => e.StartTime < to.Value.ToUniversalTime());

        var events = await query.OrderBy(e => e.StartTime).ToListAsync();
        return Ok(events.Select(e => ToDto(e)).ToList());
    }

    [HttpPost]
    public async Task<ActionResult<EventDto>> CreateEvent(CreateEventRequest req)
    {
        var isMember = await db.GroupMembers
            .AnyAsync(gm => gm.GroupId == req.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

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
        await db.SaveChangesAsync();

        await db.Entry(ev).Reference(e => e.CreatedBy).LoadAsync();
        await db.Entry(ev).Reference(e => e.Group).Query()
            .Include(g => g.Members).LoadAsync();

        var dto = ToDto(ev);

        // Notify all group members in real time
        await hub.Clients.Group($"group-{req.GroupId}").SendAsync("EventCreated", dto);

        // Create in-app notifications for group members (except creator)
        var groupMembers = await db.GroupMembers
            .Where(gm => gm.GroupId == req.GroupId && gm.UserId != CurrentUserId)
            .ToListAsync();
        var dateStr = ev.StartTime.ToString("MMM d");
        var notifs = groupMembers.Select(gm => new Notification
        {
            UserId = gm.UserId,
            Message = $"{ev.CreatedBy.Username} added \"{ev.Title}\" on {dateStr}",
            EventId = ev.Id,
        }).ToList();
        db.Notifications.AddRange(notifs);
        await db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetEvent), new { id = ev.Id }, dto);
    }

    [HttpPut("{id}")]
    public async Task<ActionResult<EventDto>> UpdateEvent(Guid id, UpdateEventRequest req)
    {
        var ev = await db.Events
            .Include(e => e.CreatedBy)
            .Include(e => e.Group).ThenInclude(g => g.Members)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (ev is null) return NotFound();
        if (ev.CreatedByUserId != CurrentUserId) return Forbid();

        ev.Title = req.Title;
        ev.Description = req.Description;
        ev.StartTime = req.StartTime;
        ev.EndTime = req.EndTime;
        ev.IsWorkHours = req.IsWorkHours;

        await db.SaveChangesAsync();

        var dto = ToDto(ev);
        await hub.Clients.Group($"group-{ev.GroupId}").SendAsync("EventUpdated", dto);

        return Ok(dto);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEvent(Guid id)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        if (ev.CreatedByUserId != CurrentUserId) return Forbid();

        db.Events.Remove(ev);
        await db.SaveChangesAsync();

        await hub.Clients.Group($"group-{ev.GroupId}").SendAsync("EventDeleted", id);

        return NoContent();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<EventDto>> GetEvent(Guid id)
    {
        var ev = await db.Events
            .Include(e => e.CreatedBy)
            .Include(e => e.Group).ThenInclude(g => g.Members)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (ev is null) return NotFound();

        var isMember = await db.GroupMembers
            .AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

        return Ok(ToDto(ev));
    }

    [HttpGet("{id}/reactions")]
    public async Task<ActionResult<List<ReactionDto>>> GetReactions(Guid id)
    {
        var ev = await db.Events.FindAsync(id);
        if (ev is null) return NotFound();
        var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

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
        var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

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
        var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

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
        var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

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
        var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

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
        var isMember = await db.GroupMembers.AnyAsync(gm => gm.GroupId == ev.GroupId && gm.UserId == CurrentUserId);
        if (!isMember) return Forbid();

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

    private static EventDto ToDto(CalendarEvent e)
    {
        var member = e.Group.Members.FirstOrDefault(m => m.UserId == e.CreatedByUserId);
        return new EventDto(
            e.Id,
            e.GroupId,
            e.CreatedByUserId,
            e.CreatedBy.Username,
            member?.Color ?? "#3B82F6",
            e.Title,
            e.Description,
            e.StartTime,
            e.EndTime,
            e.IsWorkHours
        );
    }
}
