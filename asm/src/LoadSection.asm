; This file handles the BASIC loading part
;-----------------------------------------------------
; 10 BORDER 0: PAPER 0: INK 7: CLEAR 24835
; 20 LOAD "" CODE SCREEN$: PAUSE 0		
; 30 LOAD "" CODE 24835		
; 40 RANDOMIZE USR 25860	
;-----------------------------------------------------

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


; BASIC Program Header
#code		PROG_HEADER,0,17,HEADERFLAG	; declare code segment

			defb 0							; Program
			defm "cybernoid "				; Pad to 10 chars
			defw PROGRAM1END
			defw 10							; BASIC Line number for autostart
			defw PROGRAM1END    			; length of BASIC program without variables

; BASIC Program
#code		PROG_DATA,0,*,DATAFLAG	; declare code segment

; 10 BORDER 0: PAPER 0: INK 7: CLEAR 24835	; $6103
			defb 0,10   					; line number
			defb L10END-($+1)				; line length
			defb 0							; statement number
			defb KWRDBORDER					; token BORDER
        	defm "0",$0e0000000000   		; number 0, ascii & internal format
			defb ':'
			defb KWRDPAPER					; token PAPER
        	defm "0",$0e0000000000  		; number 0, ascii & internal format
			defb ':'
			defb KWRDINK					; token INK
        	defm "7",$0e0000070000   		; number 7, ascii & internal format
 			defb ':'
        	defb KWRDCLEAR					; token CLEAR
        	defm "24835",$0e0000036100   	; number 24835, ascii & internal format
L10END		defb $0D						; line end marker

; 20 LOAD "" CODE SCREEN$: PAUSE 0					; $4000
			defb 0,20								; line number
			defb L20END-($+1)						; line length
			defb 0									; statement number
			defb KWRDLOAD,'"','"',KWRDSCREENSTR     ; token LOAD, 2 quotes, token SCREEN$
 			defb ':'
        	defb KWRDPAUSE							; token PAUSE
        	defm "0",$0e0000000000  				; number 0, ascii & internal format
L20END		defb $0D								; line end marker

; 30 LOAD "" CODE 24835						; $6103
			defb 0,30						; line number
			defb L30END-($+1)				; line length
			defb 0							; statement number
			defb KWRDLOAD,'"','"',KWRDCODE 	; token LOAD, 2 quotes, token CODE
        	defm "24835",$0e0000036100  	; number 24835, ascii & internal format
L30END		defb $0D						; line end marker

; 40 RANDOMIZE USR 25860				; **** CODE START AT: $6504 (MAIN:)****
			defb 0,40					; line number
			defb L40END-($+1)			; line length
			defb 0						; statement number
			defb KWRDRANDOMIZE,KWRDUSR	; token RANDOMIZE, token USR
        	defm "25860",$0e0000046500	; number 25860, ascii & internal format
L40END		defb $0D                    ; line end marker

PROGRAM1END equ $

; Code Block 1 Header - loading screen header
#code		CODE_HEADER,0,17,HEADERFLAG	; declare code segment

CODE1START	equ $4000					; $4000, 16384
			defb 3						; Code
			defm "cybernoid "			; Pad to 10 chars
			defw CODE1END-CODE1START	; Length
			defw CODE1START				; Code Start Address
			defw 0						; Unused

;-----------------------------------------------------------------------------
; Code Block 1 Data - loading screen data
#code		CODE_DATA,CODE1START,$1B00,DATAFLAG	; declare code segment
; ====================================================
#include "loading-screen.asm"  ; uses 0x4000 -> 0x5AFF
; ====================================================
CODE1END equ $ ; Marker to show end of object code

;-----------------------------------------------------------------------------
; note: startup code will clear $5B00 to $6503
;-----------------------------------------------------------------------------
; Code Block 2 Header - game code
#code		header2,0,17,HEADERFLAG	; declare code segment
CODE2START	equ $6103					;
			defb 3             			; Code
			defm "cybernoid "			; Pad to 10 chars
			defw CODE2END-CODE2START	; Length 4405 $1135
			defw CODE2START				; Code Start Address
			defw 0              		; Unused

; Code Block 2 Data - game code 
#code		codeblock2,CODE2START,*,DATAFLAG	; declare code segment

