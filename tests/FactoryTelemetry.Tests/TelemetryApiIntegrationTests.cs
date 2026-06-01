using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using FactoryTelemetry.Api.Models;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;

namespace FactoryTelemetry.Tests;

/// <summary>
/// Spins up the real API in-process (in-memory database) and exercises the HTTP surface end to end.
/// </summary>
public class TelemetryApiIntegrationTests
{
    // Mirror the API's JSON contract: enums are exchanged as strings ("Running").
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() }
    };

    [Fact]
    public async Task Health_ReturnsHealthy()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/health");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task PostTelemetry_ThenReadBack_RoundTrips()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var payload = new TelemetryIngestRequest
        {
            MachineId = "WELD-CELL-07",
            State = MachineState.Running,
            TemperatureC = 72.4,
            PartsProduced = 12,
            PartsRejected = 1
        };

        var post = await client.PostAsJsonAsync("/api/telemetry", payload, Json);
        post.StatusCode.Should().Be(HttpStatusCode.Created);

        var readings = await client.GetFromJsonAsync<List<TelemetryReading>>("/api/telemetry/WELD-CELL-07", Json);
        readings.Should().ContainSingle();
        readings![0].PartsProduced.Should().Be(12);
        readings[0].State.Should().Be(MachineState.Running);
    }

    [Fact]
    public async Task PostTelemetry_WithRejectedExceedingProduced_IsRejected()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var payload = new TelemetryIngestRequest
        {
            MachineId = "WELD-CELL-07",
            State = MachineState.Running,
            PartsProduced = 5,
            PartsRejected = 9
        };

        var post = await client.PostAsJsonAsync("/api/telemetry", payload, Json);

        post.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Oee_AfterIngestingSamples_IsComputed()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        // Ingest a handful of running samples with some scrap.
        for (var i = 0; i < 5; i++)
        {
            await client.PostAsJsonAsync("/api/telemetry", new TelemetryIngestRequest
            {
                MachineId = "PRESS-12",
                State = MachineState.Running,
                TemperatureC = 65,
                PartsProduced = 2,
                PartsRejected = i == 0 ? 1 : 0
            }, Json);
        }

        var oee = await client.GetFromJsonAsync<OeeResult>("/api/machines/PRESS-12/oee", Json);

        oee.Should().NotBeNull();
        oee!.MachineId.Should().Be("PRESS-12");
        oee.SampleCount.Should().Be(5);
        oee.TotalPartsProduced.Should().Be(10);
        oee.TotalPartsRejected.Should().Be(1);
        oee.Oee.Should().BeInRange(0, 1);
    }

    [Fact]
    public async Task Oee_ForUnknownMachine_ReturnsNotFound()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/api/machines/DOES-NOT-EXIST/oee");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
