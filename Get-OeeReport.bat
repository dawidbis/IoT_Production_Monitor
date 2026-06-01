@echo off
setlocal

set "DEFAULT_URL=http://localhost:5150"
set "DEFAULT_MACHINES=WELD-CELL-07,PRESS-12"

echo.
set /p BASEURL="BaseUrl [%DEFAULT_URL%]: "
if "%BASEURL%"=="" set "BASEURL=%DEFAULT_URL%"

set /p MACHINES="Machines [%DEFAULT_MACHINES%]: "
if "%MACHINES%"=="" set "MACHINES=%DEFAULT_MACHINES%"

echo.
echo Pobieranie raportu OEE...
echo BaseUrl: %BASEURL%
echo Machines: %MACHINES%
echo.

powershell -ExecutionPolicy Bypass -Command "& { $machArray = '%MACHINES%'.Split(','); .\scripts\Get-OeeReport.ps1 -BaseUrl '%BASEURL%' -Machines $machArray }"

echo.
pause