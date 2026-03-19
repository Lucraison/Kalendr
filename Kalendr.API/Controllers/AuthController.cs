using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Kalendr.API.Data;
using Kalendr.API.Models;
using Kalendr.Shared.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace Kalendr.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(AppDbContext db, IConfiguration config) : ControllerBase
{
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest req)
    {
        if (await db.Users.AnyAsync(u => u.Email == req.Email))
            return Conflict("Email already in use.");

        var user = new User
        {
            Username = req.Username,
            Email = req.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password)
        };

        db.Users.Add(user);
        await db.SaveChangesAsync();

        return Ok(new AuthResponse(GenerateToken(user), user.Username, user.Id));
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest req)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == req.Email);

        if (user is null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            return Unauthorized("Invalid credentials.");

        return Ok(new AuthResponse(GenerateToken(user), user.Username, user.Id));
    }

    [HttpPatch("username")]
    [Authorize]
    public async Task<ActionResult<AuthResponse>> UpdateUsername([FromBody] UpdateUsernameRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Username) || req.Username.Length < 2)
            return BadRequest(new { message = "Username must be at least 2 characters." });

        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var user = await db.Users.FindAsync(userId);
        if (user is null) return NotFound();

        user.Username = req.Username.Trim();
        await db.SaveChangesAsync();

        return Ok(new AuthResponse(GenerateToken(user), user.Username, user.Id));
    }

    [HttpDelete("account")]
    [Authorize]
    public async Task<IActionResult> DeleteAccount()
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // Delete in dependency order to avoid FK violations
        var eventIds = await db.Events.Where(e => e.CreatedByUserId == userId).Select(e => e.Id).ToListAsync();

        // Clear reactions/rsvps/comments on user's events from other users
        await db.Reactions.Where(r => eventIds.Contains(r.EventId)).ExecuteDeleteAsync();
        await db.Rsvps.Where(r => eventIds.Contains(r.EventId)).ExecuteDeleteAsync();
        await db.Comments.Where(c => eventIds.Contains(c.EventId)).ExecuteDeleteAsync();

        // Clear user's own reactions/rsvps/comments on other events
        await db.Reactions.Where(r => r.UserId == userId).ExecuteDeleteAsync();
        await db.Rsvps.Where(r => r.UserId == userId).ExecuteDeleteAsync();
        await db.Comments.Where(c => c.UserId == userId).ExecuteDeleteAsync();
        await db.Notifications.Where(n => n.UserId == userId).ExecuteDeleteAsync();

        // Delete user's events and group memberships
        await db.Events.Where(e => e.CreatedByUserId == userId).ExecuteDeleteAsync();
        await db.GroupMembers.Where(m => m.UserId == userId).ExecuteDeleteAsync();

        // Delete the user
        await db.Users.Where(u => u.Id == userId).ExecuteDeleteAsync();

        return NoContent();
    }

    private string GenerateToken(User user)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.Username)
        };

        var token = new JwtSecurityToken(
            issuer: config["Jwt:Issuer"],
            audience: config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddDays(30),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
