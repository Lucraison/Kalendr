namespace Kalendr.API.Models;

public class EventGroupShare
{
    public Guid EventId { get; set; }
    public CalendarEvent Event { get; set; } = null!;
    public Guid GroupId { get; set; }
    public Group Group { get; set; } = null!;
}
