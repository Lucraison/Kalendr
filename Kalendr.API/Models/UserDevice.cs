namespace Kalendr.API.Models;

/// <summary>
/// An FCM token registered to a user's device. One user can have many devices;
/// one device (Token) should be unique — if it shows up under a different user,
/// the old row is deleted to prevent sending a push to the wrong person.
/// </summary>
public class UserDevice
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public string Token { get; set; } = "";
    public string Platform { get; set; } = "android"; // "android" | "ios"
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
}
