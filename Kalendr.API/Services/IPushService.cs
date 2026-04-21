namespace Kalendr.API.Services;

/// <summary>
/// Sends FCM push notifications to users' registered devices. Implementations
/// should look up tokens from <c>UserDevices</c>, dispatch via Firebase Admin,
/// and prune tokens that FCM reports as permanently invalid.
///
/// Calls are expected to be awaited from request handlers — keep the work fast
/// and never let an FCM failure bubble out as a request error.
/// </summary>
public interface IPushService
{
    /// <summary>
    /// Send the same <paramref name="body"/> to every device registered to any
    /// of the given user IDs. Safe to call with an empty collection.
    /// </summary>
    /// <param name="eventId">Optional — passed through as a data payload so the
    /// Flutter client can deep-link into the relevant event when the user taps.</param>
    Task SendToUsersAsync(
        IEnumerable<Guid> userIds,
        string body,
        Guid? eventId = null,
        CancellationToken ct = default);
}
