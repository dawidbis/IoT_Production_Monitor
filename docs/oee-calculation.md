# OEE — Overall Equipment Effectiveness

OEE is the manufacturing gold-standard metric for how well a piece of equipment is utilised.
It combines three independent factors into a single percentage:

```
OEE = Availability × Performance × Quality
```

A "world-class" OEE is around **85 %**; a typical plant sits at 60 %.

## The three factors

### 1. Availability — *"Was the machine running when it should have been?"*

```
Availability = Run Time / Planned Production Time
Run Time     = Planned Production Time − Stop Time
```

Captures **availability loss**: unplanned breakdowns and unrecorded stops. Planned stops
(changeovers, scheduled maintenance, breaks) are excluded from Planned Production Time.

### 2. Performance — *"Did it run as fast as it should have?"*

```
Performance = (Ideal Cycle Time × Total Count) / Run Time
```

Captures **performance loss**: slow cycles and small stops. Capped at 100 % — running
"faster than ideal" means the nameplate cycle time is mis-configured, not that efficiency
exceeds 100 %.

### 3. Quality — *"How many parts were good?"*

```
Quality = Good Count / Total Count
Good Count = Total Count − Reject Count
```

Captures **quality loss**: scrap and rework.

## How this project computes it

The API stores discrete telemetry *heartbeats*. Each heartbeat represents one
`SampleInterval` of machine time (default **60 s**) and carries the reported state plus parts
counts. `OeeCalculator` (in [`src/FactoryTelemetry.Api/Services/OeeCalculator.cs`](../src/FactoryTelemetry.Api/Services/OeeCalculator.cs))
aggregates them:

| Quantity | Derived from |
| --- | --- |
| Planned Production Time | count of samples whose state ≠ `PlannedStop` × `SampleInterval` |
| Run Time | count of `Running` samples × `SampleInterval` |
| Total Count | Σ `partsProduced` |
| Reject Count | Σ `partsRejected` |
| Ideal Cycle Time | configured plant master data (default **30 s/part**) |

Both `IdealCycleTime` and `SampleInterval` are bound from configuration (`Oee` section of
`appsettings.json`).

## Worked example

A machine reports **10 samples** in a window:

- 6 × `Running` (producing), 2 × `Down`, 2 × `PlannedStop`
- Total produced = 60 parts, rejected = 3
- `SampleInterval` = 60 s, `IdealCycleTime` = 30 s

| Factor | Calculation | Result |
| --- | --- | --- |
| Availability | run 6 / planned 8 | **0.750** |
| Performance | (30 s × 60) / (6 × 60 s) = 1800 / 360, capped | **1.000** |
| Quality | (60 − 3) / 60 | **0.950** |
| **OEE** | 0.750 × 1.000 × 0.950 | **0.7125 → 71.3 %** |

These exact relationships are locked in by the unit tests in
[`tests/FactoryTelemetry.Tests/OeeCalculatorTests.cs`](../tests/FactoryTelemetry.Tests/OeeCalculatorTests.cs).

## References

- [OEE.com — Calculate OEE](https://www.oee.com/calculating-oee/)
