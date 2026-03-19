namespace Kalendr.API.Models;

public class GroupMember
{
    public Guid GroupId { get; set; }
    public Group Group { get; set; } = null!;

    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    // Each member has a distinct color within this group
    public string Color { get; set; } = "#3B82F6";

    public bool IsOwner { get; set; } = false;
}
