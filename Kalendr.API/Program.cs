using System.Text;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Kalendr.API.Data;
using Kalendr.API.Hubs;
using Kalendr.API.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.IdentityModel.Tokens;
using Scalar.AspNetCore;

// Npgsql 6+ enforces UTC-only DateTime by default. This restores legacy behaviour
// so wall-clock times stored by the app continue to work without a data migration.
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

// Initialise Firebase Admin once per process. The SDK reads credentials from
// the file at GOOGLE_APPLICATION_CREDENTIALS (set in the kalendr.service unit
// on prod). If unset/missing — e.g. local dev without FCM set up — we just
// skip: FirebasePushService treats a null DefaultInstance as a no-op so the
// rest of the API still works.
if (FirebaseApp.DefaultInstance is null)
{
    try
    {
        FirebaseApp.Create(new AppOptions
        {
            Credential = GoogleCredential.GetApplicationDefault(),
        });
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine(
            $"[startup] Firebase Admin init skipped: {ex.Message}. " +
            "Push notifications will be disabled for this process.");
    }
}

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(opt =>
{
    var cs = builder.Configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException("Connection string 'Default' is not configured.");

    // SQLite connection strings start with "Data Source="; everything else is treated as Postgres.
    if (cs.StartsWith("Data Source=", StringComparison.OrdinalIgnoreCase))
        opt.UseSqlite(cs);
    else
        opt.UseNpgsql(cs);

    opt.ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning));
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };

        // Allow JWT via query string for SignalR
        opt.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) &&
                    ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddSignalR();
builder.Services.AddScoped<IEmailService, SmtpEmailService>();
builder.Services.AddScoped<IPushService, FirebasePushService>();
builder.Services.AddControllers();
builder.Services.AddOpenApi();

var app = builder.Build();

// Auto-apply migrations on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.Migrate();
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(); // UI at /scalar/v1
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<CalendarHub>("/hubs/calendar");

app.Run();