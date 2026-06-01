using System.ComponentModel.DataAnnotations;

namespace FactoryTelemetry.Api.Models;

/// <summary>
/// Inbound payload accepted by the ingestion endpoint. Decoupled from the
/// persistence entity so the public contract can evolve independently.
/// </summary>
/// <example>
/// {
///   "machineId": "WELD-CELL-07",
///   "state": "Running",
///   "temperatureC": 72.4,
///   "partsProduced": 12,
///   "partsRejected": 1
/// }
/// </example>
public class TelemetryIngestRequest
{
    [Required]
    [MaxLength(64)]
    public string MachineId { get; set; } = string.Empty;

    [Required]
    public MachineState State { get; set; }

    [Range(-50, 500, ErrorMessage = "Temperature is outside the plausible sensor range.")]
    public double TemperatureC { get; set; }

    [Range(0, int.MaxValue)]
    public int PartsProduced { get; set; }

    [Range(0, int.MaxValue)]
    public int PartsRejected { get; set; }
}
