namespace Kalendr.API.Services;

public interface IEmailService
{
    Task SendPasswordResetCodeAsync(string toEmail, string username, string code);
}
