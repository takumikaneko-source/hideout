@echo off
chcp 65001 >nul
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set "PYEXE="
for /f "delims=" %%P in ('dir /b /s "%LOCALAPPDATA%\Programs\Python\python.exe" 2^>nul') do set "PYEXE=%%P"
if not defined PYEXE for /f "delims=" %%P in ('dir /b /s "%ProgramFiles%\Python*\python.exe" 2^>nul') do set "PYEXE=%%P"
if not defined PYEXE (where py >nul 2>nul && (set "PYEXE=py") || (set "PYEXE=python"))
if not defined PYEXE (
  echo [ERROR] Python not found. Install Python from https://www.python.org/ and retry.
  pause
  exit /b 1
)
"%PYEXE%" program\env_check.py
echo.
echo   Finished. Press any key to close.
pause >nul
