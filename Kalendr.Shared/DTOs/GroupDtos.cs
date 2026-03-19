namespace Kalendr.Shared.DTOs;

public record CreateGroupRequest(string Name);
public record JoinGroupRequest(string InviteCode);
public record UpdateColorRequest(string Color);
public record RenameGroupRequest(string Name);

public record GroupDto(
    Guid Id,
    string Name,
    string InviteCode,
    List<GroupMemberDto> Members
);

public record GroupMemberDto(
    Guid UserId,
    string Username,
    string Color,
    bool IsOwner
);
