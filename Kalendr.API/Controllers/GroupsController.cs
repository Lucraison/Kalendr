using System.Security.Claims;
using Kalendr.API.Data;
using Kalendr.API.Models;
using Kalendr.Shared.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kalendr.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class GroupsController(AppDbContext db) : ControllerBase
{
    private Guid CurrentUserId =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<List<GroupDto>> GetMyGroups()
    {
        return await db.GroupMembers
            .Where(gm => gm.UserId == CurrentUserId)
            .Include(gm => gm.Group)
                .ThenInclude(g => g.Members)
                    .ThenInclude(m => m.User)
            .Select(gm => ToDto(gm.Group))
            .ToListAsync();
    }

    [HttpPost]
    public async Task<ActionResult<GroupDto>> CreateGroup(CreateGroupRequest req)
    {
        var group = new Group { Name = req.Name };
        db.Groups.Add(group);

        // Creator gets the first color
        db.GroupMembers.Add(new GroupMember
        {
            Group = group,
            UserId = CurrentUserId,
            Color = "#3B82F6",
            IsOwner = true
        });

        await db.SaveChangesAsync();

        var created = await db.Groups
            .Include(g => g.Members).ThenInclude(m => m.User)
            .FirstAsync(g => g.Id == group.Id);

        return CreatedAtAction(nameof(GetGroup), new { id = group.Id }, ToDto(created));
    }

    [HttpPost("join")]
    public async Task<ActionResult<GroupDto>> JoinGroup(JoinGroupRequest req)
    {
        var group = await db.Groups
            .Include(g => g.Members).ThenInclude(m => m.User)
            .FirstOrDefaultAsync(g => g.InviteCode == req.InviteCode.ToUpper());

        if (group is null) return NotFound("Invalid invite code.");

        if (group.Members.Any(m => m.UserId == CurrentUserId))
            return Conflict("Already a member.");

        var color = PickNextColor(group.Members.Count);
        db.GroupMembers.Add(new GroupMember { Group = group, UserId = CurrentUserId, Color = color });
        await db.SaveChangesAsync();

        // Reload with new member
        await db.Entry(group).Collection(g => g.Members).LoadAsync();
        return Ok(ToDto(group));
    }

    [HttpPatch("{id}/rename")]
    public async Task<IActionResult> RenameGroup(Guid id, [FromBody] RenameGroupRequest req)
    {
        var group = await db.Groups
            .Include(g => g.Members)
            .FirstOrDefaultAsync(g => g.Id == id);

        if (group is null) return NotFound();
        if (!group.Members.Any(m => m.UserId == CurrentUserId && m.IsOwner)) return Forbid();

        group.Name = req.Name;
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPatch("{id}/color")]
    public async Task<IActionResult> UpdateColor(Guid id, [FromBody] UpdateColorRequest req)
    {
        var membership = await db.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == CurrentUserId);

        if (membership is null) return NotFound();

        membership.Color = req.Color;
        await db.SaveChangesAsync();

        return NoContent();
    }

    [HttpDelete("{id}/leave")]
    public async Task<IActionResult> LeaveGroup(Guid id)
    {
        var membership = await db.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == CurrentUserId);

        if (membership is null) return NotFound();

        db.GroupMembers.Remove(membership);
        await db.SaveChangesAsync();

        return NoContent();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<GroupDto>> GetGroup(Guid id)
    {
        var group = await db.Groups
            .Include(g => g.Members).ThenInclude(m => m.User)
            .FirstOrDefaultAsync(g => g.Id == id);

        if (group is null) return NotFound();
        if (!group.Members.Any(m => m.UserId == CurrentUserId)) return Forbid();

        return Ok(ToDto(group));
    }

    [HttpDelete("{id}/members/{userId}")]
    public async Task<IActionResult> KickMember(Guid id, Guid userId)
    {
        var myMembership = await db.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == CurrentUserId);
        if (myMembership is null || !myMembership.IsOwner) return Forbid();
        if (userId == CurrentUserId) return BadRequest(new { message = "Cannot kick yourself." });

        var target = await db.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == userId);
        if (target is null) return NotFound();

        db.GroupMembers.Remove(target);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/transfer/{userId}")]
    public async Task<IActionResult> TransferOwnership(Guid id, Guid userId)
    {
        var myMembership = await db.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == CurrentUserId);
        if (myMembership is null || !myMembership.IsOwner) return Forbid();

        var target = await db.GroupMembers
            .FirstOrDefaultAsync(gm => gm.GroupId == id && gm.UserId == userId);
        if (target is null) return NotFound();

        myMembership.IsOwner = false;
        target.IsOwner = true;
        await db.SaveChangesAsync();
        return NoContent();
    }

    private static GroupDto ToDto(Group g) => new(
        g.Id,
        g.Name,
        g.InviteCode,
        g.Members.Select(m => new GroupMemberDto(m.UserId, m.User.Username, m.Color, m.IsOwner)).ToList()
    );

    private static readonly string[] Colors =
    [
        "#3B82F6", "#EF4444", "#10B981", "#F59E0B",
        "#8B5CF6", "#EC4899", "#14B8A6", "#F97316"
    ];

    private static string PickNextColor(int memberCount) =>
        Colors[memberCount % Colors.Length];
}
