@echo off
setlocal

set "DEFAULT_PATH=%~dp0scripts"
set "DEFAULT_TEST_PATH=%~dp0scripts\tests"

echo.
set /p SCAN_PATH="Sciezka do analizy [%DEFAULT_PATH%]: "
if "%SCAN_PATH%"=="" set "SCAN_PATH=%DEFAULT_PATH%"

set /p TEST_PATH="Sciezka do testow [%DEFAULT_TEST_PATH%]: "
if "%TEST_PATH%"=="" set "TEST_PATH=%DEFAULT_TEST_PATH%"

echo.
echo Uruchamianie analizy statycznej i testow Pester...
echo Sciezka: %SCAN_PATH%
echo Testy:   %TEST_PATH%
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Invoke-StaticAnalysis.ps1" ^
    -Path "%SCAN_PATH%" ^
    -TestPath "%TEST_PATH%"

echo.
pause
