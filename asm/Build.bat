@echo off

set "REFERENCE_PATH=RefNoLabels\cybernoid-tap.tap"
set "OUTPUT_FILE=cybernoid.tap"

:: ----------------------------------------------------------------------------------
:: Delete the old TAP file to prevent accidental reuse if assembly fails
:: ----------------------------------------------------------------------------------
if exist "%OUTPUT_FILE%" del "%OUTPUT_FILE%"

:: ----------------------------------------------------------------------------------
:: Assemble the source file to generate "cybernoid.tap" & "cybernoid.lst"
:: ----------------------------------------------------------------------------------
zasm-tool\zasm.exe --z80 --opcodes --labels --cycles cybernoid.asm

echo.

:: ----------------------------------------
:: Compare the new tap with the reference 
:: ------------------------------------------
fc /b "%OUTPUT_FILE%" "%REFERENCE_PATH%" >nul

if %errorlevel% equ 0 (
    echo     [SUCCESS] Binary matches reference
    echo     --------------------------------
    echo       Build Validation Successful  
    echo     --------------------------------
    color 0A
) else (
    echo     [FAILURE] Binary mismatch detected!
    color 0C
)

echo.
echo.
pause
