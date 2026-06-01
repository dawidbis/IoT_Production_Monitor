using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace FactoryTelemetry.Api.Data;

/// <summary>
/// Design-time factory used only by the EF Core tooling (`dotnet ef migrations ...`).
/// It pins the SQL Server provider so migrations are generated for the relational schema,
/// independent of the runtime configuration (which may select the in-memory provider).
/// The connection string is never connected to at design time.
/// </summary>
public class TelemetryDbContextFactory : IDesignTimeDbContextFactory<TelemetryDbContext>
{
    public TelemetryDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<TelemetryDbContext>()
            .UseSqlServer("Server=localhost;Database=design;Trusted_Connection=True;")
            .Options;

        return new TelemetryDbContext(options);
    }
}
