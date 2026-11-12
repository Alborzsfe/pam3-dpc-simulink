@echo off
cd /d "%~dp0"
py -3 -m venv .venv
if errorlevel 1 goto fail
.venv\Scripts\python.exe -m pip install -r requirements.txt
if errorlevel 1 goto fail
.venv\Scripts\python.exe -m unittest discover -s tests -v
if errorlevel 1 goto fail
.venv\Scripts\python.exe run_simulation.py
if errorlevel 1 goto fail
.venv\Scripts\python.exe make_report.py
if errorlevel 1 goto fail
start "" PAM3_Results.html
pause
exit /b
:fail
echo Reproduction failed. Read the error above.
pause
