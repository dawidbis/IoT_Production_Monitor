namespace FactoryTelemetry.Api.Models;

/// <summary>
/// Operational state reported by a production machine (e.g. a ZF robotic welding cell).
/// Mirrors the canonical states used on a manufacturing andon board.
/// </summary>
public enum MachineState
{
    /// <summary>Machine is actively producing parts.</summary>
    Running,

    /// <summary>Machine is powered but waiting (e.g. material starvation, no operator).</summary>
    Idle,

    /// <summary>Unplanned stop / breakdown.</summary>
    Down,

    /// <summary>Planned stop (changeover, scheduled maintenance, break).</summary>
    PlannedStop
}
