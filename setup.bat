@echo off
rem One-step setup of the UCEA "cea" environment on Windows.
rem Run from an Anaconda/Miniforge Prompt in the repo root:  setup.bat
setlocal

set "ENV_NAME=cea"
set "REPO_DIR=%~dp0"
if "%REPO_DIR:~-1%"=="\" set "REPO_DIR=%REPO_DIR:~0,-1%"
set "CONSTRAINTS=%REPO_DIR%\constraints.txt"
set "GPKG=%REPO_DIR%\cea\resources\radiation\INE_com_NPAV_norm0.gpkg"
set "WEIGHTS=%REPO_DIR%\ultralytics\best.pt"

where conda >nul 2>&1 || (echo conda not found. Run this from an Anaconda or Miniforge Prompt. & exit /b 1)

echo.
echo ==^> Checking conda-lock
call conda run -n base conda-lock --version >nul 2>&1
if errorlevel 1 (
    call conda install -y -n base -c conda-forge conda-lock || goto :fail
)

echo.
echo ==^> Creating the "%ENV_NAME%" environment from conda-lock.yml
call conda env list | findstr /b /c:"%ENV_NAME% " >nul
if not errorlevel 1 (
    echo Environment "%ENV_NAME%" already exists, skipping. Remove it with: conda env remove -n %ENV_NAME%
) else (
    call conda run -n base --no-capture-output conda-lock install --name %ENV_NAME% "%REPO_DIR%\conda-lock.yml" || goto :fail
)

echo.
echo ==^> Installing PyTorch (CPU build from PyPI)
call conda run -n %ENV_NAME% --no-capture-output python -m pip install torch torchvision -c "%CONSTRAINTS%" || goto :fail

echo.
echo ==^> Installing UCEA and its bundled ultralytics copy
call conda run -n %ENV_NAME% python -m pip uninstall -y ultralytics >nul 2>&1
call conda run -n %ENV_NAME% --no-capture-output python -m pip install -e "%REPO_DIR%" -e "%REPO_DIR%\ultralytics" -c "%CONSTRAINTS%" || goto :fail

echo.
echo ==^> Checking data files
set "MISSING=0"
if not exist "%WEIGHTS%" (echo MISSING: %WEIGHTS% ^(YOLO roof weights^) & set "MISSING=1")
if not exist "%GPKG%" (echo MISSING: %GPKG% ^(download from the SharePoint link in the README^) & set "MISSING=1")

echo.
echo ==^> Verifying
call conda run -n %ENV_NAME% --no-capture-output python -c "import numpy, cv2, torch, torchvision, ultralytics; print('numpy', numpy.__version__, '| opencv', cv2.__version__, '| torch', torch.__version__, '| torchvision', torchvision.__version__); print('ultralytics from', ultralytics.__file__)" || goto :fail
if exist "%WEIGHTS%" (
    call conda run -n %ENV_NAME% --no-capture-output python -c "from ultralytics import YOLO; print('model task:', YOLO(r'%WEIGHTS%').task)" || goto :fail
)

echo.
if "%MISSING%"=="0" (
    echo Done. Run: conda activate %ENV_NAME% ^&^& cea ucea --scenario "C:\ucea_runs\<name>"
) else (
    echo Environment ready, but add the missing files above before running cea ucea.
)
exit /b 0

:fail
echo.
echo Setup failed at the step above.
exit /b 1
