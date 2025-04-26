@echo off
setlocal enabledelayedexpansion

set "REFERENCE_PATH=..\reference\cybernoid-tap.tap"
set "OUTPUT_FILE=cybernoid.tap"
set "OUTPUT_DIR=outputs"

:: ----------------------------------------------------------------------------------
:: Setup output directory
:: ----------------------------------------------------------------------------------
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: ----------------------------------------------------------------------------------
:: Delete old output file
:: ----------------------------------------------------------------------------------
if exist "%OUTPUT_DIR%\%OUTPUT_FILE%" del "%OUTPUT_DIR%\%OUTPUT_FILE%"

:: ----------------------------------------------------------------------------------
:: Assemble the source
:: ----------------------------------------------------------------------------------
..\tools\zasm-tool\zasm.exe --z80 --opcodes --labels --cycles cybernoid.asm

:: Check if assembler failed
if errorlevel 1 (
    echo [ERROR] Assembly failed. Skipping comparison.
    color 0C
    pause
    exit /b
)

:: ----------------------------------------------------------------------------------
:: Move output files (if needed)
:: ----------------------------------------------------------------------------------
move /Y "%OUTPUT_FILE%" "%OUTPUT_DIR%\%OUTPUT_FILE%" >nul
move /Y "cybernoid.lst" "%OUTPUT_DIR%\cybernoid.lst" >nul

echo.

:: ----------------------------------------------------------------------------------
:: Compare the new TAP with the reference
:: ----------------------------------------------------------------------------------
fc /b "%OUTPUT_DIR%\%OUTPUT_FILE%" "%REFERENCE_PATH%" >nul

if %errorlevel% equ 0 (
    echo     [SUCCESS] Binary matches reference
    echo     --------------------------------
    echo       Build Validation Successful  
    echo     --------------------------------
    color 0A
) else (
    echo [FAILURE] Binary mismatch detected!
    fc /b "%OUTPUT_DIR%\%OUTPUT_FILE%" "%REFERENCE_PATH%"
    echo ^(ignore the "0000BAAA:" checksum line^)
    color 0C
)

echo.
echo.
pause
