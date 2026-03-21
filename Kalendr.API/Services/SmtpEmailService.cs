using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace Kalendr.API.Services;

public class SmtpEmailService(IConfiguration config) : IEmailService
{
    public async Task SendPasswordResetCodeAsync(string toEmail, string username, string code)
    {
        var smtp = config.GetSection("Smtp");
        var host = smtp["Host"]!;
        var port = int.Parse(smtp["Port"]!);
        var user = smtp["Username"]!;
        var pass = smtp["Password"]!;
        var from = smtp["From"] ?? user;
        var fromName = smtp["FromName"] ?? "Kalendr";

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(fromName, from));
        message.To.Add(new MailboxAddress(username, toEmail));
        message.Subject = "Your Kalendr password reset code";

        message.Body = new TextPart("html")
        {
            Text = $"""
                <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;background:#fff;border-radius:16px">
                  <h1 style="font-size:28px;font-weight:800;color:#1A1A1A;margin:0 0 4px">Kalendr 📅</h1>
                  <p style="color:#9E9E9E;margin:0 0 32px;font-size:14px">Your shared calendar</p>
                  <p style="color:#1A1A1A;font-size:16px">Hi <strong>{username}</strong>,</p>
                  <p style="color:#1A1A1A;font-size:15px">Use this code to reset your password. It expires in <strong>15 minutes</strong>.</p>
                  <div style="background:#F7F3F0;border-radius:12px;padding:24px;text-align:center;margin:24px 0">
                    <span style="font-size:40px;font-weight:800;letter-spacing:12px;color:#FF6B6B">{code}</span>
                  </div>
                  <p style="color:#9E9E9E;font-size:13px">If you didn't request this, you can safely ignore this email.</p>
                </div>
                """
        };

        using var client = new SmtpClient();
        await client.ConnectAsync(host, port, SecureSocketOptions.StartTls);
        await client.AuthenticateAsync(user, pass);
        await client.SendAsync(message);
        await client.DisconnectAsync(true);
    }
}
