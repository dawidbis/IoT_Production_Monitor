using FactoryTelemetry.Api.Models;

namespace FactoryTelemetry.Api.Services;

/// <summary>
/// Computes Overall Equipment Effectiveness from a sequence of telemetry readings.
/// </summary>
public interface IOeeCalculator
{
    /// <summary>
    /// Calculate OEE for a single machine over the window spanned by the supplied readings.
    /// </summary>
    /// <param name="machineId">Machine the readings belong to.</param>
    /// <param name="readings">Telemetry samples for the machine (any order).</param>
    /// <param name="parameters">Plant master data (ideal cycle time, sample interval).</param>
    OeeResult Calculate(string machineId, IReadOnlyList<TelemetryReading> readings, OeeParameters parameters);
}
