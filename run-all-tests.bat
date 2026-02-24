@echo off
REM ============================================================
REM  Docker Enterprise Security Validation Suite
REM  Windows CMD Launcher - runs bash tests via WSL2
REM ============================================================

echo ============================================================
echo  Docker Enterprise Security Validation Suite
echo  Windows CMD Launcher
echo ============================================================
echo.

REM Check Docker Desktop is accessible
docker info >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Docker is not running or not accessible.
    echo.
    echo  Please ensure:
    echo   1. Docker Desktop is installed and running
    echo   2. WSL2 integration is enabled:
    echo      Docker Desktop -^> Settings -^> Resources -^> WSL Integration
    echo.
    pause
    exit /b 1
)
echo [OK] Docker Desktop detected
echo.

REM Check WSL is available
wsl --status >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] WSL2 is not available.
    echo.
    echo  Install WSL2 by running in PowerShell as Administrator:
    echo    wsl --install
    echo.
    pause
    exit /b 1
)
echo [OK] WSL2 detected
echo.

echo Running security validation tests via WSL2...
echo ============================================================
echo.

REM Run the bash test suite via WSL2.
REM WSL automatically translates the Windows working directory.
wsl bash run-all-tests.sh
set EXIT_CODE=%ERRORLEVEL%

echo.
echo ============================================================
if %EXIT_CODE% EQU 0 (
    echo  ALL TESTS PASSED
) else (
    echo  SOME TESTS FAILED - review output above
)
echo ============================================================
echo.
pause
exit /b %EXIT_CODE%
