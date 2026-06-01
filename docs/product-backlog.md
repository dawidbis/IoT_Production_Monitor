# Product Backlog — Factory Telemetry & OEE Monitor

This backlog is structured the way it would live in **Azure Boards** (Epics → Features →
User Stories with acceptance criteria), demonstrating the Product Management / ALM side of
the role alongside the DevOps engineering.

> **Vision:** Give plant managers a single, trustworthy OEE number per machine, fed
> automatically from the shop floor, on infrastructure that any engineer can recreate from
> code in minutes.

## Personas

| Persona | Goal |
| --- | --- |
| **Hanna — Plant Manager** | See OEE per line to spot underperforming equipment. |
| **Marek — Maintenance Engineer** | Get early warning from temperature / downtime trends. |
| **Dawid — DevOps Engineer** | Provision and deploy the whole system reproducibly and safely. |

---

## Epic 1 — Telemetry ingestion

**Feature 1.1 — Accept machine signals**

- **US-01** As a *machine*, I want to POST a JSON status (`state`, `temp`, `parts`) so that my
  activity is recorded.
  - **AC1** Given a valid payload, when POSTed to `/api/telemetry`, then it returns `201 Created` and persists a row.
  - **AC2** Given `partsRejected > partsProduced`, then it returns `400` with a validation message.
  - **AC3** Given an out-of-range temperature, then it returns `400`.
  - *Status: ✅ Done*
- **US-02** As a *maintenance engineer*, I want to read the latest readings for a machine so
  that I can investigate issues.
  - **AC1** `GET /api/telemetry/{machineId}` returns the most recent N readings, newest first.
  - *Status: ✅ Done*

## Epic 2 — OEE calculation

**Feature 2.1 — Compute OEE per machine**

- **US-03** As a *plant manager*, I want an OEE figure for a machine over a time window so
  that I can rank line performance.
  - **AC1** `GET /api/machines/{id}/oee` returns Availability, Performance, Quality and OEE.
  - **AC2** OEE = Availability × Performance × Quality, each in 0–1.
  - **AC3** Performance is capped at 100 %.
  - **AC4** No telemetry in window → `404`.
  - *Status: ✅ Done — covered by unit + integration tests*
- **US-04** As a *plant manager*, I want a default window of one shift (8 h) so that I don't
  have to specify dates for the common case.
  - *Status: ✅ Done*

## Epic 3 — Infrastructure as Code

- **US-05** As a *DevOps engineer*, I want all Azure resources defined in Terraform so that any
  environment can be recreated from code.
  - **AC1** `terraform apply` provisions RG, App Service, Azure SQL, IoT Hub, ACR, App Insights.
  - **AC2** State is stored remotely; no secrets are committed.
  - *Status: ✅ Done*

## Epic 4 — CI/CD automation

- **US-06** As a *DevOps engineer*, I want a pipeline that builds, tests and deploys on every
  merge to `main` so that releases are repeatable and safe.
  - **AC1** Build stage runs .NET tests, Pester tests, PSScriptAnalyzer and `terraform validate`.
  - **AC2** Deploy stage builds the image, pushes to ACR, deploys to App Service and smoke-tests `/health`.
  - *Status: ✅ Done (pipeline authored)*

## Epic 5 — Observability *(future)*

- **US-07** As a *maintenance engineer*, I want an alert when a machine's temperature exceeds a
  threshold so that I can act before a breakdown. — *📋 Backlog*
- **US-08** As a *plant manager*, I want a Power BI / Grafana dashboard of OEE trends. — *📋 Backlog*

---

## Sample sprint plan (Kanban)

| Sprint | Goal | Stories |
| --- | --- | --- |
| **Sprint 1** | Walking skeleton: ingest + persist + run locally | US-01, US-02 |
| **Sprint 2** | The KPI: OEE endpoint + full test coverage | US-03, US-04 |
| **Sprint 3** | Cloud foundation: Terraform for all resources | US-05 |
| **Sprint 4** | Ship it: end-to-end pipeline + container deploy | US-06 |
| **Sprint 5** | Insight: alerting & dashboards | US-07, US-08 |

## Definition of Done

- [ ] Code reviewed and merged via PR
- [ ] Unit/integration tests added and green
- [ ] PSScriptAnalyzer & `terraform validate` clean in CI
- [ ] Docs / Wiki updated
- [ ] Deployed to `dev` and `/health` is green
