using FactoryTelemetry.Api.Models;

namespace FactoryTelemetry.Api.Services;

/// <summary>
/// Reference implementation of the standard OEE formula (per oee.com / SEMI E10):
///
///   Availability = Run Time / Planned Production Time
///   Performance  = (Ideal Cycle Time × Total Count) / Run Time
///   Quality      = Good Count / Total Count
///   OEE          = Availability × Performance × Quality
///
/// Time is derived from sample counts: each heartbeat represents one
/// <see cref="OeeParameters.SampleInterval"/> of machine time. Planned production time
/// excludes samples reported as <see cref="MachineState.PlannedStop"/>.
/// </summary>
public class OeeCalculator : IOeeCalculator
{
    public OeeResult Calculate(string machineId, IReadOnlyList<TelemetryReading> readings, OeeParameters parameters)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(machineId);
        ArgumentNullException.ThrowIfNull(readings);
        ArgumentNullException.ThrowIfNull(parameters);

        if (readings.Count == 0)
        {
            return new OeeResult
            {
                MachineId = machineId,
                WindowStartUtc = default,
                WindowEndUtc = default,
                Availability = 0,
                Performance = 0,
                Quality = 0,
                Oee = 0,
                TotalPartsProduced = 0,
                TotalPartsRejected = 0,
                SampleCount = 0
            };
        }

        var sampleSeconds = parameters.SampleInterval.TotalSeconds;

        // --- Availability ---------------------------------------------------
        int plannedSamples = readings.Count(r => r.State != MachineState.PlannedStop);
        int runningSamples = readings.Count(r => r.State == MachineState.Running);

        double plannedProductionTime = plannedSamples * sampleSeconds;
        double runTime = runningSamples * sampleSeconds;
        double availability = plannedProductionTime > 0 ? runTime / plannedProductionTime : 0;

        // --- Quality --------------------------------------------------------
        int totalCount = readings.Sum(r => r.PartsProduced);
        int rejectedCount = readings.Sum(r => r.PartsRejected);
        int goodCount = Math.Max(0, totalCount - rejectedCount);
        // No parts produced => nothing defective; Quality is undefined but treated as perfect
        // so it never masks an Availability/Performance problem (OEE still collapses via Performance).
        double quality = totalCount > 0 ? (double)goodCount / totalCount : 1.0;

        // --- Performance ----------------------------------------------------
        double idealProductionTime = parameters.IdealCycleTime.TotalSeconds * totalCount;
        // Capped at 1.0: producing "faster than ideal" indicates the nameplate cycle time is mis-set,
        // not >100% efficiency. This is the conventional OEE treatment.
        double performance = runTime > 0 ? Math.Min(idealProductionTime / runTime, 1.0) : 0;

        double oee = availability * performance * quality;

        return new OeeResult
        {
            MachineId = machineId,
            WindowStartUtc = readings.Min(r => r.RecordedAtUtc),
            WindowEndUtc = readings.Max(r => r.RecordedAtUtc),
            Availability = availability,
            Performance = performance,
            Quality = quality,
            Oee = oee,
            TotalPartsProduced = totalCount,
            TotalPartsRejected = rejectedCount,
            SampleCount = readings.Count
        };
    }
}
