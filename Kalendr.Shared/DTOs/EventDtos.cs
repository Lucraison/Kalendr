namespace Kalendr.Shared.DTOs;

public record ReactionDto(Guid Id, Guid UserId, string Username, string Emoji);
public record AddReactionRequest(string Emoji);

public record CreateEventRequest(
    Guid GroupId,
    string Title,
    string? Description,
    DateTime StartTime,
    DateTime EndTime,
    bool IsWorkHours
);

public record UpdateEventRequest(
    string Title,
    string? Description,
    DateTime StartTime,
    DateTime EndTime,
    bool IsWorkHours
);

public record EventDto(
    Guid Id,
    Guid GroupId,
    Guid CreatedByUserId,
    string CreatedByUsername,
    string UserColor,
    string Title,
    string? Description,
    DateTime StartTime,
    DateTime EndTime,
    bool IsWorkHours
);

public record RsvpDto(Guid UserId, string Username, string Status);
public record SetRsvpRequest(string Status); // "going" | "maybe" | "declined"

public record CommentDto(Guid Id, Guid UserId, string Username, string Content, DateTime CreatedAt);
public record AddCommentRequest(string Content);
