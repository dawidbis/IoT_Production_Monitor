@echo off
setlocal

set "DEFAULT_URL=http://localhost:5150"
set "DEFAULT_MACHINES=WELD-CELL-07,PRESS-12"
set "DEFAULT_COUNT=30"

echo.
set /p BASEURL="BaseUrl [%DEFAULT_URL%]: "
if "%BASEURL%"=="" set "BASEURL=%DEFAULT_URL%"

set /p MACHINES="Machines [%DEFAULT_MACHINES%]: "
if "%MACHINES%"=="" set "MACHINES=%DEFAULT_MACHINES%"

set /p COUNT="Count [%DEFAULT_COUNT%]: "
if "%COUNT%"=="" set "COUNT=%DEFAULT_COUNT%"

echo.
echo Uruchamianie symulatora telemetrii...
echo BaseUrl:  %BASEURL%
echo Machines: %MACHINES%
echo Count:    %COUNT%
echo.

powershell -ExecutionPolicy Bypass -Command "& { $machArray = '%MACHINES%'.Split(','); & '%~dp0scripts\New-SampleTelemetry.ps1' -BaseUrl '%BASEURL%' -Machines $machArray -Count %COUNT% }"

echo.
pause
