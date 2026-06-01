# syntax=docker/dockerfile:1

# ---- Build stage --------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Restore as a separate layer so dependency caching survives source changes.
COPY ["FactoryTelemetry.Api.csproj", "./"]
RUN dotnet restore "FactoryTelemetry.Api.csproj"

COPY . .
RUN dotnet publish "FactoryTelemetry.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# ---- Runtime stage ------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

# Run as a non-root user (App Service / container hardening best practice).
RUN groupadd --system app && useradd --system --gid app app
USER app

COPY --from=build /app/publish .

ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "FactoryTelemetry.Api.dll"]
