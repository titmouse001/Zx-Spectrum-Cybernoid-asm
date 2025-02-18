; ZX Spectrum 48K 'Sinclair BASIC' tokenized keywords
; Example KWRDUSR = "USR" function (calls a machine code routine)
KWRDSCREENSTR	equ	$AA	
KWRDAT			equ	$AC
KWRDCODE		equ	$AF
KWRDVAL			equ	$B0
KWRDEXP			equ	$B9
KWRDUSR			equ	$C0
KWRDLINE		equ	$CA
KWRDCAT			equ	$CF
KWRDBEEP		equ	$D7
KWRDINK			equ	$D9
KWRDPAPER		equ	$DA
KWRDBRIGHT		equ	$DC
KWRDLPRINT		equ	$E0
KWRDSTOP		equ	$E2
KWRDREAD		equ	$E3
KWRDDATA		equ	$E4
KWRDRESTORE		equ	$E5
KWRDBORDER		equ	$E7
KWRDREM			equ	$EA
KWRDLOAD		equ	$EF
KWRDPAUSE		equ	$F2
KWRDPOKE		equ	$F4
KWRDPRINT		equ	$F5
KWRDRANDOMIZE	equ	$F9
KWRDCLS			equ	$FB
KWRDCLEAR		equ	$FD

; ZX Spectrum tape file flags
HEADERFLAG		equ $00 
DATAFLAG		equ $FF
