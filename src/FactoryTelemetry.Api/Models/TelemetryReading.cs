using System.ComponentModel.DataAnnotations;

namespace FactoryTelemetry.Api.Models;

/// <summary>
/// A single telemetry sample emitted by a machine and persisted to the database.
/// One row == one heartbeat from the shop floor.
/// </summary>
public class TelemetryReading
{
    /// <summary>Surrogate primary key.</summary>
    public long Id { get; set; }

    /// <summary>Logical identifier of the machine, e.g. "WELD-CELL-07".</summary>
    [Required]
    [MaxLength(64)]
    public string MachineId { get; set; } = string.Empty;

    /// <summary>Reported operational state at the moment of the sample.</summary>
    public MachineState State { get; set; }

    /// <summary>Process temperature in degrees Celsius (used for condition monitoring / alerting).</summary>
    public double TemperatureC { get; set; }

    /// <summary>Total parts produced since the previous sample (good + scrap).</summary>
    public int PartsProduced { get; set; }

    /// <summary>Defective parts within <see cref="PartsProduced"/> for this sample.</summary>
    public int PartsRejected { get; set; }

    /// <summary>UTC timestamp when the sample was recorded by the API.</summary>
    public DateTimeOffset RecordedAtUtc { get; set; } = DateTimeOffset.UtcNow;
}
