namespace Kalendr.API.Models;

public class Group
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string InviteCode { get; set; } = Guid.NewGuid().ToString("N")[..8].ToUpper();

    public ICollection<GroupMember> Members { get; set; } = [];
    public ICollection<CalendarEvent> Events { get; set; } = [];
}
