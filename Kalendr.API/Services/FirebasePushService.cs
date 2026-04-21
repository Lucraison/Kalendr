using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Kalendr.API.Data;
using Microsoft.EntityFrameworkCore;

namespace Kalendr.API.Services;

/// <summary>
/// Firebase Cloud Messaging push sender.
///
/// Relies on <see cref="FirebaseApp.DefaultInstance"/> being initialised at
/// startup (see Program.cs). If FCM credentials aren't configured — e.g. local
/// dev without a service-account JSON — the service logs a warning and becomes
/// a no-op rather than throwing, so the request path continues to work.
///
/// Scoped lifetime: shares the request's <see cref="AppDbContext"/> for
/// token lookups and stale-token deletion. Do NOT register as Singleton.
/// </summary>
public class FirebasePushService(AppDbContext db, ILogger<FirebasePushService> logger) : IPushService
{
    // FCM's multicast API accepts up to 500 tokens per call. We chunk above this.
    private const int MulticastBatchSize = 500;

    // Title shown on the Android notification. We use a static app name because
    // the current Notification model is a single pre-formatted Message string.
    // If/when the schema grows a title field, thread it through here.
    private const string NotificationTitle = "Chalk";

    // Must match the channel the Flutter client creates in push_service.dart.
    private const string AndroidChannelId = "chalk_default";

    public async Task SendToUsersAsync(
        IEnumerable<Guid> userIds,
        string body,
        Guid? eventId = null,
        CancellationToken ct = default)
    {
        var ids = userIds as ICollection<Guid> ?? userIds.ToList();
        if (ids.Count == 0) return;

        if (FirebaseApp.DefaultInstance is null)
        {
            logger.LogWarning(
                "Firebase Admin not initialised — skipping push to {UserCount} user(s). " +
                "Set GOOGLE_APPLICATION_CREDENTIALS to enable.",
                ids.Count);
            return;
        }

        var tokens = await db.UserDevices
            .Where(d => ids.Contains(d.UserId))
            .Select(d => d.Token)
            .ToListAsync(ct);

        if (tokens.Count == 0) return;

        var data = new Dictionary<string, string>();
        if (eventId.HasValue) data["eventId"] = eventId.Value.ToString();

        for (var offset = 0; offset < tokens.Count; offset += MulticastBatchSize)
        {
            var batch = tokens
                .Skip(offset)
                .Take(MulticastBatchSize)
                .ToList();

            var message = new MulticastMessage
            {
                Tokens = batch,
                Notification = new Notification
                {
                    Title = NotificationTitle,
                    Body = body,
                },
                Data = data,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = AndroidChannelId,
                    },
                },
            };

            try
            {
                var response = await FirebaseMessaging.DefaultInstance
                    .SendEachForMulticastAsync(message, ct);

                await PruneStaleTokensAsync(response, batch, ct);
            }
            catch (FirebaseMessagingException ex)
            {
                // A wholesale failure (auth/transport) — log and continue. The
                // request handler should not 500 just because push is down.
                logger.LogWarning(ex,
                    "FCM multicast failed for {TokenCount} tokens.", batch.Count);
            }
        }
    }

    /// <summary>
    /// Delete tokens FCM reports as permanently invalid. Transient failures
    /// (Unavailable, Internal, QuotaExceeded) are logged but NOT pruned — they
    /// might succeed on the next send and the token is still valid.
    /// </summary>
    private async Task PruneStaleTokensAsync(
        BatchResponse response,
        IList<string> sentTokens,
        CancellationToken ct)
    {
        var stale = new List<string>();

        for (var i = 0; i < response.Responses.Count; i++)
        {
            var r = response.Responses[i];
            if (r.IsSuccess) continue;

            var code = r.Exception?.MessagingErrorCode;
            if (code == MessagingErrorCode.Unregistered ||
                code == MessagingErrorCode.InvalidArgument ||
                code == MessagingErrorCode.SenderIdMismatch)
            {
                stale.Add(sentTokens[i]);
            }
            else
            {
                logger.LogWarning(r.Exception,
                    "FCM send failed for token (transient, keeping): code={Code}", code);
            }
        }

        if (stale.Count == 0) return;

        logger.LogInformation("Pruning {Count} stale FCM token(s).", stale.Count);
        await db.UserDevices
            .Where(d => stale.Contains(d.Token))
            .ExecuteDeleteAsync(ct);
    }
}
