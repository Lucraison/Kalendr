using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Kalendr.API.Data;
using Kalendr.API.Models;
using Kalendr.API.Services;
using Kalendr.Shared.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace Kalendr.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController(AppDbContext db, IConfiguration config, IEmailService email) : ControllerBase
{
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest req)
    {
        if (await db.Users.AnyAsync(u => u.Email == req.Email))
            return Conflict("Email already in use.");

        if (await db.Users.AnyAsync(u => u.Username == req.Username))
            return Conflict(new { message = "Username already taken." });

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

    [HttpPatch("password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest req)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var user = await db.Users.FindAsync(userId);
        if (user is null) return NotFound();

        if (!BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash))
            return BadRequest(new { message = "Current password is incorrect." });

        if (req.NewPassword.Length < 6)
            return BadRequest(new { message = "Password must be at least 6 characters." });

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        await db.SaveChangesAsync();
        return Ok();
    }

    [HttpPatch("email")]
    [Authorize]
    public async Task<IActionResult> ChangeEmail(ChangeEmailRequest req)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var user = await db.Users.FindAsync(userId);
        if (user is null) return NotFound();

        if (!BCrypt.Net.BCrypt.Verify(req.CurrentPassword, user.PasswordHash))
            return BadRequest(new { message = "Current password is incorrect." });

        var normalizedNew = req.NewEmail.Trim().ToLower();
        if (await db.Users.AnyAsync(u => u.Email == normalizedNew && u.Id != userId))
            return Conflict("Email already in use.");

        user.Email = normalizedNew;
        try { await db.SaveChangesAsync(); }
        catch (Microsoft.EntityFrameworkCore.DbUpdateException)
        {
            return Conflict("Email already in use.");
        }
        return Ok();
    }

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest req)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == req.Email);
        // Always return OK to avoid email enumeration
        if (user is null) return Ok();

        var code = Random.Shared.Next(100000, 999999).ToString();
        user.PasswordResetCode = BCrypt.Net.BCrypt.HashPassword(code);
        user.PasswordResetCodeExpiry = DateTime.UtcNow.AddMinutes(15);
        await db.SaveChangesAsync();

        try { await email.SendPasswordResetCodeAsync(user.Email, user.Username, code); }
        catch { /* don't leak email errors */ }

        Console.WriteLine($"[DEV] Reset code for {user.Email}: {code}"); // TEMP

        return Ok();
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest req)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == req.Email);
        if (user is null
            || user.PasswordResetCode is null
            || user.PasswordResetCodeExpiry < DateTime.UtcNow
            || !BCrypt.Net.BCrypt.Verify(req.Code, user.PasswordResetCode))
            return BadRequest(new { message = "Invalid or expired code." });

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        user.PasswordResetCode = null;
        user.PasswordResetCodeExpiry = null;
        await db.SaveChangesAsync();

        return Ok();
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
