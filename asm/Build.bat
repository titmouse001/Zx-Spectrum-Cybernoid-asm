:: outputs: "cybernoid-tap.tap" & "cybernoid-tap.lst"
:: note: "cybernoid-tap.lst" is a nice to have with extra details like clock cycles []

@if exist cybernoid-tap.tap del cybernoid-tap.tap

zasm-tool\zasm.exe --z80 --opcodes --labels --cycles  cybernoid-tap.asm
pause


