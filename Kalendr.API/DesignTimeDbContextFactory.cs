using Kalendr.API.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Kalendr.API;

/// <summary>
/// Used by EF tooling (`dotnet ef migrations add`, etc.) to build a DbContext
/// independent of the runtime configuration. Without this, the CLI picks up
/// whichever provider is configured by Program.cs — which is SQLite locally
/// (see appsettings.Development.json) and produces migrations that are
/// invalid on the PostgreSQL production database.
///
/// The connection string below is a placeholder; EF does not open a real
/// connection when scaffolding migrations — it only needs the provider
/// (Npgsql) so the generated column types are PostgreSQL-flavoured.
///
/// We also mirror the legacy-timestamp switch from Program.cs here so EF
/// generates `timestamp without time zone` for DateTime properties (matching
/// the prod schema), rather than the Npgsql 6+ default of `timestamptz`.
/// </summary>
public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    static DesignTimeDbContextFactory()
    {
        // Must match Program.cs — otherwise every migration add will try to
        // convert DateTime columns to timestamptz.
        AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
    }

    public AppDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql("Host=localhost;Database=chalk_migrations_scaffold;Username=postgres;Password=postgres")
            .Options;
        return new AppDbContext(options);
    }
}
