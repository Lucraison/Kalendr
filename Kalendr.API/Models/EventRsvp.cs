namespace Kalendr.API.Models;

public enum RsvpStatus { Going, Maybe, Declined }

public class EventRsvp
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid EventId { get; set; }
    public CalendarEvent Event { get; set; } = null!;
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public RsvpStatus Status { get; set; }
}
