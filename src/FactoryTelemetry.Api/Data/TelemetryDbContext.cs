using FactoryTelemetry.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace FactoryTelemetry.Api.Data;

/// <summary>
/// EF Core unit-of-work for telemetry persistence.
/// Backed by Azure SQL Database in the cloud and by the in-memory provider for local dev / tests.
/// </summary>
public class TelemetryDbContext(DbContextOptions<TelemetryDbContext> options) : DbContext(options)
{
    public DbSet<TelemetryReading> Readings => Set<TelemetryReading>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TelemetryReading>(entity =>
        {
            entity.HasKey(r => r.Id);
            entity.Property(r => r.MachineId).IsRequired().HasMaxLength(64);
            entity.Property(r => r.State).HasConversion<string>().HasMaxLength(16);

            // Composite index supports the most common query: readings for a machine within a window.
            entity.HasIndex(r => new { r.MachineId, r.RecordedAtUtc });
        });

        base.OnModelCreating(modelBuilder);
    }
}
