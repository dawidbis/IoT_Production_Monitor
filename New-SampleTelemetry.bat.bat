@echo off
setlocal

set "DEFAULT_URL=http://localhost:5000"
set "DEFAULT_COUNT=30"

echo.
set /p BASEURL="BaseUrl [%DEFAULT_URL%]: "
if "%BASEURL%"=="" set "BASEURL=%DEFAULT_URL%"

set /p COUNT="Count [%DEFAULT_COUNT%]: "
if "%COUNT%"=="" set "COUNT=%DEFAULT_COUNT%"

echo.
echo Uruchamianie...
echo BaseUrl: %BASEURL%
echo Count: %COUNT%
echo.

powershell -ExecutionPolicy Bypass -File ".\scripts\New-SampleTelemetry.ps1" ^
    -BaseUrl "%BASEURL%" ^
    -Count %COUNT%

echo.
pause