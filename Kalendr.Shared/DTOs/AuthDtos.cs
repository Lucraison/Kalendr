namespace Kalendr.Shared.DTOs;

public record RegisterRequest(string Username, string Email, string Password);
public record LoginRequest(string Username, string Password);
public record AuthResponse(string Token, string Username, Guid UserId, string Email);
public record ForgotPasswordRequest(string UsernameOrEmail);
public record ForgotPasswordResponse(string MaskedEmail);
public record ResetPasswordRequest(string UsernameOrEmail, string Code, string NewPassword);
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);
public record ChangeEmailRequest(string CurrentPassword, string NewEmail);
public record RegisterDeviceRequest(string Token, string Platform);
