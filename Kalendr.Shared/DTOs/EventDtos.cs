namespace Kalendr.Shared.DTOs;

public record ReactionDto(Guid Id, Guid UserId, string Username, string Emoji);
public record AddReactionRequest(string Emoji);

public record CreateEventRequest(
    Guid? GroupId,
    string Title,
    string? Description,
    DateTime StartTime,
    DateTime EndTime,
    bool IsWorkHours,
    string? Color = null,
    List<Guid>? SharedGroupIds = null,
    Guid? RecurrenceId = null
);

public record UpdateEventRequest(
    string Title,
    string? Description,
    DateTime StartTime,
    DateTime EndTime,
    bool IsWorkHours,
    string? Color = null,
    List<Guid>? SharedGroupIds = null
);

public record EventDto(
    Guid Id,
    Guid? GroupId,
    Guid CreatedByUserId,
    string CreatedByUsername,
    string UserColor,
    string Title,
    string? Description,
    DateTime StartTime,
    DateTime EndTime,
    bool IsAllDay,       // serializes as "isAllDay" — matches Flutter model
    string? Color,
    List<Guid> SharedGroupIds,
    Guid? RecurrenceId = null
);

public record BatchCreateEventRequest(List<CreateEventRequest> Events);

// Update all events with the same title+owner — keeps each event's date, applies new time
public record UpdateSeriesRequest(
    string Title,
    Guid? GroupId,
    int StartHour,
    int StartMinute,
    int DurationMinutes,
    bool IsWorkHours,
    string? Color,
    string? Description,
    List<Guid>? SharedGroupIds
);

public record UpdateRecurrenceSeriesRequest(
    string Title,
    string? Description,
    string? Color,
    List<Guid>? SharedGroupIds,
    int? StartHour,
    int? StartMinute,
    int? DurationMinutes
);

public record PatchEventMetadataRequest(
    string Title,
    string? Description,
    string? Color,
    List<Guid>? SharedGroupIds
);

public record RsvpDto(Guid UserId, string Username, string Status);
public record SetRsvpRequest(string Status); // "going" | "maybe" | "declined"

public record CommentDto(Guid Id, Guid UserId, string Username, string Content, DateTime CreatedAt);
public record AddCommentRequest(string Content);
