namespace Kalendr.Shared.DTOs;

public record NotificationDto(Guid Id, string Message, Guid? EventId, Guid? GroupId, bool IsRead, DateTime CreatedAt);
