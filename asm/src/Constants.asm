ROM48K_ADDRESS         EQU $386E	; 48K Speccy ROM holds $FF here	


; ********************************
; *** Sound Effect Definitions ***
; ********************************
; (E=SFX,CALL PLAY_SFX)
SFX_SHIELD				EQU 22
SFX_SEEKER				EQU 23
SFX_MISSILE				EQU 24
SFX_PICKUP				EQU 25
SFX_BULLETS				EQU 26
SFX_EXPLODEA			EQU 27
SFX_BOUNCE1				EQU 28
SFX_BOUNCE2				EQU 29
SFX_LARGEEXPLODE		EQU 30
SFX_MINE				EQU 31
SFX_EXPLODEB			EQU 32
SFX_MACEHIT				EQU 33
SFX_GAMEOVER			EQU 34
SFX_HISCORE				EQU 40

;----------------------------
; Weapon Item Index (Index into 'SPRITE24x16_DATA' graphics)
WEAPON_ITEM_BACKSHOT_L    EQU 7
WEAPON_ITEM_BACKSHOT_R    EQU 8
WEAPON_ITEM_MACE          EQU 17  ; Also used as seeker
;-----------------------------

;-----------------------------------------
; ******************************
; *** Draw List Definitions  ***
; ******************************
;
; Command Definitions 
MOVE				EQU $78		; Base value for relative moves ($79-$8F)
SET_POS				EQU $DF		; Set absolute position (Y,X)
GLOBAL_COL			EQU $E0		; Set global color attribute (paper + default ink)
SET_SOURCE_DATA		EQU $E6		; Patch icon source address (L,H)
SETUP				EQU $EB		; Configure rendering routine via lookup table
END_MARKER			EQU $FF		; End of draw list

; Ink Colors  (these are bright variants using +8)
INK_BLACK			EQU $CF+0+8	
INK_BLUE			EQU $CF+1+8	
INK_RED				EQU $CF+2+8	
INK_PURPLE			EQU $CF+3+8
INK_GREEN			EQU $CF+4+8
INK_CYAN			EQU $CF+5+8
INK_YELLOW			EQU $CF+6+8
INK_WHITE			EQU $CF+7+8

;-----------------------------------------

; Animated Sprite Structure (10 bytes per sprite)
Xpos                EQU $00     ; [byte] Bits 0-6=Sprite ID, 7=end-of-list
Ypos                EQU $01     ; [byte] Animation Frame
StartingFrameLow    EQU $02     ; [word] For frame reset
StartingFrameHigh   EQU $03     ; 
FrameLow            EQU $04     ; [word] Current frame
FrameHigh           EQU $05     ; 
TileGfxLow          EQU $06     ; [byte] Graphics data
TileGfxHigh         EQU $07     ; [byte] 
InitCounter         EQU $08      ; [byte] Initial delay between frames
Counter             EQU $09     ; [byte] Current countdown to next frame

;-----------------------------------------

; AY Music Definitions
envelope_step       EQU ENVELOPE_STEP-ENVELOPE_STEP		; +$00	
envelope_substep    EQU ENVELOPE_SUBSTEP-ENVELOPE_STEP  ; +$01
env_phase           EQU ENV_PHASE-ENVELOPE_STEP  		; +$02	
reserved	        EQU RESERVED-ENVELOPE_STEP         	; +$03	
env_data_ptr        EQU ENV_DATA_PTR-ENVELOPE_STEP      ; +$04 (2)
env_base_speed      EQU ENV_BASE_SPEED-ENVELOPE_STEP    ; +$06
env_speed_mod       EQU ENV_SPEED_MOD-ENVELOPE_STEP    	; +$07
env_loop_counter    EQU ENV_LOOP_COUNTER-ENVELOPE_STEP  ; +$08	
reserved_09         EQU RESERVED_09-ENVELOPE_STEP  		; +$09
arp_index           EQU ARP_INDEX-ENVELOPE_STEP     	; +$0A	
arp_speed           EQU ARP_SPEED-ENVELOPE_STEP         ; +$0B
vibrato_depth       EQU VIBRATO_DEPTH-ENVELOPE_STEP     ; +$0C 
vibrato_speed       EQU VIBRATO_SPEED-ENVELOPE_STEP     ; +$0D 
portamento_target   EQU PORTAMENTO_TARGET-ENVELOPE_STEP ; +$0E
portamento_speed    EQU PORTAMENTO_SPEED-ENVELOPE_STEP 	; +$0F
ch_status           EQU CH_STATUS-ENVELOPE_STEP  		; +$10	
duration_counter    EQU DURATION_COUNTER-ENVELOPE_STEP  ; +$11
current_data_ptr    EQU CURRENT_DATA_PTR-ENVELOPE_STEP 	; +$12 (2)
loop_start_ptr      EQU LOOP_START_PTR-ENVELOPE_STEP  	; +$14 (2)
phrase_start_ptr    EQU PHRASE_START_PTR-ENVELOPE_STEP  ; +$16 (2)
transposition       EQU TRANSPOSITION-ENVELOPE_STEP		; +$18
env_override_flag   EQU ENV_OVERRIDE_FLAG-ENVELOPE_STEP	; +$19
custom_env_ptr      EQU CUSTOM_ENV_PTR-ENVELOPE_STEP	; +$1A (2)
tone_register_ptr   EQU TONE_REGISTER_PTR-ENVELOPE_STEP	; +$1C (2)
env_release_rate    EQU ENV_RELEASE_RATE-ENVELOPE_STEP	; +$1E
reserved_1F         EQU RESERVED_1F-ENVELOPE_STEP 		; +$1F
vibrato_control     EQU VIBRATO_CONTROL-ENVELOPE_STEP   ; +$20
vol_fade_speed      EQU VOL_FADE_SPEED-ENVELOPE_STEP	; +$21
vol_fade_target     EQU VOL_FADE_TARGET-ENVELOPE_STEP 	; +$22

;-----------------------------------------

