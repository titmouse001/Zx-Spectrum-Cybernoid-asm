:: outputs: "cybernoid.tap" & "cybernoid.lst"
:: note: "cybernoid.lst" is a nice to have with extra details like clock cycles []

@if exist cybernoid-tap.tap del cybernoid-tap.tap
zasm-tool\zasm.exe --z80 --opcodes --labels --cycles  cybernoid.asm

:: No making any changes yet - make sure the reworking anything 
:: hardcoded is still the same binary is still the same.
fc /b cybernoid.tap RefNoLabels/cybernoid-tap.tap

pause


