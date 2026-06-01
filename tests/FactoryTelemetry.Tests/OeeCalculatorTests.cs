using FactoryTelemetry.Api.Models;
using FactoryTelemetry.Api.Services;
using FluentAssertions;

namespace FactoryTelemetry.Tests;

public class OeeCalculatorTests
{
    private readonly OeeCalculator _sut = new();

    private static readonly OeeParameters Params = new()
    {
        IdealCycleTime = TimeSpan.FromSeconds(30),
        SampleInterval = TimeSpan.FromSeconds(60)
    };

    private static TelemetryReading Reading(MachineState state, int produced = 0, int rejected = 0) => new()
    {
        MachineId = "WELD-CELL-07",
        State = state,
        PartsProduced = produced,
        PartsRejected = rejected,
        RecordedAtUtc = DateTimeOffset.UtcNow
    };

    [Fact]
    public void Calculate_WithNoReadings_ReturnsZeroOee()
    {
        var result = _sut.Calculate("WELD-CELL-07", [], Params);

        result.Oee.Should().Be(0);
        result.SampleCount.Should().Be(0);
    }

    [Fact]
    public void Availability_IsRunTimeOverPlannedProductionTime()
    {
        // 6 running, 2 down, 2 planned stop -> planned = 8 samples, running = 6 -> 0.75
        var readings = new List<TelemetryReading>();
        readings.AddRange(Enumerable.Range(0, 6).Select(_ => Reading(MachineState.Running, produced: 2)));
        readings.AddRange(Enumerable.Range(0, 2).Select(_ => Reading(MachineState.Down)));
        readings.AddRange(Enumerable.Range(0, 2).Select(_ => Reading(MachineState.PlannedStop)));

        var result = _sut.Calculate("WELD-CELL-07", readings, Params);

        result.Availability.Should().BeApproximately(0.75, 1e-9);
    }

    [Fact]
    public void Quality_IsGoodCountOverTotalCount()
    {
        var readings = new[]
        {
            Reading(MachineState.Running, produced: 80, rejected: 0),
            Reading(MachineState.Running, produced: 20, rejected: 5)
        };

        var result = _sut.Calculate("WELD-CELL-07", readings, Params);

        // total 100, rejected 5, good 95 -> 0.95
        result.Quality.Should().BeApproximately(0.95, 1e-9);
        result.TotalPartsProduced.Should().Be(100);
        result.TotalPartsRejected.Should().Be(5);
    }

    [Fact]
    public void Performance_IsCappedAtOneHundredPercent()
    {
        // 1 running sample = 60s run time; producing 10 parts at 30s ideal => ideal time 300s.
        // 300/60 = 5.0 but performance must cap at 1.0.
        var readings = new[] { Reading(MachineState.Running, produced: 10) };

        var result = _sut.Calculate("WELD-CELL-07", readings, Params);

        result.Performance.Should().Be(1.0);
    }

    [Fact]
    public void Oee_IsProductOfThreeFactors()
    {
        // Construct: Availability 0.5 (1 running, 1 down), Quality 0.9 (10 produced, 1 rejected).
        // Run time = 60s, ideal = 30s * 10 = 300s -> performance capped at 1.0.
        var readings = new[]
        {
            Reading(MachineState.Running, produced: 10, rejected: 1),
            Reading(MachineState.Down)
        };

        var result = _sut.Calculate("WELD-CELL-07", readings, Params);

        result.Availability.Should().BeApproximately(0.5, 1e-9);
        result.Quality.Should().BeApproximately(0.9, 1e-9);
        result.Performance.Should().Be(1.0);
        result.Oee.Should().BeApproximately(0.5 * 1.0 * 0.9, 1e-9);
        result.OeePercent.Should().Be(45.0);
    }

    [Fact]
    public void Calculate_WithNoParts_DoesNotDivideByZero()
    {
        var readings = new[] { Reading(MachineState.Idle), Reading(MachineState.Down) };

        var result = _sut.Calculate("WELD-CELL-07", readings, Params);

        result.Quality.Should().Be(1.0);   // no parts => quality undefined, treated as perfect
        result.Performance.Should().Be(0);  // no run time
        result.Oee.Should().Be(0);
    }
}
