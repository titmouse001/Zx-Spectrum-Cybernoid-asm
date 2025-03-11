@echo off
:: Outputs: "cybernoid.tap" & "cybernoid.lst"
:: Note: "cybernoid.lst" is a nice-to-have with extra details like clock cycles []

@if exist cybernoid.tap del cybernoid.tap
zasm-tool\zasm.exe --z80 --opcodes --labels --cycles cybernoid.asm

:: No making any changes yet - ensure that reworking anything still produces the same binary.
fc /b cybernoid.tap RefNoLabels/cybernoid-tap.tap >nul
if %errorlevel% equ 0 (
    echo All good! Binary matches reference.
) else (
    echo FAILED: Binary does not match reference!
)

pause
