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
public class AuthController(AppDbContext db, IConfiguration config, IEmailService email, ILogger<AuthController> logger) : ControllerBase
{
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest req)
    {
        if (await db.Users.AnyAsync(u => u.Email == req.Email))
            return Conflict(new { message = "Email already in use." });

        if (await db.Users.AnyAsync(u => u.Username == req.Username))
            return Conflict(new { message = "Username already taken." });

        if (req.Password.Length < 6)
            return BadRequest(new { message = "Password must be at least 6 characters." });

        var user = new User
        {
            Username = req.Username,
            Email = req.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password)
        };

        db.Users.Add(user);
        await db.SaveChangesAsync();

        return Ok(new AuthResponse(GenerateToken(user), user.Username, user.Id, user.Email));
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest req)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Username == req.Username);

        if (user is null || !BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            return Unauthorized("Invalid credentials.");

        return Ok(new AuthResponse(GenerateToken(user), user.Username, user.Id, user.Email));
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
        var input = req.UsernameOrEmail.Trim();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Username == input || u.Email == input);
        // Always return OK to avoid username/email enumeration
        if (user is null) return Ok(new ForgotPasswordResponse(""));

        var code = Random.Shared.Next(100000, 999999).ToString();
        user.PasswordResetCode = BCrypt.Net.BCrypt.HashPassword(code);
        user.PasswordResetCodeExpiry = DateTime.UtcNow.AddMinutes(15);
        await db.SaveChangesAsync();

        try { await email.SendPasswordResetCodeAsync(user.Email, user.Username, code); }
        catch (Exception ex) { logger.LogError(ex, "Failed to send password reset email to {Email}", user.Email); }

        var parts = user.Email.Split('@');
        var masked = parts[0].Length <= 2
            ? new string('*', parts[0].Length) + '@' + parts[1]
            : parts[0][0] + new string('*', parts[0].Length - 2) + parts[0][^1] + '@' + parts[1];

        return Ok(new ForgotPasswordResponse(masked));
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest req)
    {
        var input = req.UsernameOrEmail.Trim();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Username == input || u.Email == input);
        if (user is null
            || user.PasswordResetCode is null
            || user.PasswordResetCodeExpiry < DateTime.UtcNow
            || !BCrypt.Net.BCrypt.Verify(req.Code, user.PasswordResetCode))
            return BadRequest(new { message = "Invalid or expired code." });

        if (req.NewPassword.Length < 6)
            return BadRequest(new { message = "Password must be at least 6 characters." });

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
        user.PasswordResetCode = null;
        user.PasswordResetCodeExpiry = null;
        await db.SaveChangesAsync();

        return Ok();
    }

    // Registers an FCM token for the current user. Tokens are unique globally —
    // if the same token is already on another user (reinstall / account switch on
    // same device) we reassign it. Safe to call on every app start.
    [HttpPost("fcm-token")]
    [Authorize]
    public async Task<IActionResult> RegisterDevice(RegisterDeviceRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Token))
            return BadRequest(new { message = "Token required." });

        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var platform = string.IsNullOrWhiteSpace(req.Platform) ? "android" : req.Platform;
        var existing = await db.UserDevices.FirstOrDefaultAsync(d => d.Token == req.Token);

        if (existing is null)
        {
            db.UserDevices.Add(new UserDevice
            {
                UserId = userId,
                Token = req.Token,
                Platform = platform,
                CreatedAt = DateTime.UtcNow,
                LastSeenAt = DateTime.UtcNow,
            });
        }
        else
        {
            existing.UserId = userId;
            existing.Platform = platform;
            existing.LastSeenAt = DateTime.UtcNow;
        }

        await db.SaveChangesAsync();
        return Ok();
    }

    // Called on logout — remove this device from the current user so pushes stop.
    [HttpDelete("fcm-token")]
    [Authorize]
    public async Task<IActionResult> UnregisterDevice([FromQuery] string token)
    {
        if (string.IsNullOrWhiteSpace(token)) return BadRequest();

        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await db.UserDevices
            .Where(d => d.Token == token && d.UserId == userId)
            .ExecuteDeleteAsync();
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
