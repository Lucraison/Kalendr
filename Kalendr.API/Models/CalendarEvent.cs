namespace Kalendr.API.Models;

public class CalendarEvent
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public bool IsWorkHours { get; set; }

    public Guid? GroupId { get; set; }
    public Group? Group { get; set; }

    public Guid CreatedByUserId { get; set; }
    public User CreatedBy { get; set; } = null!;

    public string? Color { get; set; }
    public ICollection<EventGroupShare> SharedWith { get; set; } = [];
}
