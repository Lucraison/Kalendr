using System.Security.Claims;
using Kalendr.API.Data;
using Kalendr.Shared.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kalendr.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController(AppDbContext db) : ControllerBase
{
    private Guid CurrentUserId =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<ActionResult<List<NotificationDto>>> GetNotifications()
    {
        var notifications = await db.Notifications
            .Where(n => n.UserId == CurrentUserId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(50)
            .GroupJoin(
                db.Events,
                n => n.EventId,
                e => (Guid?)e.Id,
                (n, events) => new { Notification = n, Events = events })
            .SelectMany(
                x => x.Events.DefaultIfEmpty(),
                (x, e) => new
                {
                    x.Notification.Id,
                    x.Notification.Message,
                    x.Notification.EventId,
                    x.Notification.IsRead,
                    x.Notification.CreatedAt,
                    GroupId = e != null ? e.GroupId : (Guid?)null
                })
            .ToListAsync();

        return Ok(notifications.Select(n =>
            new NotificationDto(n.Id, n.Message, n.EventId, n.GroupId, n.IsRead, n.CreatedAt)).ToList());
    }

    [HttpPost("mark-read")]
    public async Task<IActionResult> MarkAllRead()
    {
        await db.Notifications
            .Where(n => n.UserId == CurrentUserId && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));
        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var n = await db.Notifications.FindAsync(id);
        if (n is null || n.UserId != CurrentUserId) return NotFound();
        db.Notifications.Remove(n);
        await db.SaveChangesAsync();
        return NoContent();
    }
}
