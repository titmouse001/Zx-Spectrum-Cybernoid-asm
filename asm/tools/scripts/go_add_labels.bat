:: note: "\RefNoLabels\cybernoid-tap.asm" 
::	is the starting point with hardcoded 
:: 	jump points we will need to analyse here.
:: outputs: labels-cybernoid-tap.asm

if not exist "outputs" mkdir "outputs"
python add_labels.py ..\..\reference\cybernoid-tap.zasm outputs\labels-cybernoid-tap.asm

pause