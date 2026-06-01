using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using FactoryTelemetry.Api.Data;
using FactoryTelemetry.Api.Models;
using FactoryTelemetry.Api.Services;
using Microsoft.EntityFrameworkCore;
using Serilog;

// Bootstrap logger so failures during start-up are captured before the host is built.
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((context, services, configuration) => configuration
        .ReadFrom.Configuration(context.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .WriteTo.Console());

    // --- Persistence --------------------------------------------------------
    // Use Azure SQL when a connection string is supplied, otherwise fall back to the
    // in-memory provider so the API runs locally / in CI with zero infrastructure.
    var connectionString = builder.Configuration.GetConnectionString("TelemetryDb");
    builder.Services.AddDbContext<TelemetryDbContext>(options =>
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            options.UseInMemoryDatabase("telemetry");
        }
        else
        {
            options.UseSqlServer(connectionString, sql => sql.EnableRetryOnFailure());
        }
    });

    // Accept and emit enums as human-readable strings (e.g. "Running") instead of integers,
    // matching the documented telemetry contract ({ "state": "Running" }).
    builder.Services.ConfigureHttpJsonOptions(options =>
        options.SerializerOptions.Converters.Add(new JsonStringEnumConverter()));

    // --- Domain services ----------------------------------------------------
    builder.Services.Configure<OeeParameters>(builder.Configuration.GetSection("Oee"));
    builder.Services.AddSingleton<IOeeCalculator, OeeCalculator>();

    // --- API surface --------------------------------------------------------
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(c => c.SwaggerDoc("v1", new()
    {
        Title = "Factory Telemetry & OEE Monitor",
        Version = "v1",
        Description = "Ingests machine telemetry from the shop floor and computes Overall Equipment Effectiveness (OEE)."
    }));

    var app = builder.Build();

    // Ensure the in-memory schema exists for local runs.
    using (var scope = app.Services.CreateScope())
    {
        var db = scope.ServiceProvider.GetRequiredService<TelemetryDbContext>();
        if (db.Database.IsInMemory())
        {
            db.Database.EnsureCreated();
        }
    }

    app.UseSerilogRequestLogging();
    app.UseSwagger();
    app.UseSwaggerUI();

    MapEndpoints(app);

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Factory Telemetry API terminated unexpectedly during start-up");
}
finally
{
    Log.CloseAndFlush();
}

static void MapEndpoints(WebApplication app)
{
    app.MapGet("/", () => Results.Redirect("/swagger"))
        .ExcludeFromDescription();

    app.MapGet("/health", () => Results.Ok(new { status = "Healthy", utc = DateTimeOffset.UtcNow }))
        .WithName("HealthCheck")
        .WithTags("Diagnostics");

    // --- Ingest a telemetry sample -----------------------------------------
    app.MapPost("/api/telemetry", async (TelemetryIngestRequest request, TelemetryDbContext db) =>
    {
        var validation = new List<ValidationResult>();
        if (!Validator.TryValidateObject(request, new ValidationContext(request), validation, validateAllProperties: true))
        {
            return Results.ValidationProblem(validation.ToDictionary(
                v => v.MemberNames.FirstOrDefault() ?? "request",
                v => new[] { v.ErrorMessage ?? "Invalid value." }));
        }

        if (request.PartsRejected > request.PartsProduced)
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["partsRejected"] = ["Rejected parts cannot exceed produced parts."]
            });
        }

        var reading = new TelemetryReading
        {
            MachineId = request.MachineId,
            State = request.State,
            TemperatureC = request.TemperatureC,
            PartsProduced = request.PartsProduced,
            PartsRejected = request.PartsRejected,
            RecordedAtUtc = DateTimeOffset.UtcNow
        };

        db.Readings.Add(reading);
        await db.SaveChangesAsync();

        return Results.Created($"/api/telemetry/{reading.Id}", reading);
    })
    .WithName("IngestTelemetry")
    .WithTags("Telemetry");

    // --- Recent readings for a machine -------------------------------------
    app.MapGet("/api/telemetry/{machineId}", async (string machineId, TelemetryDbContext db, int take = 50) =>
    {
        var readings = await db.Readings
            .Where(r => r.MachineId == machineId)
            .OrderByDescending(r => r.RecordedAtUtc)
            .Take(Math.Clamp(take, 1, 500))
            .ToListAsync();

        return readings.Count == 0 ? Results.NotFound() : Results.Ok(readings);
    })
    .WithName("GetRecentReadings")
    .WithTags("Telemetry");

    // --- OEE for a machine over a window -----------------------------------
    app.MapGet("/api/machines/{machineId}/oee", async (
        string machineId,
        TelemetryDbContext db,
        IOeeCalculator calculator,
        Microsoft.Extensions.Options.IOptions<OeeParameters> oeeOptions,
        DateTimeOffset? fromUtc,
        DateTimeOffset? toUtc) =>
    {
        var from = fromUtc ?? DateTimeOffset.UtcNow.AddHours(-8); // default: one shift
        var to = toUtc ?? DateTimeOffset.UtcNow;

        var readings = await db.Readings
            .Where(r => r.MachineId == machineId && r.RecordedAtUtc >= from && r.RecordedAtUtc <= to)
            .OrderBy(r => r.RecordedAtUtc)
            .ToListAsync();

        if (readings.Count == 0)
        {
            return Results.NotFound(new { message = $"No telemetry for machine '{machineId}' in the requested window." });
        }

        var result = calculator.Calculate(machineId, readings, oeeOptions.Value);
        return Results.Ok(result);
    })
    .WithName("GetMachineOee")
    .WithTags("OEE");
}

// Exposed so integration tests can spin up the API via WebApplicationFactory<Program>.
public partial class Program { }
