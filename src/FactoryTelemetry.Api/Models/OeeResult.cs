namespace FactoryTelemetry.Api.Models;

/// <summary>
/// Result of an OEE (Overall Equipment Effectiveness) computation for a machine
/// over a time window. All ratio values are normalised to the 0.0 – 1.0 range.
///
/// OEE = Availability × Performance × Quality
/// </summary>
public record OeeResult
{
    public required string MachineId { get; init; }

    public DateTimeOffset WindowStartUtc { get; init; }
    public DateTimeOffset WindowEndUtc { get; init; }

    /// <summary>Run time / planned production time.</summary>
    public double Availability { get; init; }

    /// <summary>(Ideal cycle time × total count) / run time.</summary>
    public double Performance { get; init; }

    /// <summary>Good count / total count.</summary>
    public double Quality { get; init; }

    /// <summary>Availability × Performance × Quality.</summary>
    public double Oee { get; init; }

    public int TotalPartsProduced { get; init; }
    public int TotalPartsRejected { get; init; }
    public int SampleCount { get; init; }

    /// <summary>OEE expressed as a percentage, rounded to one decimal place (convenience for dashboards).</summary>
    public double OeePercent => Math.Round(Oee * 100, 1);
}
