namespace FactoryTelemetry.Api.Services;

/// <summary>
/// Plant configuration required to turn raw telemetry into an OEE figure.
/// In a real deployment these come from the line's master data; here they are bound from configuration.
/// </summary>
public record OeeParameters
{
    /// <summary>
    /// The theoretical fastest time to produce one part ("nameplate" cycle time).
    /// Drives the Performance factor.
    /// </summary>
    public TimeSpan IdealCycleTime { get; init; } = TimeSpan.FromSeconds(30);

    /// <summary>
    /// Nominal machine time represented by a single telemetry heartbeat.
    /// Used to convert sample counts into Availability time buckets.
    /// </summary>
    public TimeSpan SampleInterval { get; init; } = TimeSpan.FromSeconds(60);
}
