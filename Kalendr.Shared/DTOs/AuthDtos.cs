namespace Kalendr.Shared.DTOs;

public record RegisterRequest(string Username, string Email, string Password);
public record LoginRequest(string Email, string Password);
public record AuthResponse(string Token, string Username, Guid UserId);
public record ForgotPasswordRequest(string Email);
public record ResetPasswordRequest(string Email, string Code, string NewPassword);
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);
public record ChangeEmailRequest(string CurrentPassword, string NewEmail);
