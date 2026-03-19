namespace Kalendr.Shared.DTOs;

public record RegisterRequest(string Username, string Email, string Password);
public record LoginRequest(string Email, string Password);
public record AuthResponse(string Token, string Username, Guid UserId);
public record UpdateUsernameRequest(string Username);
