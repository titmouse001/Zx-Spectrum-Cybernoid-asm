; Cybernoid Game (C) 1988 Hewson Consultants Ltd
; For original credits, see "RefNoLabels/cybernoid-tap.asm"
;
;------------------------------------------------------------------
#target		tap					; Output: Build file format
#include 	"LoadSection.asm"	; basic load part	
#include 	"Constants.asm"
;------------------------------------------------------------------

			;--------------------------------------------------------------------------
			; Note: $6103-$6503 is cleared early at startup
			;--------------------------------------------------------------------------
			; $6300-6400 is the game's screen Ypos lookup table (initialied at statup)
			; High byte table $6400
			;  Low byte table $6300
			;--------------------------------------------------------------------------
			; Technical Note: The game uses XOR drawing for a more flicker-free sprite ERASURE by 
			; simply redrawing the sprite at the same position (no need to store/restore backgrounds)
			    
			defb $3E										; $6103
			defs $619A-$6104,0								; $6104-$6199
			defb $DB,$02,$4D,$00,$04,$65,$00,$00,$03		; $619A
			defb $65,$28,$FE,$1C,$5B						; $61A3
			defs $64FE-$61A5,0								; $61A8-$6500
L_6501:		defb $00,$00,$00                                ; $6501

			; ----------------------------------------------------------------------
			; Entry point – Game execution starts here
MAIN:		DI                  	   		; $6504  ; <- Called by BASIC
			LD SP, $0000				    ; $6505  ; Initialize stack pointer	
			CALL SETUP_IM2_JUMP_TABLE		; $6508  ; Set up Interrupt Mode 2 (IM2)
			; ----------------------------------------------------------------------		
			; Clear memory from $5B00 to $6503 (area after screen) 
			LD HL,$5B00					; $650B
			LD DE,$5B01					; $650E
			LD (HL),$00					; $6511
			LD BC,$6503-$5B00			; $6513  ; Bytes to clear
			LDIR						; $6516  ; Block fill with zero
			; ------------------------------------------------
			XOR A						; $6518 ; Zero reset
			LD (MODE48K),A				; $6519
			LD (SELECTED_WEAPON),A		; $651C	
			OUT ($FE),A					; $651F ; border black
			; ----------------------------------------------------------------
			; Check Speccy model (48K or 128K) to enable AY music flag
			LD A,(ROM48K_ADDRESS)		; $6521	; 48K ROM: holds $FF here
			SUB $FF						; $6524	; 
			JR Z, IS_48K				; $6526	; A=0, use 48K setup 
			LD A, $01					; $6528	; Assume 128K (with AY chip)
IS_48K:		LD (SPECCY_MODEL), A			; $652A	; default 0 (48K) or 1 (128K)
			OR A						; $652D	; 
			JP NZ, SKIP_48K_SETUP		; $652E	; Skip 48K setup
			;------------------------------------------------------------
			; 48K Speccy setup - Disable AY Music (128k machine) 
			LD A, $C9					; $6531	; $C9=RET, for self-modifying code
			LD (AY_MUSIC), A			; $6533	; Modify code to use "RET"
			LD (AY_RESET_MUSIC), A		; $6536	; Modify code to use "RET"
			LD (PLAY_SFX), A			; $6539	; Modify code to use "RET"
			CALL BEEPER_SETUP			; $653C	; 48K setup
			; -----------------------------------------------------------
SKIP_48K_SETUP:	
			CALL AY_RESET_MUSIC				; $653F
			LD E,$01						; $6542
			CALL PLAY_SFX					; $6544
			EI								; $6547

			CALL L_7BFC						; $6548
			CALL INIT_MENU_SCREEN_TABLES	; $654B  
			CALL DO_MENU					; $654E  
			CALL INIT_GAME_SCREEN_TABLES	; $6551
			LD A,$04						; $6554	 	; starting lives)
			LD (LIVES),A					; $6556		; store lives
			LD HL,$78F9						; $6559
			LD DE,$78FA						; $655C
			LD BC,$0005						; $655F
			LD (HL),$30						; $6562
			LDIR							; $6564
			XOR A							; $6566
			CALL RESET_GAME					; $6567

INGAME_LOOP: 
	
	;***************************
;	NOP
;	ld a,1
;	ld (BACKSHOT_ENABLE),a
	;***************************

			; ----------------------------------------------------------------------
			; Limit frame rate to 25FPS
			LD A,(FRAME_COUNTER) 		; $656A	 ; (Background interrupt updates this counter)
			CP $02						; $656D  ; spot every other frame
			JR NC,GO_25FPS				; $656F
			JP INGAME_LOOP				; $6571
GO_25FPS:	XOR A						; $6574  ; reset for next 25FPS test
			LD (FRAME_COUNTER),A  		; $6575
			; ----------------------------------------------------------------------
			LD HL,GAME_COUNTER_8BIT		; $6578
			INC (HL)					; $657B	 ; Timing counter (byte wraps)
			; ----------------------------------------------------------------------
			LD HL,SPRITE_LIST			; $657C
			LD (HL),$FF					; $657F ; Next item as END-MARKER
			LD (SPRITE_LIST_PTR),HL		; $6581 ; Next item is then First location to read 
			; ----------------------------------------------------------------------
			CALL USER_INPUT				; $6584 	; Store user inputs using QAOP or Joystick
			CALL MOVE_SHIP				; $6587		; Move player's ship
			CALL END_LEVEL				; $658A		; Detects End-Level platform
			CALL DO_PLR_SHOOTING			; $658D 	; Fire New Shots + SFX

			CALL PLR_UPDATE_SHOTS		; $6590 	; move player shots
			CALL UPDATE_PLR_BOMBS		; $6593		; move player bombs (rockets)
			CALL SELECT_PLR_WEAPON  	; $6596 	; Player weapon slection using 1-5 keys
			CALL FIRE_SUPER_WEAPONS		; $6599  	; Activate any super weapons (driven by table-of-functions)
			CALL DEBRIS_SPRITES			; $659C		; Volcanoes, Trails
			CALL ANIMATE_SPRITE			; $659F		; animated icons (pump)
			CALL BONUS_TEXT				; $65A2		; bonus scores, like "250" on big items 
			CALL UPDATE_BOUNCY_BALLS	; $65A5		; Player super weapon launches 4 bouncing balls
			CALL TIMEOUT_BOUNCY_BALLS	; $65A8		; Lifetime of weapon
			CALL DRAW_TRACER_EFFECT		; $65AB  	; Tracer effect (mace,bombs)		
			
			CALL EXPLOSION_CLUSTER		; $65AE  	; explosions + sound 
			CALL DO_EXPLOSIONS			; $65B1		; Draw explosions with random colours

			CALL VOLCANO_EJECTA			; $65B4  	;  Volcano Ejecta
			CALL STATIC_ENEMY_GUNS		; $65B7		; Enemy static guns (plant,ball turret)
			CALL DRAW_ENEMY_SHOTS		; $65BA		; Enemies shoot + shots hit scene with sparkle
			CALL LANE_GUARDIANS			; $65BD		; Enemy Tunnel Aliens
			CALL SNAKES					; $65C0		; Enemy snakes
			CALL PROXIMITY_ROCKET		; $65C3		; Trigger Launch - Enemy scene rockets
			CALL DO_ROCKET				; $65C6		; Move & check against scene
			CALL ENEMY_SHIPS			; $65C9		; flying Enemies
			CALL DRAW_ENEMY_SHIPS		; $65CC		; Draw Flying Enemies
			CALL DRAW_PICKUPS			; $65CF		; Draw PickUps (mace, rear gun)
			CALL DO_SEEKER				; $65D2		; Draw
			CALL DO_PICKUPS				; $65D5		; logic for all pickups (mace, gems...)
			CALL PLAYER_COLLISION		; $65D8		; Player collision
	;	NOP
	;	NOP
	;	NOP
			CALL DO_MINES				; $65DB     ; check mines
			CALL DO_EGG_TIMER			; $65DE		; Games countdown timer
			CALL INGAME_RESET			; $65E1
			CALL PAUSE_GAME				; $65E4
		JP INGAME_LOOP					; $65E7

GAME_COUNTER_8BIT:	defb 0					; $65EA  ; timing (hold delay when firing bombs (rockets))

; This pause section confused me, then I read the 1988 game manual :)
; (btw: original disasembly used hex for the AND test, changed to binary)
; Games Manual Says:
;"Pause - Press CAPS SHIFT & SYMBOL SHIFT" 
PAUSE_GAME: LD A,$FE				; $65EB
			IN A,($FE)				; $65ED
			AND %00000001			; $65EF  ; shift key
			RET NZ					; $65F1
			LD A,$7F				; $65F2
			IN A,($FE)				; $65F4  
			AND %00000010			; $65F6  ; Symbol shift key
			RET NZ					; $65F8

			; This next WAIT_21xBC is not really needed here
			LD BC,$01F4				; $65F9  
			CALL WAIT_21xBC			; $65FC

L_65FF:		CALL ANY_KEY_DOWN		; $65FF  ; all keys released
			JR NZ,L_65FF			; $6602
	
L_6604:		CALL GET_KEY			; $6604  ; pause - wait for key press
			OR A					; $6607
			JR Z,L_6604				; $6608
			RET						; $660A

;----------------------------------------------------
INGAME_RESET:	; press "1,2,3,4,5" to reset ingame
			LD A,$F7				; $660B
			IN A,($FE)				; $660D
			AND $1F					; $660F
			RET NZ					; $6611
			JP MAIN					; $6612
;----------------------------------------------------

; Developer feature - yet to find the other code half
LEVEL_SELECTOR_DRAW_LIST:
			defb $E6,$F1,$C2,$DF,$0A,$0A                        ; $6615 ......
			defb $E0,$45,$57,$48,$49,$43,$48,$20				; $661B .EWHICH 
			defb $4C,$45,$56,$45,$4C,$20,$3F,$FF				; $6623 LEVEL ?.


; NOTE: Reading Keyboard Ports, for example "A=$FE then IN A,($FE)"
; 		A zero in one of the five lowest bits means that the corresponding key is pressed.
GET_KEY:    PUSH    BC            
            PUSH    HL              
            LD      HL, KeyTable    
            LD      D, $FE          ; 1st Port to read
LoopSetup:  LD      A, D            
Loop:       IN      A, ($FE)        ; Read key state
            LD      E, $01          ; Bitmask for key check
            LD      B, $05          ; 5 bits (keys) in each row

CheckKey:   RRCA                    ; 
            JR      NC, KeyPressed  ; key down (bit checked is zero)
            INC     HL              ; next lookup
			SLA     E         		; move test mask
            DJNZ    CheckKey        

            RLC     D               ; next port row to read ($FD,$FB...)
            JR      C, LoopSetup
KeyPressed: LD      A, (HL)         ; get char value from table
            POP     HL            
            POP     BC              
            RET                  

KeyTable:	; Key row mapping  ; $6649
			; $01=shift, ; $0D=enter, $20=space, $02=sym shft
			defb $01,"ZXCV"			
			defb "ASDFG"
			defb "QWERT"
			defb "12345"
			defb "09876"
			defb "POIUY"
			defb $0D,"LKJH"   		
			defb $20,$02,"MNB" 
			defb $0	; tables end marker

; -------------------------------------------------------------
; $00FE (undocumented) - Unlike $7FFE (which detects keys 1,2,3,4 & 5 when A=$7F),
; this port appears to show if *any* key is pressed.
; 
; Returns key status in A: 
;   0 = at least one key is pressed
;   1 = no keys are pressed
;
ANY_KEY_DOWN:   XOR A    ; $6672  ; A==0, Not a valid port, but works!
          IN A,($FE)     ; $6673  ; Read keyboard
          CPL            ; $6675  ; Invert bits (active low input)
          AND $1F        ; $6676  ; Mask to check any of the 5 lowest bits
          RET            ; $6678  ;

; The hardware seems to detect if *any* key is down, 
; but does not distinguish between the 8 half-rows (5 keys per row).
; -------------------------------------------------------------

; DATA_12 = (DATA_12 + 7) * 13 (mod 65536).

GET_RAND_VALUE:		
			PUSH HL				; $6679
			PUSH DE				; $667A
			PUSH BC				; $667B
			INC A				; $667C
			PUSH AF				; $667D
			LD HL,(RAND_STATE)				; $667E
			LD DE,$0007				; $6681
			ADD HL,DE				; $6684
			LD E,L				; $6685
			LD D,H				; $6686
			ADD HL,HL				; $6687
			ADD HL,HL				; $6688
			LD C,L				; $6689
			LD B,H				; $668A
			ADD HL,HL				; $668B
			ADD HL,BC				; $668C
			ADD HL,DE				; $668D
			LD (RAND_STATE),HL				; $668E
			LD A,L				; $6691
			XOR H				; $6692
			LD E,A				; $6693
			LD D,$00				; $6694
			POP AF				; $6696
			LD HL,$0000				; $6697
			LD B,$08				; $669A
L_669C:		ADD HL,HL				; $669C
			RLA				; $669D
			JR NC,L_66A1				; $669E
			ADD HL,DE				; $66A0
L_66A1:		DJNZ L_669C				; $66A1
			LD A,H				; $66A3
			POP BC				; $66A4
			POP DE				; $66A5
			POP HL				; $66A6
			RET				; $66A7

RAND_STATE:			defw 	$0000 	; $66A8

;---------------------------------------------------------------------
; Clear Screen (works backwards)
CLR_SCREEN:	
			LD C,$00				; $66AA
			LD HL,$5AFF				; $66AC
			LD DE,$5AFE				; $66AF
			LD (HL),C				; $66B2
			LD BC,$0300				; $66B3 ; Attribute memory
			LDDR					; $66B6
			LD (HL),$00				; $66B8
			LD BC,$17FF				; $66BA ; Screen bitmap
			LDDR					; $66BD
			RET						; $66BF
;---------------------------------------------------------------------

; future thing - this CLR_GAME_SCREEN could be more like above with 32 skipped, 
;				 maybe the game had borders at some point ?
CLR_GAME_SCREEN:		
			LD C,$00				; $66C0
			LD HL,$5880				; $66C2
			LD (HL),C				; $66C5
			LD DE,$5881				; $66C6
			LD BC,$027F				; $66C9
			LDIR					; $66CC
			LD HL,$4080				; $66CE
			LD B,$A0				; $66D1
CLR_SCR_LOOP:
			PUSH BC					; $66D3
			PUSH HL					; $66D4
			LD E,L					; $66D5
			LD D,H					; $66D6
			INC DE					; $66D7
			LD (HL),$00				; $66D8
			LD BC,$001F				; $66DA
			LDIR					; $66DD
			POP HL					; $66DF
			CALL NEXT_SCR_LINE		; $66E0
			POP BC					; $66E3
			DJNZ CLR_SCR_LOOP		; $66E4
			RET						; $66E6

INIT_GAME_SCREEN_TABLES:
			LD HL,$6300				; $66E7 ; CODE NEEDED ? LDIR section - why bother clearing
			LD (HL),$00				; $66EA
			LD DE,$6301				; $66EC
			LD BC,$001F				; $66EF ; 32 bytes
			LDIR					; $66F2 ; Zero-fill $6300-$631F
			LD HL,$6400				; $66F4 ; CODE NEEDED ? LDIR section - why bother clearing
			LD (HL),$00				; $66F70
			LD DE,$6401				; $66F9
			LD BC,$001F				; $66FC ; 32 bytes
			LDIR					; $66FF ; Zero-fill $6400-$641F
			LD IX,$6320				; $6701 ; data part (after header)
			LD IY,$6420				; $6705 ; data part (after header)
			LD HL,$4080				; $6709 ; 32 pixels for menu (not needed)
			LD B,$A0				; $670C ; 160 lines (192-32)
FILLOUT_INGAME_TABLE:
			LD (IX+$00),H			; $670E ; $6320 (IX)
			LD (IY+$00),L			; $6711 ; $6420 (IY) 
			CALL NEXT_SCR_LINE		; $6714	; Screen Address Calculation
			INC IX					; $6717
			INC IY					; $6719
			DJNZ FILLOUT_INGAME_TABLE		; $671B
			RET						; $671D

INIT_MENU_SCREEN_TABLES:		
			LD IX,$6300				; $671E  ; future thing - reacon just this table is needed for the whole game
			LD IY,$6400				; $6722  
			LD HL,$4000				; $6726  ; screen start
			LD B,$C0				; $6729  ; full screen 192
FILLOUT_MENU_TABLE:		
			LD (IX+$00),H			; $672B
			LD (IY+$00),L			; $672E
			CALL NEXT_SCR_LINE		; $6731
			INC IX					; $6734
			INC IY					; $6736
			DJNZ FILLOUT_MENU_TABLE	; $6738
			RET						; $673A

; This lookup sits in the 0x6300 range of contended memory.
; Speccy: 0x4000 to 0x7FFF is shared by display refresh and so will slow!
LOOKUP_6300_ADDR_OFFSET:		
			PUSH AF					; $673B
			LD L,D					; $673C
			LD H,$63				; $673D	 ; Base address
			LD A,(HL)				; $673F
			INC H					; $6740
			LD L,(HL)				; $6741
			LD H,A					; $6742
			LD A,E					; $6743
			AND $7C					; $6744  ; %01111100
			RRCA					; $6746
			RRCA					; $6747
			ADD A,L					; $6748
			LD L,A					; $6749
			POP AF					; $674A
			RET						; $674B

NEXT_SCR_LINE:
			INC H				; $674C
			LD A,H				; $674D
			AND $07				; $674E
			RET NZ				; $6750
			LD A,L				; $6751
			ADD A,$20			; $6752
			LD L,A				; $6754
			RET C				; $6755
			LD A,H				; $6756
			SUB $08				; $6757
			LD H,A				; $6759
			RET				; $675A

L_675B:
			LD A,H				; $675B
			DEC H				; $675C
			AND $07				; $675D
			RET NZ				; $675F
			LD A,L				; $6760
			SUB $20				; $6761
			LD L,A				; $6763
			RET C				; $6764
			LD A,H				; $6765
			ADD A,$08				; $6766
			LD H,A				; $6768
			RET				; $6769

WAIT_21xBC:   ; 21cycles x BC  (ignoring setup cost)
			PUSH BC				; $676A
			PUSH DE				; $676B
			PUSH HL				; $676C
			LD HL,$0000			; $676D
			LD DE,$0000			; $6770
			LDIR				; $6773
			POP HL				; $6775
			POP DE				; $6776
			POP BC				; $6777
			RET					; $6778


; Input: D = Y-coord, E = X-coord (repurposed from animation params)
; Output: HL = offset for color attribute address
GET_ANIM_ADDR:
			PUSH AF				; $6779
			PUSH DE				; $677A

			LD A,D				; $677B  ; 
			AND $F8				; $677C  ; Mask Y to 8-pixel row boundaries
			LD L,A				; $677E  ; L = coarse Y position
			LD H,$00			; $677F
			ADD HL,HL			; $6781  ; X2
			ADD HL,HL			; $6782  ; X4  (Y * 32 bytes per attribute row)
		
			LD A,E				; $6783  ; attriute X pos or Sprite index 
			AND $7C				; $6784  ; Mask X to 4-pixel column boundaries
			RRCA				; $6786  ; /2
			RRCA				; $6787  ; /4  (8 pixels per attribute column)
			LD E,A				; $6788
			LD D,$00			; $6789
			ADD HL,DE			; $678B   ; HL = offset within anim or attribute table
			POP DE				; $678C
			POP AF				; $678D
			RET					; $678E

GET_ANIM_ADDR_AS_HL:
			PUSH DE					; $678F
			CALL GET_ANIM_ADDR		; $6790   
			LD DE,$5F00				; $6793	 ; Base address of animation struct/pattern table
			ADD HL,DE				; $6796  ; Final address 
			POP DE					; $6797
			RET						; $6798

GET_ATTRIBUTE_AS_HL:
			PUSH DE					; $6799
			CALL GET_ANIM_ADDR		; $679A  ; HL=offset based on Y/X (seeing DE=$2000 before call)
			LD DE,$5800				; $679D  ; Spectrum color attribute base
			ADD HL,DE				; $67A0  ; HL=exact attribute address we are after from original x,y
			POP DE					; $67A1
			RET						; $67A2

L_67A3:
			PUSH DE				; $67A3
			CALL GET_ANIM_ADDR				; $67A4
			LD DE,$5B00				; $67A7
			ADD HL,DE				; $67AA
			POP DE				; $67AB
			RET				; $67AC

CLR_SCRN_ATTRIBUTES:
			LD HL,$5800				; $67AD
			LD DE,$5B00				; $67B0
			LD BC,$0300				; $67B3
			LDIR				; $67B6
			RET				; $67B8

L_67B9:
			PUSH AF				; $67B9
			PUSH BC				; $67BA
			PUSH HL				; $67BB
			PUSH IX				; $67BC
			ADD A,A				; $67BE
			ADD A,A				; $67BF
			LD L,A				; $67C0
			LD H,$00				; $67C1
			LD BC,TABLE_01				; $67C3
			ADD HL,BC				; $67C6
			PUSH HL				; $67C7
			POP IX				; $67C8
			LD A,(IX+$02)				; $67CA
			LD ($6805),A				; $67CD
			ADD A,(IX+$00)				; $67D0
			NEG				; $67D3
			INC A				; $67D5
			LD ($6807),A				; $67D6
			LD A,(IX+$03)				; $67D9
			LD ($680E),A				; $67DC
			ADD A,(IX+$01)				; $67DF
			NEG				; $67E2
			INC A				; $67E4
			LD ($6810),A				; $67E5
			POP IX				; $67E8
			POP HL				; $67EA
			POP BC				; $67EB
			POP AF				; $67EC
			RET				; $67ED

TABLE_01:
			defb $04,$08,$04,$08,$08                            ; $67EE .....
			defb $10,$08,$10,$08,$10,$04,$08,$08				; $67F3 ........
			defb $10,$01,$01,$00,$00,$08,$10                    ; $67FB .......

; Checks if (C=X, B=Y) is inside an 8×16 hitbox from (E=X, D=Y)
; Note: Games X valus are at 1/2 scale
COLLISION_DETECTION:
			LD A,E				; $6802 
			SUB C				; $6803
			SUB $08				; $6804
			CP $F0				; $6806
			LD A,$00			; $6808
			RET C				; $680A ; A==0 Ok
			LD A,D				; $680B
			SUB B				; $680C
			SUB $10				; $680D
			CP $E0				; $680F
			LD A,$00			; $6811
			RET C				; $6813
			INC A				; $6814  
			RET					; $6815  ; A=1 Collision

DEFAULT_KEYS:
			LD D,$01			; $6816 
			LD HL,$68A6			; $6818
			LD C,$FE			; $681B
			INC HL				; $681D
			LD B,$DF			; $681E	
			IN A,(C)			; $6820  ; Port $DFFE (Y, U, I, O, P)
			AND $02				; $6822  ; bit 1, "O" key
			JR NZ,L_6827		; $6824
			LD (HL),D			; $6826
L_6827:
			INC HL				; $6827
			LD B,$DF			; $6828 
			IN A,(C)			; $682A  ; Port $DFFE (Y, U, I, O, P):
			AND $01				; $682C  ; bit 0, "P" key. 
			JR NZ,L_6831		; $682E
			LD (HL),D			; $6830
L_6831:
			INC HL				; $6831
			LD B,$FB			; $6832  
			IN A,(C)			; $6834  ; Port $FBFE (Q, W, E, R, T)
			AND $01				; $6836  ; bit 0, "Q" key
			JR NZ,L_683B		; $6838
			LD (HL),D			; $683A
L_683B:
			INC HL				; $683B
			LD B,$7F			; $683C
			IN A,(C)			; $683E  ; Port $7FFE (B, N, M, Symbol Shift, Space)
			AND $01				; $6840  ; bit 0, Space key.
			RET NZ				; $6842
			LD (HL),D			; $6843
			RET					; $6844

INTERFACE2_JOY:
			LD BC,$EFFE			; $6845
			IN A,(C)			; $6848		 ; Port $EFFE keys 6, 7, 8, 9, 0 
			CPL					; $684A
			AND $1F				; $684B
			LD D,A				; $684D
			CALL GET_LSB		; $684E
			LD (FIRE_BUTTON),A	; $6851		; key "0"
			CALL GET_LSB		; $6854
			LD (UP_BUTTON),A	; $6857		; key "9"
			CALL GET_LSB		; $685A		; ignore down bit
			CALL GET_LSB		; $685D
			LD (RIGHT_BUTTON),A	; $6860		; key "7"
			CALL GET_LSB		; $6863
			LD (LEFT_BUTTON),A	; $6866		; key "6"
			RET					; $6869

; -----------------------------------------------------------------
; Kempston Joystick - Cybernoid does not use down.
;  7 6 5 4 3 2 1 0
;  0 0 0 1 1 1 1 1 (i.e $1F)
;  x x x F U D L R (fire,up,down,left,right)
KEMPSTON_JOYSTICK:		
			LD C,$1F				; $686A
			IN D,(C)				; $686C
			CALL GET_LSB				; $686E
			LD (RIGHT_BUTTON),A			; $6871
			CALL GET_LSB				; $6874
			LD (LEFT_BUTTON),A			; $6877
			CALL GET_LSB				; $687A
			CALL GET_LSB				; $687D
			LD (UP_BUTTON),A			; $6880
			CALL GET_LSB				; $6883
			LD (FIRE_BUTTON),A			; $6886
			RET						; $6889

; ------------------------
; GET_LSB - Helper Routine 
; Shifts D right, returns LSB in A.
; ------------------------
GET_LSB:	XOR A					; $688A
			SRL D					; $688B
			RLA						; $688D
			RET						; $688E
; ------------------------

USER_INPUT:	LD HL,$0000				; $688F
			LD (LEFT_BUTTON),HL		; $6892 ; clear keys
			LD (UP_BUTTON),HL		; $6895	; clear keys
			LD A,(INPUT_TYPE)		; $6898 
			OR A					; $689B
			JP Z,DEFAULT_KEYS		; $689C
			CP $01					; $689F
			JP Z,INTERFACE2_JOY		; $68A1 ; Alt Keys, $68AB = 1
			JP KEMPSTON_JOYSTICK	; $68A4

; ---------------------------------------------------------------------
; Games inputs via memory addresses
LEFT_BUTTON:	defb $0					; $68A7 ; Left 
RIGHT_BUTTON:	defb $0					; $68A8 ; Right 
UP_BUTTON		defb $0					; $68A9 ; Up 
FIRE_BUTTON:	defb $0					; $68AA ; Fire 
				; Stores 3 input methods - Keys, INTERFACE2 or joy
INPUT_TYPE:		defb $0					; $68AB ; 0,1 or joy
; ---------------------------------------------------------------------

MOVE_SHIP:  LD A,(INPUT_ENABLED)			; $68AC
			OR A					; $68AF
			RET NZ					; $68B0

			LD ($696F),A			; $68B1 ; zero
			LD DE,(POS_XY)			; $68B4 ; get E=x,D=y coords
			LD (POS_XY_COPY),DE		; $68B8 ; 
			LD HL,(LEFT_BUTTON)		; $68BC ; left/right button states

			; --- HORIZONTAL (X-AXIS) MOVEMENT ---
			LD A,H					; $68BF
			XOR L					; $68C0	 ; Check Left or Right pressed
			JR Z,DONE_X				; $68C1

			BIT 0,L					; $68C3
			JR NZ,MOVE_SHIP_LEFT	; $68C5  ; moves ship left

    		; Check we are facing left, change to right.
			LD A,(DIRECTION)		; $68C7  ; 
			CP $FF					; $68CA  ;  Make sure we are facing left
			LD A,$01				; $68CC  ;  $01 = RIGHT
			LD (DIRECTION),A		; $68CE  ;  set as Right
			JR NZ,MOVE_SHIP_RIGHT	; $68D1  ;  moves ship right
			LD (PLR_MOVEMENT_FLAG),A			; $68D3
			JP DONE_X				; $68D6
			; -----------------------------------------------------------
MOVE_SHIP_RIGHT:		
			LD A,E					; $68D9
			CP $78					; $68DA  ; Xpos (logical so 1/2 width) 
			CALL Z,UPDATE_SCENE		; $68DC  ; trigger scene update
			CALL CHECK_SCENE_RIGHT	; $68DF  ; check scene hit going right

			JR NZ,DONE_X			; $68E2
			INC E					; $68E4  ; xpos+=1 
			LD A,$01				; $68E5
			LD (PLR_MOVEMENT_FLAG),A			; $68E7  ; set as 1
			JR DONE_X				; $68EA
			; ---------------------------------------------------------------
MOVE_SHIP_LEFT:		
			; Which way are we facing and can we turn LEFT
			LD A,(DIRECTION)		; $68EC
			CP $01					; $68EF  ;  Make sure we are facing right
			LD A,$FF				; $68F1  ;  $FF = LEFT
			LD (DIRECTION),A		; $68F3  ;  set as Left
			JR NZ,L_68FE			; $68F6
			LD (PLR_MOVEMENT_FLAG),A			; $68F8
			JP DONE_X				; $68FB

L_68FE:		LD A,E					; $68FE
			OR A					; $68FF
			CALL Z,UPDATE_SCENE		; $6900  ; move ship X
			CALL CHECK_SCENE_LEFT  			 ; check scene hit going left

			JR NZ,DONE_X			; $6906
			DEC E					; $6908	; xpos-=1; 
			LD A,$01				; $6909
			LD (PLR_MOVEMENT_FLAG),A			; $690B
			; ---------------------------------------------------------------
DONE_X: 	LD A,(UP_BUTTON)	; $690E	; get only up
			OR A				; $6911
			JR Z,DONE_Y			; $6912
			LD A,$FE			; $6914
			LD ($696C),A		; $6916

			LD A,D				; $6919
			CP $20				; $691A
			CALL Z,UPDATE_SCENE		; $691C
			CALL CHECK_SCENE_UP			; $691F  ; Check scene hit going up

			JR NZ,NO_GRAV		; $6922
			DEC D				; $6924	 ; move y
			DEC D				; $6925	 ; ypos-=2 (UP)
			LD A,$01			; $6926
			LD (PLR_MOVEMENT_FLAG),A		; $6928  ; set as 1 
			JR NO_GRAV			; $692B

DONE_Y:		LD A,$02			; $692D
			LD ($696C),A		; $692F

			LD A,D				; $6932 ; copy ypos
			CP $B0				; $6933	; = y176 (going into next screen)
			CALL Z,UPDATE_SCENE	; $6935
			CALL CHECK_SCENE_DOWN			; $6938    ; Check scene hit going down

			JR NZ,NO_GRAV		; $693B
			; ---------------------------------------------------------
			; Apply gravity to ship
			INC D						; $693D 
			INC D						; $693E ; ypos+=2  TL(0,0)BR(256,192)
			LD A,$01					; $693F
			LD (PLR_MOVEMENT_FLAG),A	; $6941
			; -----------------------------------------------------------
NO_GRAV:	LD A,(PLR_MOVEMENT_FLAG)	; $6944
			OR A						; $6947
			JP Z,L_6A46					; $6948
			LD BC,(POS_XY)				; $694B
			LD (POS_XY),DE				; $694F
			; Get sprite frame (facing direction)
L_6953:		LD A,(DIRECTION)			; $6953  ;
			LD L,$01					; $6956
			INC A						; $6958
			JR NZ,USE_RIGHT_FRAME		; $6959
			INC L						; $695B	 ; flip from right to a left ship frame
USE_RIGHT_FRAME:		
			LD A,L						; $695C
			LD HL,(SPRITE_GFX_BASE)				; $695D
			CALL SPRITE_24x16			; $6960  ; Draw player's ship
			LD (SPRITE_GFX_BASE),HL				; $6963  
			JP L_6A0A					; $6966

POS_XY:					defb $40,$58  			; $6969 ;  ships current Y/X pos
DIRECTION:				defb $01 				; $696B ;  ships facing direction
						defb $02      			; $696C ;
SPRITE_GFX_BASE:		defw SPRITE24x16_DATA   ; $696D ;  Graphics base address 
PLR_MOVEMENT_FLAG:		defb $01	   			; $696F ;  
OLD_POS_XY:				defb $00,$00  			; $6970 ;  keep old starting X/Y pos
			

;---------------------------------------------------------------
; Handles ship's right-edge collision (2 tiles right), combining tile results from current and next row(s). 
; If y%8 != 0, checks a third row. A holds non-zero if collision.
; Left-edge check is similar but 1 tile left.
; Down/Up are again similar, but down does not need to check so far ahead.

CHECK_SCENE_RIGHT:		
			PUSH BC						; $6972
			PUSH DE						; $6973
			PUSH HL						; $6974
			LD A,E						; $6975	; Load xpos into A
			AND $03						; $6976 ; Check if xpos is a multiple of 4
			LD A,$00					; $6978 ; Default: No collision (A = 0)
			JR NZ,NO_RIGHT_HIT			; $697A
			LD A,E						; $697C ; xpos
			CP $78						; $697D
			LD A,$00					; $697F ; Default: No collision (A = 0)
			JR NC,NO_RIGHT_HIT			; $6981 ; If xpos>=120, skip to end (no collision)
			CALL GET_ANIM_ADDR_AS_HL	; $6983
			INC L						; $6986 ; (NOTE: ship16x16 is really 24x16 pre-rotated pixel data)
			INC L						; $6987 ; Move over (x2 tile8x8 right)
 			LD BC,$0020					; $6988	; Set BC = 32 (offset to next row of tiles)
			LD A,(HL)					; $698B ; Get tile value
			ADD HL,BC					; $698C ; Move HL down by 1 row (32 bytes, or 4 tiles)
			OR (HL)						; $698D ; Combine ongoing tiles
			LD E,A						; $698E ; Save
			LD A,D						; $698F
			AND $07						; $6990 ; Sitting on a multiple of 8
			LD A,E						; $6992 ; Restore
			JR Z,NO_RIGHT_HIT			; $6993 ; additional tile checked (not a multiple,now part into next tile down)
			ADD HL,BC					; $6995 ; Move HL down by another row (right edge, 2 rows down)
			OR (HL)						; $6996 ; Combine ongoing tiles
NO_RIGHT_HIT:
			OR A						; $6997 ; Final collision check on combined tiles
			POP HL						; $6998
			POP DE						; $6999
			POP BC						; $699A
			RET							; $699B ; A=status (0:OK,non-zero:collision). 
										; NOTE: The calling code only checks the NZ flag and does not use the A-register value afterward.
CHECK_SCENE_LEFT:		
			PUSH BC				; $699C
			PUSH DE				; $699D
			PUSH HL				; $699E
			LD A,E				; $699F
			AND $03				; $69A0
			LD A,$00				; $69A2
			JR NZ,NO_LEFT_HIT				; $69A4
			LD A,E				; $69A6
			OR A				; $69A7
			LD A,$00				; $69A8
			JR Z,NO_LEFT_HIT				; $69AA
			CALL GET_ANIM_ADDR_AS_HL				; $69AC
			DEC L				; $69AF
			LD BC,$0020				; $69B0
			LD A,(HL)				; $69B3
			ADD HL,BC				; $69B4
			OR (HL)				; $69B5
			LD E,A				; $69B6
			LD A,D				; $69B7
			AND $07				; $69B8
			LD A,E				; $69BA
			JR Z,NO_LEFT_HIT				; $69BB
			ADD HL,BC				; $69BD
			OR (HL)				; $69BE
NO_LEFT_HIT:
			OR A				; $69BF
			POP HL				; $69C0
			POP DE				; $69C1
			POP BC				; $69C2
			RET				; $69C3

CHECK_SCENE_DOWN:		
			PUSH BC				; $69C4
			PUSH DE				; $69C5
			PUSH HL				; $69C6
			LD A,D				; $69C7
			AND $07				; $69C8
			LD A,$00				; $69CA
			JR NZ,NO_DOWN_HIT				; $69CC
			CALL GET_ANIM_ADDR_AS_HL				; $69CE
			LD BC,$0040				; $69D1
			ADD HL,BC				; $69D4
			LD A,(HL)				; $69D5
			INC L				; $69D6
			OR (HL)				; $69D7
			LD D,A				; $69D8
			LD A,E				; $69D9
			AND $03				; $69DA
			LD A,D				; $69DC
			JR Z,NO_DOWN_HIT				; $69DD
			INC L				; $69DF
			OR (HL)				; $69E0
NO_DOWN_HIT:
			OR A				; $69E1
			POP HL				; $69E2
			POP DE				; $69E3
			POP BC				; $69E4
			RET				; $69E5

CHECK_SCENE_UP:		
			PUSH BC				; $69E6
			PUSH DE				; $69E7
			PUSH HL				; $69E8
			LD A,D				; $69E9
			AND $07				; $69EA
			LD A,$00			; $69EC
			JR NZ,NO_UP_HIT		; $69EE
			CALL GET_ANIM_ADDR_AS_HL			; $69F0
			LD BC,$FFE0			; $69F3
			ADD HL,BC			; $69F6
			LD A,(HL)			; $69F7
			INC L				; $69F8
			OR (HL)				; $69F9
			LD D,A				; $69FA
			LD A,E				; $69FB
			AND $03				; $69FC
			LD A,D				; $69FE
			JR Z,NO_UP_HIT			; $69FF
			INC L				; $6A01
			OR (HL)				; $6A02
NO_UP_HIT:	
			OR A				; $6A03
			POP HL				; $6A04
			POP DE				; $6A05
			POP BC				; $6A06
			RET					; $6A07

POS_XY_COPY:		; MOVE_SHIP saves, but doesn’t appear used ???
			defb $00			; $6A08  
			defb $00			; 

L_6A0A:		LD A,(BACKSHOT_ENABLE)			; $6A0A 
			OR A							; $6A0D
			JP Z,L_6A46						; $6A0E
			LD HL,(BACKSHOT_GFX_BASE)		; $6A11
			LD BC,(BACKSHOT_POS)			; $6A14
			LD DE,(POS_XY)					; $6A18
			LD A,(DIRECTION)				; $6A1C
			CP $FF							; $6A1F
			JR Z,L_6A36						; $6A21
			LD A,E							; $6A23
			SUB $08							; $6A24
			LD E,A							; $6A26
			LD (BACKSHOT_POS),DE			; $6A27
			LD A,WEAPON_ITEM_BACKSHOT_L		; $6A2B
			CALL SPRITE_24x16				; $6A2D  ; draw Backshot
			LD (BACKSHOT_GFX_BASE),HL		; $6A30
			JP L_6A46						; $6A33
L_6A36:		LD A,E							; $6A36
			ADD A,$08						; $6A37
			LD E,A							; $6A39
			LD (BACKSHOT_POS),DE			; $6A3A
			LD A,WEAPON_ITEM_BACKSHOT_R		; $6A3E
			CALL SPRITE_24x16				; $6A40
			LD (BACKSHOT_GFX_BASE),HL		; $6A43
L_6A46:		LD A,(MACE_ENABLE)				; $6A46 ; get Mace enabled state
			OR A							; $6A49
			JR Z,L_6ABA						; $6A4A  
			LD DE,(MACE_POS)				; $6A4C
			LD A,(INPUT_ENABLED)					; $6A50
			OR A							; $6A53
			JP NZ,L_6A87					; $6A54
			LD A,(DIRECTION)				; $6A57
			CP $FF							; $6A5A
			LD A,(MACE_SPIN_INDEX)			; $6A5C
			JR Z,L_6A6B						; $6A5F
			CP $17							; $6A61
			JR C,L_6A67						; $6A63
			LD A,$FF						; $6A65
L_6A67:		INC A							; $6A67  ; Spin clockwize
			JP L_6A71						; $6A68
L_6A6B:		OR A							; $6A6B
			JR NZ,L_6A70					; $6A6C
			LD A,$18						; $6A6E
L_6A70:	 	DEC A							; $6A70   ; Spin Anticlockwise
L_6A71:		LD (MACE_SPIN_INDEX),A			; $6A71
			ADD A,A							; $6A74
			LD L,A							; $6A75  ; Sine Wave index
			LD H,$00						; $6A76  
			LD BC,SINE_WAVE_TABLE			; $6A78
			ADD HL,BC						; $6A7B
			; -----------------------------------------------------
			; centre mace on ship
			LD DE,(POS_XY)			; $6A7C
			LD A,(HL)				; $6A80  ; Sine Wave X
			ADD A,E					; $6A81  ; 
			LD E,A					; $6A82
			INC HL					; $6A83
			LD A,(HL)				; $6A84  ; Sine Wave Y
			ADD A,D					; $6A85  ; 
			LD D,A					; $6A86	 
			; -----------------------------------------------------
L_6A87:		LD BC,(MACE_POS)				; $6A87
			LD (MACE_POS),DE				; $6A8B
			LD HL,(MACE_GFX_BASE)			; $6A8F
			LD A,WEAPON_ITEM_MACE			; $6A92	 ; mace = item 17
			CALL SPRITE_24x16				; $6A94  ; Draw Mace
			LD (MACE_GFX_BASE),HL			; $6A97
			LD A,$7B						; $6A9A
			CP E							; $6A9C
			CALL NC,SPARKLE_EFFECT			; $6A9D		; Mace tail

			LD A,$01						; $6AA0
			CALL L_67B9						; $6AA2
			CALL ENEMY_COLLISIONS			; $6AA5
			JR Z,L_6AB1						; $6AA8
			
			PUSH DE							; $6AAA
			LD E,SFX_MACEHIT				; $6AAB  ; mace hit sound
			CALL PLAY_SFX					; $6AAD
			POP DE					; $6AB0

L_6AB1:		;-------------------------------------------
			; Use centre point (Enemies using Tiles)
			INC E						; $6AB1
			INC E						; $6AB2
			INC D						; $6AB3
			INC D						; $6AB4
			INC D						; $6AB5
			INC D						; $6AB6
			CALL DO_SCENE_COLLISION		; $6AB7
			;-------------------------------------------
L_6ABA:		LD C,$47				; $6ABA  ; 	%01000111  colour
			LD A,(SHIELD_AMOUNT)	; $6ABC
			OR A					; $6ABF
			JR Z,NO_SHIELD			; $6AC0 
			DEC A					; $6AC2  
			LD (SHIELD_AMOUNT),A	; $6AC3
			;--------------------------------------------------------
			LD A,(GAME_COUNTER_8BIT)		; $6AC6
			AND $07					; $6AC9  ; %00000111	
			OR $40					; $6ACB  ; %01000000
			LD C,A					; $6ACD  ; Flashing Shield Colour
			;--------------------------------------------------------
NO_SHIELD:		
			LD DE,(POS_XY)					; $6ACE
			CALL SET_SCRN_ATTR				; $6AD2
			LD A,(BACKSHOT_ENABLE)			; $6AD5
			OR A							; $6AD8
			JR Z,L_6AE2						; $6AD9
			LD DE,(BACKSHOT_POS)			; $6ADB
			CALL SET_SCRN_ATTR				; $6ADF
L_6AE2:		LD A,(MACE_ENABLE)				; $6AE2
			OR A							; $6AE5
			RET Z							; $6AE6
			LD DE,(MACE_POS)				; $6AE7
			JP SET_SCRN_ATTR				; $6AEB

					; ----------------------------------------------------
BACKSHOT_ENABLE:	defb $00				; $6AEE 
BACKSHOT_GFX_BASE:	defb $00,$00   		 	; $6AEF 
BACKSHOT_POS:		defw $0000 			  	; $6AF1 
					; ----------------------------------------------------
MACE_ENABLE			defb $00				; $6AF3 
MACE_GFX_BASE:		defw $0000				; $6AF4 
MACE_POS:			defw $0000				; $6AF6 
MACE_SPIN_INDEX:	defb $00				; $6AF8  ; into Sine Wave Table
SINE_WAVE_TABLE:	defb $00,$E0			; $6AF9  ; Sine Wave for Mace (22 Y/X Coords)
					defb $04,$E2,$08,$E6,$0B,$EB,$0D,$F1	
					defb $0F,$F8,$0F,$00,$0F,$08,$0D,$0F	
					defb $0B,$15,$08,$1A,$04,$1E,$00,$20	
					defb $FC,$1E,$F8,$1A,$F5,$15,$F3,$0F	
					defb $F1,$08,$F1,$00,$F1,$F8,$F3,$F1	
					defb $F5,$EB,$F8,$E6,$FC,$E2
					; ----------------------------------------------------

; --------------------------------------------------------------------------
; Draw List Of Icons (16x16)
; Input: HL=Draw List
DRAW_LIST:	
			ld a,(HL)				; $6B29
			inc hl					; $6B2A
			CP $61					; $6B2B  
			JP NC,SKIP_MENU_DRAW	; $6B2D  ; Bytes >= $61
			CALL ICON16x16			; $6B30  ; IN: DE=y/x, C=colour (A < $61)
			INC E					; $6B33	 ; Next position (screenX is 0-255)  
			JP DRAW_LIST			; $6B34  ; keep drawing until marker
SKIP_MENU_DRAW:		
			;-----------------------------------------------------
			; Relative move
			CP $90					; $6B37 
			JP NC,SKIP_X_AXIS		; $6B39 ; A >= $90
			; --- X/Y Relative Move ---
			SUB $78					; $6B3C ; Newline  (i.e. $79-$78)
			ADD A,D					; $6B3E  
			LD D,A					; $6B3F ; Ypos moved 
			LD A,(HL)				; $6B40 ; Get X amount to move (i.e $F3)
			ADD A,E					; $6B41
			LD E,A					; $6B42	; Xpos moved 
			INC HL					; $6B43
			JP DRAW_LIST			; $6B44
SKIP_X_AXIS:		
			CP $CF					; $6B47 ;  
			JP NC,SKIP_Y_AXIS		; $6B49 ; A >= $CF
			; --- Y-axis Move ---
			INC D					; $6B4C ; Down one pixel row
			SUB $AF					; $6B4D
			ADD A,E					; $6B4F ; horizontal position
			LD E,A					; $6B50
			JP DRAW_LIST			; $6B51
SKIP_Y_AXIS:
			;-----------------------------------------------------
			; Ink $D0-$DE (after sub $CF -> $01 to $0F) 
			CP $DF					; 
			JP NC,SKIP_INK			; A >= $DF, not ink/color code
			; --- Set Ink Color ---
			SUB $CF					; Convert ($D0-$DE) to 0-14 
			CP $08					;
			JP C,DO_SIMPLE_INK		; A < 8 (simple ink color)
			SUB $08					; 
			OR $40					; Set brightness
DO_SIMPLE_INK:
			LD B,A					; ink/brightness
			LD A,C					; get global $E0 setting
			AND $38					; Mask ink (preserve paper color only, %FBPPPIII)
			OR B					; Merge new ink/brightness
			LD C,A					; color attribute
			JP DRAW_LIST			; 
SKIP_INK:	
			;------------------------------------------------------------------			
			; Set Absolute Position
			CP $DF					; $6B6D 
			JP NZ,SKIP_SET_POS		; $6B6F  if A != $DF
			LD D,(HL)				; $6B72  ; get Y
			INC HL					; $6B73
			LD E,(HL)				; $6B74  ; get X
			INC HL					; $6B75
			JP DRAW_LIST			; $6B76
SKIP_SET_POS:	
			;------------------------------------------------------------------
			; Set Colour Attribute (global for paper)
			CP $E0					; $6B79  ;  
			JP NZ,SKIP_ATTR			; $6B7B  ; 
			LD C,(HL)				; $6B7E  ; get Colour
			INC HL					; $6B7F
			JP DRAW_LIST			; $6B80
SKIP_ATTR:		
			;------------------------------------------------------------------			
			; Loop Control (Start loop)
			CP $E1					; $6B83  
			JP NZ,SKIP_CTR1			; $6B85
			LD B,(HL)				; $6B88  ; get counter
			INC HL					; $6B89
LOOP_CTR	PUSH HL					; $6B8A  
			PUSH BC					; $6B8B  ; Save counter
			JP DRAW_LIST			; $6B8C
SKIP_CTR1:
			;------------------------------------------------------------------	
			; Loop Control (end loop)
			CP $E2					; $6B8F 
			JP NZ,SKIP_CTR2			; $6B91
			POP BC					; $6B94  ; Restore counter
			DJNZ SKIP_				; $6B95  ; jmp foward ($E1:counter)
			POP AF					; $6B97
			JP DRAW_LIST			; $6B98
SKIP_:		POP HL					; $6B9B
			JP LOOP_CTR				; $6B9C
SKIP_CTR2:				
			;------------------------------------------------------------------	
			; Recursive Drawing
			CP $E3					; $6B9F 
			JP NZ,L_6BB5			; $6BA1
			LD A,(HL)				; $6BA4  ; Load address low byte
			INC HL					; $6BA5
			PUSH HL					; $6BA6
			LD H,(HL)				; $6BA7  ; Load address high byte
			LD L,A					; $6BA8
			PUSH BC					; $6BA9
			PUSH DE					; $6BAA
			CALL DRAW_LIST			; $6BAB  ; Recursively process submenu at (HL)
			POP DE					; $6BAE
			POP BC					; $6BAF
			POP HL					; $6BB0
			INC HL					; $6BB1
			JP DRAW_LIST			; $6BB2
L_6BB5:
			;------------------------------------------------------------------	
			; Draw tiles horizontally
			CP $E4					; $6BB5  
			JP NZ,L_6BC7			; $6BB7
			LD B,(HL)				; $6BBA  ; repeat count
			INC HL					; $6BBB 
			LD A,(HL)				; $6BBC  ; tile ID
L_6BBD:		CALL ICON16x16			; $6BBD
			INC E					; $6BC0  ; Move right
			DJNZ L_6BBD				; $6BC1
			INC HL					; $6BC3  ; Next comman
			JP DRAW_LIST			; $6BC4
L_6BC7:	
			;------------------------------------------------------------------	
			; Draw tiles vertically
			CP $E5					; $6BC7 
			JP NZ,L_6BD9			; $6BC9
			LD B,(HL)				; $6BCC ; repeat count
			INC HL					; $6BCD
			LD A,(HL)				; $6BCE ; tile ID
L_6BCF:		CALL ICON16x16			; $6BCF
			INC D					; $6BD2 ; Move dow
			DJNZ L_6BCF				; $6BD3
			INC HL					; $6BD5 ; Next command
			JP DRAW_LIST			; $6BD6
L_6BD9:	
			;------------------------------------------------------------------	
			; Patch Title Data Source Address
			CP $E6							; $6BD9 
			JR NZ,L_6BEA					; $6BDB
			LD A,(HL)						; $6BDD
			LD (ICON_LD_ADDR+1),A			; $6BDE 
			INC HL							; $6BE1
			LD A,(HL)						; $6BE2
			LD (ICON_LD_ADDR+2),A			; $6BE3
			INC HL							; $6BE6
			JP DRAW_LIST					; $6BE7
L_6BEA:		CP $E7							; $6BEA  ;$E7:store
			JR NZ,L_6C07					; $6BEC
			PUSH HL							; $6BEE
			LD HL,(ICON_LD_ADDR+1)			; $6BEF  ; Get icon address
			PUSH HL							; $6BF2
			LD HL,FONT_DATA					; $6BF3
			LD (ICON_LD_ADDR+1),HL			; $6BF6
			LD A,$20						; $6BF9  ; Tile ID
			CALL ICON16x16					; $6BFB
			INC E							; $6BFE  ; Move right
			POP HL							; $6BFF
			LD (ICON_LD_ADDR+1),HL			; $6C00
			POP HL							; $6C03
			JP DRAW_LIST					; $6C04
			; --------------------------------------------------------------------------			
L_6C07:		CP $E8					; $6C07  ;$E6:store
			JR NZ,L_6C13			; $6C09
			LD A,(HL)				; $6C0B
			LD ($6C82),A			; $6C0C
			INC HL					; $6C0F
			JP DRAW_LIST			; $6C10
L_6C13:		CP $E9					; $6C13
			JR NZ,L_6C1A			; $6C15
			JP DRAW_LIST			; $6C17
L_6C1A:		CP $EA					; $6C1A
			JR NZ,L_6C21			; $6C1C
			JP DRAW_LIST			; $6C1E
L_6C21:		CP $EB					; $6C21  ; 
			RET NZ					; $6C23  ; Return if not (Z flag set if $EB)

			;  (notes: for menu, here HL = $8235 +1)
			;------------------------------------------------------------------
			; !!!This section does dynamic reconfiguration of the draw list!!!
			PUSH BC					; $6C24
			PUSH HL					; $6C25
			LD L,(HL)				; $6C26       
			LD H,$00				; $6C27
			ADD HL,HL				; $6C29  ; X2
			LD BC,$6C44				; $6C2A  ; Lookup  table
			ADD HL,BC				; $6C2D  ; HL = $6C44 + (2 * index)
			LD A,(HL)				; $6C2E  ; Load low byte of target address
			INC HL					; $6C2F  ; 
			LD H,(HL)				; $6C30  ; Load high byte
			LD L,A					; $6C31
			LD ($6B31),HL			; $6C32  ; Patch CALL ICON16x16 to use new routine
			LD ($6BBE),HL			; $6C35  ; 
			LD ($6BD0),HL			; $6C38  ; 
			LD ($6BFC),HL			; $6C3B  ; 
			POP HL					; $6C3E
			POP BC					; $6C3F
			INC HL					; $6C40  
			;  (notes: for Menu here HL = $8235 +2, (i.e. MENU_TEXT+2) )
			JP DRAW_LIST			; $6C41  
			;------------------------------------------------------------------
			; Setup Command ($EB):
			; - Table entries are addresses of rendering functions (e.g ICON16x16)
			defb $4A,$6C,$87,$6C,$87,$6C     ; $6C44  ; Lookup table: addresses for rendering routines
			;------------------------------------------------------------------

; == DISPLAY 8x8 icon ==
; input: D=Y, E=X, A=char
; This draws text + other icons - The top bar is drawn with this.
ICON16x16:
			PUSH AF				; $6C4A
			PUSH DE				; $6C4B
			PUSH HL				; $6C4C
			PUSH BC				; $6C4D
			LD L,A				; $6C4E
			LD H,$00			; $6C4F
			ADD HL,HL			; $6C51
			ADD HL,HL			; $6C52
			ADD HL,HL			; $6C53	;Ax8 for 8 byte char bitmap

ICON_LD_ADDR:
			LD BC,$0000			; $6C54  ; code patched here with new address

			ADD HL,BC			; $6C57
			PUSH HL				; $6C58
			LD A,D				; $6C59	; Y coords
			AND $F8				; $6C5A ; Aligned to 8-pixel rows
			OR $40				; $6C5C	; screen base
			LD B,A				; $6C5E
			LD A,D				; $6C5F
			LD H,B				; $6C60
			AND $07				; $6C61	; pixel row offset
			RRCA				; $6C63
			RRCA				; $6C64
			RRCA				; $6C65	; /8
			ADD A,E				; $6C66	; X coords
			LD L,A				; $6C67
			POP DE				; $6C68
			LD B,$08			; $6C69
L_6C6B:		LD A,(DE)			; $6C6B ; char data
			INC DE				; $6C6C
			LD (HL),A			; $6C6D ; 8 pixels to screen
			INC H				; $6C6E ; +0x100, skip 8 lines 
			DJNZ L_6C6B			; $6C6F
			DEC H				; $6C71 ; get last value
			POP BC				; $6C72
			LD A,H				; $6C73
			RRCA				; $6C74
			RRCA				; $6C75
			RRCA				; $6C76 ; attribute row 
			AND $03				; $6C77
			OR $58				; $6C79	; 0x5800, attribute memory
			LD H,A				; $6C7B
			LD (HL),C			; $6C7C	; set colour (L value same as icon)
			LD DE,$0700			; $6C7D
			ADD HL,DE			; $6C80
			LD (HL),$00			; $6C81 ; marker flag ?
			POP HL				; $6C83
			POP DE				; $6C84
			POP AF				; $6C85
			RET				; $6C86

			RET				; $6C87

L_6C88:
			LD A,$06				; $6C88
			CALL GET_RAND_VALUE				; $6C8A
			SUB $03				; $6C8D
			LD C,A				; $6C8F
			LD A,$0C				; $6C90
			CALL GET_RAND_VALUE				; $6C92
			INC A				; $6C95
			NEG				; $6C96
			LD B,A				; $6C98
			RET				; $6C99

DO_SCENE_COLLISION:
			PUSH AF				; $6C9A
			PUSH BC				; $6C9B
			PUSH DE				; $6C9C
			PUSH HL				; $6C9D
			PUSH IX				; $6C9E
			LD B,D				; $6CA0
			LD C,E				; $6CA1
			DEC C				; $6CA2
			DEC C				; $6CA3
			DEC B				; $6CA4
			DEC B				; $6CA5
			DEC B				; $6CA6
			DEC B				; $6CA7
			LD IX,DATA_08				; $6CA8
LOOP_SCENE_COLLISION:
			LD A,(IX+$00)				; $6CAC
			CP $FF				; $6CAF
			JR Z,NO_SCENE_COLLISION				; $6CB1
			LD A,(IX+$04)				; $6CB3
			OR A				; $6CB6
			JR Z,NEXT_SCENE_COLLISION				; $6CB7
			LD A,(IX+$02)				; $6CB9
			LD ($67FE),A				; $6CBC
			LD A,(IX+$03)				; $6CBF
			LD ($67FF),A				; $6CC2
			LD A,$04				; $6CC5
			CALL L_67B9				; $6CC7
			LD E,(IX+$00)				; $6CCA
			LD D,(IX+$01)				; $6CCD
			CALL COLLISION_DETECTION				; $6CD0
			OR A				; $6CD3
			JR Z,NEXT_SCENE_COLLISION				; $6CD4

			LD (IX+$04),$00				; $6CD6
			LD BC,($67FE)				; $6CDA
			LD A,$F8				; $6CDE
			ADD A,C				; $6CE0
			LD C,A				; $6CE1
			LD A,$F0				; $6CE2
			ADD A,B				; $6CE4
			LD B,A				; $6CE5
			CALL L_6D4D				; $6CE6
			LD E,SFX_LARGEEXPLODE				; $6CE9
			CALL PLAY_SFX				; $6CEB
NO_SCENE_COLLISION:
			POP IX				; $6CEE
			POP HL				; $6CF0
			POP DE				; $6CF1
			POP BC				; $6CF2
			POP AF				; $6CF3
			RET				; $6CF4

NEXT_SCENE_COLLISION:		LD DE,$0008
			ADD IX,DE						; 
			JR LOOP_SCENE_COLLISION			; $6CFA

DATA_08:
			defb $4C,$44,$09,$48,$2C,$28,$48					; $6CFC
			defb $4C,$29,$0D,$0A,$24,$33,$3A,$09				; $6D03 L)..$3:.
			defb $4F,$52,$09,$30,$0D,$0A,$09,$4C				; $6D0B OR.0...L
			defb $44,$09,$4C,$2C,$41,$0D,$0A,$09				; $6D13 D.L,A...
			defb $49,$4E,$43,$09,$43,$0D,$0A,$0D				; $6D1B INC.C...
			defb $0A,$09,$4C,$44,$09,$41,$2C,$28				; $6D23 ..LD.A,(
			defb $44,$45,$29,$0D,$0A,$09,$58,$4F				; $6D2B DE)...XO
			defb $52,$09,$28,$48,$4C,$29,$0D,$0A				; $6D33 R.(HL)..
			defb $24,$39,$3A,$09,$4C,$44,$09,$28				; $6D3B $9:.LD.(
			defb $48,$4C,$29,$2C,$41,$0D,$0A,$09				; $6D43 HL),A...
			defb $49,$FF                                        ; $6D4B I.

L_6D4D:
			LD E,(IX+$00)				; $6D4D
			LD D,(IX+$01)				; $6D50
			PUSH DE				; $6D53
			LD A,(IX+$05)				; $6D54
			CALL L_8A3E				; $6D57
			LD E,(IX+$06)				; $6D5A
			LD D,(IX+$07)				; $6D5D
			CALL L_78D4				; $6D60
			CALL L_788E				; $6D63
			POP DE				; $6D66
			LD A,(IX+$02)				; $6D67
			AND $F8				; $6D6A
			RRCA				; $6D6C
			RRCA				; $6D6D
			RRCA				; $6D6E
			LD B,A				; $6D6F
			LD A,(IX+$03)				; $6D70
			AND $F0				; $6D73
			RRCA				; $6D75
			RRCA				; $6D76
			RRCA				; $6D77
			RRCA				; $6D78
			LD C,A				; $6D79
L_6D7A:		PUSH DE				; $6D7A
			PUSH BC				; $6D7B
			CALL GET_ANIM_ADDR_AS_HL				; $6D7C
L_6D7F:		LD A,(HL)				; $6D7F
			OR A				; $6D80
			CALL NZ,L_6D96				; $6D81
			INC HL				; $6D84
			INC HL				; $6D85
			LD A,E				; $6D86
			ADD A,$08				; $6D87
			LD E,A				; $6D89
			DJNZ L_6D7F				; $6D8A
			POP BC				; $6D8C
			POP DE				; $6D8D
			LD A,D				; $6D8E
			ADD A,$10				; $6D8F
			LD D,A				; $6D91
			DEC C				; $6D92
			JR NZ,L_6D7A				; $6D93
			RET				; $6D95

L_6D96:		PUSH BC				; $6D96
			PUSH DE				; $6D97
			PUSH HL				; $6D98
			LD HL,SPRITE24x16_DATA				; $6D99
			CALL DRAW4X4SPRITE				; $6D9C

			CALL ADD_EXPLOSION_WITH_SFX				; $6D9F
			LD L,A				; $6DA2
			LD H,$00				; $6DA3
			ADD HL,HL				; $6DA5
			ADD HL,HL				; $6DA6
			LD BC,$E9B9				; $6DA7
			ADD HL,BC				; $6DAA
			CALL L_6DE0				; $6DAB
			LD C,(HL)				; $6DAE
			CALL L_6E8B				; $6DAF
			CALL L_6E8B				; $6DB2
			INC HL				; $6DB5
			LD A,E				; $6DB6
			ADD A,$04				; $6DB7
			LD E,A				; $6DB9
			LD C,(HL)				; $6DBA
			CALL L_6E8B				; $6DBB
			CALL L_6E8B				; $6DBE
			INC HL				; $6DC1
			SUB $04				; $6DC2
			LD E,A				; $6DC4
			LD A,D				; $6DC5
			ADD A,$08				; $6DC6
			LD D,A				; $6DC8
			LD C,(HL)				; $6DC9
			CALL L_6E8B				; $6DCA
			CALL L_6E8B				; $6DCD
			INC HL				; $6DD0
			LD A,E				; $6DD1
			ADD A,$04				; $6DD2
			LD E,A				; $6DD4
			LD C,(HL)				; $6DD5
			CALL L_6E8B				; $6DD6
			CALL L_6E8B				; $6DD9
			POP HL				; $6DDC
			POP DE				; $6DDD
			POP BC				; $6DDE
			RET				; $6DDF

L_6DE0:
			PUSH AF				; $6DE0
			PUSH BC				; $6DE1
			PUSH DE				; $6DE2
			PUSH HL				; $6DE3
			CALL L_67A3				; $6DE4
			XOR A				; $6DE7
			PUSH HL				; $6DE8
			LD (HL),A				; $6DE9
			INC L				; $6DEA
			LD (HL),A				; $6DEB
			LD DE,$001F				; $6DEC
			ADD HL,DE				; $6DEF
			LD (HL),A				; $6DF0
			INC L				; $6DF1
			LD (HL),A				; $6DF2
			POP HL				; $6DF3
			LD DE,$0400				; $6DF4
			ADD HL,DE				; $6DF7
			LD (HL),A				; $6DF8
			INC L				; $6DF9
			LD (HL),A				; $6DFA
			LD DE,$001F				; $6DFB
			ADD HL,DE				; $6DFE
			LD (HL),A				; $6DFF
			INC L				; $6E00
			LD (HL),A				; $6E01
			POP HL				; $6E02
			POP DE				; $6E03
			POP BC				; $6E04
			POP AF				; $6E05
			RET				; $6E06

L_6E07:		PUSH AF					; $6E07
			PUSH BC					; $6E08
			PUSH HL					; $6E09
			LD HL,DATA_10				; $6E0A
L_6E0D:		LD C,A					; $6E0D 
			LD A,(HL)				; $6E0E
			CP $FF					; $6E0F
			LD A,C					; $6E11
			JR Z,L_6E1D				; $6E12
			CP (HL)					; $6E14
			JR Z,L_6E21				; $6E15
			LD BC,$0008				; $6E17
			ADD HL,BC				; $6E1A
			JR L_6E0D				; $6E1B
L_6E1D:		POP HL					; $6E1D
			POP BC					; $6E1E
			POP AF					; $6E1F
			RET						; $6E20

L_6E21:
			LD (IX+$04),A				; $6E21
			INC HL				; $6E24
			LD A,(HL)				; $6E25
			ADD A,E				; $6E26
			LD (IX+$00),A				; $6E27
			INC HL				; $6E2A
			LD A,(HL)				; $6E2B
			ADD A,D				; $6E2C
			LD (IX+$01),A				; $6E2D
			INC HL				; $6E30
			LD A,(HL)				; $6E31
			LD (IX+$02),A				; $6E32
			INC HL				; $6E35
			LD A,(HL)				; $6E36
			LD (IX+$03),A				; $6E37
			INC HL				; $6E3A
			LD A,(HL)				; $6E3B
			LD (IX+$05),A				; $6E3C
			INC HL				; $6E3F
			LD A,(HL)				; $6E40
			LD (IX+$06),A				; $6E41
			INC HL				; $6E44
			LD A,(HL)				; $6E45
			LD (IX+$07),A				; $6E46
			LD BC,$0008				; $6E49
			ADD IX,BC				; $6E4C
			POP HL				; $6E4E
			POP BC				; $6E4F
			POP AF				; $6E50
			RET				; $6E51

DATA_10:
			defb $27                                    ; $6E52 
			defb $00,$00,$10,$20,$3A,$16,$79,$23		; $6E53 
			defb $00,$00,$10,$20,$38,$0A,$79,$2B		; $6E5B 
			defb $00,$00,$10,$20,$39,$10,$79,$30		; $6E63 
			defb $00,$00,$10,$20,$3A,$16,$79,$46		; $6E6B 
			defb $00,$00,$08,$10,$39,$10,$79,$47		; $6E73 
			defb $00,$00,$08,$10,$39,$10,$79,$A0		; $6E7B 
			defb $00,$00,$10,$30,$3A,$16,$79			; $6E83 			 
			defb $FF ; end-marker

L_6E8B:
			PUSH AF				; $6E8B
			PUSH DE				; $6E8C
			PUSH HL				; $6E8D
			PUSH BC				; $6E8E
			LD BC,$0006				; $6E8F
			LD HL,$6EC4				; $6E92
L_6E95:
			LD A,(HL)				; $6E95
			OR A				; $6E96
			JR Z,L_6EA0				; $6E97
			CP $FF				; $6E99
			JR Z,L_6EBF				; $6E9B
			ADD HL,BC				; $6E9D
			JR L_6E95				; $6E9E
L_6EA0:
			LD A,$01				; $6EA0
			CALL GET_RAND_VALUE				; $6EA2
			ADD A,$02				; $6EA5
			LD (HL),A				; $6EA7
			EX AF,AF'				; $6EA8
			INC HL				; $6EA9
			LD (HL),E				; $6EAA
			INC HL				; $6EAB
			LD (HL),D				; $6EAC
			INC HL				; $6EAD
			CALL L_6C88				; $6EAE
			LD (HL),C				; $6EB1
			INC HL				; $6EB2
			LD (HL),B				; $6EB3
			EX AF,AF'				; $6EB4
			CALL DRAW_SPRITE16X8				; $6EB5
			POP BC				; $6EB8
			PUSH BC				; $6EB9
			INC HL				; $6EBA
			LD A,C				; $6EBB
			AND $47				; $6EBC
			LD (HL),A				; $6EBE
L_6EBF:
			POP BC				; $6EBF
			POP HL				; $6EC0
			POP DE				; $6EC1
			POP AF				; $6EC2
			RET				; $6EC3


DATA_02:
			defb $0A,$09,$45,$58,$09,$44,$45                    ; $6EC4 ..EX.DE
			defb $2C,$48,$4C,$0D,$0A,$09,$50,$4F				; $6ECB ,HL...PO
			defb $50,$09,$48,$4C,$0D,$0A,$09,$4C				; $6ED3 P.HL...L
			defb $44,$09,$41,$2C,$28,$44,$45,$29				; $6EDB D.A,(DE)
			defb $0D,$0A,$09,$4F,$52,$09,$41,$0D				; $6EE3 ...OR.A.
			defb $0A,$09,$4A,$52,$09,$4E,$5A,$2C				; $6EEB ..JR.NZ,
			defb $24,$33,$0D,$0A,$09,$4C,$44,$09				; $6EF3 $3...LD.
			defb $28,$48,$4C,$29,$2C,$43,$0D,$0A				; $6EFB (HL),C..
			defb $24,$33,$3A,$09,$49,$4E,$43,$09				; $6F03 $3:.INC.
			defb $48,$4C,$0D,$0A,$09,$49,$4E,$43				; $6F0B HL...INC
			defb $09,$44,$45,$0D,$0A,$09,$4C,$44				; $6F13 .DE...LD
			defb $09,$41,$2C,$28,$44,$45,$29,$0D				; $6F1B .A,(DE).
			defb $0A,$09,$4F,$52,$09,$41,$0D,$0A				; $6F23 ..OR.A..
			defb $09,$4A,$52,$09,$4E,$5A,$2C,$24				; $6F2B .JR.NZ,$
			defb $34,$0D,$0A,$09,$4C,$44,$09,$28				; $6F33 4...LD.(
			defb $48,$4C,$29,$2C,$43,$0D,$0A,$24				; $6F3B HL),C..$
			defb $34,$3A,$09,$49,$4E,$43,$09,$48				; $6F43 4:.INC.H
			defb $4C,$0D,$0A,$09,$49,$4E,$43,$09				; $6F4B L...INC.
			defb $44,$45,$0D,$0A,$09,$4C,$44,$09				; $6F53 DE...LD.
			defb $41,$2C,$28,$44,$45,$29,$0D,$0A				; $6F5B A,(DE)..
			defb $09,$4F,$52,$09,$41,$0D,$0A,$09				; $6F63 .OR.A...
			defb $4A,$52,$09,$4E,$5A,$2C,$24,$35				; $6F6B JR.NZ,$5
			defb $0D,$0A,$09,$4C,$44,$09,$28,$48				; $6F73 ...LD.(H
			defb $4C,$29,$2C,$43,$0D,$0A,$24,$35				; $6F7B L),C..$5
			defb $3A,$09,$4C,$44,$09,$44,$45,$2C				; $6F83 :.LD.DE,
			defb $33,$30,$0D,$0A,$09,$41,$44,$44				; $6F8B 30...ADD
			defb $09,$48,$4C,$2C,$44,$45,$0D,$0A				; $6F93 .HL,DE..
			defb $09,$44,$4A,$4E,$5A,$09,$24,$32				; $6F9B .DJNZ.$2
			defb $0D,$0A,$09,$50,$4F,$50,$09,$48				; $6FA3 ...POP.H
			defb $4C,$0D,$0A,$09,$50,$4F,$50,$09				; $6FAB L...POP.
			defb $44,$45,$0D,$0A,$09,$50,$4F,$50				; $6FB3 DE...POP
			defb $09,$42,$43,$0D,$0A,$09,$50,$4F				; $6FBB .BC...PO
			defb $50,$09,$41,$46,$0D,$0A,$09,$52				; $6FC3 P.AF...R
			defb $45,$54,$0D,$0A,$0D,$0A,$41,$54				; $6FCB ET....AT
			defb $52,$32,$32,$32,$3A,$09,$50,$55				; $6FD3 R222:.PU
			defb $53,$48,$09,$41,$46,$09,$09,$3B				; $6FDB SH.AF..;
			defb $53,$41,$4D,$45,$20,$41,$53,$20				; $6FE3 SAME AS 
			defb $41,$42,$4F,$56,$45,$20,$42,$55				; $6FEB ABOVE BU
			defb $54,$20,$44,$45,$41,$4C,$53,$20				; $6FF3 T DEALS 
			defb $57,$49,$54,$48,$20,$54,$57,$4F				; $6FFB WITH TWO
			defb $20,$43,$4F,$4C,$4F,$55,$52,$53				; $7003  COLOURS
			defb $20,$28,$42,$2B,$43,$29,$0D,$0A				; $700B  (B+C)..
			defb $09,$50,$55,$53,$48,$09,$42,$43				; $7013 .PUSH.BC
			defb $09,$09,$3B,$43,$20,$4F,$4E,$20				; $701B ..;C ON 
			defb $54,$48,$45,$20,$4C,$45,$46,$54				; $7023 THE LEFT
			defb $20,$41,$4E,$44,$20,$42,$20,$4F				; $702B  AND B O
			defb $4E,$20,$54,$48,$45,$20,$52,$49				; $7033 N THE RI
			defb $47,$48,$54,$0D,$0A,$09,$50,$55				; $703B GHT...PU
			defb $53,$48,$09,$44,$45,$0D,$0A,$09				; $7043 SH.DE...
			defb $50,$55,$53,$48,$09,$48,$4C,$0D				; $704B PUSH.HL.
			defb $0A,$09,$4C,$44,$09,$41,$2C,$45				; $7053 ..LD.A,E
			defb $0D,$0A,$09,$43,$50,$09,$31,$32				; $705B ...CP.12
			defb $38,$0D,$0A,$09,$4A,$FF                        ; $7063 8...J.

;------------------------------------------------------
; Debris, explosions and volcanic eruptions
DEBRIS_SPRITES:
			LD HL,$6EC4			; $7069   ; Explosive data
L_706C:
			LD A,(HL)			; $706C
			LD B,A				; $706D
			CP $FF				; $706E   
			RET Z				; $7070	  ; exit sprites loop on $ff marker
			OR A				; $7071
			JR NZ,L_707A			; $7072
			LD BC,$0006			; $7074
			ADD HL,BC			; $7077
			JR L_706C			; $7078
L_707A:
			PUSH HL				; $707A
			INC HL				; $707B
			PUSH HL				; $707C
			LD E,(HL)			; $707D
			INC HL				; $707E
			LD D,(HL)			; $707F
			LD A,B				; $7080
			CALL DRAW_SPRITE16X8			; $7081
			INC HL				; $7084
			LD A,E				; $7085
			ADD A,(HL)			; $7086
			LD E,A				; $7087
			CP $78				; $7088
			JR NC,L_70AA			; $708A
			INC HL				; $708C
			INC (HL)			; $708D
			LD A,(HL)			; $708E
			ADD A,D				; $708F
			LD D,A				; $7090
			CP $B8				; $7091
			JR NC,L_70AA			; $7093
			INC HL				; $7095
			LD C,(HL)			; $7096
			POP HL				; $7097
			LD (HL),E			; $7098
			INC HL				; $7099
			LD (HL),D			; $709A
			LD A,B				; $709B
			CALL DRAW_SPRITE16X8			; $709C
			CALL L_A4AD			; $709F  ;  Draw explosion
			POP HL				; $70A2
			LD BC,$0006			; $70A3
			ADD HL,BC			; $70A6
			JP L_706C			; $70A7
L_70AA:
			POP HL				; $70AA
			POP HL				; $70AB
			LD (HL),$00			; $70AC
			LD BC,$0006			; $70AE
			ADD HL,BC			; $70B1
			JR L_706C			; $70B2

;--------------------------------------------------------
; *** ROUTINE TO SETUP IM2 ***
SETUP_IM2_JUMP_TABLE:
			; Patch location ($FDFD-$FDFF) with "JP L_70D3"
			LD A,$C3				; $70B4
			LD ($FDFD),A			; $70B6
			LD HL,$70D3				; $70B9
			LD ($FDFE),HL			; $70BC	 
			; Fills jump table with $FD	
			; (Can't used the rom trick due to 128k)
			LD HL,$FE00				; $70BF
			LD (HL),$FD				; $70C2
			LD DE,$FE01				; $70C4
			LD BC,$0101				; $70C7
			LDIR					; $70CA
			IM 2					; $70CC
			LD A,$FE				; $70CE
			LD I,A					; $70D0
			RET						; $70D2

;--------------------------------------------------------
; *** INTERRUPT ROUTINE, called 50pfs ***
L_70D3:					 
			PUSH AF				; $70D3
			PUSH BC				; $70D4
			PUSH DE				; $70D5
			PUSH HL				; $70D6
			PUSH IX				; $70D7
			PUSH IY				; $70D9
			EXX					; $70DB
			EX AF,AF'			; $70DC
			PUSH AF				; $70DD
			PUSH BC				; $70DE
			PUSH DE				; $70DF
			PUSH HL				; $70E0

			LD HL,FRAME_COUNTER 	; $70E1
			INC (HL)				; $70E4	
			;-----------------------------------------------------------
			; Disable AY music - menu option 6
			LD A,(AY_MUSIC_FLAG)			; $70E5
			OR A					; $70E8
			CALL Z,AY_RESET_MUSIC			; $70E9  ; Stop AY music
			LD A,(AY_MUSIC_FLAG)			; $70EC
			OR A					; $70EF
			JR Z,EXIT_IM2			; $70F0	 ; Get out - Don't play AY music
			;----------------------------------------------------------
			LD A,(SPECCY_MODEL)		; $70F2
			OR A					; $70F5
			JR NZ,USE_AY			; $70F6
			;----------------------------------------------------------
			; INGAME BEEPER SFX DRIVER - called at a 50% duty cycle
			LD A,($711B)					; $70F8 ; get
			XOR $01							; $70FB ; flip (A=!A)
			LD ($711B),A					; $70FD ; store
			CALL Z,POLL_SFX_USING_BEEPER 	; $7100 
			;----------------------------------------------------------
			JP EXIT_IM2			; $7103
			;----------------------------------------------------------
			; AY Music at 50Hz (50fps PAL)
USE_AY:		CALL AY_MUSIC		; $7106	
			;----------------------------------------------------------
EXIT_IM2:	
			POP HL				; $7109
			POP DE				; $710A
			POP BC				; $710B
			POP AF				; $710C
			EX AF,AF'			; $710D
			EXX					; $710E
			POP IY				; $710F
			POP IX				; $7111
			POP HL				; $7113
			POP DE				; $7114
			POP BC				; $7115
			POP AF				; $7116
			EI					; $7117
			RETI				; $7118

; =================================================================
; Vars used by interrupt routine
FRAME_COUNTER: 	defb $00        ; $711A
DUTY_CYCLE:  	defb $00		; $711B  ; bit flip per frame for 50% duty cycle
;-------------------------------------------------------------------

OFFSET_INTO_MAP:  defw  $A5AA  							; $711C

			defb $25,$A6,$82,$A6,$D3					; $711E
			defb $A6,$42,$A7,$BD,$A7,$C0,$A7,$2D		; $7123 
			defb $A8,$A9,$A8,$03,$A9,$71,$A9,$CB		; $712B 
			defb $A9,$CE,$A9,$32,$AA,$A1,$AA,$19		; $7133 
			defb $AB,$98,$AB,$03,$AC,$06,$AC,$95		; $713B 
			defb $AC,$08,$AD,$83,$AD,$FB,$AD,$79		; $7143 
			defb $AE,$D2,$AE,$40,$AF,$CD,$AF,$37		; $714B 
			defb $B0,$C6,$B0,$45,$B1,$B8,$B1,$2D		; $7153 
			defb $B2,$86,$B2,$DA,$B2,$5B,$B3,$D8		; $715B 
			defb $B3,$4C,$B4,$C4,$B4,$22,$B5,$8F		; $7163 
			defb $B5,$06,$B6,$99,$B6,$9C,$B6,$16		; $716B 
			defb $B7,$8B,$B7,$DA,$B7,$11,$B8,$4F		; $7173 
			defb $B8,$C0,$B8,$28,$B9,$91,$B9,$FF		; $717B 
			defb $B9,$62,$BA,$C9,$BA,$1D,$BB,$86		; $7183 
			defb $BB,$18,$BC,$76,$BC,$D7,$BC,$3D		; $718B 
			defb $BD,$C9,$BD,$33,$BE,$B4,$BE,$16		; $7193 
			defb $BF,$5E,$BF,$CC,$BF,$3C,$C0,$AB		; $719B 
			defb $C0,$05,$C1,$A5,$C1,$45,$C2,$AC		; $71A3 
			defb $C2,$FD,$C2,$75,$C3,$91				; $71AB 
			defb $77    								; $71B1

		
IMMUNE_TIMER:			defw $0000                      ; $71B2

; NOTE:  WWhile reverse engineering this I found that I had had at first 
; mixed X/Y here when using OLD_POS_XY+1, interestingly this allowed the game to go back to last screen (X-axis)
; IN: E = current X, D = current Y
; Does the screen transitions when player moves outside the screen limits
UPDATE_SCENE:		

			; if (X==120 || X==0)
			LD A,E      					; X coords
			CP $78 	    					; 120 (right screen edge)
			JR Z,X_SCRN_EDGE 				; 
			OR A        					; zero (left screen edge)
			JR Z,X_SCRN_EDGE  				; 

			LD A,(OLD_POS_XY+1)				; $71BC  
			CP D							; $71BF  ; Compare old Y to current Y (D)
			JP NZ,DO_SCENE_UPDATE_CHECKS	; $71C0  ; If different, trigger scene update
			JP NO_SCENE_UPDATE				; $71C3
X_SCRN_EDGE:					
			LD A,(OLD_POS_XY)				; $71C6
			CP E							; $71C9	 ; Compare old X to current X (E)
			JP NZ,DO_SCENE_UPDATE_CHECKS	; $71CA  ; If different, trigger scene update

NO_SCENE_UPDATE:		
			POP HL							; $71CD 
			INC HL							; $71CE
			INC HL							; $71CF
			INC HL							; $71D0
			LD A,$01						; $71D1
			OR A							; $71D3
			PUSH HL							; $71D4
			RET								; $71D5  ; Return without transition

DO_SCENE_UPDATE_CHECKS:		
			POP HL							; $71D6
			LD A,(DIRECTION)				; $71D7
			CP $FF							; $71DA  ; $FF = LEFT
			LD A,E							; $71DC	 ; Xpos
			JR Z,LEFT_EDGE					; $71DD  ; X==0, do left edge transition
			CP $78							; $71DF  ; 120
			JR NZ,DO_VERT_CHECK				; $71E1  ; X!=120, move onto vertical checks
			LD A,$01						; $71E3  ; Right facing
			LD E,$00						; $71E5  ; Xpos=0 (reset ship to left side)
			JR SCENCE_TRANSITION			; $71E7  ; 
			; --- Ship's left edge transition (X==0,facing left) ---
LEFT_EDGE:	
			OR A							; $71E9  ; was Xpos zero above
			JR NZ,DO_VERT_CHECK				; $71EA  ; X!=0, continue checks
			LD A,$FF						; $71EC
			LD E,$78						; $71EE	 ; X=120 (reset ship to right side, 240pixels)
			JR SCENCE_TRANSITION			; $71F0  ;
			; --- Vertical scene transition checks ---
DO_VERT_CHECK:	
			LD A,($696C)					; $71F2
			CP $FE							; $71F5
			LD A,D							; $71F7
			JR Z,DO_TOP_EDGE				; $71F8  ; Y==0 (top edge)
			CP $B0							; $71FA  ; 176
			RET NZ							; $71FC  ; Get out, Y not bottom edge
			; --- Bottom edge transition (Y==176) ---
			LD A,($744C)					; $71FD
			LD D,$20						; $7200  ; y=32
			JR SCENCE_TRANSITION			; $7202  ;
			; --- Top edge transition ---
DO_TOP_EDGE:
			CP $20							; $7204  ; 32
			RET NZ							; $7206
			LD A,($744C)					; $7207
			NEG								; $720A
			LD D,$B0						; $720C  ; 176
			; --- Finalize Scene Transition ---
SCENCE_TRANSITION:		
			LD (POS_XY),DE					; $720E
			LD (OLD_POS_XY),DE				; $7212
			LD DE,(TABLE_INDEX)				; $7216
			ADD A,E							; $721A
			LD (TABLE_INDEX),A				; $721B
RESET_FOR_NEXT_SCREEN:		
			; ------------------------------------------
			; Clear any ongoing super weapons
			XOR A							; $721E
			LD (SHIELD_AMOUNT),A			; $721F
			LD (TIMEOUT_BALLS),A			; $7222
			LD (GAME_COUNTER_8BIT),A		; $7225
			LD ($80B3),A					; $7228
			; ------------------------------------------
			LD A,$FF						; $722B
			LD ($9B47),A					; $722D
			LD ($9BD5),A					; $7230
			; -----------------------------------------
			LD A,$32						; $7233
			LD ($9BD4),A					; $7235
			; ------------------------------------------
			; Setup time limit for level
			LD HL,$0753						; $7238
			LD (IMMUNE_TIMER),HL			; $723B
			; ------------------------------------------
			; Setup base GFX
			LD HL,SPRITE24x16_DATA			; $723E
			LD (SPRITE_GFX_BASE),HL		; $7241
			LD (BACKSHOT_GFX_BASE),HL		; $7244
			LD (MACE_GFX_BASE),HL			; $7247
			; ------------------------------------------
			LD HL,$9142						; $724A
			LD (HL),$FF						; $724D
			LD ($9140),HL					; $724F
			; ------------------------------------------
			LD HL,$921E						; $7252
			LD (HL),$FF						; $7255
			LD ($9265),HL					; $7257
			; ------------------------------------------

			CALL L_7457						; $725A	; clear blocking tile map ?
			CALL CLR_TABLE_ITEMS			; $725D ; 
			CALL CLR_GAME_SCREEN			; $7260 ; 
			;----------------------------------------
			LD A,(TABLE_INDEX)				; $7263 ; Index (each entry is 2 bytes)
			; $06, $0c,$0d
		
			LD BC,OFFSET_INTO_MAP			; $7266 ; Offset
			CALL GET_ADR_FROM_TABLE			; $7269
			;----------------------------------------

			; NOTE: DE is about to become store for a global x/y coordinate for setting screen attributes!
			LD DE,$2000						; $726C  ; D=Y,E=X (attributes ONLY, tiles have internal store!)
UPDATE_INGAME_TILES:	
			LD A,(HL)						; $726F ; Tile index ($FF indicates repeat same tile)
			INC HL							; $7270
			OR A							; $7271
			JR Z,SKIP_GROUP					; $7272
			CP $FF							; $7274 ; $FF=repeat same tile
			JR Z,TILE_GROUP_REPEAT			; $7276
			PUSH HL							; $7278
			CALL DRAW16x16_TILE				; $7279
			CALL SET_TILE16X16_COL			; $727C  ; DE=y/x coords
			CALL GET_ANIM_ADDR_AS_HL		; $727F
			LD (HL),A						; $7282  ; Tile hit map (base at $5F00)
			POP HL							; $7283
SKIP_GROUP:	LD A,E							; $7284
			ADD A,$08						; $7285  ; E=(X+=8), pixels as helper utils use pixels.
			LD E,A							; $7287
			CP $80							; $7288  ; Row Completion Check (16 steps)
			JP NZ,UPDATE_INGAME_TILES		; $728A
			LD A,D							; $728D
			CP $B0							; $728E  ; Limit draw on Y-axis (176)
			JR Z,BACKGROUND_DONE			; $7290  ; Finished Drawing 
			ADD A,$10						; $7292  ; D=(Y+=16)
			LD D,A							; $7294
			LD E,$00						; $7295  ; reset E=X
			JP UPDATE_INGAME_TILES			; $7297

; saves data - However overhead is 3 bytes ($FF,AMOUNT,TILE)
TILE_GROUP_REPEAT:		
			LD B,(HL)						; $729A  ; B=amount, draw same tile multiple times
			INC HL							; $729B
			LD A,(HL)						; $729C	 ; Tile index
			INC HL							; $729D
SPECIAL_TITLES:		
			LD C,A							; $729E
			OR A							; $729F
			JR Z,SKIP_SPECIAL				; $72A0
			PUSH HL							; $72A2
			CALL DRAW16x16_TILE				; $72A3
			CALL SET_TILE16X16_COL			; $72A6
			CALL GET_ANIM_ADDR_AS_HL		; $72A9
			LD (HL),A						; $72AC  ; Tile hit map (base at $5F00)
			LD C,A							; $72AD
			POP HL							; $72AE
SKIP_SPECIAL:
			LD A,E							; $72AF
			ADD A,$08						; $72B0
			LD E,A							; $72B2
			CP $80							; $72B3
			JP NZ,L_72C2					; $72B5
			LD A,D							; $72B8
			CP $B0							; $72B9
			JR Z,BACKGROUND_DONE			; $72BB
			ADD A,$10						; $72BD
			LD D,A							; $72BF
			LD E,$00						; $72C0
L_72C2:		LD A,C							; $72C2
			DJNZ SPECIAL_TITLES				; $72C3
			JP UPDATE_INGAME_TILES			; $72C5

BACKGROUND_DONE:		
			CALL L_742E						; $72C8
			LD IX,DATA_08					; $72CB
			LD DE,$2000						; $72CF  ; y/x coords
L_72D2:		CALL GET_ANIM_ADDR_AS_HL		; $72D2
			LD A,(HL)						; $72D5
			CP $E9							; $72D6  ; max tile value?
			JR C,L_72DF						; $72D8
			LD (HL),$00						; $72DA
			JP L_72EC						; $72DC
L_72DF:		OR A							; $72DF
			CALL NZ,L_732A					; $72E0

			CALL L_8748						; $72E3
			CALL L_6E07						; $72E6
			CALL L_73AA						; $72E9
L_72EC:		CALL L_8FD6						; $72EC
			CALL L_91B1						; $72EF

			CALL SPAWN_ENEMY_SHIPS			; $72F2  ; Generate flying enemies
			CALL PLACE_PICKUPS				; $72F5  ; first time pick up (mace,+1 items)

			LD A,E							; $72F8
			ADD A,$08						; $72F9
			LD E,A							; $72FB
			CP $80							; $72FC
			JP NZ,L_72D2					; $72FE
			LD A,D							; $7301
			CP $B0							; $7302
			JR Z,L_730E						; $7304
			ADD A,$10						; $7306
			LD D,A							; $7308
			LD E,$00						; $7309
			JP L_72D2						; $730B
L_730E:		LD (IX+$00),$FF					; $730E
			CALL CLR_SCRN_ATTRIBUTES		; $7312
			CALL L_9BD8						; $7315
			LD A,$01						; $7318
			LD ($9BD3),A					; $731A
			LD DE,(POS_XY)					; $731D
			LD (BACKSHOT_POS),DE			; $7321
			LD B,D							; $7325
			LD C,E							; $7326
			JP L_6953						; $7327
L_732A:		CP $E9							; $732A
			RET NC							; $732C

			PUSH AF					; $732D
			PUSH DE					; $732E
			PUSH HL					; $732F
			LD DE,$0005				; $7330
			LD B,A					; $7333
			LD HL,$736D				; $7334
L_7337:		LD A,(HL)				; $7337
			ADD HL,DE				; $7338
			CP $FF					; $7339
			JR Z,L_735B				; $733B
			CP B					; $733D
			JR NZ,L_7337			; $733E
			SBC HL,DE				; $7340
			INC HL					; $7342
			EX DE,HL				; $7343
			POP HL					; $7344
			PUSH HL					; $7345
			LD A,(DE)				; $7346
			LD (HL),A				; $7347
			INC HL					; $7348
			INC DE					; $7349
			LD A,(DE)				; $734A
			LD (HL),A				; $734B
			INC DE					; $734C
			LD BC,$001F				; $734D
			ADD HL,BC				; $7350
			LD A,(DE)				; $7351
			LD (HL),A				; $7352
			INC HL					; $7353
			INC DE					; $7354
			LD A,(DE)				; $7355
			LD (HL),A				; $7356
			POP HL					; $7357
			POP DE					; $7358
			POP AF					; $7359
			RET						; $735A

L_735B:		POP HL					; $735B
			PUSH HL					; $735C
			INC HL					; $735D
			LD (HL),$01				; $735E
			LD DE,$001F				; $7360
			ADD HL,DE				; $7363
			LD (HL),$01				; $7364
			INC HL					; $7366
			LD (HL),$01				; $7367
			POP HL					; $7369
			POP DE					; $736A
			POP AF					; $736B
			RET						; $736C

			defb $0F,$00,$00,$01,$01,$0D                        ; $736D ......
			defb $00,$00,$01,$01,$35,$01,$01,$00				; $7373 ....5...
			defb $00,$37,$01,$01,$00,$00,$80,$00				; $737B .7......
			defb $01,$01,$01,$82,$01,$00,$01,$01				; $7383 ........
			defb $83,$00,$00,$00,$00,$84,$00,$00				; $738B ........
			defb $00,$00,$89,$00,$00,$00,$00,$8A				; $7393 ........
			defb $00,$00,$00,$00,$95,$01,$00,$01				; $739B ........
			defb $00,$97,$00,$01,$00,$01,$FF                    ; $73A3 .......

L_73AA:		PUSH AF				; $73AA
			PUSH DE				; $73AB
			PUSH HL				; $73AC
			LD HL,$73F4			; $73AD
			LD B,A				; $73B0
L_73B1:		LD A,(HL)			; $73B1
			INC HL				; $73B2
			CP $FF				; $73B3
			JP Z,L_73F0			; $73B5
			CP B				; $73B8
			JR Z,L_73BF			; $73B9
			INC HL				; $73BB
			JP L_73B1			; $73BC
L_73BF:		PUSH HL				; $73BF
			PUSH BC				; $73C0
			LD L,(HL)			; $73C1
			LD H,$00			; $73C2
			LD C,L				; $73C4
			LD B,H				; $73C5
			ADD HL,HL			; $73C6
			ADD HL,HL			; $73C7
			ADD HL,BC			; $73C8
			LD BC,$7413			; $73C9
			ADD HL,BC			; $73CC
			PUSH HL				; $73CD
			POP IY				; $73CE
			LD L,(IY+$02)		; $73D0
			LD H,(IY+$03)		; $73D3
			LD (HL),E			; $73D6
			INC HL				; $73D7
			LD (HL),D			; $73D8
			INC HL				; $73D9
			LD C,(IY+$04)		; $73DA
			DEC C				; $73DD
			DEC C				; $73DE
			LD B,$00			; $73DF
			ADD HL,BC			; $73E1
			LD (HL),$FF			; $73E2
			LD (IY+$02),L		; $73E4
			LD (IY+$03),H		; $73E7
			POP BC				; $73EA
			POP HL				; $73EB
			INC HL				; $73EC
			JP L_73B1			; $73ED
L_73F0:		POP HL				; $73F0
			POP DE				; $73F1
			POP AF				; $73F2
			RET					; $73F3

			defb $2E,$00,$2F,$00,$8D,$00,$8E                    ; $73F4 ../....
			defb $00,$8F,$00,$90,$00,$27,$01,$32				; $73FB .....'.2
			defb $01,$52,$01,$94,$01,$98,$01,$46				; $7403 .R.....F
			defb $02,$47,$02,$81,$03,$83,$04,$FF				; $740B .G......
			defb $33,$75,$00,$00,$02,$1C,$8E,$00				; $7413 3u......
			defb $00,$02,$79,$98,$00,$00,$02,$A3				; $741B ..y.....
			defb $75,$00,$00,$02,$44,$76,$00,$00				; $7423 u...Dv..
			defb $02,$00,$00                                    ; $742B ...

L_742E:		LD BC,$0005				; $742E
			LD IX,$7413				; $7431
L_7435:		LD A,(IX+$00)			; $7435
			LD L,A					; $7438
			LD H,(IX+$01)			; $7439
			OR H					; $743C
			RET Z					; $743D
			LD (HL),$FF				; $743E
			LD (IX+$02),L			; $7440
			LD (IX+$03),H			; $7443
			ADD IX,BC				; $7446
			JP L_7435				; $7448

TABLE_INDEX:	
			defb $00				; $744B
			defb $00				; $744C

;--------------------------------------------------
GET_ADR_FROM_TABLE:		
			;Inputs: A=Table Index (each entry is 2 bytes), BC=Lookup table base
			LD L,A					; $744D
			LD H,$00				; $744E
			ADD HL,HL				; $7450
			ADD HL,BC				; $7451
			LD A,(HL)				; $7452
			INC HL					; $7453
			LD H,(HL)				; $7454
			LD L,A					; $7455
			RET						; $7456
;--------------------------------------------------

L_7457:		LD HL,$5F00				; $7457  ; blocking - tile map ?
			LD DE,$5F01				; $745A
			LD BC,$03FF				; $745D
			LD (HL),$00				; $7460
			LDIR					; $7462
			RET						; $7464

RESET_GAME:
			; ---------------------------------------------------
			LD (START_POS_TABLE_INDEX),A		; $7465
			ADD A,A								; $7468  ; x2
			ADD A,A								; $7469	 ; x4
			ADD A,A								; $746A  ; x8
			LD L,A								; $746B
			LD H,$00							; $746C
			LD BC,START_POS						; $746E  ; base
			ADD HL,BC							; $7471  ; offfset
			LD E,(HL)							; $7472	 ; Xpos
			INC HL								; $7473
			LD D,(HL)							; $7474  ; Ypos
			INC HL								; $7475
			LD (POS_XY),DE						; $7476
			LD (OLD_POS_XY),DE					; $747A
			; ---------------------------------------------------
			LD A,(HL)							; $747E
			LD ($744C),A						; $747F
			INC HL								; $7482
			LD A,(HL)							; $7483
			LD (TABLE_INDEX),A					; $7484
			;------------------------------------------------
			INC HL								; $7487
			LD E,(HL)							; $7488
			INC HL								; $7489
			LD D,(HL)							; $748A
			LD (COUNTDOWN_TIMER_RESET),DE		; $748B
			LD (COUNTDOWN_TIMER),DE				; $748F
			;------------------------------------------------
			INC HL								; $7493
			LD A,(HL)							; $7494f
			LD (DIRECTION),A					; $7495
			;------------------------------------------------
			XOR A								; $7498
			LD (EGG_TIMER),A					; $7499
			LD (DATA_11),A						; $749C
			LD (BACKSHOT_ENABLE),A				; $749F
			LD (MACE_ENABLE),A					; $74A2
			LD (INPUT_ENABLED),A				; $74A5
			LD (FRAME_COUNTER),A	  			; $74A8
			;------------------------------------------------
			LD HL,$0000							; $74AB
			LD ($7973),HL						; $74AE
			CALL L_7935							; $74B1
			;------------------------------------------------
			CALL CLR_SCREEN						; $74B4
			CALL L_77FF							; $74B7
			CALL RESET_FOR_NEXT_SCREEN			; $74BA
			;------------------------------------------------
			LD DE,(POS_XY)						; $74BD
			LD B,D								; $74C1
			LD C,E								; $74C2
			CALL L_6953							; $74C3
			JP INIT_GAME_SCREEN_TABLES			; $74C6

; Data is in a X,Y seqeuence (Xpos is 1/2 screen width)
; for example: (256/2)-8,(192/2)-8 will put the ship centre Y but far right screen edge
			;------------
START_POS:	defb $20,$90	; $74C9 ; ships starting x,y on screen
			defb $06,$00	; $74CB 
			defb $F4,$01
			defb $01,$00
			;------------
			defb $60,$50
			defb $06,$15
			defb $EE,$02
			defb $FF,$00
			;------------
			defb $60,$60		
			defb $08,$2B
			defb $84,$03
			defb $FF,$00                
			;------------

START_POS_TABLE_INDEX:	
			defb $00			; $74E1 

L_74E2:		PUSH AF				; $74E2
			PUSH BC				; $74E3
			PUSH DE				; $74E4
			PUSH HL				; $74E5
			DEC D				; $74E6
			DEC D				; $74E7
			DEC D				; $74E8
			DEC D				; $74E9
			DEC E				; $74EA
			DEC E				; $74EB
			JP L_74F3			; $74EC
L_74EF:		PUSH AF				; $74EF
			PUSH BC				; $74F0
			PUSH DE				; $74F1
			PUSH HL				; $74F2
L_74F3:		LD C,E				; $74F3
			LD B,D				; $74F4
			LD HL,DATA_14		; $74F5
L_74F8:		LD A,(HL)			; $74F8
			CP $FF				; $74F9
			JR NZ,L_7502		; $74FB
			POP HL				; $74FD
			POP DE				; $74FE
			POP BC				; $74FF
			POP AF				; $7500
			RET					; $7501
L_7502:		LD E,A				; $7502
			INC HL				; $7503
			LD D,(HL)					; $7504
			INC HL						; $7505
			PUSH HL						; $7506
			CALL COLLISION_DETECTION	; $7507
			OR A						; $750A
			JR Z,L_752F					; $750B
			CALL GET_ANIM_ADDR_AS_HL	; $750D
			LD A,(HL)					; $7510
			OR A						; $7511
			JR Z,L_752F					; $7512
			CALL ADD_EXPLOSION_WITH_SFX	; $7514
			LD A,(HL)					; $7517
			LD HL,SPRITE24x16_DATA		; $7518
			CALL DRAW4X4SPRITE			; $751B
			CALL L_6DE0					; $751E
			LD DE,$7904					; $7521
			CALL L_78D4					; $7524
			CALL L_788E					; $7527
			LD A,$04					; $752A
			CALL SET_BEEPER_SFX					; $752C
L_752F:		POP HL						; $752F
			JP L_74F8					; $7530

DATA_14:	defb $45,$54,$52,$49,$45,$56,$45,$20		; $7533 ETRIEVE
			defb $4F,$4C,$44,$20,$43,$4F,$4F,$52		; $753B OLD COOR
			defb $44,$53,$0D,$0A,$09,$4C,$44,$09		; $7543 DS...LD.
			defb $41,$2C,$45,$0D,$0A,$09,$41,$4E		; $754B A,E...AN
			defb $44,$09,$30,$31,$31,$31,$31,$31		; $7553 D.011111
			defb $30,$30,$42,$0D,$0A,$09,$52,$52		; $755B 00B...RR
			defb $43,$41,$0D,$0A,$09,$52,$52,$43		; $7563 CA...RRC
			defb $41,$0D,$0A,$09,$4C,$44,$09,$28		; $756B A...LD.(
			defb $24,$33,$2B,$31,$29,$2C,$41,$0D		; $7573 $3+1),A.
			defb $0A,$09,$4C,$44,$09,$43,$2C,$44		; $757B ..LD.C,D
			defb $FF                                    ; $7583 .

VOLCANO_EJECTA:		
			LD HL,VOLCANO_LIST		; $7584
L_7587:		LD A,(HL)				; $7587
			CP $FF					; $7588
			RET Z					; $758A
			LD E,A					; $758B
			INC E					; $758C
			INC E					; $758D
			INC HL					; $758E
			LD D,(HL)				; $758F
			LD A,D					; $7590
			SUB $08					; $7591
			LD D,A					; $7593
			INC HL					; $7594
			LD A,$01				; $7595
			CALL GET_RAND_VALUE				; $7597
			ADD A,$42				; $759A
			LD C,A					; $759C
			CALL L_6E8B				; $759D
			JP L_7587				; $75A0

VOLCANO_LIST:
			defb $49,$54,$45,$20,$41,$44,$44,$52				; $75A3 ITE ADDR
			defb $45,$53,$53,$0D,$0A,$09,$45,$58				; $75AB ESS...EX
			defb $58,$0D,$0A,$0D,$FF                            ; $75B3 X....

			; ---------------------------------------------------------
END_LEVEL:	LD DE,(DATA_11+1)			; $75B8
			LD A,E						; $75BC
			CP $FF						; $75BD  ;
			RET Z						; $75BF	 ; flag $FF, get out
			; ---------------------------------------------------------
			LD A,(DATA_11)				; $75C0
			OR A						; $75C3
			JP Z,L_75DC					; $75C4  ; A==0, jmp
			; ---------------------------------------------------------
			DEC A						; $75C7
			LD (DATA_11),A				; $75C8  ; store a-=1
			RET NZ						; $75CB  ; A!=0, return
			; ---------------------------------------------------------
			CALL L_7647					; $75CC
			LD A,(START_POS_TABLE_INDEX)			; $75CF
			INC A						; $75D2
			CP $03						; $75D3  
			JP NZ,RESET_GAME			; $75D5  ; A!=3, jump to RESET_GAME
			XOR A						; $75D8
			JP RESET_GAME				; $75D9
			; ---------------------------------------------------------
L_75DC:		LD HL,(POS_XY)				; $75DC
			LD A,D						; $75DF
			SUB $10						; $75E0
			CP H						; $75E2
			RET NC						; $75E3  ; A >= H, return
			LD A,E						; $75E4
			INC L						; $75E5
			INC L						; $75E6
			CP L						; $75E7
			RET NC						; $75E8  ; A >= L, return
			ADD A,$08					; $75E9
			DEC L						; $75EB
			DEC L						; $75EC
			DEC L						; $75ED
			DEC L						; $75EE
			CP L						; $75EF
			RET C						; $75F0  ; A < L, return
			LD HL,SPRITE24x16_DATA				; $75F1
			LD A,$83					; $75F4
			CALL DRAW4X4SPRITE			; $75F6
			LD A,$0C					; $75F9
			CALL L_9FA2					; $75FB
			LD A,E						; $75FE
			ADD A,$08					; $75FF
			LD E,A						; $7601
			LD HL,SPRITE24x16_DATA				; $7602
			LD A,$84					; $7605
			CALL DRAW4X4SPRITE			; $7607
			LD A,$0D					; $760A
			CALL L_9FA2					; $760C
			LD A,D						; $760F
			SUB $10						; $7610
			LD D,A						; $7612
			LD A,E						; $7613
			SUB $04						; $7614
			LD E,A						; $7616
			LD A,$0E					; $7617
			CALL L_9FA2					; $7619
			LD A,$FF					; $761C
			LD (INPUT_ENABLED),A				; $761E
			LD A,$40					; $7621
			LD (DATA_11),A				; $7623
			LD DE,(POS_XY)				; $7626
			LD B,D						; $762A
			LD C,E						; $762B
			LD HL,SPRITE24x16_DATA					; $762C
			LD (SPRITE_GFX_BASE),HL				; $762F
			LD (BACKSHOT_GFX_BASE),HL				; $7632
			LD (MACE_GFX_BASE),HL				; $7635
			CALL L_6953					; $7638
			XOR A						; $763B
			LD (BACKSHOT_ENABLE),A				; $763C
			LD (MACE_ENABLE),A				; $763F
			RET							; $7642

DATA_11:
			defb $00,$00,$00,$FF    	; $7643 

L_7647:		CALL CLR_GAME_SCREEN		; $7647
			XOR A						; $764A
			LD ($696A),A				; $764B
			LD A,$4A					; $764E
			LD (TABLE_INDEX),A			; $7650
			CALL RESET_FOR_NEXT_SCREEN	; $7653
			LD DE,$1038					; $7656  ; D=Y,E=X
			; ----------------------------------------------------------------
			LD A,$0C					; $7659  ; 
			CALL L_9FA2					; $765B  ; Add platform lift (left part)
			; ----------------------------------------------------------------
			LD A,E						; $765E
			ADD A,$08					; $765F  ; Xpos
			LD E,A						; $7661
			LD A,$0D					; $7662	 ; 
			CALL L_9FA2					; $7664  ; Add platforms lift (right part)
			; ----------------------------------------------------------------
			LD A,D						; $7667
			SUB $10						; $7668  ; Y-=16
			LD D,A						; $766A
			LD A,E						; $766B
			SUB $04						; $766C  ; X+=4, center on lift
			LD E,A						; $766E
			LD A,$0E					; $766F
			CALL L_9FA2					; $7671  ; add player's ship

			LD B,$60					; $7674
			;---------------------------------------------
			; Player lowered into bunus area
L_7676:		PUSH BC						; $7676
			HALT						; $7677
			HALT						; $7678
			CALL DRAW_PICKUPS			; $7679  ; Platform & Player's ship
			CALL DO_PICKUPS				; $767C  ; move down
			POP BC						; $767F
			DJNZ L_7676					; $7680
			;---------------------------------------------
			LD A,(EGG_TIMER)			; $7682
			CP $11						; $7685
			JP NC,BAD_LUCK_MESSAGE		; $7687
			LD HL,($7973)				; $768A
			LD DE,$05DC					; $768D
			AND A						; $7690
			SBC HL,DE					; $7691
			JR C,BAD_LUCK_MESSAGE		; $7693
			;---------------------------------------------
			LD HL,$796D					; $7695
			LD DE,BONUS_POINTS_TXT 			; $7698
			LD BC,$0005					; $769B
			LDIR						; $769E ; copy data
			;---------------------------------------------
			; Display - Well Done message
			LD HL,WELL_DONE_TXT			; $76A0
			CALL DRAW_LIST				; $76A3
			LD HL,LIVES					; $76A6	; load lives
			INC (HL)					; $76A9	; bonus life
			LD DE,$7972					; $76AA
			CALL L_78D4					; $76AD
LOOP_WDM_FIRE:
			CALL USER_INPUT				; $76B0
			LD A,(FIRE_BUTTON)			; $76B3
			OR A						; $76B6
			JP Z,LOOP_WDM_FIRE			; $76B7
			RET							; $76BA
			;---------------------------------------------
			; Display - Bad Luck message
BAD_LUCK_MESSAGE:
			LD HL,BAD_LUCK_TXT			; $76BB
			CALL DRAW_LIST				; $76BE
LOOP_BLM_FIRE:
			CALL USER_INPUT				; $76C1
			LD A,(FIRE_BUTTON)			; $76C4
			OR A						; $76C7
			JP Z,LOOP_BLM_FIRE			; $76C8
			RET							; $76CB
			;-----------------------------------------------		
WELL_DONE_TXT:												; $76CC   
			defb SET_SOURCE_DATA 
			defw FONT_DATA		
			defb GLOBAL_COL,%01000101	 ; (bright cyan)						
			defb SET_POS,19,3										
			defb "WELL DONE CYBERNOID PILOT!" 
			defb MOVE+2,228, "YOUR SKILL HAS EARNED ANOTHER"
			defb MOVE+2,227,"CRAFT AND "					; $770D			
			defb INK_YELLOW 
BONUS_POINTS_TXT:
			defb "000000"	 			      			    ; $771A	
			defb INK_CYAN," BONUS POINTS.",END_MARKER       ; $7720
			; ----------------------------------------------
BAD_LUCK_TXT:												; $7730
			defb SET_SOURCE_DATA
			defw FONT_DATA                				
			defb GLOBAL_COL,%01000011	; (bright magenta)
			defb SET_POS,19,3										 
			defb "YOU HAVE FAILED TO RETREIVE"						 
			defb $7A,$E2, "A CARGO VALUE OF 1500 WITHIN THE"		 
			defb $7A,$E4, "TIME ALLOCATED - BAD LUCK"				 
			defb END_MARKER											
			; ---------------------------------------------

			defb $FF,$06
			defb $00,$87,$00,$00,$87,$FF,$0C,$00				; $7793 ........
			defb $87,$00,$00,$87,$FF,$09,$00,$0B				; $779B ........
			defb $00,$00,$8B,$00,$00,$8B,$FF,$09				; $77A3 ........
			defb $00,$0A,$00,$00,$87,$00,$00,$87				; $77AB ........
			defb $FF,$09,$00,$09,$00,$00,$87,$00				; $77B3 ........
			defb $00,$87,$00,$46,$46,$FF,$05,$00				; $77BB ...FF...
			defb $06,$07,$08,$00,$88,$89,$8A,$88				; $77C3 ........
			defb $00,$4C,$4D,$46,$00,$00,$FF,$05				; $77CB .LMF....
			defb $14,$9A,$FF,$04,$9B,$9C,$FF,$05				; $77D3 ........
			defb $14,$FF,$30,$00,$E5,$CD,$44,$11				; $77DB ..0...D.
			defb $C2,$B5,$0A,$CD,$EF,$0B,$CD,$E1				; $77E3 ........
			defb $0B,$E1,$18,$E8,$19,$11,$00,$40				; $77EB .......@
			defb $19,$E5,$36,$FA,$23,$35,$23,$35				; $77F3 ..6.#5#5
			defb $97,$32,$6E,$0A                                ; $77FB .2n.

L_77FF:
			LD HL,$7814				; $77FF
			CALL DRAW_LIST			; $7802
			CALL L_788E				; $7805
			CALL L_78AF				; $7808
			CALL L_78C8				; $780B
			CALL L_79A9				; $780E
			JP UPDATE_WEAPONS_DISPLAY				; $7811

			defb $DF,$00,$00,$E6,$D1,$C5,$DE                    ; $7814 .......
			defb $18,$DC,$E4,$1E,$19,$DE,$1A,$DF				; $781B ........
			defb $03,$00,$DE,$1B,$DC,$E4,$1E,$1C				; $7823 ........
			defb $DE,$1D,$DF,$01,$01,$DE,$00,$01				; $782B ........
			defb $AD,$02,$03,$DF,$01,$06,$DC,$0A				; $7833 ........
			defb $DB,$0B,$AD,$0C,$D3,$0D,$DF,$01				; $783B ........
			defb $0F,$DE,$04,$DD,$05,$AD,$DD,$06				; $7843 ........
			defb $D5,$07,$78,$02,$DA,$08,$D2,$09				; $784B ..x.....
			defb $DF,$01,$18,$DA,$0E,$D2,$0F,$AD				; $7853 ........
			defb $10,$D9,$11,$DF,$01,$00,$DC,$1E				; $785B ........
			defb $AE,$1E,$DF,$01,$1F,$DC,$1E,$AE				; $7863 ........
			defb $1E,$DF,$00,$05,$E3,$7F,$78,$DF				; $786B ......x.
			defb $00,$0E,$E3,$7F,$78,$DF,$00,$17				; $7873 ....x...
			defb $E3,$7F,$78,$FF,$DE,$1F,$D4,$23				; $787B ..x....#
			defb $AD,$DE,$20,$AE,$D6,$21,$AE,$22				; $7883 .. ..!."
			defb $D4,$24,$FF                                    ; $788B .$.

L_788E:
			PUSH AF				; $788E
			PUSH BC				; $788F
			PUSH DE				; $7890
			PUSH HL				; $7891
			LD C,$45				; $7892
			LD HL,FONT_DATA			; $7894
			LD (ICON_LD_ADDR+1),HL				; $7897
			LD HL,$78F9				; $789A
			LD DE,$0108				; $789D
			LD B,$06				; $78A0
L_78A2:
			LD A,(HL)				; $78A2
			CALL ICON16x16				; $78A3
			INC E				; $78A6
			INC HL				; $78A7
			DJNZ L_78A2				; $78A8
			POP HL				; $78AA
			POP DE				; $78AB
			POP BC				; $78AC
			POP AF				; $78AD
			RET				; $78AE

L_78AF:
			LD HL,FONT_DATA				; $78AF
			LD (ICON_LD_ADDR+1),HL				; $78B2
			LD C,$43				; $78B5
			LD HL,$796C				; $78B7
			LD DE,$0208				; $78BA
			LD B,$06				; $78BD
L_78BF:
			LD A,(HL)				; $78BF
			CALL ICON16x16				; $78C0
			INC E				; $78C3
			INC HL				; $78C4
			DJNZ L_78BF			; $78C5
			RET					; $78C7

; === DISPLAY LIVES ===												
L_78C8:
			LD A,(LIVES)			; $78C8	; load lives;
			LD DE,$0203				; $78CB	; char_y=02,char_x=03
			LD C,$46				; $78CE	; colour (FBPPPIII)
			JP Display3DigitNumber	; $78D0	; display score

LIVES:		defb $0					; $78D3	

L_78D4:
			PUSH AF				; $78D4
			PUSH BC				; $78D5
			PUSH DE				; $78D6
			PUSH HL				; $78D7
			LD C,$00				; $78D8
			LD HL,$78FE				; $78DA
			LD B,$06				; $78DD
L_78DF:
			LD A,(DE)				; $78DF
			ADD A,(HL)				; $78E0
			SUB $30				; $78E1
			ADD A,C				; $78E3
			CP $3A				; $78E4
			LD C,$01				; $78E6
			JR C,L_78EE				; $78E8
			SUB $0A				; $78EA
			JR L_78EF				; $78EC

L_78EE:
			DEC C				; $78EE
L_78EF:
			LD (HL),A				; $78EF
			DEC HL				; $78F0
			DEC DE				; $78F1
			DJNZ L_78DF				; $78F2
			POP HL				; $78F4
			POP DE				; $78F5
			POP BC				; $78F6
			POP AF				; $78F7
			RET				; $78F8

			defb $30,$30                                        ; $78F9 00
			defb $30,$30,$30,$30,$30,$30,$30,$30				; $78FB 00000000
			defb $32,$35,$30,$30,$30,$31,$30,$30				; $7903 25000100
			defb $30,$30,$30,$32,$35,$30,$30,$30				; $790B 00025000
			defb $30,$35,$30,$30,$30,$30,$31,$30				; $7913 05000010
			defb $30,$30,$30,$30,$32,$30,$30,$30				; $791B 00002000
			defb $30,$30,$35,$30,$30,$30,$30,$31				; $7923 00500001
			defb $30,$30,$30,$30,$30,$32,$30,$30				; $792B 00000200
			defb $30,$30                                        ; $7933 00

L_7935:
			LD HL,($7973)				; $7935
			LD IX,$796D				; $7938
			LD IY,$7962				; $793C
L_7940:
			LD A,$30				; $7940
			LD E,(IY+$00)				; $7942
			LD D,(IY+$01)				; $7945
L_7948:
			OR A				; $7948
			SBC HL,DE				; $7949
			JR C,L_7950				; $794B
			INC A				; $794D
			JR L_7948				; $794E

L_7950:
			ADD HL,DE				; $7950
			LD (IX+$00),A				; $7951
			INC IX				; $7954
			INC IY				; $7956
			INC IY				; $7958
			LD A,(IX+$00)				; $795A
			CP $FF				; $795D
			RET Z				; $795F
			JR L_7940				; $7960

			defb $10                                            ; $7962 .
			defb $27,$E8,$03,$64,$00,$0A,$00,$01				; $7963 '..d....
			defb $00,$30,$30,$30,$30,$30,$30,$FF				; $796B .000000.
			defb $00,$00,$00,$00                                ; $7973 ....

; === Display Routine, uses custom font FONT_DATA ($C2F1) ===					
; note: the game code chops off the 3 digit! Can be fixed to display 3 digits.
Display3DigitNumber:  ; L_7977:
			PUSH BC					; $7977
			PUSH HL					; $7978
			LD HL,FONT_DATA			; $7979 ; font data
			LD (ICON_LD_ADDR+1),HL	; $797C	; modifies this "LD BC,$XXXX" @ICON_LD_ADDR+1 
			LD B,$64				; $797F
			CALL Display8x8Digits	; $7981 ; hundreds
			LD B,$0A				; $7984
			CALL Display8x8Digits	; $7986	; hundreds
			LD B,$01				; $7989
			CALL Display8x8Digits	; $798B	; last digit
			POP HL					; $798E
			POP BC					; $798F
			RET						; $7990

Display8x8Digits:
			LD L,$00				; $7991
COUNT_DIGIT_VALUE:
			SUB B					; $7993
			JR C,COUNT_DIGIT_DONE	; $7994
			INC L					; $7996 ; count the digit value
			JR COUNT_DIGIT_VALUE	; $7997
COUNT_DIGIT_DONE:
			ADD A,B				; $7999  ; remainder
			PUSH AF				; $799A
			
			; Note: this will chop off the 3 digit (?could update to space leading zeros?)
			LD A,B				; $799B
			CP $64				; $799C	 ; skip digits after 100
			
			JR Z,L_79A7			; $799E
			LD A,L				; $79A0
			ADD A,$30			; $79A1  ; ascii 48 = "0"
			CALL ICON16x16			; $79A3	 ; Display 8X8 icon
			INC E				; $79A6	 ; X coords 
L_79A7:
			POP AF				; $79A7
			RET					; $79A8

; Display Egg Timer 
; E register: X coords (initial $7B = 123)
L_79A9:		LD HL,$79BE			; $79A9  ; data address
			CALL DRAW_LIST			; $79AC
			LD A,(EGG_TIMER)	; $79AF  ; count down from 17 (egg timer)
			OR A				; $79B2
			RET Z				; $79B3  ; dont display
			LD E,$7B			; $79B4	 ; X coord
			LD B,A				; $79B6  ; get number segments
L_79B7:		CALL L_79D4			; $79B7  ; Wipe timer segment
			DEC E				; $79BA  ; Move left
			DJNZ L_79B7			; $79BB  ; do remaining
			RET					; $79BD

			defb $DF,$01,$1D,$E6,$D1                            ; $79BE .....
			defb $C5,$E0,$05,$12,$DC,$13,$AB,$D3				; $79C3 ........
			defb $14,$DB,$15,$D4,$16,$DC,$17,$FF				; $79CB ........
EGG_TIMER	defb $00                                            ; $79D3 .

L_79D4:
			PUSH AF					; $79D4
			PUSH BC					; $79D5
			PUSH HL					; $79D6
			LD A,E					; $79D7  ; Get X
			AND $03					; $79D8	 ; limit sampling to 4 mask items
			LD L,A					; $79DA	 ; HL (holds X as offset)
			LD H,$00				; $79DB
			LD BC,EGG_TIMER_MASK	; $79DD  ; Mask table
			ADD HL,BC				; $79E0  ; Now HL points to mask
			LD C,(HL)				; $79E1  ; get mask (based of X)

			LD HL,$4020				; $79E2  ; Screen (top right)
			LD A,E					; $79E5  ; 
			AND $FC					; $79E6  ; boundary (x & %11111100)
			RRCA					; $79E8  ; /2
			RRCA					; $79E9  ; /4
			ADD A,L					; $79EA
			LD L,A					; $79EB
			LD B,$10				; $79EC  ; 16 lines
BLANK_LP:	LD A,C					; $79EE  ; get mask
			AND (HL)				; $79EF  ; mask out pixels using screen
			LD (HL),A				; $79F0  ; Update screen
			CALL NEXT_SCR_LINE		; $79F1
			DJNZ BLANK_LP			; $79F4  ; do remaining
			POP HL					; $79F6
			POP BC					; $79F7
			POP AF					; $79F8
			RET						; $79F9

			; Egg timer mask: 00111111110011111111001111111100
EGG_TIMER_MASK		
			defb $3F                ; $79FA  ; %00111111
			defb $CF 		        ; $79FB  ; %11001111
			defb $F3				; $79FC  ; %11110011
			defb $FC				; $79FD  ; %11111100


; Countdown Timer with screen update
; COUNTDOWN_TIMER: Current timer (16bit)
; $7A1D: Timer reset  (16bit)
; $79D3: Display state counter (8bit)
DO_EGG_TIMER:		
			LD HL,(COUNTDOWN_TIMER)				; $79FE
			DEC HL								; $7A01
			LD (COUNTDOWN_TIMER),HL				; $7A02
			LD A,L								; $7A05
			OR H								; $7A06
			RET NZ								; $7A07  ; not expired

			LD HL,(COUNTDOWN_TIMER_RESET)		; $7A08
			LD (COUNTDOWN_TIMER),HL				; $7A0B  ; Timer expired - reset

			LD A,(EGG_TIMER)					; $7A0E  ; display state
			CP $11								; $7A11  ; final state (17)
			RET Z								; $7A13  ; stop displaying timer
			
			INC A								; $7A14  ; this will reduce timer
			LD (EGG_TIMER),A					; $7A15  ; store

			JP L_79A9							; $7A18  ;Update display

COUNTDOWN_TIMER				defb $00,$00		; $7A1B ; Egg Timer current
COUNTDOWN_TIMER_RESET		defb $00,$00		; $7A1D ; Egg Timer reset


; draw ships shots
DRAW_PLR_BULLETS: 	
			PUSH AF							; $7A1F
			PUSH BC							; $7A20
			PUSH HL							; $7A21
			LD A,E							; $7A22
			AND $03							; $7A23
			LD L,A							; $7A25
			LD H,$00						; $7A26
			LD BC,L_7A4C					; $7A28
			ADD HL,BC						; $7A2B
			LD C,(HL)						; $7A2C
			CALL LOOKUP_6300_ADDR_OFFSET	; $7A2D
			LD A,C							; $7A30
			XOR (HL)						; $7A31
			LD (HL),A						; $7A32
			LD A,H							; $7A33
			RRCA							; $7A34
			RRCA							; $7A35
			RRCA							; $7A36
			AND $03							; $7A37
			LD H,A							; $7A39
			LD BC,$5B00						; $7A3A
			ADD HL,BC						; $7A3D
			LD A,(HL)						; $7A3E
			OR A							; $7A3F
			JR NZ,L_7A48					; $7A40
			LD BC,$FD00						; $7A42
			ADD HL,BC						; $7A45
			LD (HL),$47						; $7A46
L_7A48:		POP HL							; $7A48
			POP BC							; $7A49
			POP AF							; $7A4A
			RET								; $7A4B
L_7A4C:		RET NZ							; $7A4C
			JR NC,RESET_WEAPON_TIMER		; $7A4D
			INC BC							; $7A4F

;--------------------------------------------------------------------------------
DO_PLR_SHOOTING:		
			LD A,(INPUT_ENABLED)			; $7A50
			OR A							; $7A53
			RET NZ							; $7A54  ; A!=0, return
			LD A,(FIRE_BUTTON)				; $7A55
			OR A							; $7A58
			JR NZ,FIRE_PRESSED				; $7A59  ; A!=0 
RESET_WEAPON_TIMER:		
			LD (SUPER_WEAPON_TIMER),A		; $7A5B  ; Reset cooldown timer (A=0 here)
			RET								; $7A5E  ; do nothing, get out
			; -----------------------------------------------------
FIRE_PRESSED:
			LD A,(SUPER_WEAPON_TIMER)		; $7A5F
			OR A							; $7A62
			JR Z,L_7A6B						; $7A63  ; Timer expired (ready to fire)
			INC A							; $7A65  ; 
			RET Z							; $7A66  ; stop timer overflow
			LD (SUPER_WEAPON_TIMER),A		; $7A67
			RET								; $7A6A  ; Exit during cooldown

L_7A6B:		INC A							; $7A6B  ; init to 1
			LD (SUPER_WEAPON_TIMER),A		; $7A6C  ; 
			LD DE,(POS_XY)					; $7A6F  ; D=Ypos, E=Xpos
			; ----------------------------------------------------------------
			; Self-modifying code to store offset for top/bottom barrel positions
			LD A,(BARREL_OFFSET)		; $7A73
			XOR $04						; $7A76 
			LD (BARREL_OFFSET),A		; $7A78  
			ADD A,D						; $7A7B ; $0A or $0E
			LD D,A						; $7A7C ; 
			; ------------------------------------------------------
			; Fire Forward Twin Guns (each barrel takes turns)
			LD A,(DIRECTION)			; $7A7D
			CP $FF						; $7A80
			LD A,$05					; $7A82
			JR NZ,L_7A88				; $7A84
			LD A,$01					; $7A86
L_7A88:		ADD A,E						; $7A88
			LD E,A						; $7A89
			LD A,(DIRECTION)			; $7A8A ; $FF=(-)left, $01=(+)right (bullet velocity)
			ADD A,A						; $7A8D ; x2 (-2 or +2)
			ADD A,A						; $7A8E ; x4 (-4 or +4)
			CALL ADD_BULLET				; $7A8F ; Fire front guns, D=Y,E=X,A=offset
			; ------------------------------------------------------
			LD A,(BACKSHOT_ENABLE)		; $7A92
			OR A						; $7A95
			RET Z						; $7A96  ; No backshot, exit
			; -------------------------------------------
			; Backshot Gun Logic
			LD DE,(POS_XY)				; $7A97
			LD A,(DIRECTION)			; $7A9B
			CP $FF						; $7A9E
			; Facing left, so backshot is facing right 
			LD A,14						; $7AA0 (14 pixels)  
			LD C,4						; $7AA2	
			JR Z,BACKSHOT_OFFSETS		; $7AA4  
			; Facing right, so backshot is facing left
            LD A,-6                   	; Xoff (-12 pixels)
            LD C,-4                    	; Yoff 
BACKSHOT_OFFSETS:
			ADD A,E						; $7AAA
			LD E,A						; $7AAB  ; Xpos
			LD A,D						; $7AAC
			ADD A,$04				    ; $7AAD  
			LD D,A						; $7AAF  ; Ypos+=4 line up with back barrel
			LD A,C						; $7AB0  ; Bullet velocity
			JP ADD_BULLET				; Fire back gun, D=Y,E=X,A=offset

			; -------------------------------------------
BARREL_OFFSET: 							; Address toggles between -4 or 4
			LD A,(BC)					; $7AB4; Placeholder instruction for data
			; -------------------------------------------
			
ADD_BULLET:
			EX AF,AF'					; $7AB5  ; fast push (!!! interrupt uses EX AF,AF' too) 
			LD A,E						; $7AB6
			CP $7C						; $7AB7
			RET NC						; $7AB9  ;  X>=124 (248pixels), exit
			; ------------------------------------------------------------
			LD HL,BULLET_LIST			; $7ABA
FIND_UNUSED_LOOP:		
			BIT 7,(HL)					; $7ABD  ; XPos (bit 7=end loop)
			RET NZ						; $7ABF  ; list end, exit
			INC HL						; $7AC0
			INC HL						; $7AC1
			LD A,(HL)					; $7AC2
			INC HL						; $7AC3
			OR A						; $7AC4
			JR NZ,FIND_UNUSED_LOOP 	    ; $7AC5
			; ------------------------------------------------------------
			; If an interrupt occurs inside this routine, it will overwrite the AF/AF' pair.
			; This may alter velocity, causing bullets to stop or move at high speed!
			EX AF,AF'					; $7AC7 ; fast pop (!!! interrupt uses EX AF,AF' too)

			DEC HL						; $7AC8
			LD (HL),A					; $7AC9  ; Bullet velocity
			DEC HL						; $7ACA
			LD (HL),D					; $7ACB  ; Ypos
			DEC HL						; $7ACC
			LD (HL),E					; $7ACD	 ; Xpos

			; --------------------------------------------
			LD A,$05					; $7ACE
			CALL SET_BEEPER_SFX			; $7AD0
			; --------------------------------------------

			PUSH HL						; $7AD3
			PUSH DE						; $7AD4
			LD E,SFX_BULLETS			; $7AD5
			CALL PLAY_SFX				; $7AD7   ; ships guns
			POP DE						; $7ADA
			CALL GET_ANIM_ADDR_AS_HL	; $7ADB
			LD A,(HL)					; $7ADE
			OR (HL)						; $7ADF
			POP HL						; $7AE0
			JP Z,DRAW_PLR_BULLETS		; $7AE1 
			INC HL						; $7AE4
			INC HL						; $7AE5
			LD (HL),$00					; $7AE6
			RET							; $7AE8

SUPER_WEAPON_TIMER:			defb $00  ;  $7AE9


PLR_UPDATE_SHOTS:		
			LD A,$03					; $7AEA
			CALL L_67B9					; $7AEC
			LD HL,BULLET_LIST			; $7AEF  ; each 3
CHECK_BULLETS_LOOP:		
			LD E,(HL)					; $7AF2
			BIT 7,E						; $7AF3  ; XPos (bit 7=end loop)
			RET NZ						; $7AF5
			INC HL						; $7AF6
			LD D,(HL)					; $7AF7  ; Ypos
			INC HL						; $7AF8
			LD A,(HL)					; $7AF9  ; Movement delta	
			INC HL						; $7AFA
			OR A						; $7AFB  
			JR Z,CHECK_BULLETS_LOOP		; $7AFC ; delta!=0, bullet active/moving
			LD C,E						; $7AFE 
			ADD A,E						; $7AFF ; Xpos+=delta
			CP $7C						; $7B00  
			JR NC,SHOT_HIT				; $7B02  ; >124, Screen edge
			EX AF,AF'					; $7B04
			PUSH HL						; $7B05
			CALL GET_ANIM_ADDR_AS_HL	; $7B06
			LD A,(HL)					; $7B09  ; Get tile properties
			POP HL						; $7B0A
			OR A						; $7B0B
			JR NZ,SHOT_HIT				; $7B0C  ; collision solid tile
			CALL ENEMY_COLLISIONS		; $7B0E
			JP NZ,SHOT_HIT				; $7B11	 ; hit Enemy
			EX AF,AF'					; $7B14
			LD E,A						; $7B15  ; Updated Xpos
			;-------------------------------------------------------------
			; Update Bullet Position (walk struct)
			DEC HL						; $7B16
			DEC HL						; $7B17
			DEC HL						; $7B18
			LD (HL),A					; $7B19	 ; Update Xpos
			INC HL						; $7B1A
			INC HL						; $7B1B
			INC HL						; $7B1C
			;-------------------------------------------------------------
			CALL DRAW_PLR_BULLETS		; $7B1D  ; Erase bullet at old position (XOR draw)
			LD E,C						; $7B20  ; C=Xpos+delta
			CALL DRAW_PLR_BULLETS		; $7B21  ; Draw bullet at new position 
			JP CHECK_BULLETS_LOOP		; $7B24

SHOT_HIT:	CALL DRAW_PLR_BULLETS		; $7B27  ; Erase bullet
			DEC HL						; $7B2A
			LD (HL),$00					; $7B2B  ; Deactivate bullet (delta=0)
			INC HL						; $7B2D	
			CALL SPARKLE_EFFECT			; $7B2E  ; Bullet splash effect (hit scene)
			CALL L_74EF					; $7B31
			JR CHECK_BULLETS_LOOP		; $7B34

; Bullet list: X,Y,Delta (x3 Bytes)
; XPos (bit 7=end loop)
BULLET_LIST:  
			defb $0A,$09,$4C            ; $7B36
			defb $44,$09,$48
			defb $2C,$30,$0D
			defb $0A,$09,$41
			defb $44,$44,$09
			defb $48,$4C,$2C
			defb $FF                
			
LAST_WEAPON_USED:
			defb $00 									; $7B49

; Weapon selection and Display
SELECT_PLR_WEAPON:
			LD A,$F7					; $7B4A  ; keys "1-5"
			IN A,($FE)					; $7B4C
			AND $1F						; $7B4E  ; Mask 
			CP $1F						; $7B50
			JR NZ,WEAPON_KEYS_USED		; $7B52  ; keys pressed (all bits 1 = no press)
			; No keys - reset last_weapon_used
			XOR A						; $7B54  ;
			LD (LAST_WEAPON_USED),A				; $7B55  ; zero
			RET							; $7B58
WEAPON_KEYS_USED:
			LD D,A						; $7B59 ; Store raw keys
			LD A,(LAST_WEAPON_USED)				; $7B5A  
			OR A						; $7B5D
			RET NZ						; $7B5E ; Exit (last_weapon_used)
		  	; New key press detected
			INC A						; $7B5F ; init 1
			LD (LAST_WEAPON_USED),A				; $7B60 ; Update last_weapon_used
			LD A,D						; $7B63 ; Restore keys
			; find which key was pressed
			LD BC,$0500           		; B=5 (bits to check) note: C=0 (key index counter)
CHECK_KEY_BITS:
			RRCA                    	; get each key bits
			JR NC,L_7B6E            	; bit was 0 (key pressed), exit loop
			INC C                   	; index
			DJNZ CHECK_KEY_BITS        	; 
			RET                     	; Fallback - shouldn't be reached
				
L_7B6E:		LD A,C						; $7B6E ;  key index (0-4)
			LD (SELECTED_WEAPON),A		; $7B6F

UPDATE_WEAPONS_DISPLAY:		
			LD C,$47					; $7B72 ;  Attribute colour 
			LD A,(SELECTED_WEAPON)		; $7B74 

			LD HL,FONT_DATA				; $7B77
			LD (ICON_LD_ADDR+1),HL		; $7B7A  ; Self-modify code to font data
			ADD A,A						; $7B7D  ; x2
			ADD A,A						; $7B7E  ; x4
			ADD A,A						; $7B7F  ; x8
			ADD A,A						; $7B80  ; x16
			LD L,A						; $7B81
			LD H,$00					; $7B82  HL = index * 16
			LD DE,BOMBS_LABEL			; $7B84
			ADD HL,DE					; $7B87

			LD DE,$0111					; $7B88  ; y=1,x=17
			LD B,$06					; $7B8B  ; 6 chars
CHAR_LOOP:	LD A,(HL)					; $7B8D	 ; get Char index
			CALL ICON16x16				; $7B8E	 ; draw text
			INC HL						; $7B91  ; onto next data
			INC E						; $7B92  ; move Xpos
			DJNZ CHAR_LOOP					; $7B93

			; Display current ammo count
			LD DE,$0005					; $7B95  
			ADD HL,DE					; $7B98  ; skip remaing chars
			LD DE,$0211					; $7B99  ; Y=2,X=17
			LD A,(HL)					; $7B9C
			CALL Display3DigitNumber	; $7B9D  ; Current weapon count (left side)
			INC HL						; $7BA0  
			INC HL						; $7BA1
			INC HL						; $7BA2
			INC HL						; $7BA3  ; 
			LD A,(HL)					; $7BA4
			LD E,$15					; $7BA5  ; X=21
			JP Display3DigitNumber		; $7BA7  ; Max weapon count  (right side)
	

; ------------------------------------------------------------------------
; Super Weapons Table
; Each super weapon structure takes 16 bytes 

BOMBS_LABEL:   		defb "BOMBS      "      ; $7BAA  "BOMBS" (space padded to 11 chars)
WEAPONS_BASE:		defb $00           		; $7BB5 - current count
    				defw TABLE_JMP_BOMBS	; $7BB6 - Super Weapon routine address
BOMBS_START:   		defb $14               	; $7BB8 - starting amount
BOMBS_MAX    		defb $14               	; $7BB9 - max
MINES_LABEL:   		defb "MINES      "      ; $7BBA  "MINES"
    				defb $00           		; $7BC5 - current count
    				defw TABLE_JMP_MINES	; $7BC6 - Super Weapon routine address
MINES_START:   		defb $14               	; $7BC8 - starting amount
MINES_MAX:    		defb $14               	; $7BC9 - max
SHIELD_LABEL:  		defb "SHIELD     "      ; $7BCA  "SHIELD"
    				defb $00           		; $7BD4 - current count
    				defw TABLE_JMP_SHIELD	; $7BD5 - Super Weapon routine address
SHIELD_START:  		defb $01               	; $7BD8 - starting amount
SHIELD_MAX:   		defb $01               	; $7BD9 - max
BOUNCE_LABEL:  		defb "BOUNCE     "    	; $7BDA  "BOUNCE"
    				defb $00           		; $7BE4 - current count
    				defw TABLE_JMP_BOUNCE 	; $7BE5 - Super Weapon routine address
BOUNCE_START:  		defb $05               	; $7BE8 - starting amount
BOUNCE_MAX:   		defb $05               	; $7BE9 - max
SEEKER_LABEL:  		defb "SEEKER     "      ; $7BEA  "SEEKER"W
    				defb $00           		; $7BF4 - current count
    				defw TABLE_JMP_SEEKER	; $7BF5 - Super Weapon routine address
SEEKER_START:  		defb $05               	; $7BF8 - starting amount
SEEKER_MAX:   		defb $05               	; $7BF9 - max
					


; 'SELECTED_WEAPON' - 16bit Offset, low byte fixed at $00
; Example: bombs:$0000, mines:$0100, ... seeker:$0400
SELECTED_WEAPON: defb $00, $00   		; $7BFA 
				
L_7BFC:		LD DE,$0010					; $7BFC
			LD B,$05					; $7BFF
			LD IX,$7BAA					; $7C01
L_7C05:		LD A,(IX+$0E)				; $7C05
			LD (IX+$0B),A				; $7C08
			ADD IX,DE					; $7C0B
			DJNZ L_7C05					; $7C0D
			RET							; $7C0F

FIRE_SUPER_WEAPONS:		
			LD A,(INPUT_ENABLED)				; $7C10
			OR A						; $7C13
			RET NZ						; $7C14  ; Fire disabled - do nothing

			LD DE,(POS_XY)				; $7C15  ; get ships coords
			LD A,E						; $7C19  ; X pos
			; limit super weapon at screen edges ???
			CP $79						; $7C1A  ; Xpos
			RET NC						; $7C1C
			LD A,D						; $7C1D
			CP $B1						; $7C1E  ; Ypos
			RET NC						; $7C20
			CP $20						; $7C21	 ; Ypos
			RET C						; $7C23

			LD A,(SUPER_WEAPON_TIMER)	; $7C24
			CP $05						; $7C27  ; Hold time to activate super weapons
			RET C						; $7C29  ; not yet active

			; Index the selected super weapon structure
			LD HL,(SELECTED_WEAPON)		; $7C2A	 ; Super weapons offset
			ADD HL,HL					; $7C2D  ; X2
			ADD HL,HL					; $7C2E  ; X4
			ADD HL,HL					; $7C2F  ; X8
			ADD HL,HL					; $7C30  ; X16 (struct is 16bytes)
			LD BC,WEAPONS_BASE			; $7C31  ; Base 
			ADD HL,BC					; $7C34	 ; HL+=(index*16)
			LD A,(HL)					; $7C35  ; get amount left
			OR A						; $7C36	 ; 
			RET Z						; $7C37  ; Empty, do nothing and return
			PUSH HL						; $7C38

			; --------------------------------------------------------
			; Activate Super weapon
			INC HL						; $7C39  ; move to function address in table
			LD A,(HL)					; $7C3A  ; low byte
			INC HL						; $7C3B
			LD H,(HL)					; $7C3C  ; high byte
			LD L,A						; $7C3D  ; Jump address
			XOR A						; $7C3E
			LD (SUPER_WEAPON_AMOUNT),A	; $7C3F  ; shared store for all weapon amounts

			; ***************************
			; *** (HL) JMP POINT HERE ***
			; ***************************
			JP (HL)						; $7C42 ; Jump to Super Weapon Routine
			; --------------------------------------------------------

			; --------------------------------------------------------
			; Dispaly Super Weapon Amount
UPDATE_SUPER_WEAPON_DIGITS:		
			POP HL						; $7C43
			LD A,(SUPER_WEAPON_AMOUNT)	; $7C44  ; Weapon Amount Left
			OR A						; $7C47  ;
			RET Z						; $7C48  ; Empty, do nothing and return
			LD A,(HL)					; $7C49	 ; get amount
			DEC A						; $7C4A	 ; reduce super weapon
			LD (HL),A					; $7C4B  ; store
			LD DE,$0211					; $7C4C  ; Y=2, X=32 (half for X)
			LD C,$47					; $7C4F  ; Col=%01000111
			JP Display3DigitNumber		; $7C51  ; update amount
			; --------------------------------------------------------

SUPER_WEAPON_AMOUNT:	defb 	$00		; $7C54

			XOR A								; $7C55
			LD (SUPER_WEAPON_AMOUNT),A			; $7C56
			JP UPDATE_SUPER_WEAPON_DIGITS		; $7C59

TABLE_JMP_BOMBS: 	; rockets
			LD HL,$7D75							; $7C5C
			LD A,($696C)						; $7C5F
			CP $02								; $7C62
			JP Z,L_7C6A							; $7C64
			LD HL,$7D85							; $7C67
L_7C6A:		LD IX,$7D95							; $7C6A
			LD A,(GAME_COUNTER_8BIT)					; $7C6E
			AND $03								; $7C71
			JP NZ,UPDATE_SUPER_WEAPON_DIGITS	; $7C73
			LD BC,$0007							; $7C76
L_7C79:		LD A,(IX+$00)						; $7C79
			CP $FF								; $7C7C
			JP Z,UPDATE_SUPER_WEAPON_DIGITS		; $7C7E
			LD A,(IX+$02)						; $7C81
			OR A								; $7C84
			JR Z,L_7C8C							; $7C85
			ADD IX,BC							; $7C87
			JP L_7C79							; $7C89
L_7C8C:		LD A,$02					; $7C8C
			CALL SET_BEEPER_SFX					; $7C8E
			PUSH DE						; $7C91
			PUSH HL						; $7C92
			PUSH IX						; $7C93
			LD E,SFX_MISSILE			; $7C95
			CALL PLAY_SFX				; $7C97
			POP IX						; $7C9A
			POP HL						; $7C9C
			POP DE						; $7C9D
			LD (IX+$02),$10				; $7C9E
			LD (IX+$03),L				; $7CA2
			LD (IX+$04),H				; $7CA5
			LD HL,($6969)				; $7CA8
			LD DE,$0402					; $7CAB
			ADD HL,DE					; $7CAE
			LD (IX+$00),L				; $7CAF
			LD (IX+$01),H				; $7CB2
			LD A,(DIRECTION)			; $7CB5
			ADD A,A						; $7CB8
			LD (IX+$05),A				; $7CB9
			EX DE,HL					; $7CBC
			CP $FE						; $7CBD
			LD A,$01					; $7CBF
			JR Z,L_7CC4						; $7CC1
			XOR A							; $7CC3
L_7CC4:		LD (IX+$06),A					; $7CC4
			CALL DRAW_SPRITE16X8			; $7CC7
			LD A,$01						; $7CCA
			LD (SUPER_WEAPON_AMOUNT),A		; $7CCC
			JP UPDATE_SUPER_WEAPON_DIGITS	; $7CCF
UPDATE_PLR_BOMBS:		
			LD A,$02						; $7CD2
			CALL L_67B9						; $7CD4
			LD IX,$7D95					; $7CD7
L_7CDB:		LD A,(IX+$00)				; $7CDB
			CP $FF						; $7CDE
			RET Z						; $7CE0
			LD A,(IX+$02)				; $7CE1
			OR A						; $7CE4
			JR NZ,L_7CEF				; $7CE5
L_7CE7:		LD BC,$0007					; $7CE7
			ADD IX,BC					; $7CEA
			JP L_7CDB					; $7CEC
L_7CEF:		LD C,(IX+$02)				; $7CEF
			LD B,$00					; $7CF2
			LD L,(IX+$03)				; $7CF4
			LD H,(IX+$04)				; $7CF7
			DEC HL						; $7CFA
			ADD HL,BC					; $7CFB
			DEC C						; $7CFC
			JR Z,L_7D02					; $7CFD
			LD (IX+$02),C				; $7CFF
L_7D02:		LD E,(IX+$00)				; $7D02
			LD D,(IX+$01)				; $7D05
			LD A,C						; $7D08
			CP $0B						; $7D09
			JR NC,L_7D15				; $7D0B
			; ----------------------------------------
			; Do effect every other frame
			LD A,(GAME_COUNTER_8BIT)	; $7D0D
			AND $01						; $7D10
			CALL Z,SPARKLE_EFFECT		; $7D12
			; -----------------------------------------
L_7D15:		LD A,(IX+$06)				; $7D15
			CALL DRAW_SPRITE16X8		; $7D18  ; clears last rocket drawn
			LD A,(IX+$05)				; $7D1B
			LD B,A						; $7D1E
			PUSH HL						; $7D1F
			CALL GET_ANIM_ADDR_AS_HL	; $7D20
			LD A,(HL)					; $7D23
			POP HL						; $7D24
			OR A						; $7D25
			JR NZ,L_7D58				; $7D26
			LD A,B						; $7D28
			ADD A,E						; $7D29
			CP $7C						; $7D2A
			JR NC,L_7D58				; $7D2C
			LD E,A						; $7D2E
			LD (IX+$00),A				; $7D2F
			LD A,(IX+$01)				; $7D32
			LD D,A						; $7D35
			CALL L_815D					; $7D36
			JR NZ,L_7D58				; $7D39
			LD A,(HL)					; $7D3B
			ADD A,D						; $7D3C
			LD D,A						; $7D3D
			CP $B8						; $7D3E
			JR NC,L_7D58				; $7D40
			CALL ENEMY_COLLISIONS					; $7D42
			JR NZ,L_7D58				; $7D45
			LD (IX+$01),D				; $7D47
			LD A,(IX+$06)				; $7D4A
			LD C,$47					; $7D4D
			CALL L_A4AD					; $7D4F
			CALL DRAW_SPRITE16X8					; $7D52
   			JP L_7CE7					; $7D55
L_7D58:		XOR A						; $7D58
			LD (IX+$02),A				; $7D59
			CALL DO_SCENE_COLLISION					; $7D5C
			LD A,$01					; $7D5F
			CALL L_67B9					; $7D61
			CALL L_74E2					; $7D64
			CALL L_74E2					; $7D67
			CALL L_74E2					; $7D6A
			LD A,$02					; $7D6D
			CALL L_67B9					; $7D6F
			JP L_7CE7					; $7D72

BOMBS_DATA: ; (rockets)
			defb $06,$04,$04,$03,$03,$03                        ; $7D75 ......
			defb $02,$02,$02,$01,$01,$01,$00,$00				; $7D7B ........
			defb $00,$00,$FA,$FC,$FC,$FD,$FD,$FD				; $7D83 ........
			defb $FE,$FE,$FE,$FF,$FF,$FF,$00,$00				; $7D8B ........
			defb $00,$00,$C2,$16,$6C,$DD,$56,$0D				; $7D93 ....l.V.
			defb $DD,$5E,$0C,$DD,$72,$05,$DD,$73				; $7D9B .^..r..s
			defb $04,$C9,$00,$00,$00,$00,$00,$00				; $7DA3 ........
			defb $00,$38,$00,$00,$00,$64,$00,$0A				; $7DAB .8...d..
			defb $00,$00,$00,$00,$0A,$00,$00,$00				; $7DB3 ........
			defb $04,$00,$00,$00,$12,$00,$00,$00				; $7DBB ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $7DC3 ........
			defb $00,$00,$FF                                    ; $7DCB ...

TABLE_JMP_MINES:
			LD DE,(POS_XY)				; $7DCE
			;----------------------------------------
			; Drop mine center of Ship
			INC D				; $7DD2	 ;
			INC D				; $7DD3  ;
			INC D				; $7DD4  ;
			INC D				; $7DD5  ; Y+=4
			INC E				; $7DD6  ; 
			INC E				; $7DD7  ; X+=4 (as X is half screen coords)
			XOR A				; $7DD8
			;----------------------------------------
			CALL L_67B9				; $7DD9
			LD HL,MINES_DATA				; $7DDC
L_7DDF:		LD A,(HL)				; $7DDF
			CP $FF				; $7DE0
			JR Z,L_7DF7				; $7DE2
			LD C,A				; $7DE4
			INC HL				; $7DE5
			LD B,(HL)				; $7DE6
			INC HL				; $7DE7
			LD A,(HL)				; $7DE8
			INC HL				; $7DE9
			OR A				; $7DEA
			JR Z,L_7DDF				; $7DEB
			CALL COLLISION_DETECTION				; $7DED
			OR A				; $7DF0
			JP NZ,UPDATE_SUPER_WEAPON_DIGITS				; $7DF1
			JP L_7DDF				; $7DF4
L_7DF7: 	LD HL,MINES_DATA				; $7DF7
L_7DFA:		LD A,(HL)				; $7DFA
			CP $FF				; $7DFB
			JP Z,UPDATE_SUPER_WEAPON_DIGITS				; $7DFD
			INC HL				; $7E00
			INC HL				; $7E01
			LD A,(HL)				; $7E02
			OR A				; $7E03
			JR Z,L_7E0A				; $7E04
			INC HL				; $7E06
			JP L_7DFA				; $7E07
L_7E0A:		LD (HL),$01				; $7E0A
			DEC HL				; $7E0C
			LD (HL),D				; $7E0D
			DEC HL				; $7E0E
			LD (HL),E				; $7E0F
			LD A,$04				; $7E10
			CALL DRAW_SPRITE16X8				; $7E12
			LD (SUPER_WEAPON_AMOUNT),A				; $7E15
			LD A,$03				; $7E18
			CALL SET_BEEPER_SFX				; $7E1A
			PUSH DE				; $7E1D
			LD E,SFX_MINE				; $7E1E
			CALL PLAY_SFX				; $7E20
			POP DE				; $7E23
			JP UPDATE_SUPER_WEAPON_DIGITS				; $7E24
DO_MINES:		LD A,$02				; $7E27
			CALL L_67B9				; $7E29
			LD C,$47				; $7E2C
			LD HL,MINES_DATA				; $7E2E
L_7E31:		LD A,(HL)				; $7E31
			CP $FF				; $7E32
			RET Z				; $7E34
			LD E,A				; $7E35
			INC HL				; $7E36
			LD D,(HL)				; $7E37
			INC HL				; $7E38
			LD A,(HL)				; $7E39
			INC HL				; $7E3A
			OR A				; $7E3B
			JP Z,L_7E31				; $7E3C
			CALL L_A4AD				; $7E3F
			CALL ENEMY_COLLISIONS				; $7E42
			JP Z,L_7E31				; $7E45
			DEC HL				; $7E48
			LD (HL),$00				; $7E49
			INC HL				; $7E4B
			LD A,$04				; $7E4C
			CALL DRAW_SPRITE16X8				; $7E4E
			CALL SPARKLE_EFFECT				; $7E51
			JP L_7E31				; $7E54

MINES_DATA:
			defb $A1,$06,$42,$06                    ; $7E57 
			defb $E8,$05,$93,$05,$43,$05,$F7,$04	; $7E5B 
			defb $B0,$04,$6D,$04,$2D,$04,$F1,$03	; $7E63 
			defb $B8,$03,$83,$03,$50,$03,$21,$03	; $7E6B 
			defb $F4,$02,$FF                        ; $7E73 

TABLE_JMP_SHIELD:
			LD A,(SHIELD_AMOUNT)					; $7E76
			OR A									; $7E79
			JP NZ,UPDATE_SUPER_WEAPON_DIGITS		; $7E7A
			LD A,$04								; $7E7D
			CALL SET_BEEPER_SFX								; $7E7F
			PUSH DE									; $7E82
			LD E,SFX_SHIELD							; $7E83
			CALL PLAY_SFX							; $7E85
			POP DE									; $7E88
			LD A,$5A								; $7E89
			LD (SHIELD_AMOUNT),A							; $7E8B
			LD (SUPER_WEAPON_AMOUNT),A				; $7E8E
			JP UPDATE_SUPER_WEAPON_DIGITS			; $7E91

SHIELD_AMOUNT:  	 defb $00						; $7E94

TABLE_JMP_BOUNCE:
			LD A,(TIMEOUT_BALLS)							; $7E95
			OR A									; $7E98
			JP NZ,UPDATE_SUPER_WEAPON_DIGITS		; $7E99
			LD A,$96								; $7E9C
			LD (TIMEOUT_BALLS),A							; $7E9E
			LD A,$01								; $7EA1
			CALL SET_BEEPER_SFX								; $7EA3
			PUSH DE									; $7EA6
			LD E,SFX_BOUNCE1						; $7EA7
			CALL PLAY_SFX							; $7EA9
			POP DE									; $7EAC
			LD DE,(POS_XY)							; $7EAD
			LD A,E									; $7EB1
			AND $FC									; $7EB2
			LD E,A									; $7EB4
			LD A,D									; $7EB5
			AND $F8									; $7EB6
			LD D,A									; $7EB8
			LD C,$02								; $7EB9
			LD B,$04								; $7EBB
			CALL L_7EE4								; $7EBD
			LD C,$FE								; $7EC0
			LD B,$04								; $7EC2
			LD A,E									; $7EC4
			ADD A,$04								; $7EC5
			LD E,A									; $7EC7
			CALL L_7EE4								; $7EC8
			LD C,$FE								; $7ECB
			LD B,$FC								; $7ECD
			LD A,D									; $7ECF
			ADD A,$08								; $7ED0
			LD D,A									; $7ED2
			CALL L_7EE4								; $7ED3
			LD C,$02								; $7ED6
			LD B,$FC								; $7ED8
			LD A,E									; $7EDA
			SUB $04									; $7EDB
			LD E,A									; $7EDD
			CALL L_7EE4								; $7EDE
			JP UPDATE_SUPER_WEAPON_DIGITS			; $7EE1

L_7EE4:		LD HL,BOUNCE_DATA				; $7EE4
L_7EE7:		LD A,(HL)						; $7EE7
			CP $FF							; $7EE8
			RET Z							; $7EEA
			INC HL							; $7EEB
			INC HL							; $7EEC
			INC HL							; $7EED
			INC HL							; $7EEE
			LD A,(HL)						; $7EEF
			INC HL							; $7EF0
			OR A							; $7EF1
			JR NZ,L_7EE7					; $7EF2
			DEC HL							; $7EF4
			LD (HL),$01						; $7EF5
			DEC HL							; $7EF7
			LD (HL),B						; $7EF8
			DEC HL							; $7EF9
			LD (HL),C						; $7EFA
			DEC HL							; $7EFB
			LD (HL),D						; $7EFC
			DEC HL							; $7EFD
			LD (HL),E						; $7EFE
			LD A,$05						; $7EFF
			CALL DRAW_SPRITE16X8						; $7F01
			LD (SUPER_WEAPON_AMOUNT),A		; $7F04
			RET								; $7F07

BOUNCE_DATA:
			; structure: [X][Y][XVel][YVel][Active]
			defb $01,$CE,$01                            ; $7F08
			defb $CF,$01,$D9,$01,$E3,$01,$ED,$01		; $7F0B
			defb $F7,$01,$01,$02,$0B,$02,$12,$02		; $7F13
			defb $28,$FF                                ; $7F1B

UPDATE_BOUNCY_BALLS:		
			LD A,$02				; $7F1D
			CALL L_67B9				; $7F1F
			LD HL,BOUNCE_DATA		; $7F22
L_7F25:		LD A,(HL)				; $7F25
			CP $FF					; $7F26
			RET Z					; $7F28  ; end marker, return
			; --------------------------------------
			; Unpack ball data
			LD E,(HL)				; $7F29  ; Xpos
			INC HL					; $7F2A
			LD D,(HL)				; $7F2B  ; Ypos
			INC HL					; $7F2C
			LD C,(HL)				; $7F2D  ; Xvel
			INC HL					; $7F2E
			LD B,(HL)				; $7F2F  ; Yvel
			INC HL					; $7F30
			LD A,(HL)				; $7F31  ; Active flag
			INC HL					; $7F32
			OR A					; $7F33
			JR Z,L_7F25				; $7F34  ; Skip inactive balls
			; --------------------------------------
			; X-axis collision 
			LD A,C					; $7F36
			CP $FE					; $7F37
			JR Z,L_7F45				; $7F39
			CALL L_8115				; $7F3B
			OR A					; $7F3E
			CALL NZ,L_7F97			; $7F3F
			JP L_7F4C				; $7F42
L_7F45:		CALL L_8139				; $7F45
			OR A					; $7F48
			CALL NZ,L_7F97			; $7F49
			; --------------------------------------
			; Y-axis collision handling
L_7F4C:		LD A,B					; $7F4C
			CP $FC					; $7F4D
			JR Z,L_7F5B				; $7F4F
			CALL L_815D				; $7F51
			OR A					; $7F54
			CALL NZ,L_7FBF			; $7F55
			JP L_7F62				; $7F58
L_7F5B:		CALL L_8181				; $7F5B
			OR A					; $7F5E
			CALL NZ,L_7FBF			; $7F5F
			; --------------------------------------
			; Update ball position
L_7F62:		LD A,$05				; $7F62
			CALL DRAW_SPRITE16X8				; $7F64
			LD A,C					; $7F67
			ADD A,E					; $7F68
			LD E,A					; $7F69
			LD A,B					; $7F6A
			ADD A,D					; $7F6B
			LD D,A					; $7F6C
			PUSH HL					; $7F6D
			DEC HL					; $7F6E
			DEC HL					; $7F6F
			LD (HL),B				; $7F70
			DEC HL					; $7F71
			LD (HL),C				; $7F72
			DEC HL					; $7F73
			LD (HL),D				; $7F74
			DEC HL					; $7F75
			LD (HL),E				; $7F76
			POP HL					; $7F77
			LD A,$05				; $7F78
			CALL DRAW_SPRITE16X8				; $7F7A
			LD C,$47				; $7F7D
			CALL L_A4AD				; $7F7F
			CALL ENEMY_COLLISIONS	; $7F82
			LD A,(TIMEOUT_BALLS)			; $7F85
			OR A					; $7F88
			JP Z,L_7F25				; $7F89
			CP $0A					; $7F8C
			JP NC,L_7F25			; $7F8E
			CALL SPARKLE_EFFECT		; $7F91
			JP L_7F25				; $7F94
			; --------------------------------------
			; X-axis bounce
L_7F97:		LD A,C					; $7F97
			NEG						; $7F98
			LD C,A					; $7F9A
			CALL SPARKLE_EFFECT		; $7F9B
			LD A,$01				; $7F9E
			CALL L_67B9				; $7FA0
			CALL L_74E2				; $7FA3
			CALL L_74E2				; $7FA6
			CALL L_74E2				; $7FA9
			LD A,$02				; $7FAC
			CALL L_67B9				; $7FAE
			PUSH BC					; $7FB1
			PUSH DE					; $7FB2
			PUSH HL					; $7FB3
			LD E,SFX_BOUNCE2		; $7FB4
			CALL PLAY_SFX			; $7FB6
			POP HL					; $7FB9
			POP DE					; $7FBA
			POP BC					; $7FBB
			JP DO_SCENE_COLLISION	; $7FBC
			; --------------------------------------
			; Y-axis bounce (mirrors X-axis logic)
L_7FBF:		LD A,B					; $7FBF
			NEG						; $7FC0
			LD B,A					; $7FC2
			CALL SPARKLE_EFFECT		; $7FC3
			LD A,$01				; $7FC6
			CALL L_67B9				; $7FC8
			CALL L_74E2				; $7FCB
			CALL L_74E2				; $7FCE
			CALL L_74E2				; $7FD1
			LD A,$02				; $7FD4
			CALL L_67B9				; $7FD6
			PUSH BC					; $7FD9
			PUSH DE					; $7FDA
			PUSH HL					; $7FDB
			LD E,SFX_BOUNCE2		; $7FDC
			CALL PLAY_SFX			; $7FDE
			POP HL					; $7FE1
			POP DE					; $7FE2
			POP BC					; $7FE3
			JP DO_SCENE_COLLISION	; $7FE4
			; --------------------------------------
TIMEOUT_BOUNCY_BALLS:		
		    LD A,(TIMEOUT_BALLS)			; $7FE7
			OR A					; $7FEA
			RET Z					; $7FEB
			DEC A					; $7FEC
			LD (TIMEOUT_BALLS),A			; $7FED
			RET NZ					; $7FF0
			LD HL,BOUNCE_DATA		; $7FF1
RESET_BALL_LOOP:		
			LD A,(HL)				; $7FF4
			CP $FF					; $7FF5  ; end marker
			RET Z					; $7FF7
			LD E,A					; $7FF8
			INC HL					; $7FF9
			LD D,(HL)				; $7FFA
			INC HL					; $7FFB
			INC HL					; $7FFC
			INC HL					; $7FFD
			LD A,(HL)				; $7FFE
			LD (HL),$00				; $7FFF  ; Deactivate ball
			INC HL					; $8001
			OR A					; $8002
			JR Z,RESET_BALL_LOOP	; $8003
			LD A,$05				; $8005  ; sprite index
			CALL DRAW_SPRITE16X8				; $8007  ; Remove last ball
			JP RESET_BALL_LOOP		; $800A

TIMEOUT_BALLS:		defb  $00		; $800D

TABLE_JMP_SEEKER:			
			LD IX,SEEKER_LIST							; $800E
			LD A,(IX+$02)						; $8012
			OR A								; $8015
			JP NZ,UPDATE_SUPER_WEAPON_DIGITS	; $8016
			LD BC,$0008							; $8019
			LD IY,DATA_08						; $801C
L_8020:		LD A,(IY+$00)						; $8020
			CP $FF								; $8023
			JR NZ,L_8038						; $8025
			LD A,$78							; $8027
			CALL GET_RAND_VALUE					; $8029
			LD C,A								; $802C
			LD A,$90							; $802D
			CALL GET_RAND_VALUE					; $802F
			ADD A,$20							; $8032
			LD B,A								; $8034
			JP L_8049							; $8035
L_8038:		LD A,(IY+$04)						; $8038
			OR A								; $803B
			JR NZ,L_8043						; $803C
			ADD IY,BC							; $803E
			JP L_8020							; $8040
L_8043:		LD C,(IY+$00)						; $8043
			LD B,(IY+$01)						; $8046
L_8049:		LD HL,SPRITE24x16_DATA				; $8049
			LD (IX+$0A),L						; $804C
			LD (IX+$0B),H						; $804F
			LD DE,(POS_XY)						; $8052
			CALL L_8B71							; $8056
			LD A,$01							; $8059
			LD (SUPER_WEAPON_AMOUNT),A			; $805B
			LD E,SFX_SEEKER						; $805E
			CALL PLAY_SFX						; $8060
			JP UPDATE_SUPER_WEAPON_DIGITS		; $8063

DO_SEEKER:		
			LD IX,SEEKER_LIST							; $8066
			LD A,(IX+$02)						; $806A
			OR A								; $806D
			RET Z								; $806E
			LD C,(IX+$00)						; $806F
			LD B,(IX+$01)						; $8072
			LD H,$05							; $8075
L_8077:		CALL L_8BCA							; $8077
			JR Z,L_809E							; $807A
			DEC H								; $807C
			JR NZ,L_8077						; $807D
			LD L,(IX+$0A)						; $807F
			LD H,(IX+$0B)						; $8082
			LD A,WEAPON_ITEM_MACE				; $8085
			CALL SPRITE_24x16					; $8087
			; ---------------------------------------
			; centre effects to sprite
			INC D						; $808A
			INC D						; $808B
			INC D						; $808C
			INC D						; $808D
			INC E						; $808E
			INC E						; $808F
			CALL SPARKLE_EFFECT			; $8090
			; ---------------------------------------
			LD (IX+$0A),L				; $8093
			LD (IX+$0B),H				; $8096
			LD C,$47					; $8099
			JP SET_SCRN_ATTR			; $809B
L_809E:		LD L,(IX+$0A)				; $809E
			LD H,(IX+$0B)				; $80A1
			XOR A						; $80A4
			CALL SPRITE_24x16			; $80A5
			; ---------------------------------------
			; centre for hit test with map tiles
			INC E						; $80A8
			INC E						; $80A9
			INC D						; $80AA
			INC D						; $80AB
			INC D						; $80AC
			INC D						; $80AD
			JP DO_SCENE_COLLISION		; $80AE
			; ---------------------------------------

SEEKER_LIST:
			defb $01,$02,$67,$01,$C8,$80,$C8,$FF  ; $80B1
			LD BC,$018F						; $80B9
			EX AF,AF'						; $80BC

			; --------------------------------------------------------------------
			; Draws 16x8 sprites (using XOR logic)
DRAW_SPRITE16X8:		
			; Inputs: A=SpriteID, D=Ypos, E=Xpos, C=Colour
			; Uses self-modifying code for screen address optimization
			PUSH AF					; $80BD
			PUSH BC					; $80BE
			PUSH DE					; $80BF
			PUSH HL					; $80C0
			; Calculate sprite data offset (16 bytes per sprite)
			ADD A,A					; $80C1
			ADD A,A					; $80C2
			ADD A,A					; $80C3
			ADD A,A					; $80C4
			LD L,A					; $80C5
			LD H,$00				; $80C6  ;  Clear upper byte
			ADD HL,HL				; $80C8
			ADD HL,HL				; $80C9  ; HL*=4 (64 bytes per sprite group)
			; Prepare screen address 
			LD C,D					; $80CA  ; Ypos
			LD A,E					; $80CB  ; Xpos
			AND $7C					; $80CC  ; %01111100: Xpos bits for 16px-wide handling
			RRCA					; $80CE  
			RRCA					; $80CF  ; scale down to 32column (256px width/8)
 			; Self-modify screen address (Xpos)
			LD (LEFT_OFFSET+1),A	; $80D0 ; left half X-offset , A=(Xpos&0x7C)>>2
			LD (RIGHT_OFFSET+1),A	; $80D3 ; right half X-offset
			; Calculate offset
			LD A,E					; $80D6
			AND $03					; $80D7  ; 0-3 offset
			ADD A,A					; $80D9
			ADD A,A					; $80DA
			ADD A,A					; $80DB
			ADD A,A					; $80DC
			LD E,A					; $80DD
			LD D,$00				; $80DE  ; Clear upper byte
			ADD HL,DE				; $80E0
			; Set sprite data pointer
			LD DE,SPRITE_DATA		; $80E1  ; graphics
			ADD HL,DE				; $80E4
			EX DE,HL				; $80E5
			;---------------------------------------------------------
			LD B,$04				; $80E6  ; do 4 times (16px height)
LOOP_SPRITE16:
			; screen address (left half)
			;------------
			LD H,$64				; $80E8  ; High byte table $6400
			LD L,C					; $80EA  ; Y position index
			LD A,(HL)				; $80EB  ; keep
			;------------
			DEC H					; $80EC  ; Low byte table $6300
			LD H,(HL)				; $80ED
			;------------
LEFT_OFFSET: OR $00					; $80EE  ; *** SELF-MODIFIED *** X offset
			LD L,A					; $80F0  ; HL=Final screen address
			;-----------------------------------------
            ; Draw left byte
            INC C                   ; $80F1 ; Next screen line 
            LD A,(DE)               ; $80F2 ; sprite data
            INC DE                  ; $80F3 ; next sprite data (right half)
            XOR (HL)                ; $80F4 ; Merge with screen: A = screen_byte XOR sprite_byte
            LD (HL),A               ; $80F5 ; Update screen 
            INC L                   ; $80F6 ; Move right
            ; Draw right byte
            LD A,(DE)               ; $80F7 ; 
            INC DE                  ; $80F8 ; 
            XOR (HL)                ; $80F9 ; 
            LD (HL),A               ; $80FA ; 
			;-----------------------------------------
			; screen address (right half)
			LD H,$64				; $80FB
			LD L,C					; $80FD
			LD A,(HL)				; $80FE
			DEC H					; $80FF
			LD H,(HL)				; $8100
RIGHT_OFFSET: OR $00				; $8101
			LD L,A					; $8103  ; HL=Final screen address
			;-----------------------------------------
			INC C					; $8104  ; Ready next line
			LD A,(DE)				; $8105
			INC DE					; $8106  ; next sprite data
			XOR (HL)				; $8107
			LD (HL),A				; $8108
			INC L					; $8109  ; Move right
			LD A,(DE)				; $810A
			INC DE					; $810B  ; next sprite data
			XOR (HL)				; $810C
			LD (HL),A				; $810D
			DJNZ LOOP_SPRITE16		; $810E
			;------------------------------------------
			POP HL					; $8110
			POP DE					; $8111
			POP BC					; $8112
			POP AF					; $8113
			RET						; $8114
			;---------------------------------------------------------

L_8115:
			PUSH BC				; $8115
			PUSH DE				; $8116
			PUSH HL				; $8117
			LD A,E				; $8118
			CP $7A				; $8119
			JR NC,L_8134				; $811B
			AND $03				; $811D
			LD A,$00				; $811F
			JR NZ,L_8134				; $8121
			CALL GET_ANIM_ADDR_AS_HL				; $8123
			INC L				; $8126
			LD BC,$0020				; $8127
			LD A,(HL)				; $812A
			LD E,A				; $812B
			LD A,D				; $812C
			AND $07				; $812D
			LD A,E				; $812F
			JR Z,L_8134				; $8130
			ADD HL,BC				; $8132
			OR (HL)				; $8133
L_8134:
			OR A				; $8134
			POP HL				; $8135
			POP DE				; $8136
			POP BC				; $8137
			RET				; $8138

L_8139:
			PUSH BC				; $8139
			PUSH DE				; $813A
			PUSH HL				; $813B
			LD A,E				; $813C
			CP $04				; $813D
			JR C,L_8158				; $813F
			AND $03				; $8141
			LD A,$00				; $8143
			JR NZ,L_8158				; $8145
			CALL GET_ANIM_ADDR_AS_HL				; $8147
			DEC L				; $814A
			LD BC,$0020				; $814B
			LD A,(HL)				; $814E
			LD E,A				; $814F
			LD A,D				; $8150
			AND $07				; $8151
			LD A,E				; $8153
			JR Z,L_8158				; $8154
			ADD HL,BC				; $8156
			OR (HL)				; $8157
L_8158:
			OR A				; $8158
			POP HL				; $8159
			POP DE				; $815A
			POP BC				; $815B
			RET				; $815C

L_815D:
			PUSH BC				; $815D
			PUSH DE				; $815E
			PUSH HL				; $815F
			LD A,D				; $8160
			CP $B8				; $8161
			JR NC,L_817C				; $8163
			AND $07				; $8165
			LD A,$00				; $8167
			JR NZ,L_817C				; $8169
			CALL GET_ANIM_ADDR_AS_HL				; $816B
			LD BC,$0020				; $816E
			ADD HL,BC				; $8171
			LD A,(HL)				; $8172
			LD D,A				; $8173
			LD A,E				; $8174
			AND $03				; $8175
			LD A,D				; $8177
			JR Z,L_817C				; $8178
			INC L				; $817A
			OR (HL)				; $817B
L_817C:
			OR A				; $817C
			POP HL				; $817D
			POP DE				; $817E
			POP BC				; $817F
			RET				; $8180

L_8181:
			PUSH BC				; $8181
			PUSH DE				; $8182
			PUSH HL				; $8183
			LD A,D				; $8184
			CP $20				; $8185
			JR C,L_81A0				; $8187
			AND $07					; $8189
			LD A,$00				; $818B
			JR NZ,L_81A0			; $818D
			CALL GET_ANIM_ADDR_AS_HL				; $818F
			LD BC,$FFE0				; $8192
			ADD HL,BC				; $8195
			LD A,(HL)				; $8196
			LD D,A				; $8197
			LD A,E				; $8198
			AND $03				; $8199
			LD A,D				; $819B
			JR Z,L_81A0			; $819C
			INC L				; $819E
			OR (HL)				; $819F
L_81A0:		OR A				; $81A0
			POP HL				; $81A1
			POP DE				; $81A2
			POP BC				; $81A3
			RET					; $81A4


MODE48K:	defb $0		; $81A5  ; looks like a dev skip 48k music thing

DO_MENU:	CALL CLR_SCREEN				; $81A6  ; clear screen
			CALL DRAW_MENU_BORDERS		; $81A9  ; Draw menu borders

			LD HL,MENU_TEXT 			; $81AC
			CALL DRAW_LIST				; $81AF  ; menu text

; DEBUG TEST
; LD HL,WELL_DONE_TXT
; LD HL,BAD_LUCK_TXT
; LD HL,LEVEL_SELECTOR_DRAW_LIST
; CALL DRAW_LIST		

	
			LD A,(SPECCY_MODEL)			; $81B2  ; 0=48k, 1=128k
			OR A						; $81B5
			JR NZ,L_81CB				; $81B6
			LD A,(MODE48K)				; $81B8
			OR A						; $81BB
			JR NZ,L_81CB				; $81BC
			DI							; $81BE
			CALL START_BEEP_MUSIC		; $81BF
			CALL BEEP_MUSIC_LOOP		; $81C2
			EI							; $81C5
			LD A,$01					; $81C6
			LD (MODE48K),A				; $81C8 ; 48k

L_81CB:		CALL ANY_KEY_DOWN			; $81CB
			JP NZ,L_81CB				; $81CE

			LD BC,$01F4					; $81D1
L_81D4:		PUSH BC						; $81D4
			CALL SCROLL_BORDER			; $81D5  ; scrolling border effect
			CALL L_82E5					; $81D8  ; menu text
			CALL GET_KEY				; $81DB
			POP BC						; $81DE
			CP $31						; $81DF  ; invalid key (<'1')
			JR C,INVALID_KEY_PRESS		; $81E1
			CP $37						; $81E3  ; invalid key (>='7')
			JR NC,INVALID_KEY_PRESS		; $81E5
			CP $31						; $81E7  ; '1'
			RET Z						; $81E9
			CP $32						; $81EA  ; '2'
			JP Z,REDEFINE_KEYS			; $81EC
			CP $36						; $81EF  ; '6'
			JR NZ,L_8214				; $81F1
			LD A,(AY_MUSIC_FLAG)		; $81F3  ; 
			XOR $01						; $81F6  ; Toggle AY music ON/OFF
			LD (AY_MUSIC_FLAG),A		; $81F8  ;

			PUSH BC						; $81FB
			CALL AY_RESET_MUSIC					; $81FC
			LD E,$01					; $81FF
			CALL PLAY_SFX				; $8201
			POP BC						; $8204
L_8205:		CALL L_82E5					; $8205
			CALL ANY_KEY_DOWN			; $8208
			CALL NZ,SCROLL_BORDER		; $820B
			JP NZ,L_8205				; $820E
			JP INVALID_KEY_PRESS		; $8211
L_8214:		SUB $33						; $8214
			LD E,A						; $8216
			LD A,(INPUT_TYPE)			; $8217
			CP E						; $821A
			JR Z,INVALID_KEY_PRESS		; $821B
			LD A,E						; $821D
			LD (INPUT_TYPE),A			; $821E
			PUSH BC						; $8221
			LD HL,MENU_TEXT					; $8222
			CALL DRAW_LIST					; $8225
			POP BC						; $8228
INVALID_KEY_PRESS:			
			DEC BC						; $8229
			LD A,B						; $822A
			OR C						; $822B
			JP NZ,L_81D4				; $822C
			CALL L_9433					; $822F   ; Hi-Scores
			JP DO_MENU					; $8232



;--------------------------------------------------------------------------------
; *** Menu text and control bytes ***
MENU_TEXT:  						 ; $8235
            defb SETUP,$00     		 ; Setup (with index)
            defb SET_SOURCE_DATA ;,$F1,$C2 	 ; Patch 'ICON_LD_ADDR'
			defw FONT_DATA
            defb SET_POS,$09,$08 	 ; Set position (Y=9, X=8)    
            defb GLOBAL_COL,$45    	 ; Set global "standard" (%FBPPPIII) colour attribute 
            defb "BY RAFFAELE CECCO"     
            defb INK_PURPLE	 		 ; Set colour  
            defb SET_POS,11,6    	 ; Set position (Y=11, X=6) 
            defb "MUSIC BY DAVE ROGERS"  
            defb SET_POS,13,9    
            defb INK_PURPLE,"1 ",INK_GREEN,"START GAME"           	
            defb MOVE+1,-12   	
            defb INK_PURPLE,"2 ",INK_GREEN,"DEFINE KEYS"          	
            defb MOVE+1,-13   	
            defb INK_PURPLE,"3 ",INK_GREEN,"KEYBOARD"               	
            defb MOVE+1,-10  	
            defb INK_PURPLE,"4 ",INK_GREEN,"INTERFACE 2"            	
            defb MOVE+1,-13   	
            defb INK_PURPLE,"5 ",INK_GREEN,"KEMPSTON"               	
            defb MOVE+1,-10   	
            defb INK_PURPLE,"6 ",INK_GREEN,"SOUND ON/OFF"           	
            defb SET_POS,20,4  	
            defb INK_RED,"CYBERNOID * 1988 HEWSON"   
            defb END_MARKER
;--------------------------------------------------------------------------------

L_82E5:		PUSH BC							; $82E5
			LD A,(INPUT_TYPE)				; $82E6
			ADD A,$0F						; $82E9
			ADD A,A							; $82EB
			ADD A,A							; $82EC
			ADD A,A							; $82ED
			LD D,A							; $82EE
			LD E,$2C						; $82EF
			CALL GET_ATTRIBUTE_AS_HL		; $82F1
			LD A,($830B)					; $82F4
			INC A							; $82F7
			LD ($830B),A					; $82F8
			AND $07							; $82FB
			ADD A,$40						; $82FD
			LD (HL),A						; $82FF
			LD E,L							; $8300
			LD D,H							; $8301
			INC E							; $8302
			LD BC,$000F						; $8303
			LDIR							; $8306
			POP BC							; $8308
			RET								; $8309

; ---------------------------------------------------------------
;;;	LD BC,$CD00						; $830A
AY_MUSIC_FLAG:	defb $01			; $830A	
				defb $00			; $830B		
; ---------------------------------------------------------------

REDEFINE_KEYS:		CALL CLR_SCREEN		; $830C		 ; CALL $66AA
 			;	XOR D							; $830D  ; wonky disassembly
			;	LD H,(HL)						; $830E  ;

			CALL DRAW_MENU_BORDERS			; $830F
			XOR A							; $8312
			LD (INPUT_TYPE),A				; $8313
			LD HL,$83FA						; $8316
			CALL DRAW_LIST						; $8319
			LD IX,$681D						; $831C
			LD IY,$83F1						; $8320  ; get redefined keys base
			LD DE,$0C0F						; $8324	 ; Y/X coords of new keys
			LD B,$04						; $8327  ; amount to define

L_8329:		PUSH BC						; $8329
			LD A,$3F					; $832A
			LD C,$44					; $832C
			CALL ICON16x16				; $832E
			PUSH DE						; $8331

RELEASE_KEYS:	
			CALL ANY_KEY_DOWN					; $8332
			CALL NZ,SCROLL_BORDER		; $8335
			JP NZ,RELEASE_KEYS			; $8338

LOOP_INPUT:
			CALL GET_KEY				; $833B
			OR A						; $833E
			CALL Z,SCROLL_BORDER		; $833F
			JP Z,LOOP_INPUT					; $8342
			
			LD (IX+$02),D				; $8345
			LD (IX+$06),E				; $8348
			LD DE,$000A					; $834B
			ADD IX,DE					; $834E
			LD (IY+$00),A				; $8350
			INC IY						; $8353
			POP DE						; $8355
			LD HL,$83C1					; $8356
			CP $20						; $8359
			JR NZ,L_8360				; $835B
			LD HL,$83C5					; $835D
L_8360:		CP $0D						; $8360
			JR NZ,L_8367				; $8362
			LD HL,$83CD					; $8364
L_8367:		CP $01						; $8367
			JR NZ,L_836E				; $8369
			LD HL,$83D5					; $836B
L_836E:		CP $02						; $836E
			JR NZ,L_8375				; $8370
			LD HL,$83E2					; $8372
L_8375:		LD ($83C1),A				; $8375
			LD C,$44					; $8378
			CALL DRAW_LIST					; $837A
			POP BC						; $837D
			DJNZ L_8329					; $837E
			LD BC,$C350					; $8380
			CALL WAIT_21xBC				; $8383
			CALL WAIT_21xBC				; $8386
			LD HL,$83F1					; $8389
			LD DE,CHEAT_KEYS			; $838C  ; load cheat keys
			LD B,$04					; $838F
L_8391: 	LD A,(DE)					; $8391
			CP (HL)						; $8392
			JP NZ,DO_MENU				; $8393
			INC HL						; $8396
			INC DE						; $8397  ; look at next cheat key
			DJNZ L_8391					; $8398
			LD A,($8F4F)				; $839A
			XOR $35						; $839D
			LD ($8F4F),A				; $839F
			JP NZ,DO_MENU				; $83A2
			LD A,$04					; $83A5
			CALL SET_BEEPER_SFX					; $83A7
			LD E,SFX_GAMEOVER					; $83AA
			CALL PLAY_SFX				; $83AC
			LD B,$64					; $83AF
L_83B1:		CALL SCROLL_BORDER			; $83B1
			DJNZ L_83B1					; $83B4
			CALL AY_RESET_MUSIC					; $83B6
			LD E,$01					; $83B9
			CALL PLAY_SFX				; $83BB
			JP DO_MENU					; $83BE

				defb $3F,$7A                                        ; $83C1 ?z
				defb $FF,$FF,$53,$50,$41,$43,$45,$7A				; $83C3 ..SPACEz
				defb $FB,$FF,$45,$4E,$54,$45,$52,$7A				; $83CB ..ENTERz
				defb $FB,$FF,$43,$41,$50,$53,$20,$53				; $83D3 ..CAPS S
				defb $48,$49,$46,$54,$7A,$F6,$FF,$53				; $83DB HIFTz..S
				defb $59,$4D,$42,$4F,$4C,$20,$53,$48				; $83E3 YMBOL SH
				defb $49,$46,$54,$7A,$F4,$FF						; $83EB IFTz..

DEFINE_KEYS:	defb $00,$00,$00,$00								; $83F1	x4 keys saved here
				defb $00											; $83F3
CHEAT_KEYS:		defb $59,$58,$45,$53								; $83F6 YXES


;HERE

				;--------------------------------------------------------------
				; Selected Keys Menu Test (for use with DRAW_LIST)
				defb GLOBAL_COL,%01000011							; $83FA
				defb SET_POS,9,7										
				defb SET_SOURCE_DATA ; ,$F1,$C2                    		
				defw FONT_DATA		
				defb "SELECT KEY FOR...."						
				defb INK_CYAN,MOVE+3,238, "LEFT"	
				defb MOVE+2,$FC, "RIGHT"
				defb MOVE+2,$FB, "UP  "								
				defb MOVE+2,$FC, "FIRE"								
				defb $70,$04,$E5,$09,$20							
				defb SET_POS,20,4						
				defb INK_RED,"CYBERNOID * 1988 HEWSON"						
				defb END_MARKER	
				;--------------------------------------------------------------

DRAW_MENU_BORDERS:
			; -------------------------------------------------------------
			; Draw x4 Border Corners
            LD DE,$0000       		 	; $844F  ; Y,X coords (Top-left)
            LD A,$10           			; $8452  ; Tile index
            CALL DRAW16x16_TILE     	; $8454  ; (0,0)
            CALL SET_TILE16X16_COL  	; $8457  ; 
            LD DE,$0078        			; $845A  ; (Top-right)
            LD A,$11          		 	; $845D  ; 
            CALL DRAW16x16_TILE     	; $845F  ; (0,120)
            CALL SET_TILE16X16_COL  	; $8462  ; 
            LD DE,$B000        			; $8465  ; (Bottom-left)
            LD A,$12          		 	; $8468  ; 
            CALL DRAW16x16_TILE     	; $846A  ; (176,0)
            CALL SET_TILE16X16_COL  	; $846D  ; 
            LD DE,$B078       		 	; $8470  ; (Bottom-right)
            LD A,$13          		 	; $8473  ; 
   	        CALL DRAW16x16_TILE     	; $8475  ; (176,120)
            CALL SET_TILE16X16_COL  	; $8478  ; 
			; -------------------------------------------------------------
			; Draw x4 Border Lines
			LD DE,$1000				; $847B  ; Y,X coords 
			CALL DRAW_HOR_BORDER	; $847E  ; left 
			LD DE,$1078				; $8481  ; 
			CALL DRAW_HOR_BORDER	; $8484  ; right
			LD DE,$0008				; $8487
			CALL DRAW_VERT_BORDER	; $848A  ; top 
			LD DE,$B008				; $848D  
			CALL DRAW_VERT_BORDER	; $8490  ; bottom 
			
			;-------------------------------------------------------
			; Draw Menu Logo (10x3 of 16x16 titles)	
			LD DE,$101C						; $8493  ; Logo Y/X
			LD HL,LOGO_DATA					; $8496
			LD C,$03						; $8499
NEXT_LOGO_PART:
			LD B,$0A						; $849B  ; Draw 10 (16x16) tiles on X-axis
LOOP_MENU_LOGO:
			LD A,(HL)						; $849D	 ; Title
			INC HL							; $849E  ; Next title
			CALL DRAW16x16_TILE				; $849F
			CALL SET_TILE16X16_COL			; $84A2
			LD A,E							; $84A5
			ADD A,$08						; $84A6  
			LD E,A							; $84A8  ; move right one tile
			DJNZ LOOP_MENU_LOGO				; $84A9
			LD E,$1C						; $84AB  ; X+=28 (row stride)
			LD A,D							; $84AD
			ADD A,$10						; $84AE
			LD D,A							; $84B0
			DEC C							; $84B1	; move down a 16x16 tile
			JR NZ,NEXT_LOGO_PART			; $84B2
			RET								; $84B4
			;-------------------------------------------------------
DRAW_HOR_BORDER:
			LD B,$0A					; $84B5
LOOP_HOR: 	LD A,$15					; $84B7
			CALL DRAW16x16_TILE			; $84B9
			CALL SET_TILE16X16_COL		; $84BC
			LD A,D						; $84BF
			ADD A,$10					; $84C0
			LD D,A						; $84C2
			DJNZ LOOP_HOR				; $84C3
			RET							; $84C5
			;-------------------------------------------------------
DRAW_VERT_BORDER:
			LD B,$0E					; $84C6
LOOP_VERT:	LD A,$14					; $84C8
			CALL DRAW16x16_TILE			; $84CA
			CALL SET_TILE16X16_COL		; $84CD
			LD A,E						; $84D0
			ADD A,$08					; $84D1
			LD E,A						; $84D3
			DJNZ LOOP_VERT				; $84D4
			RET							; $84D6
			;-------------------------------------------------------
LOGO_DATA:
			defb $00,$6D,$6E,$00,$00,$00,$00,$00,$6F,$70  ; 1st row (each is a 16x16 tile)
			defb $5A,$5B,$5C,$5D,$5E,$5F,$60,$61,$62,$63  ;	2nd row 
			defb $00,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C  ; 3rd row

SCROLL_BORDER:		
			HALT				; $84F5
			PUSH AF				; $84F6
			PUSH BC				; $84F7
			PUSH DE				; $84F8
			PUSH HL				; $84F9
			AND A				; $84FA
			LD HL,$4102			; $84FB
			LD D,$0E			; $84FE
L_8500:		PUSH HL				; $8500
			LD B,$04			; $8501
L_8503:		RR (HL)				; $8503
			INC L				; $8505
			RR (HL)				; $8506
			INC L				; $8508
			RR (HL)				; $8509
			INC L				; $850B
			RR (HL)				; $850C
			INC L				; $850E
			RR (HL)				; $850F
			INC L				; $8511
			RR (HL)				; $8512
			INC L				; $8514
			RR (HL)				; $8515
			INC L				; $8517

			DJNZ L_8503				; $8518
			POP HL				; $851A
			JR NC,L_851F				; $851B
			SET 7,(HL)				; $851D
L_851F:
			CALL NEXT_SCR_LINE				; $851F
			DEC D				; $8522
			JP NZ,L_8500				; $8523
			LD HL,$4040				; $8526
			LD DE,$4140				; $8529
			LD B,(HL)				; $852C
			INC HL				; $852D
			LD C,(HL)				; $852E
			DEC HL				; $852F
			EX DE,HL				; $8530
			PUSH BC				; $8531
			LD BC,$013E				; $8532
L_8535:
			LDI				; $8535
			LDI				; $8537
			EX AF,AF'				; $8539
			DEC L				; $853A
			DEC L				; $853B
			LD E,L				; $853C
			LD D,H				; $853D
			CALL NEXT_SCR_LINE				; $853E
			EX AF,AF'				; $8541
			JP PE,L_8535				; $8542
			POP BC				; $8545
			EX DE,HL				; $8546
			LD (HL),B				; $8547
			INC HL				; $8548
			LD (HL),C				; $8549
			LD DE,$57BE				; $854A
			LD BC,$0140				; $854D
			LD HL,$4040				; $8550
L_8553:
			LDI				; $8553
			LDI				; $8555
			EX AF,AF'				; $8557
			DEC DE				; $8558
			DEC DE				; $8559
			DEC HL				; $855A
			DEC HL				; $855B
			CALL NEXT_SCR_LINE				; $855C
			EX DE,HL				; $855F
			CALL L_675B				; $8560
			EX DE,HL				; $8563
			EX AF,AF'				; $8564
			JP PE,L_8553				; $8565
			AND A				; $8568
			LD HL,$51DD				; $8569
			LD D,$0E				; $856C
L_856E:
			PUSH HL				; $856E
			LD B,$04				; $856F
L_8571:
			RL (HL)				; $8571
			DEC L				; $8573
			RL (HL)				; $8574
			DEC L				; $8576
			RL (HL)				; $8577
			DEC L				; $8579
			RL (HL)				; $857A
			DEC L				; $857C
			RL (HL)				; $857D
			DEC L				; $857F
			RL (HL)				; $8580
			DEC L				; $8582
			RL (HL)				; $8583
			DEC L				; $8585
			DJNZ L_8571				; $8586
			POP HL				; $8588
			JR NC,L_858D				; $8589
			SET 0,(HL)				; $858B
L_858D:
			CALL NEXT_SCR_LINE				; $858D
			DEC D				; $8590
			JP NZ,L_856E				; $8591
			POP HL				; $8594
			POP DE				; $8595
			POP BC				; $8596
			POP AF				; $8597
			RET				; $8598
; -----------------------------------------------------------------

SPECCY_MODEL: 			defb $01		; $8599 ; 0=48k, 1=128k

; -----------------------------------------------------------------

; Beeper sound effect vars:
SOUND_EFFECT_ID:		defb $00		; $859A
LAST_SND_EFFECT_ID:		defb $00		; $859B
SND_TIMER:				defb $00		; $859C
_PADDING_				defb $00		; $859D  ;
; -----------------------------------------------------------------------------------
TEMP_SND_BUFFER:                 		; $859E: temp store for parameters from BEEPER_LIST
; -----------------------------------------------------------------------------------
FREQ_PARAM1_LOW:		defb $00		; $859E
FREQ_PARAM1_HIGH:		defb $00		; $859F
FREQ_PARAM2_LOW:		defb $00		; $85A0
FREQ_PARAM2_HIGH:		defb $00		; $85A1
FREQ_DELTA:				defb $00		; $85A2
SND_REPEAT_CNT:			defb $00		; $85A3
SND_CTRL_FLAGS:			defb $00		; $85A4
SOUND_DURATION_PARAM:	defb $00		; $85A5
; -----------------------------------------------------------------------------------
; Working Sound States
SND_SWEEP_RATE:			defb $00		; $85A6
FREQ_CNT_1:				defb $00		; $85A7
						defb $00		; $85A8
SND_DURATION:			defb $00		; $85A9
FREQ_CNT_2:				defb $00 		; $85AA
						defb $00       	; $85AB
SND_PTR1:				defb $00		; $85AC
						defb $00		; $85AD
SND_PTR2:				defb $00		; $85AE
						defb $00		; $85AF
; -----------------------------------------------------------------------------------


; New smaller sound effect values are seen as more urgent.
; IN:A (SFX ID, 0=no sound)
SET_BEEPER_SFX:		
			PUSH HL							; $85B0
			LD HL,LAST_SND_EFFECT_ID		; $85B1
			CP (HL)							; $85B4  
			JR NC,SKIP_SND_UPDATE 			; $85B5 ; A>=(HL)
			LD (HL),A						; $85B7
SKIP_SND_UPDATE:		
			POP HL							; $85B8
			RET								; $85B9

;----------------------------------------------------------------
; Beeper Sound Driver (25Hz polled)
; Uses 1-bit sound output (port $FE) and makes sound by timing delays
;---------------------------------------------------------------
POLL_SFX_USING_BEEPER:		
			LD HL,SOUND_EFFECT_ID  			; $85BA
			LD A,(LAST_SND_EFFECT_ID)		; $85BD
			CP $FF							; $85C0
			JR Z,CONTINUE_SOUND				; $85C2
			 ; New sound initialization
			LD C,A							; $85C4 ; Store
			LD A,$FF						; $85C5
			LD (LAST_SND_EFFECT_ID),A		; $85C7 ; Clear
			LD A,(HL)						; $85CA ; Get current sound ID
			AND A							; $85CB
			JR Z,NEW_SOUND					; $85CC ; new sound when idle
			CP C							; $85CE ; Compare priorities
			JR C,CONTINUE_SOUND				; $85CF
NEW_SOUND:		
			LD (HL),C						; $85D1 ; store ID
			LD A,C							; $85D2 ; 
			AND A							; $85D3
			JP Z,STOP_SOUND_EFFECT			; $85D4

			; Get from table
			DEC A						; $85D7  ; index from 0
			RLCA						; $85D8	 ; x2
			RLCA						; $85D9	 ; x4
			RLCA						; $85DA  ; x8 (8 byte items)
			LD E,A						; $85DB
			LD D,$00					; $85DC
			LD HL,BEEPER_LIST			; $85DE	 ; base
			ADD HL,DE					; $85E1	 ; offset 
			LD DE,TEMP_SND_BUFFER		; $85E2
			LD BC,$0007					; $85E5
			LDIR						; $85E8  ; copy 7 items

			 ; Process control byte
			LD A,(HL)       ; $85EA  ; 8th byte of BEEPER_LIST (control flags)
			AND $0F         ; $85EB 
			LD (DE),A       ; $85ED  ; Store in SOUND_DURATION_PARAM ($85A5)
			INC DE          ; $85EE  ; DE now points to $85A6 SND_SWEEP_RATE
			XOR (HL)        ; $85EF  ; now XOR with lower nibble to get upper nibble
			RRCA            ; $85F0  ;
			RRCA            ; $85F1  ;
			RRCA            ; $85F2  ;
			RRCA            ; $85F3  ; upper nibble into lower nibble
			LD (DE),A       ; $85F4  ; Store upper nibble in $85A6  SND_SWEEP_RATE 
			
			 ; Initialize sound variables
			LD HL,SND_CTRL_FLAGS  			; $85F5
			LD C,(HL)						; $85F8
			LD HL,FREQ_CNT_1				; $85F9
			LD A,(FREQ_PARAM1_LOW)			; $85FC
			LD (HL),A						; $85FF
			INC HL							; $8600
			LD A,(FREQ_PARAM2_LOW)			; $8601
			LD (HL),A						; $8604
			LD A,(SOUND_DURATION_PARAM)		; $8605
			LD (SND_DURATION),A				; $8608
			BIT 7,C							; $860B
			EXX								; $860D
			LD HL,FREQ_CNT_1				; $860E
			LD E,L							; $8611
			LD D,H							; $8612
			JR Z,SINGLE_CHAN				; $8613
			LD DE,$85A8						; $8615
SINGLE_CHAN:		
			EXX						; $8618
			LD B,$01				; $8619
			JR SND_LOOP_ENTRY		; $861B
CONTINUE_SOUND:		
			LD A,(HL)				; $861D
			AND A					; $861E
			JP Z,STOP_SOUND_EFFECT	; $861F
			LD HL,(FREQ_CNT_2)		; $8622
			LD DE,(SND_PTR1)			; $8625
			EXX						; $8629
			LD BC,(SND_PTR2)			; $862A
SND_LOOP_ENTRY:
			LD HL,(SND_TIMER)			; $862E
			;-------------------------------------
SND_LOOP:	
			EXX						; $8631
			LD C,$02				; $8632
			LD A,$18				; $8634  ; %00011000 (both Beeper/Mic)
PHASE_LOOP:		
			LD B,(HL)				; $8636
			OUT ($FE),A				; $8637
DURATION_LOOP:		
			EXX						; $8639
			DEC HL					; $863A
			EXX						; $863B
			DJNZ DURATION_LOOP		; $863C
			EX DE,HL				; $863E
			LD A,$00				; $863F
			DEC C					; $8641
			JR NZ,PHASE_LOOP		; $8642	
			EXX						; $8644
			BIT 7,H					; $8645  ; 
			JR Z,SND_LOOP  			; $8647  ; 
			;-------------------------------------
			BIT 7,C					; $8649
			JR Z,L_865D				; $864B
			LD HL,FREQ_CNT_1		; $864D
			LD A,(FREQ_PARAM1_HIGH)			; $8650
			ADD A,(HL)				; $8653
			LD (HL),A				; $8654
			INC HL					; $8655
			LD A,(FREQ_PARAM2_HIGH)			; $8656
			ADD A,(HL)				; $8659
			LD (HL),A				; $865A
			JR L_866F				; $865B
L_865D:		LD HL,FREQ_CNT_1		; $865D
			LD A,(FREQ_PARAM1_HIGH)			; $8660
			BIT 0,B					; $8663
			JR NZ,L_866D			; $8665
			LD HL,$85A8				; $8667
			LD A,(FREQ_PARAM2_HIGH)			; $866A
L_866D:		ADD A,(HL)				; $866D
			LD (HL),A				; $866E
L_866F:		LD HL,SND_DURATION		; $866F
			DEC (HL)				; $8672
			JP NZ,L_86FE			; $8673
			LD HL,SND_REPEAT_CNT				; $8676
			DEC (HL)				; $8679
			JP Z,STOP_SOUND_EFFECT	; $867A
			LD HL,FREQ_DELTA				; $867D
			LD E,(HL)				; $8680
			LD HL,FREQ_PARAM1_HIGH				; $8681
			LD A,(HL)				; $8684
			ADD A,E					; $8685
			LD (HL),A				; $8686
			LD HL,FREQ_PARAM2_HIGH				; $8687
			LD A,(HL)				; $868A
			ADD A,E					; $868B
			LD (HL),A				; $868C
			BIT 5,C					; $868D
			JR Z,L_8699				; $868F
			LD HL,SOUND_DURATION_PARAM		; $8691
			DEC (HL)						; $8694
			JR NZ,L_8699					; $8695
			LD (HL),$01						; $8697
L_8699:		BIT 3,C							; $8699
			JR Z,L_86AC						; $869B
			BIT 7,C							; $869D
			JR NZ,L_86A5					; $869F
			BIT 0,B							; $86A1
			JR Z,L_86AC						; $86A3
L_86A5:		LD HL,FREQ_PARAM1_HIGH						; $86A5
			LD A,(HL)						; $86A8
			NEG								; $86A9
			LD (HL),A						; $86AB
L_86AC:		BIT 4,C							; $86AC
			JR Z,L_86BF						; $86AE
			BIT 7,C							; $86B0
			JR NZ,L_86B8					; $86B2
			BIT 0,B							; $86B4
			JR Z,L_86BF						; $86B6
L_86B8:		LD HL,FREQ_PARAM2_HIGH						; $86B8
			LD A,(HL)						; $86BB
			NEG								; $86BC
			LD (HL),A						; $86BE
L_86BF:		BIT 6,C							; $86BF
			JR Z,L_86CF						; $86C1
			LD HL,FREQ_CNT_1				; $86C3
			LD A,(FREQ_PARAM1_LOW)			; $86C6
			LD (HL),A						; $86C9
			INC HL							; $86CA
			LD A,(FREQ_PARAM2_LOW)			; $86CB
			LD (HL),A						; $86CE
L_86CF:		EXX								; $86CF
			LD HL,FREQ_CNT_1				; $86D0
			LD DE,$85A8						; $86D3
			LD A,(SOUND_DURATION_PARAM)		; $86D6
			EXX								; $86D9
			BIT 7,C							; $86DA
			JR NZ,L_86FB					; $86DC
			LD A,(SND_REPEAT_CNT)					; $86DE
			LD B,C							; $86E1
			SRL A							; $86E2
			JR NC,L_86EC					; $86E4
			JR NZ,L_86EA					; $86E6
			RR B							; $86E8
L_86EA:		RR B							; $86EA
L_86EC:		BIT 0,B							; $86EC
			EXX								; $86EE
			LD A,(SOUND_DURATION_PARAM)		; $86EF
			JR NZ,L_86F8					; $86F2
			EX DE,HL						; $86F4
			LD A,(SND_SWEEP_RATE)					; $86F5
L_86F8:		LD E,L							; $86F8
			LD D,H							; $86F9
			EXX								; $86FA
L_86FB:		LD (SND_DURATION),A				; $86FB
L_86FE:		LD (SND_PTR2),BC					; $86FE
			EXX								; $8702
			LD (FREQ_CNT_2),HL				; $8703
			LD (SND_PTR1),DE					; $8706
			RET								; $870A

STOP_SOUND_EFFECT:		
			XOR A							; $870B
			LD (SOUND_EFFECT_ID),A			; $870C
			RET								; $870F

; ------------------------------------------------------------------
; Table lookup for the beeper sound parameters  
; When looking at the "SET_BEEPER_SFX" usage, we pass A with values from 1 to 5.  
; This confirms that the BEEPER_LIST table consists of 5 structs, each defining different sound effects.  
BEEPER_LIST:											; $8710 
			defb $80,$FE,$01,$01,$00,$03,$87,$03   	 	; SFX_ID1
			defb $0F,$01,$00,$00,$00,$04,$07,$08	   	; SFX_ID2
			defb $50,$FB,$00,$00,$00,$06,$67,$05	   	; SFX_ID3
			defb $70,$08,$50,$FA,$00,$05,$14,$13	   	; SFX_ID4
			defb $32,$FE,$00,$00,$00,$05,$07,$02 	   	; SFX_ID5	
; Using "SFX_ID1" as an example:-
; 		$80,$FE = Freq1: $FE80
;	 	$01,$01 = Freq2: $0101)
;  	   	$00 = Delta: $00 (no sweep)
;		$03 = Repeat 3 times
;		$87 = Duration|Flags: (duration=7, control flags=8 (sweep settings))	
; ------------------------------------------------------------------


; init
BEEPER_SETUP:		
			LD HL,$0190					; $8738
			LD (SND_TIMER),HL				; $873B
			LD A,$FF					; $873E
			LD (LAST_SND_EFFECT_ID),A		; $8740
			INC A						; $8743
			LD (SOUND_EFFECT_ID),A	; $8744
			RET							; $8747

;----------

L_8748:		PUSH AF				; $8748
			PUSH BC				; $8749
			PUSH DE				; $874A
			PUSH HL				; $874B
			PUSH IX				; $874C
			LD HL,$8847				; $874E
L_8751:		LD C,A				; $8751
			LD A,(HL)				; $8752
			CP $FF				; $8753
			JP Z,L_87A5				; $8755
			LD A,C				; $8758
			CP (HL)				; $8759
			JR Z,L_8762				; $875A
			LD BC,$0004				; $875C
			ADD HL,BC				; $875F
			JR L_8751				; $8760
L_8762:		LD IX,$8814				; $8762
L_8766:		BIT 7,(IX+$00)				; $8766
			JR NZ,L_87A5				; $876A
			EX AF,AF'				; $876C
			LD A,(IX+$01)				; $876D
			OR A				; $8770
			JR Z,L_877B				; $8771
			EX AF,AF'				; $8773
			LD BC,$000A				; $8774
			ADD IX,BC				; $8777
			JR L_8766				; $8779
L_877B:		EX AF,AF'				; $877B
			PUSH HL				; $877C
			CALL L_A539				; $877D
			LD (IX+$06),L				; $8780
			LD (IX+$07),H				; $8783
			POP HL				; $8786
			LD (IX+$00),E				; $8787
			LD (IX+$01),D				; $878A
			INC HL				; $878D
			LD A,(HL)				; $878E
			LD (IX+$02),A				; $878F
			LD (IX+$04),A				; $8792
			INC HL				; $8795
			LD A,(HL)				; $8796
			LD (IX+$03),A				; $8797
			LD (IX+$05),A				; $879A
			INC HL				; $879D
			LD A,(HL)				; $879E
			LD (IX+$08),A				; $879F
			LD (IX+$09),A				; $87A2
L_87A5:		POP IX				; $87A5
			POP HL				; $87A7
			POP DE				; $87A8
			POP BC				; $87A9
			POP AF				; $87AA
			RET					; $87AB

; ---------------------------------------------------------------------

ANIMATE_SPRITE:
			LD IX,$8814						; $87AC  ; sprite table pointer
ANIM_SPRITE_LOOP:		
			LD E,(IX+SpriteIndex)			; $87B0  ; load sprite index (doubles as end marker)
			BIT 7,E							; $87B3  ; 
			RET NZ							; $87B5  ; Exit if end-of-list marker found
			LD A,(IX+AnimationControl)		; $87B6  ; animation control  
			OR A							; $87B9  ; 
			RET Z							; $87BA  ; Exit if no animation is enabled
			LD D,A							; $87BB  ; Animation control
			LD C,E							; $87BC  ; Sprite index
			CALL GET_ANIM_ADDR_AS_HL		; $87BD  ; HL=animation data address
			LD E,C							; $87C0  ; sprite index
			LD A,(HL)						; $87C1  ; get animation frame data
			OR A							; $87C2  ; get animation frame data
			JP Z,NEXT_ANIM_SPRITE			; $87C3  ; skip zero terminator (no anim)
			LD D,(IX+AnimationControl)		; $87C6  ; Reload animation control
			LD B,D							; $87C9  ; ???
			LD A,(IX+CountDown)				; $87CA  ; current delay counter
			OR A							; $87CD  ; 
			JR NZ,HANDLE_COUNTDOWN 			; $87CE  ; reaches zero, next frame

			LD A,(IX+ResetCounter)			; $87D0  ; Get initial delay value
			LD (IX+CountDown),A				; $87D3  ; Reset countdown timer (A==0)
			LD L,(IX+FrameLow)				; $87D6  ; Get current frame pointer
			LD H,(IX+FrameHigh)				; $87D9
			LD A,(HL)						; $87DC  ; get frame
			CP $FF							; $87DD  ; end-of-animation marker
			JR NZ,UPDATE_FRAME				; $87DF  ; Proceed if not at end
			
			; Reset to start of animation
			LD L,(IX+AnimationStartLow)		; $87E1  ; Reset animation
			LD H,(IX+AnimationStartHigh)	; $87E4
			LD (IX+FrameLow),L				; $87E7  ; store 
			LD (IX+FrameHigh),H				; $87EA
			LD A,(HL)						; $87ED  ; get data (back to first frame)
UPDATE_FRAME:		
			INC HL							; $87EE  ; next frame
			LD (IX+FrameLow),L				; $87EF  ; store updated frame 
			LD (IX+FrameHigh),H				; $87F2  ; 

			; Update sprite graphics
			LD L,(IX+X_POS)					; $87F5
			LD H,(IX+Y_POS)					; $87F8
			CALL DRAW4X4SPRITE				; $87FB  ; animated icons
			LD (IX+X_POS),L					; $87FE
			LD (IX+Y_POS),H					; $8801
			LD B,A							; $8804 ; frame data
			CALL GET_ANIM_ADDR_AS_HL		; $8805 ; Draw sprite at (L,H) = (X,Y)
			LD (HL),B						; $8808 ; new sprite pattern 
HANDLE_COUNTDOWN:		
			DEC (IX+CountDown)				; $8809 ; frame delay counter
NEXT_ANIM_SPRITE:		
			LD DE,$000A						; $880C	; Size of per-sprite structure
			ADD IX,DE						; $880F ; move to next sprite
			JP ANIM_SPRITE_LOOP				; $8811 ;


SPRITE_INSTRUCTION_TABLE:
			defb $FC,$00,$00,$54,$FC,$A8,$00                ; $8814
			defb $54,$FC,$00,$00,$54,$A8,$00,$00			; $881B
			defb $00,$00,$00,$00,$CF,$CF,$CF,$CF			; $8823
			defb $CF,$CF,$CF,$CF,$0F,$0F,$0F,$0F			; $882B
			defb $0F,$0F,$0F,$0F,$4F,$05,$0F,$0F			; $8833
			defb $0A,$05,$0F,$0F,$C3,$C3,$C3,$C3			; $883B
			defb $C3,$C3,$C3,$FF,$1D,$60,$88,$03			; $8843
			defb $20,$64,$88,$03,$1F,$68,$88,$03			; $884B
			defb $22,$6C,$88,$03,$52,$70,$88,$05			; $8853
			defb $53,$81,$88,$05,$FF,$1D,$1E,$1F			; $885B
			defb $FF,$20,$21,$22,$FF,$1F,$1E,$1D			; $8863
			defb $FF,$22,$21,$20,$FF,$52,$52,$52			; $886B
			defb $52,$52,$52,$54,$56,$58,$58,$58			; $8873
			defb $58,$58,$58,$56,$54,$FF,$53,$53			; $887B
			defb $53,$53,$53,$53,$55,$57,$59,$59			; $8883
			defb $59,$59,$59,$59,$57,$55                    ; $888B
			defb $FF										; $8891  ; END-OF-LIST MARKER


CLR_TABLE_ITEMS:		
			LD HL,TABLE_TO_TABLE_CLEAR_INFO	; $8892 
CLEAR_MEM_ITEMS:
			;----------------------------------------------
			; check for "$0000" end of table
			LD E,(HL)			; $8895 ; low byte
			INC HL				; $8896
			LD D,(HL)			; $8897	; high byte
			LD A,E				; $8898
			OR D				; $8899 ; 
			RET Z				; $889A	; exit - table end marker
			;----------------------------------------------
			INC HL				; $889B
			LD C,(HL)			; $889C ; 
			INC HL				; $889D
			LD B,(HL)			; $889E ; high byte, BC counter
			INC HL				; $889F ; next item
			PUSH HL				; $88A0
			LD H,D				; $88A1
			LD L,E				; $88A2 ; HL = address to zero 
			INC DE				; $88A3 ; next byte
			LD (HL),$00			; $88A4 ; Initial clear
			LDIR				; $88A6 ; zero memory
			POP HL				; $88A8
			JP CLEAR_MEM_ITEMS	; $88A9 ; next part

TABLE_TO_TABLE_CLEAR_INFO:
			;  ADDRESS (2bytes)
			;  AMOUNT  (2bytes)
			defw MINES_DATA ; 
			defb $1D,$00    ; mines, amount to clear
			defb $95,$7D
			defb $37,$00  
			defw BULLET_LIST
			defb $11,$00  
			defw DATA_02 	
			defb $A3,$01  
			defw SPRITE_INSTRUCTION_TABLE
			defb $31,$00  
			defw BOUNCE_DATA
			defb $13,$00
			defb $16,$8B
			defb $59,$00
			defb $6E,$89
			defb $31,$00
			defw DATA_03
			defb $8B,$00 
			defw BONUS_TEXT_DATA 	
			defb $27,$00
			defb $FC,$6C
			defb $4F,$00
			defw DATA_04
			defb $31,$00
			defw DATA_05
			defb $4F,$00
			defw DATA_06
			defb $77,$00
			defw DATA_07
			defb $3B,$00
			defb $00,$00              			; END MARKERS    

ADD_EXPLOSION_WITH_SFX:		
			PUSH AF				; $88EA
			PUSH BC				; $88EB
			PUSH HL				; $88EC
			LD HL,$896E			; $88ED
L_88F0:		LD A,(HL)			; $88F0
			CP $FF				; $88F1
			JR Z,L_891F			; $88F3
			OR A				; $88F5
			LD BC,$0005			; $88F6
			ADD HL,BC			; $88F9
			JR NZ,L_88F0		; $88FA
			SBC HL,BC			; $88FC
			LD (HL),$09			; $88FE
			INC HL				; $8900
			LD (HL),E			; $8901
			INC HL				; $8902
			LD (HL),D			; $8903
			INC HL				; $8904
			LD BC,SPRITE24x16_DATA			; $8905
			LD (HL),C			; $8908
			INC HL				; $8909
			LD (HL),B			; $890A
			PUSH DE				; $890B
			PUSH IY				; $890C
			PUSH IX				; $890E
			LD E,SFX_EXPLODEA			; $8910
			CALL PLAY_SFX			; $8912
			LD A,$04			; $8915
			CALL SET_BEEPER_SFX			; $8917
			POP IX				; $891A
			POP IY				; $891C
			POP DE				; $891E
L_891F:		POP HL				; $891F
			POP BC				; $8920
			POP AF				; $8921
			RET					; $8922

;   EXPLOSION_COORDS_LIST structure
;     Byte 0: Frame counter  ($FF=list terminator, 0=slot available)
;     Byte 1: Xpos
;     Byte 2: Ypos
;     Bytes 3-4: Previous screen coordinates
DO_EXPLOSIONS:		
			LD IX,EXPLOSION_COORDS_LIST		; $8923
EXPLOSIONS_LOOP:
			LD A,(IX+$00)			; $8927  ; Explosion frame
			CP $FF					; $892A
			RET Z					; $892C  ; Exit, end of list
			OR A					; $892D
			JR Z,EXPLOSION_IN_USE	; $892E  ; Skip active
			LD E,(IX+$01)			; $8930	 ; X
			LD D,(IX+$02)			; $8933  ; Y
			LD L,A					; $8936  ; frame 
			LD H,$00				; $8937  ; as 16-bit index
			DEC A					; $8939  ; next frame
			LD (IX+$00),A			; $893A
			LD BC,SPRITE_EXPLOSION_ID_LIST-1			; $893D  ; base, but NOTE -1 on label (ok as frames never reach 0)
			ADD HL,BC				; $8940	 ; frame data offset
			LD A,(HL)				; $8941  ; sprite ID for frame
			LD L,(IX+$03)			; $8942  ; erase these previous coords drawn
			LD H,(IX+$04)			; $8945
			LD B,D					; $8948 
			LD C,E					; $8949 
			CALL SPRITE_24x16		; $894A
			LD (IX+$03),L			; $894D ; store latest to erase later
			LD (IX+$04),H			; $8950
			;--------------------------------
			LD A,$06				; $8953 
			CALL GET_RAND_VALUE		; $8955  	
			ADD A,$41				; $8958
			LD C,A					; $895A
			CALL SET_SCRN_ATTR		; $895B  ; Random Colour
			;--------------------------------
EXPLOSION_IN_USE:		
			LD DE,$0005				; $895E  ; Next coord item
			ADD IX,DE				; $8961
			JR EXPLOSIONS_LOOP		; $8963
			
SPRITE_EXPLOSION_ID_LIST: 	 ;  IMPORTANT NOTE: ABOVE DOES -1 TO USE THIS ADDRERSS (OPTIMISED THING)
			defb $00,$0C,$0C,$0B,$0B,$0A,$0A,$09,$09    ; $8965 
			; This checks out as Sprite Explosion ID's are: 9,10,11,12 
			; So we read the above from last to first (ends in frame 0)
			; Sprite ID zero is blank so that also checks out.
EXPLOSION_COORDS_LIST:	
			defb $2A,$7F,$00,$00,$7B					; $896E
			defb $DF,$45,$AA,$3F,$AA,$55,$A2,$15		; $8973 
			defb $AA,$55,$A2,$15,$AA,$15,$A2,$15		; $897B 
			defb $AA,$15,$A2,$15,$2A,$15,$A2,$51		; $8983 
			defb $2A,$15,$A2,$51,$3F,$51,$A2,$F3		; $898B 
			defb $B7,$00,$00,$F3,$51,$2A,$51,$A2		; $8993 
			defb $51,$F3,$F3,$A2,$00,$FF                ; $899B 


; ship being destroyed setup?
ADD_ITEM_TO_LIST:		
			PUSH AF					; $89A1   
			PUSH BC					; $89A2
			PUSH DE					; $89A3
			PUSH HL					; $89A4
			PUSH IX					; $89A5
			LD H,D					; $89A7
			LD L,E					; $89A8
			LD DE,$0005				; $89A9  ; structure size
			LD IX,DATA_04			; $89AC	 ; base
			EX AF,AF'				; $89B0
LIST_LOOP:	LD A,(IX+$00)			; $89B1
			CP $FF					; $89B4
			JR Z,END_OF_LIST		; $89B6 ; End marker
			OR A					; $89B8
			JR Z,SLOT_USED			; $89B9 ; not free
			ADD IX,DE				; $89BB ; onto next part 
			JP LIST_LOOP			; $89BD
SLOT_USED:	EX AF,AF'				; $89C0
			LD (IX+$00),A			; $89C1
			LD (IX+$01),L			; $89C4
			LD (IX+$02),H			; $89C7
			LD (IX+$03),C			; $89CA
			LD (IX+$04),B			; $89CD
END_OF_LIST:
			POP IX					; $89D0
			POP HL					; $89D2
			POP DE					; $89D3
			POP BC					; $89D4
			POP AF					; $89D5
			RET						; $89D6

EXPLOSION_CLUSTER:		
			LD IX,DATA_04			; $89D7
L_89DB:		LD A,(IX+$00)			; $89DB
			CP $FF					; $89DE
			RET Z					; $89E0
			OR A					; $89E1
			JR NZ,L_89EC			; $89E2
L_89E4:		LD DE,$0005				; $89E4
			ADD IX,DE				; $89E7
			JP L_89DB				; $89E9
L_89EC:		DEC (IX+$00)			; $89EC
			LD E,(IX+$01)			; $89EF
			LD A,(IX+$03)			; $89F2
			CALL GET_RAND_VALUE				; $89F5
			ADD A,E					; $89F8
			LD E,A					; $89F9
			LD D,(IX+$02)			; $89FA
			LD A,(IX+$04)			; $89FD
			CALL GET_RAND_VALUE				; $8A00
			ADD A,D					; $8A03
			LD D,A					; $8A04
			CALL ADD_EXPLOSION_WITH_SFX				; $8A05
			JP L_89E4				; $8A08

DATA_04:
			defb $F3,$F3,$F3,$F3,$00,$00,$00,$00		; $8A0B 
			defb $80,$80,$80,$80,$00,$00,$00,$00		; $8A13 
			defb $F3,$F3,$F3,$F3,$00,$00,$00,$00		; $8A1B 
			defb $00,$00,$00,$00,$45,$CF,$00,$00		; $8A23 
			defb $55,$FF,$80,$00,$55,$FF,$80,$00		; $8A2B 
			defb $55,$FF,$D5,$00,$15,$3F,$D5,$AA		; $8A33 
			defb $15,$3F                                ; $8A3B 
			defb $FF  		 ; end-marker

L_8A3E:
			PUSH AF				; $8A3E
			PUSH BC				; $8A3F
			PUSH DE				; $8A40
			PUSH HL				; $8A41
			LD HL,BONUS_TEXT_DATA				; $8A42
			LD C,A				; $8A45
L_8A46:
			LD A,(HL)				; $8A46
			CP $FF				; $8A47
			JP Z,L_8A64				; $8A49
			INC HL				; $8A4C
			INC HL				; $8A4D
			INC HL				; $8A4E
			LD A,(HL)				; $8A4F
			INC HL				; $8A50
			OR A				; $8A51
			JR NZ,L_8A46				; $8A52
			DEC HL				; $8A54
			LD (HL),$28				; $8A55
			DEC HL				; $8A57
			LD (HL),C				; $8A58
			DEC HL				; $8A59
			LD (HL),D				; $8A5A
			DEC HL				; $8A5B
			LD (HL),E				; $8A5C
			LD A,C				; $8A5D
			LD HL,SPRITE24x16_DATA				; $8A5E
			CALL DRAW4X4SPRITE				; $8A61

L_8A64:		POP HL				; $8A64
			POP DE				; $8A65
			POP BC				; $8A66
			POP AF				; $8A67
			RET				; $8A68

BONUS_TEXT:		
			LD HL,BONUS_TEXT_DATA		; $8A69
L_8A6C:		LD A,(HL)			; $8A6C ; get first item
			CP $FF				; $8A6D ; end of list marker
			RET Z				; $8A6F ; back - nothing to do
			
			LD E,A				; $8A70 ; x	
			INC HL				; $8A71
			LD D,(HL)			; $8A72 ; y
			INC HL				; $8A73
			LD C,(HL)			; $8A74 ; colour
			INC HL				; $8A75
			LD A,(HL)			; $8A76	; timer
			INC HL				; $8A77 ; ready for next loop
			OR A				; $8A78
			JP Z,L_8A6C			; $8A79 ; done item, next loop
			DEC HL				; $8A7C ; not yet, get last item
			DEC (HL)			; $8A7D ; counter
			INC HL				; $8A7E ; next item
			LD A,C				; $8A7F  ; keep
			PUSH HL				; $8A80
			LD HL,SPRITE24x16_DATA			; $8A81
			CALL Z,DRAW4X4SPRITE		; $8A84  ; draws and clears bonus 
			POP HL				; $8A87
			LD A,(GAME_COUNTER_8BIT)	; $8A88
			AND $07				; $8A8B
			OR $40				; $8A8D
			LD C,A				; $8A8F	 ; restore
			CALL L_A4AD			; $8A90  ; flash colours
			JP L_8A6C			; $8A93

BONUS_TEXT_DATA:	
			defb $00,$00,$45          	          	; $8A96
			defb $22,$00 	                           	
			defb $00,$45,$22,$00,$00,$45,$22,$00		
			defb $CF,$CF,$9B,$33,$00,$00,$00,$00		
			defb $45,$CF,$33,$22,$45,$CF,$33,$22		
			defb $00,$00,$00,$00,$00,$CF,$33,$00		
			defb $00,$CF,$33,$FF                        

SPARKLE_EFFECT:		
			BIT 7,E			; $8ABF
			RET NZ					; $8AC1
			PUSH HL					; $8AC2
			LD HL,$8B16				; $8AC3
L_8AC6:		BIT 7,(HL)				; $8AC6
			JR NZ,L_8AD8			; $8AC8
			INC HL					; $8ACA
			INC HL					; $8ACB
			LD A,(HL)				; $8ACC
			OR A					; $8ACD
			INC HL					; $8ACE
			JR NZ,L_8AC6			; $8ACF
			DEC HL					; $8AD1
			LD (HL),$0A				; $8AD2
			DEC HL					; $8AD4
			LD (HL),D				; $8AD5
			DEC HL					; $8AD6
			LD (HL),E				; $8AD7
L_8AD8:		POP HL					; $8AD8
			RET						; $8AD9

DRAW_TRACER_EFFECT:		
			LD HL,$8B16				; $8ADA
TRACER_LOOP:		
			LD E,(HL)				; $8ADD
			BIT 7,E					; $8ADE
			RET NZ					; $8AE0
			INC HL					; $8AE1
			LD D,(HL)				; $8AE2
			INC HL					; $8AE3
			LD A,(HL)				; $8AE4
			INC HL					; $8AE5
			OR A					; $8AE6
			JR Z,TRACER_LOOP		; $8AE7
			PUSH HL					; $8AE9
			DEC HL					; $8AEA
			DEC (HL)				; $8AEB
			LD L,A					; $8AEC
			LD H,$00				; $8AED
			LD BC,$8B0A				; $8AEF
			ADD HL,BC				; $8AF2
			INC HL					; $8AF3
			LD A,(HL)				; $8AF4
			CALL DRAW_SPRITE16X8	; $8AF5
			DEC HL					; $8AF8
			LD A,(HL)				; $8AF9
			CALL DRAW_SPRITE16X8	; $8AFA
			LD A,$05				; $8AFD
			CALL GET_RAND_VALUE				; $8AFF
			ADD A,$42				; $8B02
			LD C,A					; $8B04
			CALL L_A4AD				; $8B05
			POP HL					; $8B08
			JR TRACER_LOOP			; $8B09

			defb $09,$08,$08,$08,$03,$08,$06,$08				; $8B0B ........
			defb $07,$06,$09,$00,$00,$45,$22,$00				; $8B13 .....E".
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $8B1B ........
			defb $00,$45,$22,$00,$00,$45,$22,$00				; $8B23 .E"..E".
			defb $00,$45,$22,$00,$00,$00,$00,$00				; $8B2B .E".....
			defb $00,$04,$80,$00,$00,$04,$80,$00				; $8B33 ........
			defb $00,$04,$80,$00,$00,$00,$00,$00				; $8B3B ........
			defb $00,$CF,$33,$00,$00,$CF,$33,$00				; $8B43 ..3...3.
			defb $00,$CF,$33,$00,$00,$00,$00,$00				; $8B4B ..3.....
			defb $45,$CF,$33,$22,$45,$CF,$33,$22				; $8B53 E.3"E.3"
			defb $00,$00,$00,$00,$CF,$CF,$9B,$33				; $8B5B .......3
			defb $00,$00,$00,$00,$00,$45,$22,$00				; $8B63 .....E".
			defb $00,$45,$22,$00,$00,$FF                        ; $8B6B .E"...

L_8B71:
			PUSH AF				; $8B71
			PUSH BC				; $8B72
			PUSH DE				; $8B73
			PUSH HL				; $8B74
			LD H,D				; $8B75
			LD L,E				; $8B76
			AND A				; $8B77
			SBC HL,BC				; $8B78
			JR Z,L_8BC5				; $8B7A
			LD H,E				; $8B7C
			LD L,D				; $8B7D
			LD A,B				; $8B7E
			LD B,C				; $8B7F
			LD C,A				; $8B80
			LD DE,$0101				; $8B81
			LD A,B				; $8B84
			SUB H				; $8B85
			JR NC,L_8B8C				; $8B86
			LD D,$FF				; $8B88
			NEG				; $8B8A
L_8B8C:
			LD B,A				; $8B8C
			LD A,C				; $8B8D
			SUB L				; $8B8E
			JR NC,L_8B95				; $8B8F
			LD E,$FF				; $8B91
			NEG				; $8B93
L_8B95:
			LD C,A				; $8B95
			OR B				; $8B96
			RET Z				; $8B97
			LD A,C				; $8B98
			CP B				; $8B99
			LD (IX+$00),H				; $8B9A
			LD (IX+$01),L				; $8B9D
			LD H,D				; $8BA0
			LD L,E				; $8BA1
			LD (IX+$04),H				; $8BA2
			LD (IX+$03),L				; $8BA5
			LD L,$00				; $8BA8
			JR C,L_8BB0				; $8BAA
			LD H,L				; $8BAC
			LD L,E				; $8BAD
			LD C,B				; $8BAE
			LD B,A				; $8BAF
L_8BB0:
			LD (IX+$06),H				; $8BB0
			LD (IX+$05),L				; $8BB3
			LD (IX+$02),B				; $8BB6
			LD A,B				; $8BB9
			SRL A				; $8BBA
			LD (IX+$07),A				; $8BBC
			LD (IX+$09),B				; $8BBF
			LD (IX+$08),C				; $8BC2
L_8BC5:
			POP HL				; $8BC5
			POP DE				; $8BC6
			POP BC				; $8BC7
			POP AF				; $8BC8
			RET				; $8BC9

L_8BCA:		PUSH BC				; $8BCA
			PUSH HL				; $8BCB
			LD B,(IX+$09)				; $8BCC
			LD C,(IX+$08)				; $8BCF
			LD L,(IX+$07)				; $8BD2
			LD A,L				; $8BD5
			ADD A,C				; $8BD6
			JR C,L_8BDC				; $8BD7
			CP B				; $8BD9
			JR C,L_8BE8				; $8BDA
L_8BDC:		SUB B				; $8BDC
			LD (IX+$07),A				; $8BDD
			LD D,(IX+$04)				; $8BE0
			LD E,(IX+$03)				; $8BE3
			JR L_8BF1				; $8BE6
L_8BE8:		LD (IX+$07),A				; $8BE8
			LD D,(IX+$06)				; $8BEB
			LD E,(IX+$05)				; $8BEE
L_8BF1:		LD H,(IX+$00)				; $8BF1
			LD L,(IX+$01)				; $8BF4
			LD A,H				; $8BF7
			ADD A,D				; $8BF8
			LD H,A				; $8BF9
			LD A,L				; $8BFA
			ADD A,E				; $8BFB
			LD L,A				; $8BFC
			LD D,L				; $8BFD
			LD E,H				; $8BFE
			DEC (IX+$02)				; $8BFF
			LD (IX+$00),E				; $8C02
			LD (IX+$01),D				; $8C05
			POP HL				; $8C08
			POP BC				; $8C09
			RET				; $8C0A

DATA_03:
			defb $A0,$DA,$00,$50,$A0,$45,$00,$50				; $8C0B ...P.E.P
			defb $A0,$45,$A0,$B0,$00,$00,$8A,$A0				; $8C13 .E......
			defb $00,$00,$DA,$20,$00,$00,$14,$20				; $8C1B ... ... 
			defb $00,$00,$00,$00,$00,$00,$00,$10				; $8C23 ........
			defb $00,$00,$00,$50,$00,$A0,$00,$B0				; $8C2B ...P....
			defb $00,$F0,$F0,$20,$10,$50,$20,$00				; $8C33 ... .P .
			defb $10,$10,$00,$00,$50,$20,$00,$00				; $8C3B ....P ..
			defb $50,$A0,$00,$00,$50,$B0,$00,$00				; $8C43 P...P...
			defb $10,$20,$00,$00,$00,$50,$00,$00				; $8C4B . ...P..
			defb $50,$00,$A0,$00,$10,$20,$A0,$00				; $8C53 P.... ..
			defb $00,$A0,$A0,$00,$00,$A0,$A0,$00				; $8C5B ........
			defb $00,$00,$9E,$20,$00,$00,$9E,$00				; $8C63 ... ....
			defb $00,$00,$9E,$00,$00,$00,$DA,$00				; $8C6B ........
			defb $00,$45,$DA,$00,$00,$45,$78,$00				; $8C73 .E...Ex.
			defb $00,$45,$78,$20,$00,$45,$78,$45				; $8C7B .Ex .ExE
			defb $00,$9E,$78,$45,$00,$9E,$F0,$45				; $8C83 ..xE...E
			defb $00,$9E,$F0,$45,$45,$78,$F0,$20				; $8C8B ...EEx. 
			defb $45,$78,$F0,$20,$FF                            ; $8C93 Ex. .

L_8C98:
			PUSH AF				; $8C98
			PUSH BC				; $8C99
			PUSH DE				; $8C9A
			PUSH HL				; $8C9B
			PUSH IX				; $8C9C
			EX AF,AF'				; $8C9E
			LD IX,$8C0B				; $8C9F
L_8CA3:
			LD A,(IX+$00)				; $8CA3
			CP $FF				; $8CA6
			JR Z,L_8CD0				; $8CA8
			LD A,(IX+$02)				; $8CAA
			OR A				; $8CAD
			JR Z,L_8CBA				; $8CAE
			PUSH DE				; $8CB0
			LD DE,$000E				; $8CB1
			ADD IX,DE				; $8CB4
			POP DE				; $8CB6
			JP L_8CA3				; $8CB7

L_8CBA:
			EX AF,AF'				; $8CBA
			LD (IX+$0B),L				; $8CBB
			LD (IX+$0A),A				; $8CBE
			LD (IX+vibrato_depth),H				; $8CC1
			CALL DRAW_SPRITE16X8				; $8CC4
			CALL L_8B71				; $8CC7
			LD A,(IX+$02)				; $8CCA
			LD (IX+vibrato_speed),A				; $8CCD
L_8CD0:
			POP IX				; $8CD0
			POP HL				; $8CD2
			POP DE				; $8CD3
			POP BC				; $8CD4
			POP AF				; $8CD5
			RET					; $8CD6

DRAW_ENEMY_SHOTS:		
			LD IX,$8C0B					; $8CD7
L_8CDB:		LD A,(IX+$00)				; $8CDB
			CP $FF						; $8CDE  ; list end
			RET Z						; $8CE0
			LD A,(IX+$02)				; $8CE1  
			OR A						; $8CE4
			JR NZ,L_8CEF				; $8CE5
LOOP_ENEMY_SHOTS:
			LD DE,$000E					; $8CE7
			ADD IX,DE					; $8CEA
			JP L_8CDB					; $8CEC
L_8CEF:		LD E,(IX+$00)				; $8CEF  ; Xpos
			LD D,(IX+$01)				; $8CF2	 ; Ypos
			LD A,(IX+$0A)				; $8CF5  ; Frame
			CALL DRAW_SPRITE16X8		; $8CF8
			LD B,(IX+$0B)				; $8CFB
L_8CFE:		CALL L_8BCA					; $8CFE
			JR Z,SHOT_HIT_SCENE			; $8D01
			DJNZ L_8CFE					; $8D03
			LD A,(IX+$0D)				; $8D05
	
			SUB (IX+$02)				; $8D08
	
			CP $14						; $8D0B
			JR C,L_8D16					; $8D0D
			CALL GET_ANIM_ADDR_AS_HL	; $8D0F 
			LD A,(HL)					; $8D12 ; Test for Scene tile
			OR A						; $8D13
			JR NZ,SHOT_HIT_SCENE		; $8D14 ; Hit Scene
L_8D16:		LD A,(IX+$0A)				; $8D16
			CALL DRAW_SPRITE16X8		; $8D19
			PUSH DE						; $8D1C
			INC D						; $8D1D
			INC D						; $8D1E
			INC D						; $8D1F
			INC D						; $8D20
			INC E						; $8D21
			INC E						; $8D22
			LD A,$03					; $8D23
			CALL PLAYER_HAZARD_LIST		; $8D25
			POP DE						; $8D28
			LD C,(IX+$0C)				; $8D29
			CALL L_A4AD					; $8D2C
			JP LOOP_ENEMY_SHOTS			; $8D2F
SHOT_HIT_SCENE:
			LD (IX+$02),$00				; $8D32 ; reset shot
			CALL SPARKLE_EFFECT			; $8D36 ; hit effect 
			JP LOOP_ENEMY_SHOTS			; $8D39

STATIC_ENEMY_GUNS:		LD HL,$8E1C				; $8D3C
L_8D3F:		LD A,(HL)				; $8D3F
			CP $FF					; $8D40
			RET Z					; $8D42
			LD E,A					; $8D43
			INC HL					; $8D44
			LD D,(HL)				; $8D45
			INC HL					; $8D46
			PUSH HL						; $8D47
			CALL GET_ANIM_ADDR_AS_HL	; $8D48
			LD A,(HL)					; $8D4B
			OR A					; $8D4C
			JR NZ,L_8D53			; $8D4D
L_8D4F:		POP HL					; $8D4F
			JP L_8D3F				; $8D50
L_8D53:		LD ($8D7A),A			; $8D53
			LD HL,$8D7B				; $8D56
			LD C,A					; $8D59
L_8D5A:		LD A,(HL)				; $8D5A
			CP $FF					; $8D5B
			JP Z,L_8D4F				; $8D5D
			CP C					; $8D60
			JR Z,L_8D6C				; $8D61
			PUSH BC					; $8D63
			LD BC,$0005				; $8D64
			ADD HL,BC				; $8D67
			POP BC					; $8D68
			JP L_8D5A				; $8D69
L_8D6C:		INC HL					; $8D6C
			LD A,(HL)				; $8D6D
			ADD A,E					; $8D6E
			LD E,A					; $8D6F
			INC HL					; $8D70
			LD A,(HL)				; $8D71
			ADD A,D					; $8D72
			LD D,A					; $8D73
			INC HL					; $8D74
			LD A,(HL)				; $8D75
			INC HL					; $8D76
			LD H,(HL)				; $8D77
			LD L,A					; $8D78
			; ============================
			; *** JUMP POINT ***
			JP (HL)					; $8D79	 
			;=============================

			defb $00                                            ; $8D7A .
			defb $27,$00,$00,$95,$8D,$32,$00,$08				; $8D7B '....2..
			defb $95,$8D,$58,$06,$05,$C8,$8D,$94				; $8D83 ..X.....
			defb $FF,$04,$F7,$8D,$98,$07,$04,$0F				; $8D8B ........
			defb $8E,$FF                                        ; $8D93 ..

			LD A,$0C				; $8D95
			CALL GET_RAND_VALUE				; $8D97
			OR A				; $8D9A
			JP NZ,L_8D4F				; $8D9B
			LD BC,(POS_XY)				; $8D9E
			LD A,$1F				; $8DA2
			CALL GET_RAND_VALUE				; $8DA4
			ADD A,C				; $8DA7
			SUB $0C				; $8DA8
			CP $7C				; $8DAA
			JR NC,L_8DAF				; $8DAC
			LD C,A				; $8DAE
L_8DAF:
			LD A,$3F				; $8DAF
			CALL GET_RAND_VALUE				; $8DB1
			ADD A,B				; $8DB4
			SUB $18				; $8DB5
			LD B,A				; $8DB7
			LD A,(START_POS_TABLE_INDEX)				; $8DB8
			ADD A,$02				; $8DBB
			LD L,A				; $8DBD
			LD H,$44				; $8DBE
			LD A,$0A				; $8DC0
			CALL L_8C98				; $8DC2
			JP L_8D4F				; $8DC5

			LD A,$06				; $8DC8
			CALL GET_RAND_VALUE				; $8DCA
			OR A				; $8DCD
			JP NZ,L_8D4F				; $8DCE
			LD BC,(POS_XY)				; $8DD1
			LD A,$1F				; $8DD5
			CALL GET_RAND_VALUE				; $8DD7
			ADD A,C				; $8DDA
			SUB $0C				; $8DDB
			CP $7C				; $8DDD
			JR NC,L_8DE2				; $8DDF
			LD C,A				; $8DE1
L_8DE2:
			LD A,$3F				; $8DE2
			CALL GET_RAND_VALUE				; $8DE4
			ADD A,B				; $8DE7
			SUB $18				; $8DE8
			LD B,A				; $8DEA
			LD L,$02				; $8DEB
			LD H,$42				; $8DED
			LD A,$05				; $8DEF
			CALL L_8C98				; $8DF1
			JP L_8D4F				; $8DF4

			LD A,$16				; $8DF7
			CALL GET_RAND_VALUE				; $8DF9
			OR A				; $8DFC
			JP NZ,L_8D4F				; $8DFD
			LD C,$00				; $8E00
L_8E02:
			LD B,D				; $8E02
			LD H,$42				; $8E03
			LD L,$02				; $8E05
			LD A,$05				; $8E07
			CALL L_8C98				; $8E09
			JP L_8D4F				; $8E0C

			LD A,$16				; $8E0F
			CALL GET_RAND_VALUE				; $8E11
			OR A				; $8E14
			JP NZ,L_8D4F				; $8E15
			LD C,$7B				; $8E18
			JR L_8E02				; $8E1A

			defb $B0,$30,$20,$00,$30,$30,$00                    ; $8E1C
			defb $FC,$22,$03,$02,$FC,$22,$03,$03				; $8E23
			defb $FC,$33,$54,$A9,$FC,$FF 						; $8E2B
		
;-------------------------------------------------------------------------
; Store list of sprites (x, y, frame)
PLAYER_HAZARD_LIST:  						; :)
			PUSH HL                			; 
			LD HL,(SPRITE_LIST_PTR)       	; Load current sprite list 
			LD (HL),A              			; Store X
			INC HL                 			; 
			LD (HL),E              			; Store Y
			INC HL                 			; 
			LD (HL),D          		    	; Store frame index 
			INC HL               		  	; 
			LD (HL),$FF        		    	; end marker
			LD (SPRITE_LIST_PTR),HL     	; Update sprite list pointer to continue writing later
			POP HL                 			; 
			RET               		    	; 
;------------------------------------------------------------------------
			
SPRITE_LIST_PTR:
	        defW $8E44          					; $8E42  (Pointer to the next available sprite slot)
SPRITE_LIST:  
        	; Storage for 50 sprites (3 bytes each) 
			; +1 extra byte for the end marker ($FF)        
       		defW $B956    					    	; $8E44  
			defb $22,$00,$00,$00,$00				;
			defb $45,$03,$FC,$33,$45,$8A,$ED,$11	; 
			defb $45,$00,$A8,$11,$45,$03,$FC,$33	; 
			defb $45,$03,$FC,$33,$45,$8A,$ED,$11	; 
			defb $45,$00,$A8,$11,$45,$03,$FC,$33	; 
			defb $00,$00,$00,$00,$45,$3C,$3C,$30	; 
			defb $45,$3C,$78,$30,$45,$3C,$F0,$30	; 
			defb $45,$3C,$B0,$30,$45,$3C,$B0,$30	; 
			defb $00,$9E,$B0,$20,$00,$9E,$30,$20	; 
			defb $00,$45,$30,$00,$00,$00,$00,$00	; $8E8B
			defb $00,$00,$00,$00,$00,$00,$00,$00	; 
			defb $00,$00,$00,$00,$00,$00,$00,$00	; 
			defb $9E,$78,$F0,$A0,$28,$00,$00,$20	; $8EA3
			defb $28,$78,$20,$20,$28,$B0,$00,$20	; 
			defb $28,$A0,$00,$20,$28,$00,$00,$20	; 
			defb $A0,$78,$20,$20,$A0,$B0,$00,$20	; 
			defb $A0,$A0,$00,$20,$A0,$00,$00,$20	; 
			defb $A0,$78,$20,$20,$A0,$B0,$00,$20	; 
			defb $A0,$A0,$00,$20,$A0,$00,$00,$FF	; $8ED3

PLAYER_COLLISION:		
			LD A,(INPUT_ENABLED)			; $8EDB
			OR A							; $8EDE
			JR NZ,INPUTS_DISABLED			; $8EDF
			LD DE,(POS_XY)					; $8EE1
			; ------------------------------------------
			; New player or just died - we are immune for a little while
			LD HL,(IMMUNE_TIMER)			; $8EE5
			DEC HL							; $8EE8
			LD A,H							; $8EE9
			OR L							; $8EEA  
			JP Z,DRAW_PLAYER				; $8EEB  ; Still immune 
			LD (IMMUNE_TIMER),HL			; $8EEE
			LD A,(SHIELD_AMOUNT)			; $8EF1 
			OR A							; $8EF4
			RET NZ							; $8EF5
			; ------------------------------------------
			; Check player against all enemy items
			LD HL,SPRITE_LIST				; $8EF6
WALK_LIST:	LD A,(HL)						; $8EF9
			CP $FF							; $8EFA
			RET Z							; $8EFC  ; End marker, leave
			CALL L_67B9						; $8EFD
			INC HL							; $8F00
			LD C,(HL)						; $8F01
			INC HL							; $8F02
			LD B,(HL)						; $8F03
			CALL COLLISION_DETECTION		; $8F04
			INC HL							; $8F07
			OR A							; $8F08
			JP Z,WALK_LIST					; $8F09

DRAW_PLAYER:		
			LD A,$64						; $8F0C
			LD (INPUT_ENABLED),A			; $8F0E
			;--------------------------------------------
			LD A,E							; $8F11
			SUB $08							; $8F12  ; X+=8 (16 pixels)
			LD E,A							; $8F14
			;--------------------------------------------
			LD A,D							; $8F15
			SUB $10							; $8F16  ; Y+=16
			LD D,A							; $8F18
			;--------------------------------------------
			LD BC,$2010						; $8F19
			LD A,$14						; $8F1C
			CALL ADD_ITEM_TO_LIST			; $8F1E
			CALL ADD_ITEM_TO_LIST			; $8F21	
			LD DE,(POS_XY)					; $8F24
			LD B,D							; $8F28
			LD C,E							; $8F29
			LD HL,SPRITE24x16_DATA			; $8F2A
			LD (SPRITE_GFX_BASE),HL			; $8F2D
			LD (BACKSHOT_GFX_BASE),HL		; $8F30
			LD (MACE_GFX_BASE),HL			; $8F33
			CALL L_6953						; $8F36
			LD HL,SPRITE24x16_DATA			; $8F39
			LD (SPRITE_GFX_BASE),HL					; $8F3C
			LD (BACKSHOT_GFX_BASE),HL		; $8F3F
			LD (MACE_GFX_BASE),HL			; $8F42
			XOR A							; $8F45
			LD (BACKSHOT_ENABLE),A			; $8F46  ; Remove backshot
			LD (MACE_ENABLE),A				; $8F49  ; Remove mace
			LD HL,LIVES						; $8F4C  ; 
			DEC (HL)						; $8F4F  ; -1 life
			LD E,SFX_EXPLODEB				; $8F50
			CALL PLAY_SFX					; $8F52
			JP L_78C8						; $8F55
INPUTS_DISABLED:		
			DEC A							; $8F58
			LD (INPUT_ENABLED),A			; $8F59
			RET NZ							; $8F5C
			LD A,(LIVES)					; $8F5D   ;load lives
			OR A							; $8F60
			JP Z,L_8F95						; $8F61
			LD HL,$0753						; $8F64
			LD (IMMUNE_TIMER),HL					; $8F67
			LD A,$32						; $8F6A
			LD (SHIELD_AMOUNT),A			; $8F6C
			CALL L_7BFC						; $8F6F
			CALL UPDATE_WEAPONS_DISPLAY		; $8F72
			LD DE,(OLD_POS_XY)				; $8F75
			LD (POS_XY),DE					; $8F79
			LD B,D							; $8F7D
			LD C,E							; $8F7E
			JP L_6953						; $8F7F

			defb $E6                                        ; $8F82
			defb $F1,$C2,$DF,$0A,$0A,$E0,$46,$47			; $8F83 ......FG
			defb $45,$54,$20,$52,$45,$41,$44,$59			; $8F8B ET READY  
			defb $FF 										; $8F93
			
INPUT_ENABLED:	defb $00                					; $8F94  

L_8F95:
			LD E,SFX_GAMEOVER				; $8F95
			CALL PLAY_SFX				; $8F97
			LD HL,FONT_DATA				; $8F9A
			LD (ICON_LD_ADDR+1),HL				; $8F9D
			LD HL,GAME_OVER_TXT				; $8FA0
			LD BC,$0945				; $8FA3
			LD DE,$0E0B				; $8FA6
L_8FA9:		PUSH BC				; $8FA9
			LD A,(HL)				; $8FAA
			CALL ICON16x16				; $8FAB
			INC HL				; $8FAE
			INC E				; $8FAF
			LD BC,$2710				; $8FB0
			CALL WAIT_21xBC				; $8FB3
			POP BC				; $8FB6
			DJNZ L_8FA9				; $8FB7
			CALL INIT_MENU_SCREEN_TABLES				; $8FB9
			LD BC,$0000				; $8FBC
			LD A,$07				; $8FBF
L_8FC1:		CALL WAIT_21xBC				; $8FC1
			DEC A				; $8FC4
			JR NZ,L_8FC1				; $8FC5
			CALL L_954F				; $8FC7
			JP L_9433				; $8FCA

GAME_OVER_TXT:
			defb "GAME OVER"		; $8FCD 

L_8FD6:
			CP $F0				; $8FD6
			RET C				; $8FD8
			CP $F8				; $8FD9
			RET NC				; $8FDB
			PUSH AF				; $8FDC
			PUSH BC				; $8FDD
			PUSH DE				; $8FDE
			PUSH HL				; $8FDF
			PUSH IX				; $8FE0
			LD IX,($9140)				; $8FE2
			LD HL,SPRITE24x16_DATA				; $8FE6
			LD (IX+$03),L				; $8FE9
			LD (IX+$04),H				; $8FEC
			LD (IX+$08),L				; $8FEF
			LD (IX+$09),H				; $8FF2
			LD (IX+$00),E				; $8FF5
			LD (IX+$01),D				; $8FF8
			LD (IX+$02),$3E				; $8FFB
			SUB $F0				; $8FFF
			ADD A,A				; $9001
			LD L,A				; $9002
			LD H,$00				; $9003
			LD BC,$9030				; $9005
			ADD HL,BC				; $9008
			LD A,(HL)				; $9009
			ADD A,D				; $900A
			LD D,A				; $900B
			INC HL				; $900C
			LD A,(HL)				; $900D
			LD (IX+$0A),A				; $900E
			LD (IX+$05),E				; $9011
			LD (IX+$06),D				; $9014
			LD A,$42				; $9017
			LD (IX+$07),A				; $9019
			LD DE,$000B				; $901C
			ADD IX,DE				; $901F
			LD (IX+$00),$FF				; $9021
			LD ($9140),IX				; $9025
			POP IX				; $9029
			POP HL				; $902B
			POP DE				; $902C
			POP BC				; $902D
			POP AF				; $902E
			RET				; $902F

			defb $3C,$FF,$37                                    ; $9030 <.7
			defb $FF,$32,$FF,$2D,$FF,$3C,$01,$37				; $9033 .2.-.<.7
			defb $01,$32,$01,$2D,$01                            ; $903B .2.-.

LANE_GUARDIANS:		
			LD IX,$9142				; $9040
L_9044:		LD A,(IX+$00)				; $9044
			CP $FF				; $9047
			RET Z				; $9049
			LD A,(IX+$0A)				; $904A
			CP $FF				; $904D
			JP Z,L_905D				; $904F
			JP L_90CA				; $9052

L_9055:		LD DE,$000B				; $9055
			ADD IX,DE				; $9058
			JP L_9044				; $905A

L_905D:		LD E,(IX+$00)				; $905D
			LD D,(IX+$01)				; $9060
			LD B,D				; $9063
			LD C,E				; $9064
			CALL CHECK_SCENE_UP				; $9065
			CALL NZ,L_9137				; $9068
			LD A,(IX+$0A)				; $906B
			ADD A,D				; $906E
			LD D,A				; $906F
			LD (IX+$01),D				; $9070
			LD A,(GAME_COUNTER_8BIT)				; $9073
			AND $03				; $9076
			ADD A,(IX+$02)				; $9078
			LD L,(IX+$03)				; $907B
			LD H,(IX+$04)				; $907E
			CALL DRAW4X4SPRITE				; $9081
			LD (IX+$03),L				; $9084
			LD (IX+$04),H				; $9087
			LD A,$01				; $908A
			CALL PLAYER_HAZARD_LIST				; $908C
			LD BC,$0747				; $908F
			CALL L_A47B				; $9092
			LD E,(IX+$05)				; $9095
			LD D,(IX+$06)				; $9098
			LD B,D				; $909B
			LD C,E				; $909C
			LD A,(IX+$0A)				; $909D
			ADD A,D				; $90A0
			LD D,A				; $90A1
			LD (IX+$06),D				; $90A2
			LD A,(GAME_COUNTER_8BIT)				; $90A5
			AND $03				; $90A8
			ADD A,(IX+$07)				; $90AA
			LD L,(IX+$08)				; $90AD
			LD H,(IX+$09)				; $90B0
			CALL DRAW4X4SPRITE				; $90B3
			LD (IX+$08),L				; $90B6
			LD (IX+$09),H				; $90B9
			LD A,$01				; $90BC
			CALL PLAYER_HAZARD_LIST				; $90BE
			LD BC,$0747				; $90C1
			CALL L_A47B				; $90C4
			JP L_9055				; $90C7

L_90CA:		LD E,(IX+$05)				; $90CA
			LD D,(IX+$06)				; $90CD
			LD B,D				; $90D0
			LD C,E				; $90D1
			CALL CHECK_SCENE_DOWN				; $90D2
			CALL NZ,L_9137				; $90D5
			LD A,(IX+$0A)				; $90D8
			ADD A,D				; $90DB
			LD D,A				; $90DC
			LD (IX+$06),D				; $90DD
			LD A,(GAME_COUNTER_8BIT)				; $90E0
			AND $03				; $90E3
			ADD A,(IX+$07)				; $90E5
			LD L,(IX+$08)				; $90E8
			LD H,(IX+$09)				; $90EB
			CALL DRAW4X4SPRITE				; $90EE
			LD (IX+$08),L				; $90F1
			LD (IX+$09),H				; $90F4
			LD A,$01				; $90F7
			CALL PLAYER_HAZARD_LIST				; $90F9
			LD BC,$0747				; $90FC
			CALL L_A47B				; $90FF
			LD E,(IX+$00)				; $9102
			LD D,(IX+$01)				; $9105
			LD B,D				; $9108
			LD C,E				; $9109
			LD A,(IX+$0A)				; $910A
			ADD A,D				; $910D
			LD D,A				; $910E
			LD (IX+$01),D				; $910F
			LD A,(GAME_COUNTER_8BIT)				; $9112
			AND $03				; $9115
			ADD A,(IX+$02)				; $9117
			LD L,(IX+$03)				; $911A
			LD H,(IX+$04)				; $911D
			CALL DRAW4X4SPRITE				; $9120
			LD (IX+$03),L				; $9123
			LD (IX+$04),H				; $9126
			LD A,$01				; $9129
			CALL PLAYER_HAZARD_LIST				; $912B
			LD BC,$0747				; $912E
			CALL L_A47B				; $9131
			JP L_9055				; $9134

L_9137:
			LD A,(IX+$0A)				; $9137
			NEG				; $913A
			LD (IX+$0A),A				; $913C
			RET				; $913F

			defb $42,$91,$00                                    ; $9140 B..
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $9143 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $914B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $9153 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $915B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $9163 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $916B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $9173 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $917B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $9183 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $918B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $9193 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $919B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $91A3 ........
			defb $00,$00,$00,$00,$00,$FF                        ; $91AB ......

L_91B1:
			CP $F8				; $91B1
			RET C				; $91B3
			PUSH AF				; $91B4
			PUSH BC				; $91B5
			PUSH DE				; $91B6
			PUSH HL				; $91B7
			PUSH IX				; $91B8
			LD IX,($9265)				; $91BA
			LD HL,SPRITE24x16_DATA				; $91BE
			LD (IX+$05),L				; $91C1
			LD (IX+$06),H				; $91C4
			LD HL,$91FE				; $91C7
			SUB $F8				; $91CA
			ADD A,A				; $91CC
			ADD A,A				; $91CD
			LD L,A				; $91CE
			LD H,$00				; $91CF
			LD BC,$91FE				; $91D1
			ADD HL,BC				; $91D4
			LD A,(HL)				; $91D5
			ADD A,E				; $91D6
			LD (IX+$00),A				; $91D7
			INC HL				; $91DA
			LD A,(HL)				; $91DB
			ADD A,D				; $91DC
			LD (IX+$01),A				; $91DD
			INC HL				; $91E0
			LD A,(HL)				; $91E1
			LD (IX+$02),A				; $91E2
			INC HL				; $91E5
			LD A,(HL)				; $91E6
			LD (IX+$03),A				; $91E7
			LD DE,$0007				; $91EA
			ADD IX,DE				; $91ED
			LD (IX+$00),$FF				; $91EF
			LD ($9265),IX				; $91F3
			POP IX				; $91F7
			POP HL				; $91F9
			POP DE				; $91FA
			POP BC				; $91FB
			POP AF				; $91FC
			RET				; $91FD

			defb $00,$04,$01,$01,$02                            ; $91FE .....
			defb $00,$02,$01,$00,$FC,$03,$01,$FE				; $9203 ........
			defb $00,$04,$01,$00,$04,$01,$02,$02				; $920B ........
			defb $00,$02,$02,$00,$FC,$03,$02,$FE				; $9213 ........
			defb $00,$04,$02,$20,$45,$78,$B0,$20				; $921B ... Ex. 
			defb $8A,$00,$00,$10,$CF,$3C,$F0,$30				; $9223 .....<.0
			defb $CF,$3C,$F0,$30,$00,$00,$00,$00				; $922B .<.0....
			defb $45,$78,$B0,$20,$45,$78,$B0,$20				; $9233 Ex. Ex. 
			defb $45,$78,$B0,$20,$45,$78,$B0,$20				; $923B Ex. Ex. 
			defb $45,$78,$B0,$20,$45,$78,$B0,$20				; $9243 Ex. Ex. 
			defb $45,$78,$B0,$20,$45,$78,$B0,$20				; $924B Ex. Ex. 
			defb $45,$78,$B0,$20,$45,$78,$B0,$20				; $9253 Ex. Ex. 
			defb $45,$78,$B0,$20,$45,$78,$B0,$20				; $925B Ex. Ex. 
			defb $45,$FF,$00,$00                                ; $9263 E...

SNAKES:		LD IX,$921E				; $9267
L_926B:		LD A,(IX+$00)				; $926B
			CP $FF				; $926E
			RET Z				; $9270
			LD A,(IX+$02)				; $9271
			OR A				; $9274
			JR NZ,L_927F				; $9275
L_9277:		LD BC,$0007				; $9277
			ADD IX,BC				; $927A
			JP L_926B				; $927C
L_927F:		LD E,(IX+$00)				; $927F
			LD D,(IX+$01)				; $9282
			LD A,(IX+$04)				; $9285
			OR A				; $9288
			JP NZ,L_9376				; $9289
			LD A,(IX+$02)				; $928C
			CP $01				; $928F
			JR Z,L_92B2				; $9291
			CP $02				; $9293
			JR Z,L_92C9				; $9295
			CP $03				; $9297
			JR Z,L_92E0				; $9299
			CALL L_9421				; $929B
			JR Z,L_92A5				; $929E
			LD A,$03				; $92A0
			JP L_92F7				; $92A2
L_92A5:		CALL L_93FC				; $92A5
			LD A,$00				; $92A8
			JP NZ,L_92F7				; $92AA
			LD A,$01				; $92AD
			JP L_92F7				; $92AF
L_92B2:		CALL L_93FC				; $92B2
			JR Z,L_92BC				; $92B5
			LD A,$04				; $92B7
			JP L_92F7				; $92B9
L_92BC:		CALL L_940F				; $92BC
			LD A,$00				; $92BF
			JP NZ,L_92F7				; $92C1
			LD A,$02				; $92C4
			JP L_92F7				; $92C6
L_92C9:		CALL L_940F				; $92C9
			JR Z,L_92D3				; $92CC
			LD A,$01				; $92CE
			JP L_92F7				; $92D0
L_92D3:		CALL L_93EA				; $92D3
			LD A,$00				; $92D6
			JP NZ,L_92F7				; $92D8
			LD A,$03				; $92DB
			JP L_92F7				; $92DD
L_92E0:		CALL L_93EA				; $92E0
			JR Z,L_92EA				; $92E3
			LD A,$02				; $92E5
			JP L_92F7				; $92E7
L_92EA:		CALL L_9421				; $92EA
			LD A,$00				; $92ED
			JP NZ,L_92F7				; $92EF
			LD A,$04				; $92F2
			JP L_92F7				; $92F4
L_92F7:		LD H,A				; $92F7
			LD L,(IX+$02)				; $92F8
			LD B,(IX+$03)				; $92FB
			OR A				; $92FE
			JR Z,L_9304				; $92FF
			LD (IX+$02),A				; $9301
L_9304:		LD A,(IX+$02)				; $9304
			CP $01				; $9307
			JR NZ,L_9312				; $9309
			LD A,B				; $930B
			NEG				; $930C
			ADD A,E				; $930E
			LD E,A				; $930F
			JR L_932B				; $9310
L_9312:		CP $02				; $9312
			JR NZ,L_931C				; $9314
			LD A,B				; $9316
			ADD A,A				; $9317
			ADD A,D				; $9318
			LD D,A				; $9319
			JR L_932B				; $931A
L_931C:		CP $03				; $931C
			JR NZ,L_9325				; $931E
			LD A,B				; $9320
			ADD A,E				; $9321
			LD E,A				; $9322
			JR L_932B				; $9323
L_9325:		LD A,B				; $9325
			NEG				; $9326
			ADD A,A				; $9328
			ADD A,D				; $9329
			LD D,A				; $932A
L_932B:		LD A,(IX+$04)				; $932B
			OR A				; $932E
			JR NZ,L_9349				; $932F
			LD A,H				; $9331
			OR A				; $9332
			JR Z,L_9349				; $9333
			CALL L_93D0				; $9335
			JR NZ,L_9349				; $9338
			LD (IX+$04),$01				; $933A
			LD (IX+$02),L				; $933E
			LD E,(IX+$00)				; $9341
			LD D,(IX+$01)				; $9344
			JR L_9376				; $9347
L_9349:		LD C,(IX+$00)				; $9349
			LD B,(IX+$01)				; $934C
			LD (IX+$00),E				; $934F
			LD (IX+$01),D				; $9352
			LD L,(IX+$05)				; $9355
			LD H,(IX+$06)				; $9358
			LD A,(IX+$02)				; $935B
			ADD A,$02				; $935E
			CALL SPRITE_24x16				; $9360
			LD A,$01				; $9363
			CALL PLAYER_HAZARD_LIST				; $9365
			LD (IX+$05),L				; $9368
			LD (IX+$06),H				; $936B
			LD C,$47				; $936E
			CALL SET_SCRN_ATTR				; $9370
			JP L_9277				; $9373
L_9376:		LD A,(IX+$02)				; $9376
			CP $01				; $9379
			JP Z,L_939A				; $937B
			CP $02				; $937E
			JP Z,L_93AC				; $9380
			CP $03				; $9383
			JP Z,L_93BE				; $9385
			CALL L_9421				; $9388
			LD B,A				; $938B
			CALL L_93FC				; $938C
			OR B				; $938F
			JP Z,L_92F7				; $9390
			LD (IX+$04),$00				; $9393
			JP L_927F				; $9397
L_939A:		CALL L_93FC				; $939A
			LD B,A				; $939D
			CALL L_940F				; $939E
			OR B				; $93A1
			JP Z,L_92F7				; $93A2
			LD (IX+$04),$00				; $93A5
			JP L_927F				; $93A9
L_93AC:		CALL L_940F				; $93AC
			LD B,A				; $93AF
			CALL L_93EA				; $93B0
			OR B				; $93B3
			JP Z,L_92F7				; $93B4
			LD (IX+$04),$00				; $93B7
			JP L_927F				; $93BB
L_93BE:		CALL L_93EA				; $93BE
			LD B,A				; $93C1
			CALL L_9421				; $93C2
			OR B				; $93C5
			JP Z,L_92F7				; $93C6
			LD (IX+$04),$00				; $93C9
			JP L_927F				; $93CD
L_93D0:		PUSH BC				; $93D0
			PUSH HL				; $93D1
			CALL L_93FC				; $93D2
			LD H,A				; $93D5
			CALL L_93EA				; $93D6
			LD L,A				; $93D9
			CALL L_9421				; $93DA
			LD B,A				; $93DD
			CALL L_940F				; $93DE
			LD C,A				; $93E1
			XOR A				; $93E2
			OR H				; $93E3
			OR L				; $93E4
			OR B				; $93E5
			OR C				; $93E6
			POP HL				; $93E7
			POP BC				; $93E8
			RET				; $93E9
L_93EA:		PUSH DE				; $93EA
			LD A,E				; $93EB
			CP $78				; $93EC
			JR NC,L_93F9				; $93EE
			INC E				; $93F0
			INC E				; $93F1
			INC D				; $93F2
			INC D				; $93F3
			INC D				; $93F4
			INC D				; $93F5
			CALL L_8115				; $93F6
L_93F9:		OR A				; $93F9
			POP DE				; $93FA
			RET				; $93FB
L_93FC:		PUSH DE				; $93FC
			LD A,E				; $93FD
			OR A				; $93FE
			LD A,$01				; $93FF
			JR Z,L_940C				; $9401
			INC E				; $9403
			INC E				; $9404
			INC D				; $9405
			INC D				; $9406
			INC D				; $9407
			INC D				; $9408
			CALL L_8139				; $9409
L_940C:		OR A				; $940C
			POP DE				; $940D
			RET				; $940E
L_940F:		PUSH DE				; $940F
			LD A,D				; $9410
			CP $B0				; $9411
			JR NC,L_941E				; $9413
			INC E				; $9415
			INC E				; $9416
			INC D				; $9417
			INC D				; $9418
			INC D				; $9419
			INC D				; $941A
			CALL L_815D				; $941B
L_941E:		OR A				; $941E
			POP DE				; $941F
			RET				; $9420
L_9421:		PUSH DE				; $9421
			LD A,D				; $9422
			CP $20				; $9423
			JR C,L_9430				; $9425
			INC E				; $9427
			INC E				; $9428
			INC D				; $9429
			INC D				; $942A
			INC D				; $942B
			INC D				; $942C
			CALL L_8181				; $942D
L_9430:		OR A				; $9430
			POP DE				; $9431
			RET				; $9432

L_9433:		CALL CLR_SCREEN				; $9433
			CALL DRAW_MENU_BORDERS				; $9436
			LD HL,$947C				; $9439
			CALL DRAW_LIST				; $943C
			LD HL,FONT_DATA			; $943F
			LD (ICON_LD_ADDR+1),HL				; $9442
			LD HL,$949C				; $9445
			LD B,$0A				; $9448
			LD C,$47				; $944A
			LD DE,$0B08				; $944C
L_944F:		PUSH BC				; $944F
			LD B,$10				; $9450
L_9452:		LD A,(HL)				; $9452
			CALL ICON16x16				; $9453
			INC HL				; $9456
			INC E				; $9457
			DJNZ L_9452				; $9458
			POP BC				; $945A
			INC D				; $945B
			LD E,$08				; $945C
			DJNZ L_944F				; $945E
L_9460:
			CALL ANY_KEY_DOWN				; $9460
			CALL NZ,SCROLL_BORDER				; $9463
			JP NZ,L_9460				; $9466
			LD BC,$00AF				; $9469
L_946C:
			PUSH BC				; $946C
			CALL SCROLL_BORDER				; $946D
			CALL GET_KEY				; $9470
			OR A				; $9473
			POP BC				; $9474
			RET NZ				; $9475
			DEC BC				; $9476
			LD A,B				; $9477
			OR C				; $9478
			RET Z				; $9479
			JR L_946C				; $947A

HI_SCORE_TXT:
			defb SET_SOURCE_DATA         					    ; $947C
			defw FONT_DATA	
			defb SET_POS,$09,$05
			defb GLOBAL_COL  
			defb $44,$43,$59,$42,$45,$52,$4E,$4F				; $9483 DCYBERNO
			defb $49,$44,$20,$48,$41,$4C,$4C,$20				; $948B ID HALL 
			defb $4F,$46,$20,$46,$41,$4D,$45,$FF				; $9493 OF FAME.
			defb $00,$52,$41,$46,$46,$41,$45,$4C				; $949B .RAFFAEL
			defb $45,$20,$20,$30,$31,$35,$30,$30				; $94A3 E  01500
			defb $30,$53,$55,$52,$59,$41,$4E,$49				; $94AB 0SURYANI
			defb $20,$20,$20,$30,$31,$30,$30,$30				; $94B3    01000
			defb $30,$42,$4F,$4E,$4E,$49,$45,$20				; $94BB 0BONNIE 
			defb $20,$20,$20,$30,$30,$35,$30,$30				; $94C3    00500
			defb $30,$51,$55,$45,$45,$4E,$20,$20				; $94CB 0QUEEN  
			defb $20,$20,$20,$30,$30,$32,$35,$30				; $94D3    00250
			defb $30,$4E,$49,$43,$4B,$20,$42,$4F				; $94DB 0NICK BO
			defb $59,$20,$20,$30,$30,$31,$30,$30				; $94E3 Y  00100
			defb $30,$53,$41,$4E,$44,$52,$41,$20				; $94EB 0SANDRA 
			defb $20,$20,$20,$30,$30,$31,$30,$30				; $94F3    00100
			defb $30,$44,$41,$56,$49,$44,$2E,$50				; $94FB 0DAVID.P
			defb $2E,$20,$20,$30,$30,$31,$30,$30				; $9503 .  00100
			defb $30,$53,$48,$41,$52,$4B,$59,$20				; $950B 0SHARKY 
			defb $20,$20,$20,$30,$30,$31,$30,$30				; $9513    00100
			defb $30,$45,$4D,$49,$4C,$59,$20,$20				; $951B 0EMILY  
			defb $20,$20,$20,$30,$30,$31,$30,$30				; $9523    00100
			defb $30,$4F,$4E,$49,$4F,$4E,$20,$20				; $952B 0ONION  
			defb $20,$20,$20,$30,$30,$31,$30,$30				; $9533    00100
			defb $30,$FF,$01,$A8,$00,$8B,$01,$A8				; $953B 0.......
			defb $45,$01,$01,$A8,$45,$02,$A8,$A8				; $9543 E...E...
			defb $45,$02,$00,$00                                ; $954B E...

L_954F:		LD IX,$949C				; $954F
L_9553:		BIT 7,(IX+$00)				; $9553
			JP NZ,L_9648				; $9557
			PUSH IX				; $955A
			LD DE,$000A				; $955C
			ADD IX,DE				; $955F
			LD HL,$78F9				; $9561
			LD B,$06				; $9564
L_9566:		LD A,(IX+$00)				; $9566
			CP (HL)				; $9569
			JP Z,L_9637				; $956A
			JP NC,L_963E				; $956D
			POP HL				; $9570
			PUSH HL				; $9571
			LD A,$FF				; $9572
			LD BC,$03E8				; $9574
			CPIR				; $9577
			LD HL,$03E8				; $9579
			AND A				; $957C
			SBC HL,BC				; $957D
			PUSH HL				; $957F
			POP BC				; $9580
			LD DE,$954B				; $9581
			LD HL,$953B				; $9584
			LDDR				; $9587
			LD A,$FF				; $9589
			LD ($953C),A				; $958B
			POP HL				; $958E
			PUSH HL				; $958F
			LD DE,$000A				; $9590
			ADD HL,DE				; $9593
			EX DE,HL				; $9594
			LD HL,$78F9				; $9595
			LD BC,$0006				; $9598
			LDIR				; $959B
			CALL CLR_SCREEN				; $959D
			LD E,SFX_HISCORE				; $95A0
			CALL PLAY_SFX				; $95A2
			LD HL,$96D0				; $95A5
			LD DE,$96D1				; $95A8
			LD BC,$0007				; $95AB
			LD (HL),$20				; $95AE
			LDIR				; $95B0
			CALL DRAW_MENU_BORDERS				; $95B2
			LD HL,$9664				; $95B5
			CALL DRAW_LIST				; $95B8
			LD DE,$0F0C				; $95BB
			LD HL,$96D0				; $95BE
L_95C1:		LD C,$44				; $95C1
			LD A,$3F				; $95C3
			CALL ICON16x16				; $95C5
L_95C8:		LD BC,$03E8				; $95C8
			CALL WAIT_21xBC				; $95CB
L_95CE:		CALL ANY_KEY_DOWN				; $95CE
			CALL NZ,SCROLL_BORDER				; $95D1
			JR NZ,L_95CE				; $95D4
			PUSH DE				; $95D6
L_95D7:		CALL GET_KEY				; $95D7
			OR A				; $95DA
			CALL Z,SCROLL_BORDER				; $95DB
			JR Z,L_95D7				; $95DE
			POP DE				; $95E0
			CP $0D				; $95E1
			JR Z,L_961F				; $95E3
			CP $01				; $95E5
			JR Z,L_95F0				; $95E7
			CP $02				; $95E9
			JR NZ,L_9610				; $95EB
			PUSH DE				; $95ED
			JR L_95D7				; $95EE
L_95F0:		LD A,E				; $95F0
			CP $13				; $95F1
			JR NZ,L_95FE				; $95F3
			LD A,(HL)				; $95F5
			CP $20				; $95F6
			JR Z,L_95FE				; $95F8
			LD (HL),$20				; $95FA
			JR L_95C1				; $95FC
L_95FE:		LD A,E				; $95FE
			CP $0C				; $95FF
			JR Z,L_95C1				; $9601
			LD A,$2D				; $9603
			LD C,$47				; $9605
			CALL ICON16x16				; $9607
			DEC HL				; $960A
			LD (HL),$20				; $960B
			DEC E				; $960D
			JR L_95C1				; $960E
L_9610:		LD (HL),A				; $9610
			LD C,$46				; $9611
			CALL ICON16x16				; $9613
			LD A,E				; $9616
			CP $13				; $9617
			JR Z,L_95C8				; $9619
			INC HL				; $961B
			INC E				; $961C
			JR L_95C1				; $961D
L_961F:		POP DE				; $961F
			LD HL,$96D0				; $9620
			LD BC,$0008				; $9623
			LDIR				; $9626
L_9628:		CALL ANY_KEY_DOWN				; $9628
			CALL NZ,SCROLL_BORDER				; $962B
			JP NZ,L_9628				; $962E
			CALL L_9433				; $9631
			JP MAIN				; $9634
L_9637:		INC HL				; $9637
			INC IX				; $9638
			DEC B				; $963A
			JP NZ,L_9566				; $963B
L_963E:		POP IX				; $963E
			LD DE,$0010				; $9640
			ADD IX,DE				; $9643
			JP L_9553				; $9645
L_9648:		CALL ANY_KEY_DOWN				; $9648
			JP NZ,L_9648				; $964B
			LD BC,$0352				; $964E
L_9651:		HALT				; $9651
			PUSH BC				; $9652
			CALL GET_KEY				; $9653
			POP BC				; $9656
			OR A				; $9657
			JP NZ,MAIN				; $9658
			DEC BC				; $965B
			LD A,B				; $965C
			OR C				; $965D
			JP NZ,L_9651				; $965E
			JP MAIN				; $9661

			defb $EB,$00,$DF,$09,$08,$E0,$46                    ; $9664 ......F
			defb $E6,$F1,$C2,$43,$4F,$4E,$47,$52				; $966B ...CONGR
			defb $41,$54,$55,$4C,$41,$54,$49,$4F				; $9673 ATULATIO
			defb $4E,$53,$21,$7A,$ED,$DB,$50,$4C				; $967B NS!z..PL
			defb $45,$41,$53,$45,$20,$45,$4E,$54				; $9683 EASE ENT
			defb $45,$52,$20,$59,$4F,$55,$52,$20				; $968B ER YOUR 
			defb $4E,$41,$4D,$45,$DF,$0F,$0C,$DE				; $9693 NAME....
			defb $2D,$2D,$2D,$2D,$2D,$2D,$2D,$2D				; $969B --------
			defb $7B,$F2,$DC,$50,$52,$45,$53,$53				; $96A3 {..PRESS
			defb $20,$43,$41,$50,$53,$20,$54,$4F				; $96AB  CAPS TO
			defb $20,$44,$45,$4C,$45,$54,$45,$7A				; $96B3  DELETEz
			defb $ED,$DD,$50,$52,$45,$53,$53,$20				; $96BB ..PRESS 
			defb $45,$4E,$54,$45,$52,$20,$54,$4F				; $96C3 ENTER TO
			defb $20,$45,$4E,$44,$FF,$20,$20,$20				; $96CB  END.   
			defb $20,$20,$20,$20,$20                            ; $96D3

L_96D8:		LD IX,$979F					; $96D8
			LD H,A						; $96DC
L_96DD:		LD A,(IX+$00)				; $96DD
			CP $FF						; $96E0
			RET Z						; $96E2
			LD A,(IX+$02)				; $96E3
			OR A						; $96E6
			JR Z,L_96F3					; $96E7
			PUSH BC						; $96E9
			LD BC,$0008					; $96EA
			ADD IX,BC					; $96ED
			POP BC						; $96EF
			JP L_96DD					; $96F0
L_96F3:		LD (IX+$00),E				; $96F3
			LD (IX+$01),D				; $96F6
			LD (IX+$02),H				; $96F9
			LD DE,SPRITE24x16_DATA		; $96FC
			LD (IX+$03),E				; $96FF
			LD (IX+$04),D				; $9702
			LD (IX+$05),L				; $9705
			LD (IX+$06),C				; $9708
			LD (IX+$07),B				; $970B
			RET							; $970E

DO_ROCKET:	LD IX,$979F					; $970F
L_9713:		LD A,(IX+$00)				; $9713
			CP $FF						; $9716
			RET Z						; $9718
			LD A,(IX+$02)				; $9719
			OR A						; $971C
			JP NZ,L_9728				; $971D
ROCKET_LOOP:		LD BC,$0008			; $9720
			ADD IX,BC					; $9723
			JP L_9713					; $9725
L_9728:		LD E,(IX+$00)				; $9728
			LD D,(IX+$01)				; $972B
			LD B,D						; $972E
			LD C,E						; $972F
			LD L,(IX+$03)				; $9730
			LD H,(IX+$04)				; $9733
			LD A,(IX+$05)				; $9736
			AND $80						; $9739
			JR NZ,L_974C				; $973B
			LD A,D						; $973D
			CP $B0						; $973E
			JP Z,ROCKET_NO_HIT			; $9740
			CALL CHECK_SCENE_DOWN		; $9743
			JP NZ,ROCKET_NO_HIT			; $9746
			JP L_9758					; $9749
L_974C:		LD A,D						; $974C
			CP $20						; $974D
			JP Z,ROCKET_NO_HIT			; $974F
			CALL CHECK_SCENE_UP			; $9752
			JP NZ,ROCKET_NO_HIT			; $9755
L_9758:		LD A,(IX+$05)				; $9758
			ADD A,D						; $975B
			LD D,A						; $975C
			LD (IX+$01),D				; $975D
			LD A,(IX+$02)				; $9760
			CALL DRAW4X4SPRITE			; $9763
			PUSH DE						; $9766
			LD A,E						; $9767
			ADD A,$02					; $9768
			LD E,A						; $976A
			LD A,D						; $976B
			ADD A,$04					; $976C
			LD D,A						; $976E
			LD A,$02					; $976F
			CALL PLAYER_HAZARD_LIST		; $9771  ;  dangerous object added 
			POP DE						; $9774
			LD (IX+$03),L				; $9775
			LD (IX+$04),H				; $9778
			LD C,(IX+$06)				; $977B
			LD B,(IX+$07)				; $977E
			CALL L_A47B					; $9781
			JP ROCKET_LOOP				; $9784
ROCKET_NO_HIT:		
			XOR A						; $9787
			LD (IX+$02),A				; $9788
			CALL DRAW4X4SPRITE			; $978B   ; removes last draw rocket
			DEC E						; $978E
			DEC E						; $978F
			LD A,D						; $9790
			SUB $04						; $9791
			LD D,A						; $9793
			LD BC,$180C					; $9794
			LD A,$0F					; $9797
			CALL ADD_ITEM_TO_LIST		; $9799  ; Add scattered explosions
			JP ROCKET_LOOP				; $979C

DATA_05:
			defb $00,$00,$00,$00                                ; $979F ....
			defb $CF,$CF,$45,$CF,$CF,$CF,$45,$33				; $97A3 ..E...E3
			defb $CF,$8B,$45,$33,$CF,$8B,$45,$8A				; $97AB ..E3..E.
			defb $CF,$8B,$45,$00,$CF							; $97B3 ..E...E3
			defb $8B											; $97B8	
			defb $45,$33										; $97B9
			defb $CF											; 
			defb $03,$45,$33,$45,$03,$45,$33					; $97BC
			defb $01,$56,$45,$33,$01,$56,$45,$33				; $97C3 .VE3.VE3
			defb $00,$FC,$45,$33,$00,$FC,$45,$33				; $97CB ..E3..E3
			defb $00,$54,$45,$8A,$00,$54,$45,$00				; $97D3 .TE..TE.
			defb $00,$00,$45,$33,$00,$00,$00,$33				; $97DB ..E3...3
			defb $CF,$8A,$CF,$CF,$33,$22,$9B,$33				; $97E3 ....3".3
			defb $33,$22,$9B,$33,$FF                            ; $97EB 3".3.

PROXIMITY_ROCKET
			LD HL,$9879				; $97F0
L_97F3:
			LD A,(HL)				; $97F3
			CP $FF				; $97F4
			RET Z				; $97F6
			LD E,A				; $97F7
			INC HL				; $97F8
			LD D,(HL)				; $97F9
			INC HL				; $97FA
			PUSH HL				; $97FB
			CALL GET_ANIM_ADDR_AS_HL				; $97FC
			LD A,(HL)				; $97FF
			OR A				; $9800
			JR NZ,L_9807				; $9801
L_9803:		POP HL				; $9803
			JP L_97F3				; $9804
L_9807:		LD ($9825),A				; $9807
			LD BC,$0005				; $980A
			LD HL,$9826				; $980D
L_9810:		CP (HL)				; $9810
			JR Z,L_9817				; $9811
			ADD HL,BC				; $9813
			JP L_9810				; $9814
L_9817:		INC HL				; $9817
			LD A,(HL)				; $9818
			ADD A,E				; $9819
			LD E,A				; $981A
			INC HL				; $981B
			LD A,(HL)				; $981C
			ADD A,D				; $981D
			LD D,A				; $981E
			INC HL				; $981F
			LD A,(HL)				; $9820
			INC HL				; $9821
			LD H,(HL)				; $9822
			LD L,A				; $9823
			JP (HL)				; $9824

			defb $00,$46,$00,$00,$31,$98                        ; $9825 .F..1.
			defb $47,$00,$00,$55,$98,$FF                        ; $982B G..U..

			LD A,(POS_XY)				; $9831
			CP E				; $9834
			JP NZ,L_9803				; $9835
			LD A,($9825)				; $9838
			LD HL,SPRITE24x16_DATA				; $983B
			CALL DRAW4X4SPRITE				; $983E
			CALL L_6DE0				; $9841
			CALL L_988E				; $9844
			LD L,$FC				; $9847
			LD BC,$4547				; $9849
			LD A,($9825)				; $984C
			CALL L_96D8				; $984F
			JP L_9803				; $9852

			LD A,(POS_XY)				; $9855
			CP E				; $9858
			JP NZ,L_9803				; $9859
			LD A,($9825)				; $985C
			LD HL,SPRITE24x16_DATA				; $985F
			CALL DRAW4X4SPRITE				; $9862
			CALL L_6DE0				; $9865
			CALL L_988E				; $9868
			LD L,$04				; $986B
			LD BC,$4547				; $986D
			LD A,($9825)				; $9870
			CALL L_96D8				; $9873
			JP L_9803				; $9876


			defb $9B,$33                                        ; $9879 .3
			defb $33,$22,$9B,$33,$67,$00,$9B,$22				; $987B 3".3g.."
			defb $22,$00,$9B,$22,$33,$22,$9B,$22				; $9883 ".."3"."
			defb $33,$22,$FF                                    ; $988B 3".

L_988E:		PUSH AF				; $988E
			PUSH BC				; $988F
			PUSH IX				; $9890
			PUSH HL				; $9892
			LD BC,$0008				; $9893
			LD IX,DATA_08				; $9896
L_989A:		LD L,(IX+$00)				; $989A
			LD H,(IX+$01)				; $989D
			AND A				; $98A0
			SBC HL,DE				; $98A1
			JR Z,L_98AA				; $98A3
			ADD IX,BC				; $98A5
			JP L_989A				; $98A7

L_98AA:		LD (IX+$04),$00				; $98AA
			POP HL				; $98AE
			POP IX				; $98AF
			POP BC				; $98B1
			POP AF				; $98B2
			RET				; $98B3

DRAW_ENEMY_SHIPS:		
			LD IX,$99B3				; $98B4
L_98B8:		LD A,(IX+$00)				; $98B8
			CP $FF				; $98BB
			RET Z				; $98BD
			OR A				; $98BE
			JP Z,L_999B				; $98BF
			LD E,(IX+$01)				; $98C2
			LD D,(IX+$02)				; $98C5
			PUSH DE				; $98C8
			LD C,(IX+$05)				; $98C9
			LD B,(IX+$06)				; $98CC
			LD A,(IX+$07)				; $98CF
			OR A				; $98D2
			JR NZ,L_98F5				; $98D3
L_98D5:		LD A,(BC)				; $98D5
			CP $E2				; $98D6
			JP Z,L_9902				; $98D8
			CP $E1				; $98DB
			JP Z,L_9911				; $98DD
			CP $E0				; $98E0
			JP Z,L_9920				; $98E2
			ADD A,E				; $98E5
			LD E,A				; $98E6
			INC BC				; $98E7
			LD A,(BC)				; $98E8
			ADD A,D				; $98E9
			LD D,A				; $98EA
			INC BC				; $98EB
			LD (IX+$05),C				; $98EC
			LD (IX+$06),B				; $98EF
			JP L_9939				; $98F2
L_98F5:		DEC (IX+$07)				; $98F5
			LD A,(BC)				; $98F8
			ADD A,E				; $98F9
			LD E,A				; $98FA
			INC BC				; $98FB
			LD A,(BC)				; $98FC
			ADD A,D				; $98FD
			LD D,A				; $98FE
			JP L_9939				; $98FF
L_9902:		INC BC				; $9902
			LD A,(BC)				; $9903
			DEC A				; $9904
			LD (IX+$07),A				; $9905
			INC BC				; $9908
			LD (IX+$05),C				; $9909
			LD (IX+$06),B				; $990C
			JR L_98F5				; $990F
L_9911:		LD C,(IX+$03)				; $9911
			LD B,(IX+$04)				; $9914
			LD (IX+$05),C				; $9917
			LD (IX+$06),B				; $991A
			JP L_98D5				; $991D
L_9920:		INC BC				; $9920
			LD (IX+$05),C				; $9921
			LD (IX+$06),B				; $9924
			PUSH BC				; $9927
			LD BC,(POS_XY)				; $9928
			LD A,$05				; $992C
			LD L,$02				; $992E
			LD H,$42				; $9930
			CALL L_8C98				; $9932
			POP BC				; $9935
			JP L_98D5				; $9936
L_9939:		POP BC				; $9939
			LD A,(IX+$0B)				; $993A
			CP $14				; $993D
			JR NC,L_9947				; $993F
			INC (IX+$0B)				; $9941
			JP L_996E				; $9944
L_9947:		
			CALL GET_ANIM_ADDR_AS_HL				; $9947
			LD A,(HL)				; $994A
			INC L				; $994B
			OR (HL)				; $994C
			PUSH BC				; $994D
			LD BC,$001F				; $994E
			ADD HL,BC				; $9951
			POP BC				; $9952
			OR (HL)				; $9953
			INC L				; $9954
			OR (HL)				; $9955
			CALL NZ,ADD_EXPLOSION_WITH_SFX				; $9956
			JP NZ,L_99A3				; $9959
			LD A,E				; $995C
			ADD A,$08				; $995D
			CP $87				; $995F
			JP NC,L_99A3				; $9961
			LD A,D				; $9964
			CP $11				; $9965
			JP C,L_99A3				; $9967
			CP $C0				; $996A
			JR NC,L_99A3				; $996C
L_996E:		LD (IX+$01),E				; $996E
			LD (IX+$02),D				; $9971
			LD A,(IX+$00)				; $9974
			LD L,(IX+$09)				; $9977
			LD H,(IX+$0A)				; $997A
			CALL SPRITE_24x16				; $997D
			PUSH DE				; $9980
			LD A,D				; $9981
			ADD A,$04				; $9982
			LD D,A				; $9984
			LD A,E				; $9985
			ADD A,$02				; $9986
			LD E,A				; $9988
			LD A,$02				; $9989
			CALL PLAYER_HAZARD_LIST				; $998B
			POP DE				; $998E
			LD (IX+$09),L				; $998F
			LD (IX+$0A),H				; $9992
			LD C,(IX+$08)				; $9995
			CALL SET_SCRN_ATTR				; $9998

L_999B:		LD DE,$000C				; $999B
			ADD IX,DE				; $999E
			JP L_98B8				; $99A0
L_99A3:		XOR A				; $99A3
			LD (IX+$00),A				; $99A4
			LD L,(IX+$09)				; $99A7
			LD H,(IX+$0A)				; $99AA
			CALL SPRITE_24x16				; $99AD
			JP L_999B				; $99B0

DATA_06:
			defb $00,$8B,$FC,$FC,$00,$45,$56,$00				; $99B3 .....EV.
			defb $00,$45,$56,$00,$00,$00,$8B,$A8				; $99BB .EV.....
			defb $00,$00,$8B,$A8,$00,$00,$45,$56				; $99C3 ......EV
			defb $00,$00,$45,$56,$00,$00,$00,$8B				; $99CB ..EV....
			defb $00,$00,$00,$8B,$00,$00,$00,$45				; $99D3 .......E
			defb $00,$00,$00,$45,$00,$00,$00,$00				; $99DB ...E....
			defb $CF,$CF,$9B,$DE,$03,$03,$45,$8B				; $99E3 ......E.
			defb $FC,$FC,$00,$8B,$FC,$A8,$00,$8B				; $99EB ........
			defb $FC,$A8,$00,$8B,$00,$00,$00,$8B				; $99F3 ........
			defb $00,$00,$00,$8B,$00,$00,$00,$8B				; $99FB ........
			defb $00,$00,$00,$8B,$00,$00,$00,$8B				; $9A03 ........
			defb $00,$00,$00,$8B,$A8,$00,$00,$8B				; $9A0B ........
			defb $A8,$00,$00,$8B,$56,$00,$00,$8B				; $9A13 ....V...
			defb $56,$00,$00,$8B,$8B,$A8,$00,$8B				; $9A1B V.......
			defb $FC,$00,$45,$CF,$FC,$00,$45,$03				; $9A23 ..E...E.
			defb $FF                                            ; $9A2B .

L_9A2C:
			LD IX,$99B3				; $9A2C
			LD C,A				; $9A30
L_9A31:
			LD A,(IX+$00)				; $9A31
			CP $FF				; $9A34
			RET Z				; $9A36
			OR A				; $9A37
			JR Z,L_9A44				; $9A38
			PUSH BC				; $9A3A
			LD BC,$000C				; $9A3B
			ADD IX,BC				; $9A3E
			POP BC				; $9A40
			JP L_9A31				; $9A41

L_9A44:
			LD (IX+$00),C				; $9A44
			LD (IX+$01),E				; $9A47
			LD (IX+$02),D				; $9A4A
			LD (IX+$03),L				; $9A4D
			LD (IX+$04),H				; $9A50
			LD (IX+$05),L				; $9A53
			LD (IX+$06),H				; $9A56
			LD (IX+$07),$00				; $9A59
			LD A,$04				; $9A5D
			CALL GET_RAND_VALUE				; $9A5F
			ADD A,$42				; $9A62
			LD (IX+$08),A				; $9A64
			LD DE,SPRITE24x16_DATA				; $9A67
			LD (IX+$09),E				; $9A6A
			LD (IX+$0A),D				; $9A6D
			LD (IX+$0B),$00				; $9A70
			RET				; $9A74

ENEMY_COLLISIONS:		
			PUSH BC							; $9A75
			PUSH DE							; $9A76
			PUSH HL							; $9A77
			LD B,D							; $9A78
			LD C,E							; $9A79
			LD HL,DATA_06					; $9A7A
LOOP_ITEMS:	
			LD A,(HL)						; $9A7D
			CP $FF							; $9A7E
			JP Z,ENEMY_COLLISIONS_END		; $9A80
			OR A							; $9A83
			JR NZ,FOUND_ITEM				; $9A84
NO_ENEMY_HIT:		
			LD DE,$000C						; $9A86  ; struct size=12  
			ADD HL,DE						; $9A89  ; move onto next part
			JP LOOP_ITEMS					; $9A8A
FOUND_ITEM:		
			PUSH HL							; $9A8D
			INC HL							; $9A8E
			LD E,(HL)						; $9A8F
			INC HL							; $9A90
			LD D,(HL)						; $9A91
			CALL COLLISION_DETECTION		; $9A92
			POP HL							; $9A95
			OR A							; $9A96
			JP Z,NO_ENEMY_HIT				; $9A97
			LD A,(HL)						; $9A9A  ; sprite index
			LD (HL),$00						; $9A9B
			LD HL,SPRITE24x16_DATA					; $9A9D
			CALL SPRITE_24x16				; $9AA0

			CALL ADD_EXPLOSION_WITH_SFX						; $9AA3
			LD A,$01						; $9AA6
			CALL GET_RAND_VALUE						; $9AA8
			OR A							; $9AAB
			JP Z,L_9AB8						; $9AAC
			LD A,$0A						; $9AAF
			CALL GET_RAND_VALUE						; $9AB1
			INC A							; $9AB4
			CALL L_9FA2						; $9AB5
L_9AB8:		LD DE,$7904						; $9AB8
			CALL L_78D4						; $9ABB
			CALL L_788E						; $9ABE
			XOR A							; $9AC1
ENEMY_COLLISIONS_END:				
			INC A							; $9AC2
			POP HL							; $9AC3
			POP DE							; $9AC4
			POP BC							; $9AC5
			RET								; $9AC6

; ??? jmp table to here, not found it yet!
			LD IX,$9B27				; $9AC7
			LD DE,$2000				; $9ACB
			LD B,$14				; $9ACE
L_9AD0:		CALL GET_ANIM_ADDR_AS_HL				; $9AD0
			LD A,(HL)				; $9AD3
			OR A				; $9AD4
			JR NZ,L_9AE0				; $9AD5
			LD (IX+$00),D				; $9AD7
			INC IX				; $9ADA
			LD HL,$9B47				; $9ADC
			INC (HL)				; $9ADF
L_9AE0:		LD A,D				; $9AE0
			ADD A,$08				; $9AE1
			LD D,A				; $9AE3
			DJNZ L_9AD0				; $9AE4
			RET				; $9AE6

; ???
			LD IX,$9B27				; $9AE7
			LD DE,$2078				; $9AEB
			LD B,$14				; $9AEE
L_9AF0:		CALL GET_ANIM_ADDR_AS_HL				; $9AF0
			LD A,(HL)				; $9AF3
			OR A				; $9AF4
			JR NZ,L_9B00				; $9AF5
			LD (IX+$00),D				; $9AF7
			INC IX				; $9AFA
			LD HL,$9B47				; $9AFC
			INC (HL)				; $9AFF
L_9B00:		LD A,D				; $9B00
			ADD A,$08				; $9B01
			LD D,A				; $9B03
			DJNZ L_9AF0				; $9B04
			RET				; $9B06

; ???
			LD IX,$9B27				; $9B07
			LD DE,$2000				; $9B0B
			LD B,$20				; $9B0E
L_9B10:		CALL GET_ANIM_ADDR_AS_HL				; $9B10
			LD A,(HL)				; $9B13
			OR A				; $9B14
			JR NZ,L_9B20				; $9B15
			LD (IX+$00),E				; $9B17
			INC IX				; $9B1A
			LD HL,$9B47				; $9B1C
			INC (HL)				; $9B1F
L_9B20:		LD A,E				; $9B20
			ADD A,$04				; $9B21
			LD E,A				; $9B23
			DJNZ L_9B10				; $9B24
			RET				; $9B26

			defb $8B,$03,$03,$00                                ; $9B27 ....
			defb $56,$FC,$FC,$A8,$FC,$00,$DE,$A8				; $9B2B V.......
			defb $A8,$00,$DE,$ED,$A8,$45,$FC,$45				; $9B33 .....E.E
			defb $00,$45,$FC,$8B,$00,$DE,$A8,$8B				; $9B3B .E......
			defb $00,$DE,$ED,$56,$00                            ; $9B43 ...V.

			LD IX,$9B27				; $9B48
			LD DE,$B000				; $9B4C
			LD B,$20				; $9B4F
L_9B51:
			CALL GET_ANIM_ADDR_AS_HL				; $9B51
			LD A,(HL)				; $9B54
			OR A				; $9B55
			JR NZ,L_9B61				; $9B56
			LD (IX+$00),E				; $9B58
			INC IX				; $9B5B
			LD HL,$9B47				; $9B5D
			INC (HL)				; $9B60
L_9B61:
			LD A,E				; $9B61
			ADD A,$04				; $9B62
			LD E,A				; $9B64
			DJNZ L_9B51				; $9B65
			RET				; $9B67f

SPAWN_ENEMY_SHIPS:
			CP $EC				; $9B68
			RET C				; $9B6A  ; A<$EC, Return
			CP $F0				; $9B6B
			RET NC				; $9B6D  ; A>=$F0 Return
			PUSH AF				; $9B6E
			PUSH BC				; $9B6F
			PUSH DE				; $9B70
			PUSH HL				; $9B71
			; Pick Enemy Type
			SUB $EC					; $9B72 ; 0 TO 3
			LD ($9BD5),A			; $9B74 ; index
			ADD A,A					; $9B77 ; X2
			ADD A,A					; $9B78 ; X4
			LD L,A					; $9B79 ; Index (Low byte)
			LD H,$00				; $9B7A
			LD BC,$9BBF				; $9B7C ; Enemy data base
			ADD HL,BC				; $9B7F ; Final location 
			;-----------------------------------------------------
			; Copy Enemy Data
			LD BC,$0004				; $9B80 ; copy 4 bytes
			LD DE,$9BCF				; $9B83
			LDIR					; $9B86
			;-----------------------------------------------------
			; Get Enemy Behavior
			LD A,($9BD5)			; $9B88 ; Enemy index
			ADD A,A					; $9B8B ; X2
			LD L,A					; $9B8C
			LD H,$00				; $9B8D
			LD BC,$9C56				; $9B8F ; base
			ADD HL,BC				; $9B92
			LD C,(HL)				; $9B93 ; first byte
			INC HL					; $9B94
			LD H,(HL)				; $9B95 ; second byte
			LD L,C					; $9B96 ; HL ready
			LD A,$03				; $9B97
			CALL GET_RAND_VALUE		; $9B99
			ADD A,$0D				; $9B9C
			LD ($9C55),A			; $9B9E
			;-----------------------------------------------------
			LD A,$03				; $9BA1
			CALL GET_RAND_VALUE		; $9BA3
			ADD A,A					; $9BA6
			LD C,A					; $9BA7
			LD B,$00				; $9BA8
			ADD HL,BC				; $9BAA  ; offset
			LD A,(HL)				; $9BAB
			INC HL					; $9BAC
			LD H,(HL)				; $9BAD
			LD L,A					; $9BAE
			;-----------------------------------------------------
			LD ($9BD6),HL			; $9BAF
			LD A,($9BD4)			; $9BB2
			SUB $0A					; $9BB5
			LD ($9BD4),A			; $9BB7
			POP HL					; $9BBA
			POP DE					; $9BBB
			POP BC					; $9BBC
			POP AF					; $9BBD
			RET						; $9BBE

			defb $E7,$9A,$01,$7F          	;$9BBF
			defb $48,$9B,$00,$BE			;$9BC3
			defb $C7,$9A,$01,$F9			;$9BC7
			defb $07,$9B,$00,$11			;$9BCB
			defw $0000						;$9BCF
			defb $00						;$9BD1
			defb $00						;$9BD2
			defb $00             			;$9BD3 
			defb $00 						;$9BD4
			defb $00	 					;$9BD5
			defw $0000						;$9BD6

L_9BD8:		LD A,($9BD5)				; $9BD8
			CP $FF				; $9BDB
			RET Z				; $9BDD
			LD HL,($9BCF)				; $9BDE
			JP (HL)				; $9BE1
ENEMY_SHIPS:		
			LD A,($9BD5)				; $9BE2
			CP $FF				; $9BE5
			RET Z				; $9BE7
			LD A,($9BD3)				; $9BE8
			DEC A				; $9BEB
			LD ($9BD3),A				; $9BEC
			OR A				; $9BEF
			RET NZ				; $9BF0
			LD A,($9BD4)				; $9BF1
			LD ($9BD3),A				; $9BF4
			LD A,($9B47)				; $9BF7
			CALL GET_RAND_VALUE				; $9BFA
			LD L,A				; $9BFD
			LD H,$00				; $9BFE
			LD BC,$9B27				; $9C00
			ADD HL,BC				; $9C03
			LD A,($9BD1)				; $9C04
			OR A				; $9C07
			LD A,($9BD2)				; $9C08
			JR Z,L_9C30				; $9C0B
			LD D,(HL)				; $9C0D
			LD E,A				; $9C0E
			LD A,($9BD5)				; $9C0F
			OR A				; $9C12
			LD A,(POS_XY)				; $9C13
			JR Z,L_9C24				; $9C16
			CP $10				; $9C18
			RET C				; $9C1A
			LD HL,($9BD6)				; $9C1B
			LD A,($9C55)				; $9C1E
			JP L_9A2C				; $9C21
L_9C24:		CP $68				; $9C24
			RET NC				; $9C26
			LD HL,($9BD6)				; $9C27
			LD A,($9C55)				; $9C2A
			JP L_9A2C				; $9C2D
L_9C30:		LD E,(HL)				; $9C30
			LD D,A				; $9C31
			LD A,($9BD5)				; $9C32
			CP $01				; $9C35
			LD A,($696A)				; $9C37
			JP Z,L_9C49				; $9C3A
			CP $40				; $9C3D
			RET C				; $9C3F
			LD HL,($9BD6)				; $9C40
			LD A,($9C55)				; $9C43
			JP L_9A2C				; $9C46
L_9C49:		CP $90				; $9C49
			RET NC				; $9C4B
			LD HL,($9BD6)				; $9C4C
			LD A,($9C55)				; $9C4F
			JP L_9A2C				; $9C52

			defb $00,$5E,$9C,$66,$9C,$6E                        ; $9C55 .^.f.n
			defb $9C,$76,$9C,$EC,$9D,$26,$9E,$51				; $9C5B .v...&.Q
			defb $9E,$88,$9E,$7E,$9C,$C3,$9C,$E5				; $9C63 ...~....
			defb $9C,$03,$9D,$C7,$9E,$01,$9F,$2C				; $9C6B .......,
			defb $9F,$63,$9F,$35,$9D,$7A,$9D,$9C				; $9C73 .c.5.z..
			defb $9D,$BA,$9D,$E2,$11,$00,$FE,$00				; $9C7B ........
			defb $FF,$00,$FF,$00,$FF,$FF,$FF,$FF				; $9C83 ........
			defb $FF,$FE,$FF,$FE,$FF,$FD,$FF,$FD				; $9C8B ........
			defb $FF,$FD,$FF,$FD,$FF,$FD,$FF,$FD				; $9C93 ........
			defb $FF,$FE,$FF,$FE,$FF,$FF,$FF,$FF				; $9C9B ........
			defb $FF,$00,$FF,$01,$FF,$01,$FF,$02				; $9CA3 ........
			defb $FF,$02,$FF,$03,$FF,$03,$FF,$03				; $9CAB ........
			defb $FF,$03,$FF,$03,$FF,$03,$FF,$02				; $9CB3 ........
			defb $FF,$02,$FF,$01,$FF,$01,$FF,$E1				; $9CBB ........
			defb $E2,$08,$00,$FC,$E2,$0C,$00,$FE				; $9CC3 ........
			defb $E2,$08,$01,$FE,$E2,$08,$00,$FE				; $9CCB ........
			defb $E2,$08,$FF,$FE,$E0,$E2,$0A,$FE				; $9CD3 ........
			defb $00,$E2,$04,$02,$04,$E2,$32,$00				; $9CDB ......2.
			defb $FE,$E1,$E2,$0C,$01,$FE,$E2,$0C				; $9CE3 ........
			defb $FF,$FE,$E2,$0C,$01,$FE,$E2,$0C				; $9CEB ........
			defb $FF,$FE,$E0,$E2,$0C,$01,$FE,$E2				; $9CF3 ........
			defb $0C,$FF,$FE,$E2,$0C,$01,$FE,$E1				; $9CFB ........
			defb $E2,$12,$00,$FE,$E2,$08,$01,$FE				; $9D03 ........
			defb $E2,$10,$FF,$FE,$E2,$08,$00,$FE				; $9D0B ........
			defb $E2,$08,$01,$FE,$E2,$08,$01,$00				; $9D13 ........
			defb $E0,$E2,$08,$01,$02,$E2,$08,$00				; $9D1B ........
			defb $03,$E2,$0A,$00,$04,$E2,$08,$FF				; $9D23 ........
			defb $02,$E2,$08,$FF,$FE,$E2,$28,$00				; $9D2B ......(.
			defb $FC,$E1,$E2,$11,$00,$02,$00,$01				; $9D33 ........
			defb $00,$01,$00,$01,$FF,$01,$FF,$01				; $9D3B ........
			defb $FE,$01,$FE,$01,$FD,$01,$FD,$01				; $9D43 ........
			defb $FD,$01,$FD,$01,$FD,$01,$FD,$01				; $9D4B ........
			defb $FE,$01,$FE,$01,$FF,$01,$FF,$01				; $9D53 ........
			defb $00,$01,$01,$01,$01,$01,$02,$01				; $9D5B ........
			defb $02,$01,$03,$01,$03,$01,$03,$01				; $9D63 ........
			defb $03,$01,$03,$01,$03,$01,$02,$01				; $9D6B ........
			defb $02,$01,$01,$01,$01,$01,$E1,$E2				; $9D73 ........
			defb $08,$00,$04,$E2,$0C,$00,$02,$E2				; $9D7B ........
			defb $08,$01,$02,$E2,$08,$00,$02,$E2				; $9D83 ........
			defb $08,$FF,$02,$E0,$E2,$0A,$FE,$00				; $9D8B ........
			defb $E2,$04,$02,$FC,$E2,$32,$00,$02				; $9D93 .....2..
			defb $E1,$E2,$0C,$01,$02,$E2,$0C,$FF				; $9D9B ........
			defb $02,$E2,$0C,$01,$02,$E2,$0C,$FF				; $9DA3 ........
			defb $02,$E0,$E2,$0C,$01,$02,$E2,$0C				; $9DAB ........
			defb $FF,$02,$E2,$0C,$01,$02,$E1,$E2				; $9DB3 ........
			defb $12,$00,$02,$E2,$08,$01,$02,$E2				; $9DBB ........
			defb $10,$FF,$02,$E2,$08,$00,$02,$E2				; $9DC3 ........
			defb $08,$01,$02,$E2,$08,$01,$00,$E0				; $9DCB ........
			defb $E2,$08,$01,$FE,$E2,$08,$00,$FD				; $9DD3 ........
			defb $E2,$0A,$00,$FC,$E2,$08,$FF,$FE				; $9DDB ........
			defb $E2,$08,$FF,$02,$E2,$28,$00,$04				; $9DE3 .....(..
			defb $E1,$E2,$07,$FC,$00,$E2,$06,$FE				; $9DEB ........
			defb $00,$E2,$0C,$FF,$00,$E2,$04,$FF				; $9DF3 ........
			defb $02,$E0,$E2,$04,$00,$02,$E2,$04				; $9DFB ........
			defb $01,$02,$E2,$04,$01,$00,$E2,$04				; $9E03 ........
			defb $01,$FE,$E2,$04,$00,$FE,$E2,$0A				; $9E0B ........
			defb $FE,$00,$E2,$0C,$FF,$FE,$E2,$0C				; $9E13 ........
			defb $FF,$02,$E2,$08,$FE,$00,$E2,$0A				; $9E1B ........
			defb $FC,$00,$E1,$E2,$0C,$FE,$00,$E2				; $9E23 ........
			defb $06,$FE,$04,$E2,$06,$FE,$FC,$E2				; $9E2B ........
			defb $06,$FE,$04,$E2,$0C,$00,$FE,$E2				; $9E33 ........
			defb $0F,$00,$00,$E0,$E2,$10,$FF,$00				; $9E3B ........
			defb $E0,$E2,$04,$FE,$00,$E2,$04,$FD				; $9E43 ........
			defb $00,$E2,$0B,$FC,$00,$E1,$E2,$07				; $9E4B ........
			defb $FC,$00,$E2,$06,$FE,$00,$E2,$0C				; $9E53 ........
			defb $FF,$00,$E2,$04,$FF,$02,$E0,$E2				; $9E5B ........
			defb $08,$FF,$FE,$E2,$08,$00,$FE,$E2				; $9E63 ........
			defb $08,$01,$FE,$E2,$08,$01,$00,$E2				; $9E6B ........
			defb $08,$00,$02,$E2,$08,$FF,$02,$E0				; $9E73 ........
			defb $E2,$0C,$FF,$00,$E2,$08,$FE,$00				; $9E7B ........
			defb $E2,$0D,$FC,$00,$E1,$FF,$00,$FF				; $9E83 ........
			defb $00,$FF,$FF,$FF,$FF,$FF,$FE,$FF				; $9E8B ........
			defb $FE,$FF,$FD,$FF,$FD,$FF,$FD,$FF				; $9E93 ........
			defb $FD,$FF,$FD,$FF,$FD,$FF,$FE,$FF				; $9E9B ........
			defb $FE,$FF,$FF,$FF,$FF,$FF,$00,$FF				; $9EA3 ........
			defb $01,$FF,$01,$FF,$02,$FF,$02,$FF				; $9EAB ........
			defb $03,$FF,$03,$FF,$03,$FF,$03,$FF				; $9EB3 ........
			defb $03,$FF,$03,$FF,$02,$FF,$02,$FF				; $9EBB ........
			defb $01,$FF,$01,$E1,$E2,$07,$04,$00				; $9EC3 ........
			defb $E2,$06,$02,$00,$E2,$0C,$01,$00				; $9ECB ........
			defb $E2,$04,$01,$02,$E0,$E2,$04,$00				; $9ED3 ........
			defb $02,$E2,$04,$FF,$02,$E2,$04,$FF				; $9EDB ........
			defb $00,$E2,$04,$FF,$FE,$E2,$04,$00				; $9EE3 ........
			defb $FE,$E2,$0A,$02,$00,$E2,$0C,$01				; $9EEB ........
			defb $FE,$E2,$0C,$01,$02,$E2,$08,$02				; $9EF3 ........
			defb $00,$E2,$0A,$04,$00,$E1,$E2,$0C				; $9EFB ........
			defb $02,$00,$E2,$06,$02,$04,$E2,$06				; $9F03 ........
			defb $02,$FC,$E2,$06,$02,$04,$E2,$0C				; $9F0B ........
			defb $00,$FE,$E2,$0F,$00,$00,$E0,$E2				; $9F13 ........
			defb $10,$01,$00,$E0,$E2,$04,$02,$00				; $9F1B ........
			defb $E2,$04,$03,$00,$E2,$0B,$04,$00				; $9F23 ........
			defb $E1,$E2,$07,$04,$00,$E2,$06,$02				; $9F2B ........
			defb $00,$E2,$0C,$01,$00,$E2,$04,$01				; $9F33 ........
			defb $02,$E0,$E2,$08,$01,$FE,$E2,$08				; $9F3B ........
			defb $00,$FE,$E2,$08,$FF,$FE,$E2,$08				; $9F43 ........
			defb $FF,$00,$E2,$08,$00,$02,$E2,$08				; $9F4B ........
			defb $01,$02,$E0,$E2,$0C,$01,$00,$E2				; $9F53 ........
			defb $08,$02,$00,$E2,$0D,$04,$00,$E1				; $9F5B ........
			defb $01,$00,$01,$00,$01,$FF,$01,$FF				; $9F63 ........
			defb $01,$FE,$01,$FE,$01,$FD,$01,$FD				; $9F6B ........
			defb $01,$FD,$01,$FD,$01,$FD,$01,$FD				; $9F73 ........
			defb $01,$FE,$01,$FE,$01,$FF,$01,$FF				; $9F7B ........
			defb $01,$00,$01,$01,$01,$01,$01,$02				; $9F83 ........
			defb $01,$02,$01,$03,$01,$03,$01,$03				; $9F8B ........
			defb $01,$03,$01,$03,$01,$03,$01,$02				; $9F93 ........
			defb $01,$02,$01,$01,$01,$01,$E1                    ; $9F9B .......

L_9FA2:		PUSH AF				; $9FA2
			PUSH BC				; $9FA3
			PUSH DE				; $9FA4
			PUSH HL				; $9FA5
			PUSH IX				; $9FA6
			LD C,A				; $9FA8
			LD A,E				; $9FA9
			CP $79				; $9FAA
			JP NC,L_9FFB				; $9FAC
			LD A,D				; $9FAF
			AND $F8				; $9FB0 ; Align to title boundry 
			LD D,A				; $9FB2
			CALL GET_ANIM_ADDR_AS_HL				; $9FB3
			LD A,(HL)				; $9FB6
			INC L				; $9FB7
			OR (HL)				; $9FB8
			PUSH DE				; $9FB9
			LD DE,$001F				; $9FBA  
			ADD HL,DE				; $9FBD  ; look at next byte
			POP DE				; $9FBE
			OR (HL)				; $9FBF
			INC L				; $9FC0
			OR (HL)				; $9FC1
			JP NZ,L_9FFB				; $9FC2
			LD IX,$A002				; $9FC5
L_9FC9:		LD A,(IX+$00)				; $9FC9
			CP $FF				; $9FCC
			JP Z,L_9FFB				; $9FCE
			OR A				; $9FD1
			JR Z,L_9FDE				; $9FD2
			PUSH BC				; $9FD4
			LD BC,$0006				; $9FD5
			ADD IX,BC				; $9FD8
			POP BC				; $9FDA
			JP L_9FC9				; $9FDB
L_9FDE:		LD A,C				; $9FDE
			CALL L_A03F				; $9FDF
			LD (IX+$00),C				; $9FE2
			LD A,(HL)				; $9FE5
			LD (IX+$01),A				; $9FE6
			LD A,E				; $9FE9
			AND $FC				; $9FEA
			LD (IX+$02),A				; $9FEC
			LD (IX+$03),D				; $9FEF
			LD DE,SPRITE24x16_DATA				; $9FF2
			LD (IX+$04),E				; $9FF5
			LD (IX+$05),D				; $9FF8
L_9FFB:		POP IX				; $9FFB
			POP HL				; $9FFD
			POP DE				; $9FFE
			POP BC				; $9FFF
			POP AF				; $A000
			RET				; $A001

DATA_07:
			defb $04                                            ; $A002 .
			defb $45,$45,$4B,$40,$45,$45,$4B,$40				; $A003 EEK@EEK@
			defb $45,$45,$C3,$40,$45,$45,$C3,$40				; $A00B EE.@EE.@
			defb $00,$0A,$82,$80,$00,$0A,$00,$80				; $A013 ........
			defb $00,$4B,$40,$80,$00,$41,$C0,$00				; $A01B .K@..A..
			defb $00,$44,$08,$00,$00,$44,$08,$00				; $A023 .D...D..
			defb $00,$CC,$0C,$00,$00,$CC,$0C,$00				; $A02B ........
			defb $44,$88,$04,$08,$44,$88,$04,$08				; $A033 D...D...
			defb $CC,$45,$0A,$FF                                ; $A03B .E..

L_A03F:
			PUSH AF				; $A03F
			PUSH BC				; $A040
			ADD A,A				; $A041
			ADD A,A				; $A042
			ADD A,A				; $A043
			LD L,A				; $A044
			LD H,$00				; $A045
			LD BC,$A15D				; $A047
			ADD HL,BC				; $A04A
			POP BC				; $A04B
			POP AF				; $A04C
			RET				; $A04D

DRAW_PICKUPS:		LD HL,$A002				; $A04E
L_A051:		LD A,(HL)				; $A051
			CP $FF				; $A052
			RET Z				; $A054
			OR A				; $A055
			JR NZ,L_A05F				; $A056
L_A058:		LD BC,$0006				; $A058
			ADD HL,BC				; $A05B
			JP L_A051				; $A05C

L_A05F:		PUSH HL				; $A05F
			INC HL				; $A060
			LD C,(HL)				; $A061
			INC HL				; $A062
			LD E,(HL)				; $A063
			INC HL				; $A064
			LD D,(HL)				; $A065
			CALL CHECK_SCENE_DOWN				; $A066
			JR NZ,L_A082				; $A069
			LD B,D				; $A06B
			INC D				; $A06C
			LD (HL),D				; $A06D
			INC HL				; $A06E
			LD A,(HL)				; $A06F
			INC HL				; $A070
			LD H,(HL)				; $A071
			LD L,A				; $A072
			LD A,C				; $A073
			LD C,E				; $A074
			CALL DRAW4X4SPRITE				; $A075
			POP IX				; $A078
			PUSH IX				; $A07A
			LD (IX+$04),L				; $A07C
			LD (IX+$05),H				; $A07F
L_A082:		POP HL				; $A082
			JP L_A058				; $A083
DO_PICKUPS:		LD A,$01				; $A086
			CALL L_67B9				; $A088
			LD IX,$A002				; $A08B
L_A08F:		LD A,(IX+$00)				; $A08F
			CP $FF				; $A092
			RET Z				; $A094

			OR A				; $A095
			JR NZ,L_A0A0				; $A096
			LD BC,$0006				; $A098
			ADD IX,BC				; $A09B
			JP L_A08F				; $A09D
L_A0A0:		LD E,(IX+$02)				; $A0A0
			LD D,(IX+$03)				; $A0A3
			LD B,A				; $A0A6
			LD A,D				; $A0A7
			CP $C0				; $A0A8
			LD A,B				; $A0AA
			JP NC,L_A0F6				; $A0AB
			CALL L_A03F				; $A0AE
			JP NC,L_A0D4				; $A0B1
			LD A,(HL)				; $A0B4
			INC HL				; $A0B5
			LD C,(HL)				; $A0B6
			INC HL				; $A0B7
			LD B,(HL)				; $A0B8
			CALL L_A47B				; $A0B9
			LD A,(INPUT_ENABLED)				; $A0BC
			OR A				; $A0BF
			JR NZ,L_A0CC				; $A0C0
			LD BC,(POS_XY)				; $A0C2
			CALL COLLISION_DETECTION				; $A0C6
			OR A				; $A0C9
			JR NZ,L_A0D4				; $A0CA
L_A0CC:		LD BC,$0006				; $A0CC
			ADD IX,BC				; $A0CF
			JP L_A08F				; $A0D1
L_A0D4:		INC HL				; $A0D4
			LD E,(HL)				; $A0D5
			INC HL				; $A0D6
			LD D,(HL)				; $A0D7
			PUSH HL				; $A0D8
			PUSH IX				; $A0D9
			LD HL,($7973)				; $A0DB
			ADD HL,DE				; $A0DE
			LD ($7973),HL				; $A0DF
			CALL L_7935				; $A0E2
			CALL L_78AF				; $A0E5
			LD E,SFX_PICKUP				; $A0E8
			CALL PLAY_SFX				; $A0EA
			POP IX				; $A0ED
			POP HL				; $A0EF
			INC HL				; $A0F0
			LD A,(HL)				; $A0F1
			INC HL				; $A0F2
			LD H,(HL)				; $A0F3
			LD L,A				; $A0F4
			JP (HL)				; $A0F5

L_A0F6:		LD (IX+$00),$00				; $A0F6
			LD C,(IX+$02)				; $A0FA
			LD B,(IX+$03)				; $A0FD
			LD L,(IX+$04)				; $A100
			LD H,(IX+$05)				; $A103
			XOR A						; $A106
			CALL DRAW4X4SPRITE			; $A107
			LD BC,$0006					; $A10A
			ADD IX,BC					; $A10D
			JP L_A08F					; $A10F
			LD A,(BACKSHOT_ENABLE)				; $A112
			OR A						; $A115
			JP NZ,L_A0F6				; $A116
			LD A,$01					; $A119
			LD (BACKSHOT_ENABLE),A				; $A11B
			LD DE,(POS_XY)				; $A11E
			LD B,D						; $A122
			LD C,E						; $A123
			CALL L_6953					; $A124
			JP L_A0F6					; $A127
			LD A,(SELECTED_WEAPON)		; $A12A
			ADD A,A						; $A12D
			ADD A,A						; $A12E
			ADD A,A						; $A12F
			ADD A,A						; $A130
			LD H,$00					; $A131
			LD L,A						; $A133
			LD BC,$7BB5					; $A134
			ADD HL,BC					; $A137
			LD C,(HL)					; $A138
			INC C						; $A139
			INC HL						; $A13A
			INC HL						; $A13B
			INC HL						; $A13C
			INC HL						; $A13D
			LD A,(HL)					; $A13E
			CP C						; $A13F
			JP C,L_A0F6					; $A140
			DEC HL						; $A143
			DEC HL						; $A144
			DEC HL						; $A145
			DEC HL						; $A146
			LD (HL),C					; $A147
			CALL UPDATE_WEAPONS_DISPLAY					; $A148
			JP L_A0F6					; $A14B
			LD A,(MACE_ENABLE)				; $A14E
			OR A						; $A151
			JP NZ,L_A0F6				; $A152
			LD A,$01					; $A155
			LD (MACE_ENABLE),A				; $A157
			JP L_A0F6					; $A15A

			defb $00,$00,$00,$00,$00,$00                        ; $A15D ......
			defb $00,$00,$71,$47,$47,$00,$00,$12				; $A163 ..qGG...
			defb $A1,$00,$72,$45,$04,$32,$00,$F6				; $A16B ..rE.2..
			defb $A0,$00,$73,$43,$42,$50,$00,$F6				; $A173 ..sCBP..
			defb $A0,$00,$74,$47,$46,$6E,$00,$F6				; $A17B ..tGFn..
			defb $A0,$00,$75,$45,$05,$8C,$00,$F6				; $A183 ..uE....
			defb $A0,$00,$72,$45,$05,$32,$00,$F6				; $A18B ..rE.2..
			defb $A0,$00,$73,$47,$46,$50,$00,$F6				; $A193 ..sGFP..
			defb $A0,$00,$74,$43,$42,$6E,$00,$F6				; $A19B ..tCBn..
			defb $A0,$00,$75,$45,$04,$8C,$00,$F6				; $A1A3 ..uE....
			defb $A0,$00,$76,$47,$46,$00,$00,$2A				; $A1AB ..vGF..*
			defb $A1,$00,$77,$47,$07,$00,$00,$4E				; $A1B3 ..wG...N
			defb $A1,$00,$83,$47,$47,$00,$00,$F6				; $A1BB ...GG...
			defb $A0,$00,$84,$47,$07,$00,$00,$F6				; $A1C3 ...G....
			defb $A0,$00,$8C,$47,$47,$00,$00,$F6				; $A1CB ...GG...
			defb $A0,$00,$FF                                    ; $A1D3 ...

PLACE_PICKUPS:		
			CP $E9				; $A1D6
			RET C				; $A1D8

			PUSH AF				; $A1D9
			PUSH BC				; $A1DA
			PUSH DE				; $A1DB
			PUSH HL				; $A1DC
			LD HL,$A1F6			; $A1DD
			LD C,A				; $A1E0
L_A1E1:		LD A,(HL)			; $A1E1
			CP $FF				; $A1E2
			JR Z,L_A1F1			; $A1E4
			INC HL				; $A1E6
			INC HL				; $A1E7
			CP C				; $A1E8
			JR NZ,L_A1E1		; $A1E9
			DEC HL				; $A1EB
			LD A,(HL)			; $A1EC
			DEC D				; $A1ED
			CALL L_9FA2			; $A1EE
L_A1F1:		POP HL				; $A1F1
			POP DE				; $A1F2
			POP BC				; $A1F3
			POP AF				; $A1F4
			RET					; $A1F5

			JP (HL)				; $A1F6

			defb $0A,$EA,$01,$EB                                ; $A1F7 ....
			defb $0B,$FF                                        ; $A1FB ..


; Draws a 24x16 pixel sprite using XOR rendering with pre-shifted graphics
; Inputs: A=index,C=Ypos,E=Xpos,D = ?
SPRITE_24x16:
			PUSH AF				; $A1FD
			PUSH BC				; $A1FE
			PUSH DE				; $A1FF
			PUSH HL				; $A200
			PUSH BC				; $A201  ; Extra BC
			LD L,A				; $A202  ; Sprite Index
			;-----------------------------------------------------------
			LD A,E				; $A203  ; X
			CP $AA				; $A204  ;
			JP NC,L_A367		; $A206  ; right screen
			;-----------------------------------------------------------
			LD A,C				; $A209  ; Y
			CP $AA				; $A20A  ; 
			JP NC,L_A367		; $A20C  ; bottom screen
			;-----------------------------------------------------------
			LD A,E				; $A20F  ; X
			CP $79				; $A210  ; 
			JP NC,$A29C			; $A212  ; partial right draw needed
			;-----------------------------------------------------------
			LD A,C				; $A215  ; Y
			CP $79				; $A216  ; 
			JP NC,$A29C			; $A218  ; partial bottom draw needed
			;-----------------------------------------------------------
			; preshift offset
			LD H,L				; $A21B  ; Sprite Index
			LD L,$00			; $A21C
			SRL H				; $A21E 
			RR L				; $A220
			LD B,H				; $A222
			LD C,L				; $A223
			SRL H				; $A224
			RR L				; $A226
			ADD HL,BC				; $A228  ; HL=sprite offset
			LD BC,SPRITE24x16_DATA	; $A229
			ADD HL,BC				; $A22C  ; HL=sprite data
			LD B,H					; $A22D
			LD C,L					; $A22E  ; ???
			;-----------------------------------------------------------
			; horizontal preshift (0-3 pixels)
			LD A,E				; $A22F
			AND $03				; $A230
			LD L,A				; $A232
			LD H,$00			; $A233
			ADD HL,HL			; $A235
			ADD HL,HL			; $A236
			ADD HL,HL			; $A237
			ADD HL,HL			; $A238
			PUSH DE				; $A239
			LD D,H				; $A23A
			LD E,L				; $A23B
			ADD HL,HL			; $A23C
			ADD HL,DE			; $A23D
			ADD HL,BC			; $A23E
			LD (LABELSPR),HL		; $A23F
			POP DE				; $A242
			;--------------------------------------------------
			; get screen address
			LD A,E				; $A243
			AND $7C				; $A244
			RRCA				; $A246
			RRCA				; $A247
			LD ($A266),A		; $A248
			LD C,D				; $A24B
			EXX					; $A24C
			POP DE				; $A24D
			LD A,E				; $A24E
			AND $7C				; $A24F
			RRCA				; $A251
			RRCA				; $A252
			LD ($A27F),A		; $A253
			LD C,D				; $A256
			POP DE				; $A257
			EXX					; $A258
			;--------------------------------------------------
			LD DE,(LABELSPR)	; $A259
			LD B,$10			; $A25D
DRAW_SPRITE_LOOP:		
			LD H,$64			; $A25F
			LD L,C				; $A261
			LD A,(HL)			; $A262
			DEC H				; $A263
			LD H,(HL)			; $A264
			OR $00				; $A265
			LD L,A				; $A267
			INC C				; $A268
			LD A,(DE)			; $A269
			XOR (HL)			; $A26A
			LD (HL),A			; $A26B
			INC L				; $A26C
			INC DE				; $A26D
			LD A,(DE)			; $A26E
			XOR (HL)			; $A26F
			LD (HL),A			; $A270
			INC L				; $A271
			INC DE				; $A272
			LD A,(DE)			; $A273
			XOR (HL)			; $A274
			LD (HL),A			; $A275
			INC DE				; $A276
			EXX					; $A277
			LD H,$64			; $A278
			LD L,C				; $A27A
			LD A,(HL)			; $A27B
			DEC H				; $A27C
			LD H,(HL)			; $A27D
			OR $00				; $A27E
			LD L,A				; $A280
			INC C				; $A281
			LD A,(DE)			; $A282
			XOR (HL)			; $A283
			LD (HL),A			; $A284
			INC L				; $A285
			INC DE				; $A286
			LD A,(DE)			; $A287
			XOR (HL)			; $A288
			LD (HL),A			; $A289
			INC L				; $A28A
			INC DE				; $A28B
			LD A,(DE)			; $A28C
			XOR (HL)			; $A28D
			LD (HL),A			; $A28E
			INC DE				; $A28F
			EXX					; $A290
			DJNZ DRAW_SPRITE_LOOP			; $A291
			LD HL,(LABELSPR)	; $A293
			POP DE				; $A296
			POP BC				; $A297
			POP AF				; $A298
			RET					; $A299

			; Self modifying code (on $A29A,$A29B)
LABELSPR:	LD SP,HL			; $A29A  ; Opcode "LD SP,HL" replaced
			ADD A,$65			; $A29B  ; Opcode "ADD A": replaced
			LD L,$00			; $A29D   
			SRL H				; $A29F
			RR L				; $A2A1
			LD B,H				; $A2A3
			LD C,L				; $A2A4
			SRL H				; $A2A5
			RR L				; $A2A7
			ADD HL,BC			; $A2A9
			LD BC,SPRITE24x16_DATA			; $A2AA
			ADD HL,BC			; $A2AD
			LD B,H				; $A2AE
			LD C,L				; $A2AF
			LD A,E				; $A2B0
			AND $03				; $A2B1
			LD L,A				; $A2B3
			LD H,$00			; $A2B4
			ADD HL,HL			; $A2B6
			ADD HL,HL			; $A2B7
			ADD HL,HL			; $A2B8
			ADD HL,HL			; $A2B9
			PUSH DE				; $A2BA
			LD D,H				; $A2BB
			LD E,L				; $A2BC
			ADD HL,HL			; $A2BD
			ADD HL,DE			; $A2BE
			ADD HL,BC			; $A2BF
			LD (LABELSPR),HL		; $A2C0
			POP DE				; $A2C3
			LD A,E				; $A2C4
			AND $7C				; $A2C5
			RRCA				; $A2C7
			RRCA				; $A2C8
			LD ($A333),A		; $A2C9
			LD C,D				; $A2CC
			LD A,$77			; $A2CD
			LD ($A33D),A		; $A2CF
			LD ($A342),A		; $A2D2
			LD ($A338),A		; $A2D5
			LD A,E				; $A2D8
			CP $79				; $A2D9
			JR C,L_A2F3			; $A2DB
			XOR A				; $A2DD
			LD ($A342),A		; $A2DE
			LD A,E				; $A2E1
			CP $7C				; $A2E2
			JR C,L_A2F3			; $A2E4
			XOR A				; $A2E6
			LD ($A33D),A		; $A2E7
			LD A,E				; $A2EA
			CP $80				; $A2EB
			JR C,L_A2F3			; $A2ED
			XOR A				; $A2EF
			LD ($A338),A		; $A2F0


L_A2F3:
			EXX				; $A2F3
			POP DE				; $A2F4
			LD A,$77				; $A2F5
			LD ($A356),A				; $A2F7
			LD ($A35B),A				; $A2FA
			LD ($A351),A				; $A2FD
			LD A,E				; $A300
			CP $79				; $A301
			JR C,L_A31B				; $A303
			XOR A				; $A305
			LD ($A35B),A				; $A306
			LD A,E				; $A309
			CP $7C				; $A30A
			JR C,L_A31B				; $A30C
			XOR A				; $A30E
			LD ($A356),A				; $A30F
			LD A,E				; $A312
			CP $80				; $A313
			JR C,L_A31B				; $A315
			XOR A				; $A317
			LD ($A351),A				; $A318
L_A31B:
			LD A,E				; $A31B
			AND $7C				; $A31C
			RRCA				; $A31E
			RRCA				; $A31F
			LD ($A34C),A				; $A320
			LD C,D				; $A323
			POP DE				; $A324
			EXX				; $A325
			LD DE,(LABELSPR)				; $A326
			LD B,$10				; $A32A
L_A32C:
			LD H,$64				; $A32C
			LD L,C				; $A32E
			LD A,(HL)				; $A32F
			DEC H				; $A330
			LD H,(HL)				; $A331
			OR $00				; $A332
			LD L,A				; $A334
			INC C				; $A335
			LD A,(DE)				; $A336
			XOR (HL)				; $A337
			LD (HL),A				; $A338
			INC L				; $A339
			INC DE				; $A33A
			LD A,(DE)				; $A33B
			XOR (HL)				; $A33C
			LD (HL),A				; $A33D
			INC L				; $A33E
			INC DE				; $A33F
			LD A,(DE)				; $A340
			XOR (HL)				; $A341
			LD (HL),A				; $A342
			INC DE				; $A343
			EXX				; $A344
			LD H,$64				; $A345
			LD L,C				; $A347
			LD A,(HL)				; $A348
			DEC H				; $A349
			LD H,(HL)				; $A34A
			OR $00				; $A34B
			LD L,A				; $A34D
			INC C				; $A34E
			LD A,(DE)				; $A34F
			XOR (HL)				; $A350
			LD (HL),A				; $A351
			INC L				; $A352
			INC DE				; $A353
			LD A,(DE)				; $A354
			XOR (HL)				; $A355
			LD (HL),A				; $A356
			INC L				; $A357
			INC DE				; $A358
			LD A,(DE)				; $A359
			XOR (HL)				; $A35A
			LD (HL),A				; $A35B
			INC DE				; $A35C
			EXX				; $A35D
			DJNZ L_A32C				; $A35E
			LD HL,(LABELSPR)				; $A360
			POP DE				; $A363
			POP BC				; $A364
			POP AF				; $A365
			RET				; $A366

L_A367:
			LD H,L				; $A367
			LD L,$00				; $A368
			SRL H				; $A36A
			RR L				; $A36C
			LD B,H				; $A36E
			LD C,L				; $A36F
			SRL H				; $A370
			RR L				; $A372
			ADD HL,BC				; $A374
			LD BC,SPRITE24x16_DATA				; $A375
			ADD HL,BC				; $A378
			LD B,H				; $A379
			LD C,L				; $A37A
			LD A,E				; $A37B
			AND $03				; $A37C
			LD L,A				; $A37E
			LD H,$00				; $A37F
			ADD HL,HL				; $A381
			ADD HL,HL				; $A382
			ADD HL,HL				; $A383
			ADD HL,HL				; $A384
			PUSH DE				; $A385
			LD D,H				; $A386
			LD E,L				; $A387
			ADD HL,HL				; $A388
			ADD HL,DE				; $A389
			ADD HL,BC				; $A38A
			LD (LABELSPR),HL				; $A38B
			POP DE				; $A38E
			LD A,E				; $A38F
			AND $7C				; $A390
			RRCA				; $A392
			RRCA				; $A393
			LD ($A412),A				; $A394
			LD C,D				; $A397
			LD HL,$2C77				; $A398
			LD ($A41C),HL				; $A39B
			LD ($A417),HL				; $A39E
			LD A,L				; $A3A1
			LD ($A421),A				; $A3A2
			LD A,E				; $A3A5
			CP $80				; $A3A6
			JR C,L_A3C8				; $A3A8
			XOR A				; $A3AA
			LD ($A412),A				; $A3AB
			LD HL,$0000				; $A3AE
			LD ($A417),HL				; $A3B1
			LD A,E				; $A3B4
			CP $FC				; $A3B5
			JR NC,L_A3C8				; $A3B7
			LD HL,$0000				; $A3B9
			LD ($A41C),HL				; $A3BC
			LD A,E				; $A3BF
			CP $F8				; $A3C0
			JR NC,L_A3C8				; $A3C2
			XOR A				; $A3C4
			LD ($A421),A				; $A3C5
L_A3C8:
			EXX				; $A3C8
			POP DE				; $A3C9
			LD A,E				; $A3CA
			AND $7C				; $A3CB
			RRCA				; $A3CD
			RRCA				; $A3CE
			LD ($A42B),A				; $A3CF
			LD HL,$2C77				; $A3D2
			LD ($A435),HL				; $A3D5
			LD ($A430),HL				; $A3D8
			LD A,L				; $A3DB
			LD ($A43A),A				; $A3DC
			LD A,E				; $A3DF
			CP $80				; $A3E0
			JR C,L_A402				; $A3E2
			XOR A				; $A3E4
			LD ($A42B),A				; $A3E5
			LD HL,$0000				; $A3E8
			LD ($A430),HL				; $A3EB
			LD A,E				; $A3EE
			CP $FC				; $A3EF
			JR NC,L_A402				; $A3F1
			LD HL,$0000				; $A3F3
			LD ($A435),HL				; $A3F6
			LD A,E				; $A3F9
			CP $F8				; $A3FA
			JR NC,L_A402				; $A3FC
			XOR A				; $A3FE
			LD ($A43A),A				; $A3FF
L_A402:
			LD C,D				; $A402
			POP DE				; $A403
			EXX				; $A404
			LD DE,(LABELSPR)				; $A405
			LD B,$10				; $A409
L_A40B:
			LD H,$64				; $A40B
			LD L,C				; $A40D
			LD A,(HL)				; $A40E
			DEC H				; $A40F
			LD H,(HL)				; $A410
			OR $00				; $A411
			LD L,A				; $A413
			INC C				; $A414
			LD A,(DE)				; $A415
			XOR (HL)				; $A416
			LD (HL),A				; $A417
			INC L				; $A418
			INC DE				; $A419
			LD A,(DE)				; $A41A
			XOR (HL)				; $A41B
			LD (HL),A				; $A41C
			INC L				; $A41D
			INC DE				; $A41E
			LD A,(DE)				; $A41F
			XOR (HL)				; $A420
			LD (HL),A				; $A421
			INC DE				; $A422
			EXX				; $A423
			LD H,$64				; $A424
			LD L,C				; $A426
			LD A,(HL)				; $A427
			DEC H				; $A428
			LD H,(HL)				; $A429
			OR $00				; $A42A
			LD L,A				; $A42C
			INC C				; $A42D
			LD A,(DE)				; $A42E
			XOR (HL)				; $A42F
			LD (HL),A				; $A430
			INC L				; $A431
			INC DE				; $A432
			LD A,(DE)				; $A433
			XOR (HL)				; $A434
			LD (HL),A				; $A435
			INC L				; $A436
			INC DE				; $A437
			LD A,(DE)				; $A438
			XOR (HL)				; $A439
			LD (HL),A				; $A43A
			INC DE				; $A43B
			EXX				; $A43C
			DJNZ L_A40B				; $A43D
			LD HL,(LABELSPR)				; $A43F
			POP DE				; $A442
			POP BC				; $A443
			POP AF				; $A444
			RET				; $A445

SET_SCRN_ATTR:		
			; IN: E=X,D=Y,C=Colour
			PUSH AF				; $A446
			PUSH BC				; $A447
			PUSH DE				; $A448
			PUSH HL				; $A449
			LD B,$03				; $A44A
			LD A,E				; $A44C
			CP $80				; $A44D
			JR C,L_A453				; $A44F
			LD E,$00				; $A451
L_A453:		CALL GET_ATTRIBUTE_AS_HL				; $A453
L_A456:		PUSH HL				; $A456
			LD DE,$0300				; $A457
			ADD HL,DE				; $A45A
			EX DE,HL				; $A45B
			POP HL				; $A45C
			LD A,(DE)				; $A45D
			OR A				; $A45E
			JR NZ,L_A462				; $A45F
			LD (HL),C				; $A461
L_A462:		INC HL				; $A462
			INC DE				; $A463
			LD A,(DE)				; $A464
			OR A				; $A465
			JR NZ,L_A469				; $A466
			LD (HL),C				; $A468
L_A469:		INC HL				; $A469
			INC DE				; $A46A
			LD A,(DE)				; $A46B
			OR A				; $A46C
			JR NZ,L_A470				; $A46D
			LD (HL),C				; $A46F
L_A470:		LD DE,$001E				; $A470
			ADD HL,DE				; $A473
			DJNZ L_A456				; $A474
			POP HL				; $A476
			POP DE				; $A477
			POP BC				; $A478
			POP AF				; $A479
			RET				; $A47A

L_A47B:		PUSH AF				; $A47B
			PUSH BC				; $A47C
			PUSH DE				; $A47D
			PUSH HL				; $A47E
			LD A,E				; $A47F
			CP $80				; $A480
			JR C,L_A486				; $A482
			LD E,$00				; $A484
L_A486:		LD A,$03				; $A486
			CALL GET_ATTRIBUTE_AS_HL				; $A488
L_A48B:		EX AF,AF'				; $A48B
			PUSH HL				; $A48C
			LD DE,$0300				; $A48D
			ADD HL,DE				; $A490
			EX DE,HL				; $A491
			POP HL				; $A492
			LD A,(DE)				; $A493
			OR A				; $A494
			JR NZ,L_A498				; $A495
			LD (HL),C				; $A497
L_A498:		INC HL				; $A498
			INC DE				; $A499
			LD A,(DE)				; $A49A
			OR A				; $A49B
			JR NZ,L_A49F				; $A49C
			LD (HL),B				; $A49E
L_A49F:		LD DE,$001F				; $A49F
			ADD HL,DE				; $A4A2
			EX AF,AF'				; $A4A3
			DEC A				; $A4A4
			JP NZ,L_A48B				; $A4A5
			POP HL				; $A4A8
			POP DE				; $A4A9
			POP BC				; $A4AA
			POP AF				; $A4AB
			RET				; $A4AC

L_A4AD:		PUSH AF				; $A4AD
			PUSH BC				; $A4AE
			PUSH DE				; $A4AF
			PUSH HL				; $A4B0
			LD B,$02				; $A4B1
			LD A,E				; $A4B3
			CP $80				; $A4B4
			JR C,L_A4BA				; $A4B6
			LD E,$00				; $A4B8
L_A4BA:		CALL GET_ATTRIBUTE_AS_HL				; $A4BA
L_A4BD:		PUSH HL				; $A4BD
			LD DE,$0300				; $A4BE
			ADD HL,DE				; $A4C1
			EX DE,HL				; $A4C2
			POP HL				; $A4C3
			LD A,(DE)				; $A4C4
			OR A				; $A4C5
			JR NZ,L_A4C9				; $A4C6
			LD (HL),C				; $A4C8
L_A4C9:		INC L				; $A4C9
			INC E				; $A4CA
			LD A,(DE)				; $A4CB
			OR A				; $A4CC
			JR NZ,L_A4D0				; $A4CD
			LD (HL),C				; $A4CF
L_A4D0:		LD DE,$001F				; $A4D0
			ADD HL,DE				; $A4D3
			DJNZ L_A4BD				; $A4D4
			POP HL				; $A4D6
			POP DE				; $A4D7
			POP BC				; $A4D8
			POP AF				; $A4D9
			RET					; $A4DA

; Draws a 16x16 sprite, uses four 8x8 sprites into a 2x2 grid.
; Used for drawing larger masked sprites (i.e pickups, animated icons).
; Uses XOR masking to blend sprite over background.
DRAW4X4SPRITE:		
			PUSH AF				; $A4DB
			PUSH BC				; $A4DC
			PUSH DE				; $A4DD
			PUSH HL				; $A4DE
			PUSH BC				; $A4DF

			; Sprite Data Address 
			LD L,A				; $A4E0	; sprite index 
			LD H,$00			; $A4E1
			ADD HL,HL			; $A4E3  ; x2
			ADD HL,HL			; $A4E4  ; x4
			ADD HL,HL			; $A4E5  ; x8
			ADD HL,HL			; $A4E6  ; x16
			ADD HL,HL			; $A4E7  ; x32  
			LD BC,TITLE16X16_DATA			; $A4E8  ; sprites base
			ADD HL,BC			; $A4EB  ; base + index
			LD (LABELSPR),HL		; $A4EC	 ; save for animation

			; Get Screen Coordinates
			LD A,E				; $A4EF	 ; Y coord
			AND $7C				; $A4F0  ;
			RRCA				; $A4F2  ;
			RRCA				; $A4F3  ; align to screen layout
			LD ($A50F),A		; $A4F4  ; coordinate 
			LD C,D				; $A4F7  ; X coord
	
			EXX					; $A4F8
			POP DE				; $A4F9
			LD A,E				; $A4FA
			AND $7C				; $A4FB
			RRCA				; $A4FD
			RRCA				; $A4FE
			LD ($A523),A		; $A4FF ; coordinate 
			LD C,D				; $A502
			POP DE				; $A503
			EXX					; $A504
			EX DE,HL			; $A505
	
			LD B,$10			; $A506  ; process 16 scanlines
DRAW_BY_LINE:
			LD H,$64			; $A508  ; data address 
			LD L,C				; $A50A
			LD A,(HL)			; $A50B  ; get upper screen address
			DEC H				; $A50C
			LD H,(HL)			; $A50D  ; get lower screen address
			OR $00				; $A50E
			LD L,A				; $A510  ; full data address in HL
			INC C				; $A511  ; next data
			LD A,(DE)			; $A512  ; sprite data 
			INC DE				; $A513
			XOR (HL)			; $A514  ; sprite left part
			LD (HL),A			; $A515	
			INC L				; $A516  ; next screen byte
			LD A,(DE)			; $A517
			INC DE				; $A518  ; sprite data 
			XOR (HL)			; $A519
			LD (HL),A			; $A51A  ; sprite right part
	
			
			EXX					; $A51B ; Blending Mask section
				LD H,$64			; $A51C  ; data address 
				LD L,C				; $A51E  ; next data
				LD A,(HL)			; $A51F	 ; upper
				DEC H				; $A520
				LD H,(HL)			; $A521  ; lower
				OR $00				; $A522
				LD L,A				; $A524
				INC C				; $A525
				LD A,(DE)			; $A526  ; mask data 
				XOR (HL)			; $A527		
				LD (HL),A			; $A528	 ; mask left (XOR blended)
				INC L				; $A529  ; next screen byte
				INC DE				; $A52A
				LD A,(DE)			; $A52B  ; mask data 
				XOR (HL)			; $A52C		
				LD (HL),A			; $A52D	 ; mask right (XOR blended)
				INC DE				; $A52E  ; advance sprite data
			EXX					; $A52F

			DJNZ DRAW_BY_LINE	; $A530  ; next scanline
			LD HL,(LABELSPR)		; $A532  ; restore modified HL

			POP DE				; $A535
			POP BC				; $A536
			POP AF				; $A537
			RET					; $A538

L_A539:		PUSH BC				; $A539
			LD L,A				; $A53A
			LD H,$00			; $A53B
			ADD HL,HL			; $A53D
			ADD HL,HL			; $A53E
			ADD HL,HL			; $A53F
			ADD HL,HL			; $A540
			ADD HL,HL			; $A541
			LD BC,TITLE16X16_DATA			; $A542
			ADD HL,BC			; $A545
			POP BC				; $A546
			RET					; $A547

; Draw 16x16 pixel tiles
; A=Tile index, D=Y coord, E=X coord
DRAW16x16_TILE:
DRAW_TEXT:	

			CP $E9				; $A548
			RET NC				; $A54A  ; max tile graphics index (233-1)
			PUSH AF				; $A54B
			PUSH BC				; $A54C
			PUSH DE				; $A54D
			PUSH HL				; $A54E
			LD L,A				; $A54F	
			LD H,$00			; $A550 ; HL = index index
			ADD HL,HL			; $A552	; X2
			ADD HL,HL			; $A553	; X4
			ADD HL,HL			; $A554 ; X8
			ADD HL,HL			; $A555 ; X16
			ADD HL,HL			; $A556 ; X32 (width 32 pixels)
			LD BC,TITLE16X16_DATA			; $A557 ; Tile Data
			ADD HL,BC			; $A55A ; HL now data with index
			LD A,E				; $A55B ; X coord
			AND $7C				; $A55C ; 
			RRCA				; $A55E ; /2
			RRCA				; $A55F ; /4  (does /4 & $1f)
			LD (X_OFFSET+1),A	; $A560 ; X-offet, Self-Modifying Code 	
			LD C,D				; $A563 ; Y coord
			EX DE,HL			; $A564
			LD B,$10			; $A565	 ; index 16 scanlines tall
TILE_LOOP	LD H,$64			; $A567	 ; lookup tables $6400
			LD L,C				; $A569
			LD A,(HL)			; $A56A
			DEC H				; $A56B
			LD H,(HL)			; $A56C
X_OFFSET:	OR $00				; $A56D  ; value ($A56E) replaced, Self-Modifying Code 
			LD L,A				; $A56F
			INC C				; $A570
			LD A,(DE)			; $A571
			INC DE				; $A572
		 	LD (HL),A			; $A573  ; Draw left tile part
			INC L				; $A574
			LD A,(DE)			; $A575
			INC DE				; $A576
			LD (HL),A			; $A577  ; Draw right tile part
			DJNZ TILE_LOOP		; $A578  ; next Y coord
			POP HL				; $A57A
			POP DE				; $A57B
			POP BC				; $A57C
			POP AF				; $A57D
			RET					; $A57E

; Add colour to 16x16 tiles
; A=Tile col index, D=Y coord, E=X coord
SET_TILE16X16_COL:
			CP $E9				; $A57F
			RET NC				; $A581   ; max tile colour index (233-1)

			PUSH AF				; $A582
			PUSH BC				; $A583
			PUSH DE				; $A584
			PUSH HL				; $A585
			LD L,A				; $A586
			LD H,$00			; $A587
			ADD HL,HL			; $A589  ; X2
			ADD HL,HL			; $A58A  ; X4
			
			LD BC,$E9B9			; $A58B  ; Tile colour data

			ADD HL,BC			; $A58E  ; HL now colour with index
			LD B,H				; $A58F
			LD C,L				; $A590
			CALL GET_ATTRIBUTE_AS_HL			; $A591

			LD A,(BC)			; $A594  ; Colour TL (%FBPPPIII)
			LD (HL),A			; $A595	
			INC L				; $A596
			INC BC				; $A597
			LD A,(BC)			; $A598
			LD (HL),A			; $A599  ; Colour TR (%FBPPPIII)
			INC BC				; $A59A
			LD DE,$001F			; $A59B
			ADD HL,DE			; $A59E
			LD A,(BC)			; $A59F 
			LD (HL),A			; $A5A0  ; Colour BL (%FBPPPIII)
			INC L				; $A5A1
			INC BC				; $A5A2
			LD A,(BC)			; $A5A3
			LD (HL),A			; $A5A4  ; Colour BR (%FBPPPIII)
			POP HL				; $A5A5
			POP DE				; $A5A6
			POP BC				; $A5A7
			POP AF				; $A5A8
			RET					; $A5A9

			defb $01                                            ; $A5AA .
			defb $02,$03,$04,$05,$01,$01,$15,$16				; $A5AB ........
			defb $17,$18,$16,$17,$15,$02,$01,$02				; $A5B3 ........
			defb $48,$FF,$05,$14,$13,$FF,$05,$00				; $A5BB H.......
			defb $15,$01,$02,$03,$15,$00,$1D,$00				; $A5C3 ........
			defb $1F,$FF,$05,$00,$10,$14,$4B,$01				; $A5CB ......K.
			defb $01,$04,$15,$FF,$09,$00,$15,$02				; $A5D3 ........
			defb $01,$01,$01,$05,$15,$FF,$09,$00				; $A5DB ........
			defb $15,$01,$03,$01,$02,$01,$15,$FF				; $A5E3 ........
			defb $09,$00,$15,$04,$01,$01,$01,$02				; $A5EB ........
			defb $15,$FF,$09,$00,$12,$14,$49,$01				; $A5F3 ......I.
			defb $02,$03,$15,$FF,$0A,$00,$1D,$15				; $A5FB ........
			defb $03,$04,$04,$15,$00,$00,$96,$0D				; $A603 ........
			defb $80,$81,$82,$00,$0F,$0E,$0D,$4A				; $A60B .......J
			defb $14,$14,$01,$15,$00,$00,$15,$01				; $A613 ........
			defb $02,$03,$04,$05,$01,$04,$03,$01				; $A61B ........
			defb $01,$02,$02,$03,$04,$05,$02,$03				; $A623 ........
			defb $04,$05,$15,$01,$01,$02,$03,$04				; $A62B ........
			defb $05,$02,$FF,$08,$14,$13,$34,$35				; $A633 ......45
			defb $34,$35,$34,$35,$34,$7C,$00,$4E				; $A63B 45454|.N
			defb $4F,$FF,$0C,$00,$7E,$00,$50,$51				; $A643 O...~.PQ
			defb $FF,$0C,$00,$7E,$00,$52,$53,$FF				; $A64B ...~.RS.
			defb $0C,$00,$7D,$FF,$0F,$00,$7C,$FF				; $A653 ..}...|.
			defb $0D,$00,$27,$28,$7E,$FF,$07,$00				; $A65B ..'(~...
			defb $23,$24,$FF,$04,$00,$29,$2A,$7D				; $A663 #$...)*}
			defb $FF,$07,$00,$25,$26,$00,$00,$00				; $A66B ...%&...
			defb $10,$14,$14,$7C,$FF,$05,$00,$79				; $A673 ...|...y
			defb $FF,$05,$78,$79,$15,$01,$01,$01				; $A67B ..xy....
			defb $02,$03,$01,$02,$03,$04,$05,$01				; $A683 ........
			defb $03,$04,$05,$15,$01,$02,$03,$34				; $A68B .......4
			defb $35,$36,$35,$36,$37,$36,$35,$34				; $A693 56567654
			defb $35,$35,$34,$15,$04,$05,$01,$FF				; $A69B 554.....
			defb $0C,$00,$12,$14,$14,$14,$FF,$0D				; $A6A3 ........
			defb $00,$30,$31,$FF,$0E,$00,$32,$33				; $A6AB .01...23
			defb $FF,$1D,$00,$FF,$04,$EC,$FF,$10				; $A6B3 ........
			defb $00,$FF,$06,$14,$11,$FF,$09,$00				; $A6BB ........
			defb $01,$02,$03,$03,$01,$02,$15,$0D				; $A6C3 ........
			defb $0E,$0F,$0D,$0E,$0F,$0D,$0E,$0E				; $A6CB ........
			defb $01,$01,$04,$01,$15,$19,$1A,$FF				; $A6D3 ........
			defb $09,$1B,$02,$03,$02,$03,$15,$00				; $A6DB ........
			defb $00,$3C,$00,$3C,$00,$3C,$FF,$04				; $A6E3 .<.<.<..
			defb $FA,$FF,$04,$14,$13,$00,$00,$3B				; $A6EB .......;
			defb $F1,$3B,$00,$3D,$FF,$0B,$00,$3D				; $A6F3 .;.=...=
			defb $00,$3B,$F6,$FF,$0E,$00,$3D,$00				; $A6FB .;....=.
			defb $3C,$FF,$0B,$00,$3C,$00,$00,$00				; $A703 <...<...
			defb $3B,$00,$10,$14,$14,$FF,$07,$00				; $A70B ;.......
			defb $3B,$00,$3C,$00,$3B,$00,$15,$01				; $A713 ;.<.;...
			defb $01,$FF,$07,$00,$3D,$00,$3D,$00				; $A71B ....=.=.
			defb $3D,$00,$15,$02,$03,$FF,$05,$00				; $A723 =.......
			defb $10,$FF,$07,$14,$4B,$04,$05,$0C				; $A72B ....K...
			defb $0D,$0E,$0D,$0E,$15,$01,$02,$03				; $A733 ........
			defb $04,$05,$01,$03,$04,$01,$02,$FF				; $A73B ........
			defb $0A,$1B,$1C,$19,$15,$01,$02,$01				; $A743 ........
			defb $00,$00,$00,$2B,$2C,$00,$2B,$2C				; $A74B ...+,.+,
			defb $FF,$04,$00,$12,$14,$14,$49,$FF				; $A753 ......I.
			defb $04,$00,$2D,$00,$00,$2D,$FF,$07				; $A75B ..-..-..
			defb $00,$15,$FF,$0E,$00,$2E,$15,$FF				; $A763 ........
			defb $0A,$00,$E9,$00,$EA,$2F,$2E,$15				; $A76B ...../..
			defb $14,$14,$14,$11,$FF,$05,$00,$2E				; $A773 ........
			defb $2F,$2E,$2F,$2E,$2F,$15,$01,$02				; $A77B /././...
			defb $03,$15,$FF,$04,$00,$2E,$2F,$2E				; $A783 ....../.
			defb $2F,$2E,$2F,$2E,$15,$01,$03,$04				; $A78B /./.....
			defb $15,$00,$00,$2F,$2E,$2F,$2E,$2F				; $A793 .../././
			defb $2E,$2F,$2E,$2F,$15,$01,$02,$02				; $A79B ././....
			defb $4A,$FF,$06,$14,$49,$2F,$2E,$48				; $A7A3 J...I/.H
			defb $14,$4B,$01,$02,$03,$04,$01,$02				; $A7AB .K......
			defb $03,$01,$01,$02,$15,$2E,$2F,$15				; $A7B3 ....../.
			defb $01,$02,$FF,$A0,$00,$01,$15,$00				; $A7BB ........
			defb $00,$15,$02,$03,$04,$01,$02,$02				; $A7C3 ........
			defb $01,$02,$01,$01,$02,$01,$15,$00				; $A7CB ........
			defb $00,$12,$FF,$08,$14,$49,$03,$02				; $A7D3 .....I..
			defb $02,$15,$FF,$0B,$00,$15,$02,$03				; $A7DB ........
			defb $03,$15,$FF,$09,$00,$10,$14,$4B				; $A7E3 .......K
			defb $02,$03,$04,$15,$FF,$09,$00,$15				; $A7EB ........
			defb $01,$01,$01,$02,$04,$15,$FF,$09				; $A7F3 ........
			defb $00,$15,$01,$02,$03,$04,$01,$15				; $A7FB ........
			defb $FF,$09,$00,$12,$14,$14,$49,$01				; $A803 ......I.
			defb $02,$15,$EB,$FF,$0B,$00,$15,$01				; $A80B ........
			defb $03,$4A,$14,$11,$FF,$08,$00,$10				; $A813 .J......
			defb $14,$4B,$01,$04,$01,$02,$15,$00				; $A81B .K......
			defb $00,$ED,$ED,$FF,$04,$00,$15,$02				; $A823 ........
			defb $01,$02,$7C,$FF,$05,$00,$79,$FF				; $A82B ..|...y.
			defb $05,$78,$79,$15,$03,$01,$7D,$FF				; $A833 .xy...}.
			defb $06,$00,$3C,$00,$3C,$F6,$3C,$00				; $A83B ..<.<.<.
			defb $12,$14,$14,$7D,$FF,$06,$00,$3B				; $A843 ...}...;
			defb $F6,$3D,$00,$3B,$FF,$04,$00,$7E				; $A84B .=.;...~
			defb $FF,$06,$00,$3B,$00,$00,$00,$3D				; $A853 ...;...=
			defb $FF,$04,$00,$7C,$FF,$06,$00,$3D				; $A85B ...|...=
			defb $00,$3C,$FF,$06,$00,$7D,$FF,$08				; $A863 .<...}..
			defb $00,$3B,$00,$3C,$FF,$04,$00,$7E				; $A86B .;.<...~
			defb $FF,$06,$00,$3C,$00,$3B,$00,$3B				; $A873 ...<.;.;
			defb $00,$10,$14,$14,$7D,$FF,$05,$00				; $A87B ....}...
			defb $E9,$3D,$00,$3D,$00,$3D,$00,$15				; $A883 .=.=.=..
			defb $03,$04,$7C,$0C,$80,$81,$82,$10				; $A88B ..|.....
			defb $FF,$07,$14,$4B,$02,$01,$7F,$01				; $A893 ...K....
			defb $02,$03,$04,$15,$01,$02,$03,$04				; $A89B ........
			defb $01,$02,$03,$04,$01,$02,$01,$02				; $A8A3 ........
			defb $03,$04,$01,$02,$03,$04,$01,$02				; $A8AB ........
			defb $03,$04,$02,$01,$03,$01,$FF,$10				; $A8B3 ........
			defb $14,$FF,$0A,$00,$47,$FF,$04,$00				; $A8BB ....G...
			defb $7C,$EE,$EE,$EE,$FF,$0C,$00,$7D				; $A8C3 |......}
			defb $FF,$0F,$00,$7E,$FF,$0F,$00,$7C				; $A8CB ...~...|
			defb $14,$14,$11,$FF,$0C,$00,$7D,$01				; $A8D3 ......}.
			defb $03,$15,$00,$00,$00,$E9,$00,$E9				; $A8DB ........
			defb $FF,$06,$00,$7D,$02,$03,$4A,$FF				; $A8E3 ...}..J.
			defb $07,$14,$11,$00,$00,$00,$10,$14				; $A8EB ........
			defb $01,$02,$03,$04,$05,$01,$02,$03				; $A8F3 ........
			defb $04,$05,$15,$00,$00,$00,$15,$01				; $A8FB ........
			defb $01,$02,$03,$04,$01,$15,$79,$FF				; $A903 ......y.
			defb $07,$78,$79,$11,$01,$48,$14,$14				; $A90B .xy..H..
			defb $14,$13,$00,$00,$30,$31,$FF,$05				; $A913 ....01..
			defb $00,$15,$02,$15,$FF,$06,$00,$32				; $A91B .......2
			defb $33,$FF,$05,$00,$15,$03,$15,$FF				; $A923 3.......
			defb $0D,$00,$15,$14,$13,$FF,$08,$00				; $A92B ........
			defb $85,$83,$84,$86,$00,$15,$7C,$FF				; $A933 ......|.
			defb $09,$00,$87,$00,$00,$87,$00,$15				; $A93B ........
			defb $7C,$FF,$09,$00,$87,$00,$00,$87				; $A943 |.......
			defb $00,$15,$7D,$FF,$09,$00,$87,$00				; $A94B ..}.....
			defb $00,$87,$00,$15,$FF,$05,$14,$11				; $A953 ........
			defb $FF,$04,$00,$88,$89,$8A,$88,$00				; $A95B ........
			defb $15,$01,$02,$03,$04,$05,$15,$00				; $A963 ........
			defb $00,$10,$FF,$06,$14,$4B,$01,$02				; $A96B .....K..
			defb $15,$04,$01,$02,$03,$15,$02,$03				; $A973 ........
			defb $15,$00,$00,$15,$01,$02,$01,$02				; $A97B ........
			defb $15,$34,$35,$36,$34,$12,$14,$14				; $A983 .4564...
			defb $13,$00,$00,$12,$14,$49,$48,$14				; $A98B .....IH.
			defb $13,$FF,$0C,$00,$15,$15,$FF,$0E				; $A993 ........
			defb $00,$15,$15,$FF,$0E,$00,$15,$15				; $A99B ........
			defb $FF,$0E,$00,$15,$15,$FF,$0C,$00				; $A9A3 ........
			defb $27,$28,$15,$15,$FF,$0C,$00,$29				; $A9AB '(.....)
			defb $2A,$15,$15,$FF,$0B,$00,$10,$14				; $A9B3 *.......
			defb $14,$4B,$15,$FF,$05,$00,$ED,$ED				; $A9BB .K......
			defb $ED,$00,$00,$00,$15,$01,$02,$03				; $A9C3 ........
			defb $FF,$A0,$00,$01,$02,$03,$15,$FF				; $A9CB ........
			defb $08,$00,$15,$01,$03,$02,$02,$01				; $A9D3 ........
			defb $02,$15,$FF,$08,$00,$15,$01,$02				; $A9DB ........
			defb $03,$01,$48,$14,$13,$FF,$08,$00				; $A9E3 ..H.....
			defb $12,$14,$49,$01,$02,$15,$FF,$0C				; $A9EB ..I.....
			defb $00,$15,$02,$03,$15,$20,$FF,$0B				; $A9F3 ..... ..
			defb $00,$15,$02,$04,$4A,$14,$11,$FF				; $A9FB ....J...
			defb $0A,$00,$12,$14,$01,$02,$03,$15				; $AA03 ........
			defb $FF,$0C,$00,$04,$01,$03,$15,$FF				; $AA0B ........
			defb $07,$00,$27,$28,$00,$00,$00,$03				; $AA13 ..'(....
			defb $04,$01,$15,$00,$00,$22,$FF,$04				; $AA1B ....."..
			defb $00,$29,$2A,$00,$00,$00,$14,$14				; $AA23 .)*.....
			defb $14,$4B,$19,$1A,$FF,$0A,$1B,$01				; $AA2B .K......
			defb $02,$04,$03,$01,$15,$04,$01,$02				; $AA33 ........
			defb $03,$04,$05,$01,$02,$03,$04,$05				; $AA3B ........
			defb $04,$03,$03,$02,$15,$34,$35,$36				; $AA43 .....456
			defb $37,$35,$36,$35,$37,$35,$34,$02				; $AA4B 7565754.
			defb $03,$04,$05,$01,$15,$FF,$0A,$00				; $AA53 ........
			defb $03,$04,$01,$01,$02,$15,$FF,$0A				; $AA5B ........
			defb $00,$03,$04,$01,$02,$04,$15,$FF				; $AA63 ........
			defb $0A,$00,$FF,$05,$14,$13,$FF,$15				; $AA6B ........
			defb $00,$94,$95,$FF,$04,$00,$91,$00				; $AA73 ........
			defb $91,$00,$91,$FF,$05,$00,$3C,$00				; $AA7B ......<.
			defb $46,$46,$00,$00,$92,$93,$92,$93				; $AA83 FF......
			defb $92,$FF,$04,$00,$0E,$3D,$0C,$4C				; $AA8B .....=.L
			defb $4D,$0D,$FF,$07,$1B,$1C,$19,$0C				; $AA93 M.......
			defb $02,$02,$03,$04,$05,$01,$01,$02				; $AA9B ........
			defb $15,$04,$15,$FF,$05,$78,$79,$00				; $AAA3 .....xy.
			defb $00,$00,$15,$01,$34,$34,$12,$14				; $AAAB ....44..
			defb $13,$00,$3C,$00,$3C,$FF,$05,$00				; $AAB3 ..<.<...
			defb $15,$02,$FF,$06,$00,$3D,$F1,$3B				; $AABB .....=.;
			defb $FF,$05,$00,$15,$04,$FF,$08,$00				; $AAC3 ........
			defb $3B,$FF,$05,$00,$15,$02,$FF,$06				; $AACB ;.......
			defb $00,$3C,$00,$3D,$FF,$05,$00,$15				; $AAD3 .<.=....
			defb $03,$FF,$06,$00,$3B,$FF,$07,$00				; $AADB ....;...
			defb $15,$01,$FF,$06,$00,$3B,$00,$3C				; $AAE3 .....;.<
			defb $FF,$05,$00,$15,$04,$FF,$06,$00				; $AAEB ........
			defb $3B,$00,$3B,$FF,$05,$00,$15,$03				; $AAF3 ;.;.....
			defb $0C,$0D,$0C,$00,$00,$00,$3D,$00				; $AAFB ......=.
			defb $3D,$FF,$05,$00,$15,$02,$02,$04				; $AB03 =.......
			defb $05,$0E,$19,$1A,$1B,$1B,$1B,$1C				; $AB0B ........
			defb $19,$16,$17,$18,$15,$01,$01,$04				; $AB13 ........
			defb $03,$02,$01,$15,$00,$00,$15,$01				; $AB1B ........
			defb $02,$03,$04,$04,$04,$01,$02,$48				; $AB23 .......H
			defb $14,$14,$14,$4B,$00,$00,$4A,$14				; $AB2B ...K..J.
			defb $14,$14,$49,$03,$03,$02,$03,$15				; $AB33 ..I.....
			defb $FF,$0A,$00,$15,$02,$02,$02,$04				; $AB3B ........
			defb $15,$FF,$0A,$00,$15,$01,$01,$03				; $AB43 ........
			defb $01,$15,$FF,$08,$00,$2E,$00,$12				; $AB4B ........
			defb $14,$14,$14,$02,$15,$FF,$08,$00				; $AB53 ........
			defb $FA,$FF,$05,$00,$03,$15,$00,$46				; $AB5B .......F
			defb $46,$00,$00,$46,$46,$00,$00,$00				; $AB63 F..FF...
			defb $10,$14,$14,$14,$04,$15,$00,$4C				; $AB6B .......L
			defb $4D,$00,$46,$4C,$4D,$00,$00,$00				; $AB73 M.FLM...
			defb $15,$01,$02,$03,$04,$4A,$FF,$0A				; $AB7B .....J..
			defb $14,$4B,$04,$01,$02,$01,$02,$03				; $AB83 .K......
			defb $04,$01,$02,$04,$04,$01,$02,$03				; $AB8B ........
			defb $04,$01,$02,$03,$04,$15,$FF,$0B				; $AB93 ........
			defb $00,$15,$01,$02,$03,$15,$8D,$FF				; $AB9B ........
			defb $0A,$00,$15,$01,$02,$03,$15,$90				; $ABA3 ........
			defb $FF,$0A,$00,$12,$14,$49,$03,$15				; $ABAB .....I..
			defb $8D,$FF,$0B,$00,$FD,$15,$01,$13				; $ABB3 ........
			defb $8F,$8D,$FF,$0A,$00,$FD,$15,$02				; $ABBB ........
			defb $00,$8D,$8F,$8D,$FF,$09,$00,$FD				; $ABC3 ........
			defb $15,$03,$11,$8F,$8D,$8F,$8D,$00				; $ABCB ........
			defb $00,$46,$46,$00,$23,$24,$00,$FD				; $ABD3 .FF.#$..
			defb $15,$04,$15,$8D,$8F,$8D,$8F,$8D				; $ABDB ........
			defb $8D,$4C,$4D,$00,$25,$26,$00,$FD				; $ABE3 .LM.%&..
			defb $15,$04,$4A,$FF,$0D,$14,$4B,$04				; $ABEB ..J...K.
			defb $01,$02,$02,$03,$04,$01,$02,$03				; $ABF3 ........
			defb $04,$01,$03,$04,$01,$02,$03,$04				; $ABFB ........
			defb $FF,$A0,$00,$01,$02,$48,$FF,$0D				; $AC03 .....H..
			defb $14,$04,$03,$15,$00,$00,$3C,$00				; $AC0B ......<.
			defb $3C,$00,$3C,$00,$3C,$FF,$04,$00				; $AC13 <.<.<...
			defb $02,$01,$15,$00,$00,$3D,$00,$3B				; $AC1B .....=.;
			defb $00,$3D,$00,$3B,$00,$10,$14,$14				; $AC23 .=.;....
			defb $04,$01,$15,$FF,$04,$00,$3B,$00				; $AC2B ......;.
			defb $00,$00,$3B,$00,$15,$01,$02,$03				; $AC33 ..;.....
			defb $02,$15,$00,$00,$3C,$F2,$3B,$F6				; $AC3B ....<.;.
			defb $3C,$F2,$3B,$00,$15,$03,$04,$04				; $AC43 <.;.....
			defb $01,$15,$00,$00,$3B,$00,$3D,$00				; $AC4B ....;.=.
			defb $3B,$00,$3D,$00,$15,$01,$02,$04				; $AC53 ;.=.....
			defb $02,$15,$00,$00,$3B,$00,$00,$00				; $AC5B ....;...
			defb $3B,$00,$00,$00,$15,$03,$04,$03				; $AC63 ;.......
			defb $02,$15,$00,$00,$3B,$00,$3C,$00				; $AC6B ....;.<.
			defb $3B,$00,$3C,$00,$15,$01,$02,$04				; $AC73 ;.<.....
			defb $01,$15,$00,$00,$3D,$00,$3B,$00				; $AC7B ....=.;.
			defb $3D,$00,$3B,$00,$15,$03,$04,$01				; $AC83 =.;.....
			defb $02,$15,$00,$10,$FF,$08,$14,$4B				; $AC8B .......K
			defb $01,$02,$FF,$0D,$14,$49,$01,$02				; $AC93 .....I..
			defb $00,$00,$47,$47,$47,$FF,$05,$00				; $AC9B ..GGG...
			defb $30,$31,$00,$15,$03,$04,$14,$11				; $ACA3 01......
			defb $FF,$08,$00,$32,$33,$00,$15,$01				; $ACAB ...23...
			defb $02,$01,$15,$FF,$0B,$00,$15,$04				; $ACB3 ........
			defb $03,$02,$15,$FF,$0B,$00,$15,$05				; $ACBB ........
			defb $01,$03,$15,$FF,$05,$00,$A0,$A1				; $ACC3 ........
			defb $FF,$04,$00,$15,$02,$03,$04,$15				; $ACCB ........
			defb $FF,$05,$00,$A2,$A3,$00,$23,$24				; $ACD3 ......#$
			defb $00,$15,$05,$04,$01,$15,$FF,$05				; $ACDB ........
			defb $00,$A4,$A5,$00,$25,$26,$00,$15				; $ACE3 ....%&..
			defb $01,$02,$02,$15,$FF,$04,$00,$10				; $ACEB ........
			defb $FF,$06,$14,$4B,$03,$03,$03,$15				; $ACF3 ...K....
			defb $FF,$04,$00,$15,$01,$02,$03,$04				; $ACFB ........
			defb $05,$01,$02,$01,$02,$01,$02,$03				; $AD03 ........
			defb $04,$03,$02,$01,$04,$03,$02,$01				; $AD0B ........
			defb $05,$04,$03,$01,$02,$01,$01,$02				; $AD13 ........
			defb $03,$48,$FF,$0B,$14,$02,$01,$03				; $AD1B .H......
			defb $02,$15,$00,$4E,$4F,$FF,$08,$00				; $AD23 ...NO...
			defb $03,$48,$14,$14,$13,$00,$50,$51				; $AD2B .H....PQ
			defb $FF,$08,$00,$04,$15,$FF,$04,$00				; $AD33 ........
			defb $52,$53,$FF,$08,$00,$01,$15,$FF				; $AD3B RS......
			defb $0E,$00,$02,$15,$00,$00,$8D,$FF				; $AD43 ........
			defb $05,$00,$8D,$E9,$8D,$00,$00,$00				; $AD4B ........
			defb $03,$15,$00,$8D,$8F,$8D,$00,$8D				; $AD53 ........
			defb $00,$8D,$8F,$8D,$8F,$8D,$00,$00				; $AD5B ........
			defb $04,$4A,$14,$14,$49,$8F,$8D,$8F				; $AD63 .J..I...
			defb $8D,$8F,$8D,$8F,$48,$14,$14,$14				; $AD6B ....H...
			defb $01,$02,$03,$01,$15,$8D,$8F,$8D				; $AD73 ........
			defb $8F,$8D,$8F,$8D,$15,$01,$02,$03				; $AD7B ........
			defb $01,$02,$03,$04,$05,$02,$03,$04				; $AD83 ........
			defb $05,$01,$02,$03,$04,$05,$02,$01				; $AD8B ........
			defb $FF,$06,$14,$9A,$9B,$9C,$FF,$05				; $AD93 ........
			defb $14,$49,$01,$FF,$07,$00,$47,$FF				; $AD9B .I....G.
			defb $06,$00,$15,$02,$FF,$0E,$00,$15				; $ADA3 ........
			defb $03,$FF,$0C,$00,$0B,$00,$15,$04				; $ADAB ........
			defb $FF,$06,$00,$A0,$A1,$FF,$04,$00				; $ADB3 ........
			defb $0A,$00,$15,$05,$FF,$04,$00,$46				; $ADBB .......F
			defb $46,$A2,$A3,$46,$00,$00,$00,$09				; $ADC3 F..F....
			defb $00,$15,$02,$00,$00,$E9,$00,$4E				; $ADCB .......N
			defb $4F,$A4,$A5,$4E,$4F,$00,$06,$07				; $ADD3 O..NO...
			defb $08,$15,$03,$14,$14,$14,$9A,$FF				; $ADDB ........
			defb $06,$9B,$9C,$14,$14,$14,$4B,$04				; $ADE3 ......K.
			defb $05,$02,$03,$04,$05,$01,$02,$03				; $ADEB ........
			defb $01,$02,$02,$03,$04,$05,$02,$05				; $ADF3 ........
			defb $04,$02,$03,$04,$02,$01,$03,$04				; $ADFB ........
			defb $01,$02,$05,$04,$01,$02,$03,$01				; $AE03 ........
			defb $03,$01,$48,$FF,$0D,$14,$01,$02				; $AE0B ..H.....
			defb $15,$FF,$07,$00,$FF,$05,$F8,$00				; $AE13 ........
			defb $02,$03,$15,$00,$00,$10,$14,$14				; $AE1B ........
			defb $2E,$2F,$2E,$FF,$05,$14,$05,$01				; $AE23 ./......
			defb $15,$00,$00,$15,$FE,$FF,$05,$00				; $AE2B ........
			defb $FC,$19,$1A,$1B,$03,$04,$15,$00				; $AE33 ........
			defb $00,$12,$14,$14,$2F,$2E,$2F,$14				; $AE3B ...././.
			defb $14,$14,$49,$02,$01,$02,$15,$FF				; $AE43 ..I.....
			defb $0B,$00,$15,$04,$03,$04,$15,$00				; $AE4B ........
			defb $00,$00,$93,$00,$93,$00,$93,$00				; $AE53 ........
			defb $00,$00,$15,$03,$01,$02,$4A,$FF				; $AE5B ......J.
			defb $09,$14,$11,$00,$15,$02,$01,$02				; $AE63 ........
			defb $03,$05,$01,$02,$03,$04,$01,$02				; $AE6B ........
			defb $03,$04,$15,$00,$15,$04,$01,$15				; $AE73 ........
			defb $01,$02,$03,$04,$01,$02,$03,$04				; $AE7B ........
			defb $01,$03,$04,$01,$02,$03,$14,$13				; $AE83 ........
			defb $34,$35,$36,$37,$35,$36,$37,$35				; $AE8B 45675675
			defb $34,$35,$34,$36,$35,$34,$FF,$0E				; $AE93 454654..
			defb $00,$48,$14,$14,$11,$FF,$0C,$00				; $AE9B .H......
			defb $15,$01,$01,$15,$FF,$0C,$00,$15				; $AEA3 ........
			defb $02,$02,$15,$FF,$0C,$00,$15,$03				; $AEAB ........
			defb $03,$15,$FF,$0C,$00,$15,$04,$05				; $AEB3 ........
			defb $15,$FF,$0C,$00,$15,$05,$04,$15				; $AEBB ........
			defb $FF,$0C,$00,$15,$01,$01,$15,$ED				; $AEC3 ........
			defb $ED,$ED,$FF,$09,$00,$15,$02,$01				; $AECB ........
			defb $02,$9D,$00,$15,$01,$02,$01,$02				; $AED3 ........
			defb $04,$01,$02,$03,$04,$01,$03,$03				; $AEDB ........
			defb $04,$9F,$00,$15,$01,$02,$03,$04				; $AEE3 ........
			defb $01,$02,$03,$04,$01,$02,$02,$78				; $AEEB .......x
			defb $78,$79,$00,$12,$14,$14,$14,$9A				; $AEF3 xy......
			defb $9B,$9C,$14,$14,$14,$49,$01,$01				; $AEFB .....I..
			defb $79,$FF,$0C,$00,$15,$04,$02,$9D				; $AF03 y.......
			defb $FF,$0C,$00,$9D,$03,$03,$9E,$FF				; $AF0B ........
			defb $0C,$00,$9E,$01,$04,$9E,$FF,$0C				; $AF13 ........
			defb $00,$9F,$01,$04,$9F,$FF,$0C,$00				; $AF1B ........
			defb $15,$04,$01,$79,$78,$79,$FF,$08				; $AF23 ...yxy..
			defb $00,$10,$14,$4B,$04,$02,$03,$04				; $AF2B ...K....
			defb $9D,$00,$00,$ED,$ED,$ED,$00,$00				; $AF33 ........
			defb $00,$15,$01,$02,$03,$04,$15,$00				; $AF3B ........
			defb $00,$00,$F9,$15,$01,$02,$03,$04				; $AF43 ........
			defb $01,$02,$03,$04,$01,$01,$9D,$00				; $AF4B ........
			defb $00,$00,$F9,$15,$02,$03,$04,$01				; $AF53 ........
			defb $02,$03,$04,$01,$02,$02,$9E,$00				; $AF5B ........
			defb $00,$00,$F9,$15,$03,$04,$01,$02				; $AF63 ........
			defb $03,$04,$02,$02,$03,$03,$9E,$FF				; $AF6B ........
			defb $04,$00,$12,$14,$9A,$9B,$9B,$9C				; $AF73 ........
			defb $FF,$04,$14,$04,$9E,$FF,$0E,$00				; $AF7B ........
			defb $01,$9E,$FF,$06,$00,$91,$00,$91				; $AF83 ........
			defb $00,$10,$14,$14,$14,$02,$9E,$00				; $AF8B ........
			defb $A0,$A1,$00,$00,$00,$92,$93,$92				; $AF93 ........
			defb $93,$15,$04,$04,$04,$03,$9F,$00				; $AF9B ........
			defb $A2,$A3,$10,$FF,$06,$14,$4B,$04				; $AFA3 ......K.
			defb $04,$04,$01,$15,$EB,$A4,$A5,$15				; $AFAB ........
			defb $01,$02,$03,$04,$01,$02,$03,$04				; $AFB3 ........
			defb $04,$04,$02,$4A,$14,$14,$14,$4B				; $AFBB ...J...K
			defb $01,$02,$03,$04,$04,$04,$01,$04				; $AFC3 ........
			defb $04,$04,$01,$02,$03,$04,$15,$FF				; $AFCB ........
			defb $07,$00,$15,$01,$02,$03,$01,$48				; $AFD3 .......H
			defb $14,$14,$13,$FF,$07,$00,$15,$01				; $AFDB ........
			defb $02,$01,$02,$15,$FF,$0A,$00,$12				; $AFE3 ........
			defb $14,$49,$02,$14,$13,$FF,$0C,$00				; $AFEB .I......
			defb $9E,$03,$EE,$EE,$FF,$0C,$00,$9E				; $AFF3 ........
			defb $04,$14,$11,$FF,$0C,$00,$9E,$05				; $AFFB ........
			defb $01,$15,$FF,$0A,$00,$10,$14,$4B				; $B003 .......K
			defb $02,$02,$15,$00,$EA,$FF,$08,$00				; $B00B ........
			defb $15,$02,$01,$01,$03,$4A,$9A,$9B				; $B013 .....J..
			defb $9C,$11,$0C,$0D,$80,$81,$82,$0E				; $B01B ........
			defb $15,$02,$01,$05,$01,$02,$03,$04				; $B023 ........
			defb $05,$15,$02,$03,$04,$05,$01,$02				; $B02B ........
			defb $15,$04,$05,$01,$03,$02,$01,$04				; $B033 ........
			defb $03,$02,$01,$04,$03,$02,$01,$03				; $B03B ........
			defb $04,$02,$01,$01,$04,$48,$14,$9A				; $B043 .....H..
			defb $9B,$9C,$14,$9A,$9B,$9C,$FF,$06				; $B04B ........
			defb $14,$01,$15,$FF,$09,$00,$2F,$2E				; $B053 ....../.
			defb $2F,$2E,$00,$02,$15,$00,$97,$98				; $B05B /.......
			defb $FF,$05,$00,$2F,$2E,$48,$14,$14				; $B063 .../.H..
			defb $14,$03,$15,$00,$00,$3C,$FF,$04				; $B06B .....<..
			defb $00,$2F,$2E,$2F,$15,$03,$05,$01				; $B073 ././....
			defb $04,$15,$00,$00,$3B,$00,$00,$00				; $B07B ....;...
			defb $2F,$2E,$2F,$2E,$15,$02,$01,$04				; $B083 /./.....
			defb $04,$15,$E9,$EA,$3D,$00,$2E,$2F				; $B08B ....=../
			defb $2E,$2F,$2E,$2F,$4A,$14,$49,$02				; $B093 ././J.I.
			defb $01,$4A,$FF,$04,$14,$49,$2E,$2F				; $B09B .J...I./
			defb $2E,$2F,$2E,$2F,$2E,$15,$03,$02				; $B0A3 ././....
			defb $04,$01,$02,$03,$04,$15,$00,$2E				; $B0AB ........
			defb $2F,$2E,$2F,$2E,$00,$15,$03,$03				; $B0B3 /./.....
			defb $01,$02,$03,$04,$05,$9D,$FF,$07				; $B0BB ........
			defb $00,$15,$04,$03,$02,$04,$05,$01				; $B0C3 ........
			defb $02,$03,$04,$05,$01,$02,$03,$15				; $B0CB ........
			defb $00,$15,$03,$FF,$0C,$14,$13,$00				; $B0D3 ........
			defb $15,$03,$FF,$0E,$00,$15,$02,$14				; $B0DB ........
			defb $14,$11,$2E,$10,$FF,$04,$14,$11				; $B0E3 ........
			defb $FF,$04,$00,$15,$01,$02,$03,$15				; $B0EB ........
			defb $2F,$15,$01,$02,$03,$04,$15,$00				; $B0F3 /.......
			defb $48,$14,$14,$4B,$04,$05,$01,$15				; $B0FB H..K....
			defb $2E,$15,$04,$02,$05,$01,$15,$00				; $B103 ........
			defb $15,$01,$05,$01,$05,$48,$14,$13				; $B10B .....H..
			defb $2F,$12,$FF,$04,$14,$13,$00,$15				; $B113 /.......
			defb $01,$02,$02,$04,$15,$00,$00,$00				; $B11B ........
			defb $FF,$06,$FA,$00,$15,$03,$04,$03				; $B123 ........
			defb $03,$4A,$FF,$0A,$14,$4B,$05,$01				; $B12B .J...K..
			defb $04,$02,$01,$02,$03,$05,$01,$02				; $B133 ........
			defb $03,$04,$05,$02,$03,$04,$02,$03				; $B13B ........
			defb $05,$01,$02,$15,$FF,$0C,$00,$15				; $B143 ........
			defb $03,$05,$15,$8D,$8F,$8D,$8F,$8D				; $B14B ........
			defb $8F,$8D,$8F,$8D,$8F,$8D,$8F,$15				; $B153 ........
			defb $04,$02,$15,$8E,$8D,$8F,$8D,$8F				; $B15B ........
			defb $8D,$8F,$8D,$8F,$8D,$8E,$8D,$15				; $B163 ........
			defb $04,$03,$15,$00,$00,$8D,$00,$8D				; $B16B ........
			defb $00,$8D,$00,$8D,$00,$00,$00,$15				; $B173 ........
			defb $01,$04,$15,$FF,$0A,$00,$27,$28				; $B17B ......'(
			defb $15,$02,$05,$15,$FF,$0A,$00,$29				; $B183 .......)
			defb $2A,$15,$03,$03,$15,$FF,$0A,$00				; $B18B *.......
			defb $4E,$4F,$15,$04,$02,$15,$FF,$09				; $B193 NO......
			defb $00,$10,$14,$14,$4B,$01,$04,$15				; $B19B ....K...
			defb $FF,$09,$00,$15,$01,$02,$03,$02				; $B1A3 ........
			defb $05,$15,$ED,$ED,$ED,$FF,$06,$00				; $B1AB ........
			defb $15,$03,$04,$01,$02,$01,$02,$03				; $B1B3 ........
			defb $15,$FF,$08,$00,$15,$01,$02,$03				; $B1BB ........
			defb $04,$05,$01,$15,$FF,$08,$00,$15				; $B1C3 ........
			defb $04,$05,$01,$02,$48,$14,$13,$FF				; $B1CB ....H...
			defb $08,$00,$12,$14,$14,$14,$03,$15				; $B1D3 ........
			defb $FF,$0B,$00,$30,$31,$00,$04,$15				; $B1DB ...01...
			defb $FF,$0B,$00,$32,$33,$00,$05,$15				; $B1E3 ...23...
			defb $FF,$0A,$00,$0B,$00,$00,$00,$01				; $B1EB ........
			defb $15,$FF,$06,$00,$A0,$A1,$00,$00				; $B1F3 ........
			defb $0A,$00,$00,$00,$02,$4A,$14,$11				; $B1FB .....J..
			defb $00,$00,$23,$24,$A2,$A3,$00,$00				; $B203 ..#$....
			defb $09,$00,$00,$00,$03,$01,$02,$15				; $B20B ........
			defb $00,$00,$25,$26,$A4,$A5,$00,$06				; $B213 ..%&....
			defb $07,$08,$00,$00,$04,$03,$04,$15				; $B21B ........
			defb $19,$1A,$1B,$1B,$1C,$19,$1A,$FF				; $B223 ........
			defb $05,$1B,$01,$02,$04,$03,$15,$16				; $B22B ........
			defb $17,$18,$16,$17,$18,$16,$17,$15				; $B233 ........
			defb $01,$02,$01,$02,$03,$04,$15,$FF				; $B23B ........
			defb $08,$00,$15,$03,$04,$FF,$04,$14				; $B243 ........
			defb $13,$FF,$08,$00,$12,$14,$14,$00				; $B24B ........
			defb $00,$00,$1D,$FF,$0A,$00,$1F,$FF				; $B253 ........
			defb $1E,$00,$EC,$EC,$EC,$00,$00,$00				; $B25B ........
			defb $23,$24,$FF,$0E,$00,$25,$26,$FF				; $B263 #$...%&.
			defb $0E,$00,$4C,$4D,$00,$00,$00,$E9				; $B26B ..LM....
			defb $00,$EA,$FF,$05,$00,$FF,$05,$1B				; $B273 ........
			defb $1C,$19,$16,$17,$18,$16,$17,$18				; $B27B ........
			defb $16,$17,$18,$01,$02,$03,$15,$01				; $B283 ........
			defb $02,$03,$04,$01,$02,$03,$04,$02				; $B28B ........
			defb $03,$04,$05,$04,$05,$04,$15,$34				; $B293 .......4
			defb $35,$36,$37,$35,$34,$35,$36,$37				; $B29B 56754567
			defb $4E,$4F,$36,$14,$14,$14,$13,$FF				; $B2A3 NO6.....
			defb $09,$00,$50,$51,$FF,$0E,$00,$52				; $B2AB ..PQ...R
			defb $53,$FF,$2F,$00,$A0,$A1,$FF,$08				; $B2B3 S./.....
			defb $00,$27,$28,$00,$46,$46,$00,$A2				; $B2BB .'(.FF..
			defb $A3,$FF,$08,$00,$29,$2A,$46,$4C				; $B2C3 ....)*FL
			defb $4D,$46,$A4,$A5,$16,$17,$18,$16				; $B2CB MF......
			defb $17,$18,$19,$1A,$FF,$08,$1B,$01				; $B2D3 ........
			defb $01,$15,$03,$01,$02,$9E,$FF,$07				; $B2DB ........
			defb $00,$15,$01,$34,$00,$15,$03,$04				; $B2E3 ...4....
			defb $05,$9E,$FF,$07,$00,$15,$02,$00				; $B2EB ........
			defb $00,$15,$01,$02,$03,$9F,$FF,$07				; $B2F3 ........
			defb $00,$15,$03,$00,$00,$15,$04,$05				; $B2FB ........
			defb $01,$15,$FF,$07,$00,$15,$04,$00				; $B303 ........
			defb $00,$12,$14,$14,$14,$13,$FF,$07				; $B30B ........
			defb $00,$15,$01,$FF,$0C,$00,$94,$95				; $B313 ........
			defb $15,$02,$00,$00,$96,$00,$91,$00				; $B31B ........
			defb $91,$FF,$05,$00,$3C,$00,$15,$03				; $B323 ....<...
			defb $00,$00,$15,$93,$92,$93,$92,$0C				; $B32B ........
			defb $0D,$0E,$0D,$0E,$3D,$0C,$15,$04				; $B333 ....=...
			defb $00,$00,$15,$01,$01,$01,$02,$03				; $B33B ........
			defb $04,$05,$01,$02,$03,$04,$15,$01				; $B343 ........
			defb $1C,$19,$15,$02,$03,$01,$02,$03				; $B34B ........
			defb $04,$05,$01,$02,$03,$04,$15,$02				; $B353 ........
			defb $01,$15,$01,$02,$03,$04,$3B,$02				; $B35B ......;.
			defb $3B,$04,$3B,$02,$3B,$04,$15,$01				; $B363 ;.;.;...
			defb $02,$15,$35,$4E,$4F,$35,$3B,$35				; $B36B ..5NO5;5
			defb $3B,$35,$3B,$35,$3D,$34,$15,$02				; $B373 ;5;5=4..
			defb $03,$15,$00,$50,$51,$00,$3D,$00				; $B37B ...PQ.=.
			defb $3B,$00,$3D,$00,$47,$00,$15,$03				; $B383 ;.=.G...
			defb $04,$15,$00,$52,$53,$00,$47,$00				; $B38B ...RS.G.
			defb $3D,$00,$47,$00,$00,$00,$15,$04				; $B393 =.G.....
			defb $01,$15,$FF,$06,$00,$47,$FF,$05				; $B39B .....G..
			defb $00,$15,$01,$02,$15,$FF,$0C,$00				; $B3A3 ........
			defb $15,$02,$03,$15,$FF,$0C,$00,$12				; $B3AB ........
			defb $14,$04,$15,$FF,$09,$00,$E9,$E9				; $B3B3 ........
			defb $00,$00,$00,$01,$15,$FF,$05,$00				; $B3BB ........
			defb $46,$00,$46,$00,$16,$17,$18,$16				; $B3C3 F.F.....
			defb $17,$02,$15,$00,$00,$00,$19,$1A				; $B3CB ........
			defb $FF,$07,$1B,$1C,$19,$01,$15,$FF				; $B3D3 ........
			defb $09,$00,$15,$01,$02,$03,$04,$02				; $B3DB ........
			defb $15,$FF,$09,$00,$15,$04,$05,$01				; $B3E3 ........
			defb $02,$03,$15,$FF,$09,$00,$12,$14				; $B3EB ........
			defb $14,$14,$49,$04,$15,$FF,$0A,$00				; $B3F3 ..I.....
			defb $30,$31,$00,$15,$05,$15,$00,$00				; $B3FB 01......
			defb $00,$A0,$A1,$FF,$05,$00,$32,$33				; $B403 ......23
			defb $00,$15,$01,$15,$00,$00,$00,$A2				; $B40B ........
			defb $A3,$FF,$08,$00,$15,$14,$13,$23				; $B413 .......#
			defb $24,$00,$A4,$A5,$FF,$08,$00,$15				; $B41B $.......
			defb $00,$00,$25,$26,$00,$4E,$4F,$FF				; $B423 ..%&.NO.
			defb $08,$00,$15,$19,$1A,$FF,$05,$1B				; $B42B ........
			defb $1C,$19,$16,$17,$18,$16,$17,$18				; $B433 ........
			defb $15,$01,$02,$03,$04,$01,$02,$03				; $B43B ........
			defb $04,$01,$02,$03,$04,$01,$02,$03				; $B443 ........
			defb $15,$01,$15,$01,$02,$03,$04,$15				; $B44B ........
			defb $01,$02,$03,$15,$05,$04,$03,$02				; $B453 ........
			defb $01,$02,$15,$34,$35,$36,$37,$15				; $B45B ...4567.
			defb $04,$01,$02,$15,$34,$35,$36,$37				; $B463 ....4567
			defb $34,$03,$15,$FF,$04,$00,$12,$14				; $B46B 4.......
			defb $14,$14,$13,$FF,$05,$00,$04,$15				; $B473 ........
			defb $FF,$05,$00,$47,$47,$FF,$07,$00				; $B47B ...GG...
			defb $01,$15,$00,$85,$83,$84,$86,$FF				; $B483 ........
			defb $09,$00,$02,$15,$00,$8B,$00,$00				; $B48B ........
			defb $87,$FF,$09,$00,$03,$15,$00,$87				; $B493 ........
			defb $00,$00,$8B,$FF,$09,$00,$04,$15				; $B49B ........
			defb $00,$87,$00,$00,$87,$00,$46,$46				; $B4A3 ......FF
			defb $FF,$06,$00,$01,$15,$00,$88,$89				; $B4AB ........
			defb $8A,$88,$00,$4C,$4D,$16,$17,$18				; $B4B3 ...LM...
			defb $16,$17,$18,$02,$9A,$FF,$0D,$9B				; $B4BB ........
			defb $9C,$01,$02,$03,$04,$01,$02,$03				; $B4C3 ........
			defb $04,$01,$02,$01,$04,$01,$02,$03				; $B4CB ........
			defb $04,$34,$35,$36,$37,$34,$35,$35				; $B4D3 .4567455
			defb $36,$34,$3C,$35,$3C,$36,$34,$35				; $B4DB 64<5<645
			defb $34,$FF,$09,$00,$3B,$00,$3B,$FF				; $B4E3 4...;.;.
			defb $0D,$00,$3B,$F2,$3D,$FF,$04,$00				; $B4EB ..;.=...
			defb $EE,$FF,$08,$00,$3B,$FF,$0F,$00				; $B4F3 ....;...
			defb $3D,$00,$3C,$FF,$0F,$00,$3B,$FF				; $B4FB =.<...;.
			defb $08,$00,$EB,$FF,$04,$00,$3C,$00				; $B503 ......<.
			defb $3B,$FF,$04,$00,$16,$17,$18,$16				; $B50B ;.......
			defb $17,$18,$16,$17,$18,$3D,$00,$3D				; $B513 .....=.=
			defb $16,$17,$16,$17,$FF,$10,$14,$01				; $B51B ........
			defb $04,$01,$02,$04,$03,$02,$01,$04				; $B523 ........
			defb $03,$02,$01,$04,$02,$03,$01,$34				; $B52B .......4
			defb $35,$36,$37,$34,$35,$35,$35,$36				; $B533 56745556
			defb $37,$34,$35,$36,$37,$34,$34,$EE				; $B53B 7456744.
			defb $EE,$EE,$FF,$1C,$00,$96,$FF,$0F				; $B543 ........
			defb $00,$15,$00,$00,$00,$A0,$A1,$FF				; $B54B ........
			defb $0A,$00,$15,$00,$00,$00,$A2,$A3				; $B553 ........
			defb $00,$00,$46,$46,$00,$46,$46,$00				; $B55B ..FF.FF.
			defb $00,$00,$15,$00,$00,$00,$A4,$A5				; $B563 ........
			defb $00,$00,$4E,$4F,$46,$4E,$4F,$00				; $B56B ..NOFNO.
			defb $00,$00,$15,$19,$1A,$FF,$0A,$1B				; $B573 ........
			defb $1C,$19,$1A,$4B,$01,$02,$03,$04				; $B57B ...K....
			defb $05,$01,$02,$03,$04,$05,$01,$02				; $B583 ........
			defb $03,$04,$05,$04,$01,$02,$03,$04				; $B58B ........
			defb $01,$02,$03,$04,$01,$04,$01,$01				; $B593 ........
			defb $02,$01,$02,$01,$FF,$07,$14,$49				; $B59B .......I
			defb $02,$03,$02,$04,$03,$04,$03,$04				; $B5A3 ........
			defb $FF,$07,$00,$15,$03,$02,$05,$03				; $B5AB ........
			defb $04,$03,$04,$03,$7B,$FF,$06,$00				; $B5B3 ....{...
			defb $15,$FF,$04,$01,$02,$05,$03,$05				; $B5BB ........
			defb $7C,$FF,$06,$00,$15,$01,$04,$02				; $B5C3 |.......
			defb $02,$05,$01,$02,$01,$7D,$FF,$06				; $B5CB .....}..
			defb $00,$15,$02,$02,$02,$05,$02,$02				; $B5D3 ........
			defb $03,$02,$7F,$FF,$06,$00,$12,$FF				; $B5DB ........
			defb $08,$14,$98,$FF,$0F,$00,$96,$FF				; $B5E3 ........
			defb $06,$00,$91,$E9,$91,$E9,$91,$E9				; $B5EB ........
			defb $91,$E9,$10,$15,$19,$1A,$1B,$1B				; $B5F3 ........
			defb $1C,$19,$92,$93,$92,$93,$92,$93				; $B5FB ........
			defb $92,$93,$15,$01,$15,$00,$00,$00				; $B603 ........
			defb $7B,$01,$03,$02,$01,$02,$03,$04				; $B60B {.......
			defb $01,$01,$03,$02,$15,$00,$00,$00				; $B613 ........
			defb $7C,$01,$02,$48,$FF,$05,$14,$49				; $B61B |..H...I
			defb $04,$03,$15,$00,$00,$00,$7D,$03				; $B623 ......}.
			defb $04,$15,$2E,$00,$2E,$00,$2E,$15				; $B62B ........
			defb $01,$01,$15,$00,$00,$00,$7D,$02				; $B633 ......}.
			defb $02,$15,$2F,$E9,$2F,$E9,$2F,$15				; $B63B ../././.
			defb $02,$05,$15,$00,$00,$00,$12,$14				; $B643 ........
			defb $14,$4B,$2E,$2F,$2E,$2F,$2E,$15				; $B64B .K././..
			defb $03,$05,$15,$A0,$A1,$00,$00,$2E				; $B653 ........
			defb $2F,$2E,$2F,$2E,$00,$2E,$00,$15				; $B65B /./.....
			defb $04,$14,$13,$A2,$A3,$00,$00,$2F				; $B663 ......./
			defb $2E,$2F,$2E,$2F,$EA,$2F,$EB,$15				; $B66B ./././..
			defb $05,$00,$00,$A4,$A5,$00,$00,$2E				; $B673 ........
			defb $2F,$2E,$2F,$2E,$2F,$2E,$2F,$15				; $B67B /./././.
			defb $01,$FF,$0E,$14,$4B,$02,$01,$02				; $B683 ....K...
			defb $03,$04,$05,$01,$02,$03,$04,$05				; $B68B ........
			defb $01,$02,$03,$04,$03,$04,$FF,$A0				; $B693 ........
			defb $00,$01,$02,$03,$3B,$05,$3B,$02				; $B69B ....;.;.
			defb $03,$04,$05,$01,$A9,$03,$04,$05				; $B6A3 ........
			defb $01,$01,$48,$A8,$3B,$A8,$3B,$FF				; $B6AB ..H.;.;.
			defb $05,$A8,$13,$34,$35,$36,$37,$02				; $B6B3 ...4567.
			defb $A9,$47,$3D,$00,$3B,$00,$00,$4E				; $B6BB .G=.;..N
			defb $4F,$FF,$06,$00,$03,$A9,$00,$47				; $B6C3 O......G
			defb $00,$3D,$00,$00,$50,$51,$FF,$06				; $B6CB .=..PQ..
			defb $00,$04,$A9,$00,$00,$00,$47,$00				; $B6D3 ......G.
			defb $00,$52,$53,$FF,$06,$00,$05,$A9				; $B6DB .RS.....
			defb $FF,$0E,$00,$01,$A9,$FF,$06,$00				; $B6E3 ........
			defb $27,$28,$FF,$06,$00,$02,$A9,$FF				; $B6EB '(......
			defb $06,$00,$29,$2A,$FF,$06,$00,$03				; $B6F3 ..)*....
			defb $A9,$FF,$05,$00,$10,$14,$14,$14				; $B6FB ........
			defb $11,$0C,$0D,$0E,$0F,$04,$A9,$FF				; $B703 ........
			defb $05,$00,$15,$01,$02,$03,$15,$05				; $B70B ........
			defb $01,$02,$03,$01,$02,$03,$04,$05				; $B713 ........
			defb $01,$02,$03,$04,$05,$01,$02,$03				; $B71B ........
			defb $04,$15,$01,$34,$35,$A6,$A7,$34				; $B723 ...45..4
			defb $A6,$A7,$34,$35,$36,$34,$35,$37				; $B72B ..456457
			defb $34,$15,$01,$00,$00,$47,$47,$00				; $B733 4....GG.
			defb $47,$47,$FF,$07,$00,$15,$02,$FF				; $B73B GG......
			defb $0E,$00,$15,$03,$FF,$0E,$00,$15				; $B743 ........
			defb $04,$FF,$0B,$00,$10,$14,$14,$4B				; $B74B .......K
			defb $01,$FF,$0B,$00,$15,$01,$02,$03				; $B753 ........
			defb $01,$00,$00,$46,$46,$EB,$46,$46				; $B75B ...FF.FF
			defb $FF,$04,$00,$15,$04,$05,$01,$02				; $B763 ........
			defb $0C,$0D,$4E,$4F,$0D,$4E,$4F,$0E				; $B76B ..NO.NO.
			defb $0C,$0D,$0E,$15,$02,$03,$04,$03				; $B773 ........
			defb $01,$02,$03,$04,$01,$02,$03,$04				; $B77B ........
			defb $05,$01,$02,$15,$04,$05,$02,$04				; $B783 ........
			defb $01,$02,$03,$04,$01,$02,$03,$04				; $B78B ........
			defb $05,$01,$02,$05,$04,$01,$02,$03				; $B793 ........
			defb $04,$48,$FF,$0E,$A8,$03,$A9,$00				; $B79B .H......
			defb $1D,$1F,$00,$00,$30,$31,$FF,$07				; $B7A3 ....01..
			defb $00,$02,$A9,$FF,$05,$00,$32,$33				; $B7AB ......23
			defb $00,$00,$00,$FF,$04,$EC,$01,$A9				; $B7B3 ........
			defb $FF,$0E,$00,$05,$A9,$FF,$0E,$00				; $B7BB ........
			defb $04,$A9,$FF,$0E,$00,$03,$A9,$FF				; $B7C3 ........
			defb $0D,$00,$7B,$02,$A9,$FF,$0D,$00				; $B7CB ..{.....
			defb $7C,$01,$A9,$FF,$0D,$00,$7D,$01				; $B7D3 |.....}.
			defb $02,$A9,$19,$1A,$FF,$0B,$1B,$A8				; $B7DB ........
			defb $A8,$13,$FF,$29,$00,$FF,$04,$EC				; $B7E3 ...)....
			defb $FF,$21,$00,$EA,$FF,$0E,$00,$14				; $B7EB .!......
			defb $14,$11,$FF,$0D,$00,$02,$03,$15				; $B7F3 ........
			defb $00,$00,$EB,$FF,$0A,$00,$01,$02				; $B7FB ........
			defb $15,$19,$1A,$1B,$1C,$19,$18,$16				; $B803 ........
			defb $17,$18,$16,$17,$18,$16,$FF,$05				; $B80B ........
			defb $1B,$1C,$19,$1A,$FF,$08,$1B,$00				; $B813 ........
			defb $00,$00,$30,$31,$00,$00,$00,$A6				; $B81B ..01....
			defb $A7,$FF,$09,$00,$32,$33,$00,$00				; $B823 ....23..
			defb $00,$47,$47,$FF,$22,$00,$FF,$04				; $B82B .GG."...
			defb $EC,$FF,$38,$00,$0C,$0D,$0C,$0D				; $B833 ..8.....
			defb $0E,$0C,$0E,$0E,$17,$18,$16,$17				; $B83B ........
			defb $18,$16,$17,$0C,$02,$03,$04,$05				; $B843 ........
			defb $02,$03,$01,$01,$FF,$05,$1B,$1C				; $B84B ........
			defb $19,$15,$01,$02,$03,$04,$05,$01				; $B853 ........
			defb $02,$03,$FF,$07,$00,$12,$FF,$06				; $B85B ........
			defb $14,$49,$04,$FF,$0C,$00,$F8,$2F				; $B863 .I...../
			defb $15,$05,$FF,$0C,$00,$2F,$2E,$15				; $B86B ...../..
			defb $01,$FF,$0A,$00,$F8,$2F,$2E,$2F				; $B873 ....././
			defb $15,$02,$FF,$0A,$00,$2F,$2E,$2F				; $B87B ....././
			defb $2E,$15,$04,$00,$00,$00,$46,$46				; $B883 ......FF
			defb $00,$00,$00,$F8,$2F,$2E,$2F,$2E				; $B88B ...././.
			defb $2F,$15,$03,$00,$00,$00,$4C,$4D				; $B893 /.....LM
			defb $00,$F8,$00,$2F,$2E,$2F,$2E,$2F				; $B89B .../././
			defb $2E,$15,$01,$0E,$0C,$10,$FF,$09				; $B8A3 ........
			defb $A8,$49,$2F,$15,$02,$01,$02,$A9				; $B8AB .I/.....
			defb $04,$05,$02,$03,$04,$05,$02,$04				; $B8B3 ........
			defb $05,$A9,$2E,$15,$02,$05,$01,$02				; $B8BB ........
			defb $03,$04,$05,$01,$02,$03,$04,$05				; $B8C3 ........
			defb $01,$02,$03,$02,$01,$04,$48,$FF				; $B8CB ......H.
			defb $0E,$A8,$03,$15,$00,$A6,$A7,$00				; $B8D3 ........
			defb $A6,$A7,$00,$A6,$A7,$00,$A6,$A7				; $B8DB ........
			defb $00,$00,$02,$15,$00,$47,$47,$00				; $B8E3 .....GG.
			defb $47,$47,$00,$47,$47,$00,$47,$47				; $B8EB GG.GG.GG
			defb $00,$7B,$01,$15,$FF,$0D,$00,$7D				; $B8F3 .{.....}
			defb $05,$15,$E9,$EA,$EB,$FF,$0A,$00				; $B8FB ........
			defb $7E,$04,$4A,$14,$14,$14,$11,$FF				; $B903 ~.J.....
			defb $09,$00,$7E,$03,$01,$02,$03,$04				; $B90B ..~.....
			defb $15,$FF,$09,$00,$7D,$02,$48,$14				; $B913 ....}.H.
			defb $14,$14,$13,$FF,$09,$00,$7C,$01				; $B91B ......|.
			defb $15,$FF,$0D,$00,$7D,$01,$02,$03				; $B923 ....}...
			defb $04,$05,$01,$02,$03,$04,$01,$03				; $B92B ........
			defb $03,$04,$05,$7C,$01,$19,$1A,$1B				; $B933 ...|....
			defb $1B,$1B,$1C,$19,$1A,$FF,$04,$1B				; $B93B ........
			defb $1C,$19,$7C,$01,$FF,$08,$00,$47				; $B943 ..|....G
			defb $00,$30,$31,$00,$00,$7D,$02,$14				; $B94B .01..}..
			defb $14,$11,$FF,$07,$00,$32,$33,$00				; $B953 .....23.
			defb $00,$7E,$03,$01,$02,$15,$FF,$0B				; $B95B .~......
			defb $00,$7C,$04,$03,$05,$15,$FF,$0B				; $B963 .|......
			defb $00,$7D,$05,$01,$04,$15,$FF,$0B				; $B96B .}......
			defb $00,$7E,$01,$02,$03,$15,$FF,$0B				; $B973 .~......
			defb $00,$7C,$02,$04,$05,$15,$FF,$0B				; $B97B .|......
			defb $00,$7D,$03,$01,$02,$15,$FF,$04				; $B983 .}......
			defb $ED,$FF,$07,$00,$7E,$04,$01,$A9				; $B98B ....~...
			defb $EF,$EF,$EF,$00,$00,$15,$02,$03				; $B993 ........
			defb $04,$15,$01,$02,$03,$04,$01,$A9				; $B99B ........
			defb $FF,$05,$00,$15,$01,$02,$03,$15				; $B9A3 ........
			defb $34,$35,$36,$34,$02,$A9,$FF,$05				; $B9AB 4564....
			defb $00,$12,$14,$14,$14,$13,$FF,$04				; $B9B3 ........
			defb $00,$03,$A9,$FF,$06,$00,$30,$31				; $B9BB ......01
			defb $FF,$06,$00,$04,$A9,$FF,$06,$00				; $B9C3 ........
			defb $32,$33,$FF,$06,$00,$05,$A9,$FF				; $B9CB 23......
			defb $0E,$00,$01,$A9,$00,$23,$24,$FF				; $B9D3 .....#$.
			defb $0B,$00,$02,$A9,$22,$25,$26,$20				; $B9DB ...."%& 
			defb $FF,$0A,$00,$03,$4A,$FF,$04,$A8				; $B9E3 ....J...
			defb $11,$FF,$09,$00,$04,$01,$02,$03				; $B9EB ........
			defb $04,$01,$A9,$16,$17,$18,$16,$17				; $B9F3 ........
			defb $18,$16,$17,$18,$01,$01,$02,$03				; $B9FB ........
			defb $3B,$05,$3B,$03,$3B,$05,$01,$15				; $BA03 ;.;.;...
			defb $03,$04,$05,$01,$34,$36,$34,$35				; $BA0B ....4645
			defb $3D,$37,$3B,$35,$3B,$37,$34,$15				; $BA13 =7;5;74.
			defb $01,$02,$03,$04,$FF,$04,$00,$47				; $BA1B .......G
			defb $E9,$3D,$EA,$3B,$EB,$00,$12,$A8				; $BA23 .=.;....
			defb $A8,$49,$01,$FF,$06,$00,$47,$00				; $BA2B .I....G.
			defb $3D,$FF,$05,$00,$A9,$02,$FF,$08				; $BA33 =.......
			defb $00,$47,$FF,$05,$00,$A9,$03,$FF				; $BA3B .G......
			defb $0E,$00,$A9,$04,$FF,$0E,$00,$A9				; $BA43 ........
			defb $05,$FF,$0E,$00,$A9,$01,$FF,$0E				; $BA4B ........
			defb $00,$A9,$02,$16,$17,$18,$19,$FF				; $BA53 ........
			defb $04,$ED,$FF,$06,$00,$A9,$02,$01				; $BA5B ........
			defb $A9,$EF,$EF,$EF,$FF,$0A,$00,$9D				; $BA63 ........
			defb $02,$A9,$FF,$0D,$00,$9E,$03,$A9				; $BA6B ........
			defb $FF,$0D,$00,$9E,$04,$A9,$FF,$0D				; $BA73 ........
			defb $00,$9E,$05,$A9,$FF,$05,$00,$27				; $BA7B .......'
			defb $28,$FF,$06,$00,$9E,$01,$A9,$FF				; $BA83 (.......
			defb $05,$00,$29,$2A,$FF,$06,$00,$9E				; $BA8B ..)*....
			defb $02,$4A,$A8,$A8,$9A,$9B,$9C,$A8				; $BA93 .J......
			defb $A8,$11,$FF,$05,$00,$9F,$03,$01				; $BA9B ........
			defb $02,$03,$04,$05,$01,$02,$03,$A9				; $BAA3 ........
			defb $00,$00,$00,$10,$14,$14,$04,$48				; $BAAB .......H
			defb $A8,$A8,$9A,$9B,$9C,$A8,$A8,$13				; $BAB3 ........
			defb $00,$00,$00,$15,$01,$02,$05,$A9				; $BABB ........
			defb $FF,$0B,$00,$15,$03,$04,$01,$9D				; $BAC3 ........
			defb $16,$17,$18,$16,$17,$18,$16,$17				; $BACB ........
			defb $18,$15,$04,$03,$02,$01,$02,$9E				; $BAD3 ........
			defb $FF,$09,$00,$12,$FF,$04,$14,$03				; $BADB ........
			defb $9E,$FF,$0E,$00,$04,$9E,$FF,$0C				; $BAE3 ........
			defb $00,$3C,$00,$05,$9E,$FF,$0C,$00				; $BAEB .<......
			defb $3B,$00,$01,$9E,$FF,$0C,$00,$3B				; $BAF3 ;......;
			defb $00,$02,$9E,$FF,$0C,$00,$3B,$00				; $BAFB ......;.
			defb $03,$9E,$FF,$0C,$00,$3D,$00,$04				; $BB03 .....=..
			defb $9E,$FF,$0B,$00,$10,$14,$14,$05				; $BB0B ........
			defb $9E,$ED,$ED,$ED,$FF,$08,$00,$15				; $BB13 ........
			defb $01,$02,$01,$02,$03,$04,$05,$01				; $BB1B ........
			defb $02,$03,$04,$05,$01,$02,$03,$02				; $BB23 ........
			defb $01,$01,$FF,$05,$14,$9A,$9B,$9B				; $BB2B ........
			defb $9C,$14,$14,$14,$49,$01,$02,$03				; $BB33 ....I...
			defb $00,$00,$00,$FF,$06,$FE,$00,$00				; $BB3B ........
			defb $00,$15,$01,$04,$03,$FF,$0C,$00				; $BB43 ........
			defb $15,$02,$01,$04,$FF,$0C,$00,$12				; $BB4B ........
			defb $14,$14,$14,$97,$98,$FF,$0F,$00				; $BB53 ........
			defb $3C,$FF,$0A,$00,$91,$00,$91,$00				; $BB5B <.......
			defb $00,$3D,$FF,$0A,$00,$92,$93,$92				; $BB63 .=......
			defb $93,$FF,$05,$14,$9A,$9B,$9B,$9C				; $BB6B ........
			defb $FF,$07,$14,$01,$03,$02,$04,$01				; $BB73 ........
			defb $02,$03,$04,$05,$01,$02,$03,$04				; $BB7B ........
			defb $01,$02,$03,$01,$02,$A9,$01,$02				; $BB83 ........
			defb $03,$3B,$34,$A9,$01,$02,$03,$A9				; $BB8B .;4.....
			defb $00,$15,$01,$03,$04,$A9,$34,$35				; $BB93 ......45
			defb $36,$3B,$00,$A9,$04,$05,$01,$A9				; $BB9B 6;......
			defb $00,$15,$02,$05,$01,$A9,$00,$00				; $BBA3 ........
			defb $00,$3B,$F3,$12,$A8,$A8,$A8,$13				; $BBAB .;......
			defb $00,$15,$03,$04,$02,$A9,$00,$00				; $BBB3 ........
			defb $00,$3B,$FF,$07,$00,$15,$04,$14				; $BBBB .;......
			defb $14,$13,$00,$00,$00,$3D,$00,$3C				; $BBC3 .....=.<
			defb $FF,$05,$00,$15,$05,$FF,$04,$00				; $BBCB ........
			defb $A0,$A1,$00,$00,$3B,$FF,$05,$00				; $BBD3 ....;...
			defb $15,$01,$91,$00,$00,$00,$A2,$A3				; $BBDB ........
			defb $3C,$00,$3B,$FF,$05,$00,$15,$02				; $BBE3 <.;.....
			defb $92,$93,$00,$00,$A4,$A5,$3D,$00				; $BBEB ......=.
			defb $3B,$FF,$05,$00,$15,$03,$FF,$04				; $BBF3 ;.......
			defb $14,$9A,$9B,$9C,$11,$3D,$80,$81				; $BBFB .....=..
			defb $82,$10,$14,$4B,$01,$01,$02,$03				; $BC03 ...K....
			defb $04,$05,$01,$02,$15,$04,$05,$01				; $BC0B ........
			defb $02,$15,$04,$05,$01,$05,$A9,$EF				; $BC13 ........
			defb $EF,$EF,$FF,$0A,$00,$7E,$04,$A9				; $BC1B .....~..
			defb $FF,$0D,$00,$7C,$03,$A9,$FF,$0D				; $BC23 ...|....
			defb $00,$7D,$02,$A9,$FF,$0D,$00,$7E				; $BC2B .}.....~
			defb $01,$A9,$FF,$0D,$00,$7C,$04,$A9				; $BC33 .....|..
			defb $FF,$0D,$00,$7D,$03,$A9,$00,$46				; $BC3B ...}...F
			defb $46,$00,$00,$00,$46,$46,$FF,$05				; $BC43 F...FF..
			defb $00,$7E,$02,$A9,$46,$4C,$4D,$00				; $BC4B .~..FLM.
			defb $46,$00,$4C,$4D,$46,$FF,$04,$00				; $BC53 F.LMF...
			defb $7C,$01,$4A,$FF,$09,$A8,$11,$00				; $BC5B |.J.....
			defb $00,$00,$7E,$01,$02,$03,$04,$05				; $BC63 ..~.....
			defb $01,$02,$03,$04,$05,$01,$A9,$00				; $BC6B ........
			defb $00,$00,$7F,$01,$02,$15,$FF,$0B				; $BC73 ........
			defb $00,$7B,$01,$03,$04,$15,$00,$8D				; $BC7B .{......
			defb $FF,$07,$00,$8D,$00,$7C,$02,$05				; $BC83 .....|..
			defb $01,$9D,$8D,$8F,$8D,$FF,$05,$00				; $BC8B ........
			defb $8D,$8F,$8D,$7D,$03,$02,$03,$9E				; $BC93 ...}....
			defb $00,$8D,$FF,$07,$00,$8D,$00,$7E				; $BC9B .......~
			defb $04,$04,$05,$9E,$FF,$0B,$00,$7C				; $BCA3 .......|
			defb $05,$01,$03,$9E,$FF,$0B,$00,$7D				; $BCAB .......}
			defb $01,$04,$02,$9E,$FF,$0B,$00,$7E				; $BCB3 .......~
			defb $02,$01,$02,$9F,$FF,$0B,$00,$7E				; $BCBB .......~
			defb $03,$03,$04,$15,$FF,$0B,$00,$7C				; $BCC3 .......|
			defb $04,$05,$01,$15,$FF,$04,$ED,$FF				; $BCCB ........
			defb $07,$00,$7D,$05,$01,$01,$01,$02				; $BCD3 ..}.....
			defb $03,$04,$05,$01,$02,$03,$15,$01				; $BCDB ........
			defb $02,$A9,$01,$01,$02,$02,$48,$FF				; $BCE3 ......H.
			defb $07,$14,$13,$34,$36,$A9,$02,$02				; $BCEB ...46...
			defb $03,$03,$15,$FF,$09,$00,$FD,$A9				; $BCF3 ........
			defb $03,$03,$04,$04,$15,$FF,$09,$00				; $BCFB ........
			defb $FD,$A9,$04,$04,$05,$01,$15,$FF				; $BD03 ........
			defb $0A,$00,$12,$A8,$A8,$01,$02,$15				; $BD0B ........
			defb $FF,$0D,$00,$02,$03,$15,$FF,$0D				; $BD13 ........
			defb $00,$03,$04,$15,$FF,$08,$00,$46				; $BD1B .......F
			defb $46,$00,$00,$00,$04,$05,$15,$FF				; $BD23 F.......
			defb $07,$00,$10,$FF,$05,$A8,$01,$01				; $BD2B ........
			defb $15,$FF,$07,$00,$A9,$01,$04,$03				; $BD33 ........
			defb $02,$01,$01,$02,$01,$A9,$FF,$0A				; $BD3B ........
			defb $00,$A9,$01,$01,$02,$03,$A9,$8D				; $BD43 ........
			defb $E9,$8D,$E9,$8D,$E9,$8D,$E9,$8D				; $BD4B ........
			defb $00,$A9,$01,$02,$04,$03,$A9,$8F				; $BD53 ........
			defb $8D,$8F,$8D,$8F,$8D,$8F,$8D,$8F				; $BD5B ........
			defb $8D,$9D,$02,$03,$02,$04,$A9,$8D				; $BD63 ........
			defb $00,$8D,$00,$8D,$00,$8D,$00,$8D				; $BD6B ........
			defb $00,$9E,$03,$A8,$A8,$A8,$13,$FF				; $BD73 ........
			defb $0A,$00,$9E,$04,$2E,$EA,$2E,$EB				; $BD7B ........
			defb $2E,$2F,$FF,$04,$00,$94,$95,$00				; $BD83 ./......
			defb $00,$9F,$05,$91,$8D,$91,$8D,$91				; $BD8B ........
			defb $2E,$FF,$04,$00,$96,$00,$00,$00				; $BD93 ........
			defb $A9,$01,$92,$93,$92,$93,$92,$2F				; $BD9B ......./
			defb $FF,$04,$00,$99,$00,$00,$00,$A9				; $BDA3 ........
			defb $02,$FF,$04,$A8,$9A,$FF,$04,$9B				; $BDAB ........
			defb $9C,$FF,$04,$A8,$4B,$03,$01,$02				; $BDB3 ....K...
			defb $03,$04,$05,$01,$02,$03,$04,$05				; $BDBB ........
			defb $01,$02,$03,$04,$05,$01,$01,$A9				; $BDC3 ........
			defb $EF,$EF,$EF,$FF,$08,$00,$15,$01				; $BDCB ........
			defb $01,$02,$A9,$FF,$0B,$00,$15,$01				; $BDD3 ........
			defb $02,$03,$A9,$FF,$0B,$00,$15,$03				; $BDDB ........
			defb $04,$04,$A9,$FF,$0B,$00,$9D,$05				; $BDE3 ........
			defb $01,$05,$A9,$FF,$0B,$00,$9E,$02				; $BDEB ........
			defb $03,$01,$A9,$A0,$A1,$FF,$09,$00				; $BDF3 ........
			defb $9E,$04,$05,$02,$A9,$A2,$A3,$00				; $BDFB ........
			defb $23,$24,$FF,$06,$00,$9F,$01,$02				; $BE03 #$......
			defb $03,$A9,$A4,$A5,$00,$25,$26,$FF				; $BE0B .....%&.
			defb $06,$00,$15,$03,$04,$04,$4A,$FF				; $BE13 ......J.
			defb $08,$A8,$11,$00,$00,$15,$05,$01				; $BE1B ........
			defb $05,$05,$01,$02,$03,$04,$01,$02				; $BE23 ........
			defb $03,$04,$A9,$00,$00,$15,$02,$03				; $BE2B ........
			defb $01,$A9,$FF,$0B,$00,$15,$01,$02				; $BE33 ........
			defb $02,$A9,$2E,$2F,$2E,$2F,$2E,$2F				; $BE3B .../././
			defb $2E,$2F,$2E,$2F,$2E,$15,$03,$05				; $BE43 ././....
			defb $03,$A9,$8D,$8F,$8D,$8F,$8D,$8F				; $BE4B ........
			defb $8D,$8F,$8D,$8F,$8D,$12,$14,$14				; $BE53 ........
			defb $04,$A9,$00,$8D,$00,$8D,$00,$8D				; $BE5B ........
			defb $00,$8D,$00,$8D,$00,$00,$30,$31				; $BE63 ......01
			defb $05,$A9,$FF,$0C,$00,$32,$33,$01				; $BE6B .....23.
			defb $A9,$FF,$06,$00,$46,$46,$FF,$06				; $BE73 ....FF..
			defb $00,$03,$A9,$FF,$05,$00,$46,$4C				; $BE7B ......FL
			defb $4D,$46,$FF,$05,$00,$03,$A9,$00				; $BE83 MF......
			defb $00,$00,$46,$9A,$FF,$04,$9B,$9C				; $BE8B ..F.....
			defb $46,$00,$00,$00,$01,$4A,$A8,$A8				; $BE93 F....J..
			defb $A8,$9A,$FF,$06,$9B,$9C,$A8,$A8				; $BE9B ........
			defb $A8,$01,$02,$03,$04,$05,$01,$02				; $BEA3 ........
			defb $03,$04,$05,$01,$03,$04,$05,$01				; $BEAB ........
			defb $02,$01,$02,$03,$04,$15,$01,$02				; $BEB3 ........
			defb $03,$04,$05,$01,$02,$03,$04,$03				; $BEBB ........
			defb $04,$05,$01,$03,$02,$15,$34,$35				; $BEC3 ......45
			defb $36,$37,$34,$36,$34,$35,$37,$36				; $BECB 67464576
			defb $34,$FF,$04,$14,$13,$FF,$18,$00				; $BED3 4.......
			defb $EC,$EC,$EC,$FF,$12,$00,$A0,$A1				; $BEDB ........
			defb $FF,$0E,$00,$A2,$A3,$00,$46,$46				; $BEE3 ......FF
			defb $00,$46,$46,$00,$00,$27,$28,$FF				; $BEEB .FF..'(.
			defb $04,$00,$A4,$A5,$46,$4C,$4D,$46				; $BEF3 ....FLMF
			defb $4C,$4D,$46,$00,$29,$2A,$00,$00				; $BEFB LMF.)*..
			defb $FF,$10,$A8,$01,$02,$03,$04,$05				; $BF03 ........
			defb $01,$01,$02,$03,$04,$05,$01,$02				; $BF0B ........
			defb $03,$04,$01,$01,$02,$03,$04,$01				; $BF13 ........
			defb $02,$02,$01,$02,$34,$15,$01,$02				; $BF1B ....4...
			defb $03,$04,$01,$34,$35,$36,$37,$35				; $BF23 ...45675
			defb $34,$35,$36,$35,$00,$12,$14,$9A				; $BF2B 4565....
			defb $9B,$9C,$14,$FF,$1C,$00,$FF,$04				; $BF33 ........
			defb $EC,$FF,$40,$00,$FF,$04,$A8,$11				; $BF3B ..@.....
			defb $0D,$0E,$0C,$0D,$0C,$10,$14,$9A				; $BF43 ........
			defb $9B,$9C,$14,$01,$02,$03,$04,$A9				; $BF4B ........
			defb $01,$02,$03,$04,$05,$15,$02,$03				; $BF53 ........
			defb $04,$05,$02,$01,$01,$02,$03,$04				; $BF5B ........
			defb $04,$04,$01,$02,$03,$04,$15,$00				; $BF63 ........
			defb $00,$00,$7C,$14,$9A,$FF,$07,$9B				; $BF6B ..|.....
			defb $9C,$14,$13,$00,$00,$00,$7D,$FF				; $BF73 ......}.
			defb $06,$00,$30,$31,$00,$30,$31,$FF				; $BF7B ..01.01.
			defb $04,$00,$7E,$FF,$06,$00,$32,$33				; $BF83 ..~...23
			defb $00,$32,$33,$FF,$04,$00,$7E,$FF				; $BF8B .23...~.
			defb $0F,$00,$7D,$FF,$0F,$00,$7C,$00				; $BF93 ..}...|.
			defb $00,$00,$27,$28,$FF,$0A,$00,$7E				; $BF9B ..'(...~
			defb $00,$00,$00,$29,$2A,$FF,$0A,$00				; $BFA3 ...)*...
			defb $7D,$14,$9A,$9B,$9C,$14,$11,$0C				; $BFAB }.......
			defb $0D,$0E,$0F,$0C,$0E,$0F,$0C,$0E				; $BFB3 ........
			defb $7C,$02,$01,$02,$03,$04,$15,$01				; $BFBB |.......
			defb $02,$03,$04,$05,$01,$02,$03,$04				; $BFC3 ........
			defb $7F,$04,$05,$15,$FF,$0B,$00,$9D				; $BFCB ........
			defb $01,$01,$02,$15,$00,$00,$A0,$A1				; $BFD3 ........
			defb $FF,$07,$00,$9E,$02,$03,$04,$15				; $BFDB ........
			defb $23,$24,$A2,$A3,$FF,$07,$00,$9E				; $BFE3 #$......
			defb $03,$01,$02,$15,$25,$26,$A4,$A5				; $BFEB ....%&..
			defb $FF,$07,$00,$9E,$04,$03,$04,$4A				; $BFF3 .......J
			defb $FF,$04,$14,$11,$FF,$06,$00,$9E				; $BFFB ........
			defb $01,$01,$02,$01,$02,$03,$04,$05				; $C003 ........
			defb $15,$FF,$06,$00,$9E,$02,$05,$04				; $C00B ........
			defb $48,$FF,$04,$14,$13,$FF,$06,$00				; $C013 H.......
			defb $9E,$03,$03,$02,$15,$1D,$00,$00				; $C01B ........
			defb $1F,$FF,$07,$00,$9E,$04,$01,$04				; $C023 ........
			defb $15,$FF,$0B,$00,$9E,$01,$03,$04				; $C02B ........
			defb $15,$FF,$08,$00,$ED,$ED,$ED,$9F				; $C033 ........
			defb $02,$01,$02,$15,$FF,$07,$00,$A9				; $C03B ........
			defb $01,$02,$03,$04,$05,$03,$04,$15				; $C043 ........
			defb $FF,$07,$00,$12,$FF,$05,$A8,$05				; $C04B ........
			defb $04,$15,$FF,$08,$00,$30,$31,$00				; $C053 .....01.
			defb $00,$00,$14,$14,$13,$FF,$08,$00				; $C05B ........

			defb $32,$33,$00,$00 ; REMOVED ,$00,$7B,$1D,$FF		; $C063

			; UPDATED TO USE INSTRUCITONS
L_C067:
			NOP					; $C067
			LD A,E				; $C068
			DEC E				; $C069
			RST	 $38			; $C06A
	
			defb $0B,$00,$EC,$EC,$EC,$7C,$00,$00				; $C06B .....|..
			defb $00,$A0,$A1,$FF,$0A,$00,$7D,$00				; $C073 ......}.
			defb $00,$00,$A2,$A3,$FF,$0A,$00,$7D				; $C07B .......}
			defb $00,$00,$00,$A4,$A5,$FF,$0A,$00				; $C083 ........
			defb $9A,$9B,$9C,$14,$14,$14,$9A,$9B				; $C08B ........
			defb $9C,$14,$14,$14,$9A,$9B,$9C,$14				; $C093 ........
			defb $01,$02,$03,$04,$05,$01,$02,$03				; $C09B ........
			defb $04,$05,$01,$02,$03,$04,$05,$01				; $C0A3 ........
			defb $01,$02,$03,$04,$01,$02,$03,$04				; $C0AB ........
			defb $01,$02,$03,$04,$01,$02,$03,$04				; $C0B3 ........
			defb $FF,$06,$A8,$9A,$9B,$9B,$9B,$9C				; $C0BB ........
			defb $FF,$05,$A8,$FF,$06,$00,$2B,$2C				; $C0C3 ......+,
			defb $00,$2B,$2C,$FF,$0C,$00,$2D,$00				; $C0CB .+,...-.
			defb $00,$2D,$FF,$11,$00,$FF,$04,$EC				; $C0D3 .-......
			defb $FF,$16,$00,$46,$46,$FF,$0D,$00				; $C0DB ...FF...
			defb $46,$4C,$4D,$46,$FF,$07,$00,$FF				; $C0E3 FLMF....
			defb $04,$14,$9A,$FF,$04,$9B,$9C,$FF				; $C0EB ........
			defb $06,$14,$01,$02,$03,$04,$05,$01				; $C0F3 ........
			defb $02,$03,$04,$05,$01,$02,$03,$04				; $C0FB ........
			defb $05,$01,$01,$3B,$03,$3B,$05,$3B				; $C103 ...;.;.;
			defb $02,$3B,$04,$3B,$A9,$00,$00,$15				; $C10B .;.;....
			defb $01,$01,$A8,$3B,$A8,$3B,$A8,$3B				; $C113 ...;.;.;
			defb $A8,$3B,$A8,$3B,$13,$00,$00,$15				; $C11B .;.;....
			defb $01,$01,$00,$3B,$00,$3B,$00,$3B				; $C123 ...;.;.;
			defb $00,$3B,$00,$3B,$00,$00,$00,$15				; $C12B .;.;....
			defb $02,$01,$00,$3D,$00,$3B,$F1,$3D				; $C133 ...=.;.=
			defb $00,$3B,$F6,$3D,$00,$00,$00,$15				; $C13B .;.=....
			defb $03,$02,$00,$EA,$F1,$3B,$00,$8D				; $C143 .....;..
			defb $F2,$3B,$00,$EB,$00,$00,$00,$15				; $C14B .;......
			defb $04,$01,$00,$3C,$00,$3D,$00,$3C				; $C153 ...<.=.<
			defb $00,$3D,$00,$3C,$00,$00,$00,$15				; $C15B .=.<....
			defb $05,$03,$00,$3B,$00,$8D,$00,$3B				; $C163 ...;...;
			defb $00,$8D,$00,$3B,$00,$00,$00,$15				; $C16B ...;....
			defb $01,$04,$00,$3B,$00,$3C,$00,$3B				; $C173 ...;.<.;
			defb $00,$3C,$00,$3B,$00,$00,$00,$15				; $C17B .<.;....
			defb $02,$01,$14,$49,$00,$3B,$00,$3B				; $C183 ...I.;.;
			defb $00,$3B,$00,$3B,$00,$00,$00,$15				; $C18B .;.;....
			defb $03,$05,$01,$15,$0D,$3B,$0D,$3B				; $C193 .....;.;
			defb $0F,$3B,$0C,$3B,$0E,$0C,$0E,$15				; $C19B .;.;....
			defb $04,$01,$7B,$02,$03,$04,$3B,$34				; $C1A3 ..{...;4
			defb $3B,$36,$3B,$34,$3B,$36,$3B,$04				; $C1AB ;6;4;6;.
			defb $05,$01,$7C,$34,$35,$36,$3B,$00				; $C1B3 ..|456;.
			defb $3B,$00,$3B,$00,$3B,$00,$3B,$19				; $C1BB ;.;.;.;.
			defb $1A,$1B,$7D,$00,$00,$00,$3D,$00				; $C1C3 ..}...=.
			defb $3B,$00,$3D,$00,$3B,$00,$3D,$00				; $C1CB ;.=.;.=.
			defb $00,$00,$7E,$00,$00,$00,$8D,$F5				; $C1D3 ..~.....
			defb $3B,$F2,$8D,$F5,$3B,$F2,$8D,$00				; $C1DB ;...;...
			defb $00,$00,$7C,$85,$83,$84,$86,$00				; $C1E3 ..|.....
			defb $3D,$00,$3C,$00,$3D,$00,$3C,$00				; $C1EB =.<.=.<.
			defb $00,$00,$7D,$87,$00,$00,$87,$00				; $C1F3 ..}.....
			defb $8D,$00,$3B,$00,$8D,$00,$3B,$00				; $C1FB ..;...;.
			defb $46,$00,$7E,$8B,$00,$00,$8B,$00				; $C203 F.~.....
			defb $3C,$00,$3B,$00,$3C,$00,$3B,$10				; $C20B <.;.<.;.
			defb $14,$14,$7C,$87,$00,$00,$87,$00				; $C213 ..|.....
			defb $3B,$00,$3B,$00,$3B,$00,$3B,$15				; $C21B ;.;.;.;.
			defb $01,$01,$7D,$88,$89,$8A,$88,$0C				; $C223 ..}.....
			defb $3B,$0F,$3B,$0E,$3B,$0C,$3B,$15				; $C22B ;.;.;.;.
			defb $05,$02,$7D,$02,$03,$04,$05,$01				; $C233 ..}.....
			defb $3B,$03,$3B,$05,$3B,$02,$3B,$15				; $C23B ;.;.;.;.
			defb $04,$03,$01,$02,$03,$04,$04,$05				; $C243 ........
			defb $01,$02,$03,$04,$04,$05,$01,$02				; $C24B ........
			defb $05,$04,$FF,$06,$1B,$1C,$19,$1A				; $C253 ........
			defb $FF,$05,$1B,$1C,$19,$FF,$04,$EE				; $C25B ........
			defb $47,$47,$00,$00,$00,$47,$47,$FF				; $C263 GG...GG.
			defb $2B,$00,$A0,$A1,$FF,$08,$00,$14				; $C26B +.......
			defb $14,$14,$11,$23,$24,$A2,$A3,$FF				; $C273 ...#$...
			defb $08,$00,$01,$02,$03,$15,$25,$26				; $C27B ......%&
			defb $A4,$A5,$00,$46,$EA,$46,$EB,$00				; $C283 ...F.F..
			defb $00,$00,$04,$05,$01,$4A,$14,$14				; $C28B .....J..
			defb $14,$9A,$FF,$04,$9B,$9C,$14,$14				; $C293 ........
			defb $14,$01,$02,$03,$04,$05,$01,$02				; $C29B ........
			defb $03,$04,$05,$01,$05,$02,$01,$05				; $C2A3 ........
			defb $01,$01,$02,$03,$04,$04,$01,$03				; $C2AB ........
			defb $04,$05,$01,$A9,$05,$04,$03,$02				; $C2B3 ........
			defb $01,$FF,$0A,$A8,$13,$34,$35,$36				; $C2BB .....456
			defb $37,$34,$FF,$04,$EE,$FF,$04,$00				; $C2C3 74......
			defb $30,$31,$FF,$0E,$00,$32,$33,$FF				; $C2CB 01...23.
			defb $2E,$00,$27,$28,$FF,$09,$00,$20				; $C2D3 ..'(... 
			defb $00,$22,$00,$00,$29,$2A,$FF,$06				; $C2DB ."..)*..
			defb $00,$FF,$0A,$14,$11,$0C,$0D,$0E				; $C2E3 ........
			defb $0F,$0C,$01,$02,$03,$04						; $C2EB ........

;-----------------------------------------------------------------------------------
FONT_DATA:
			; 32 items - ascii front padding (non printable)
			defb $05,$01										; $C2F1  
			defb $02,$04,$03,$01,$15,$02,$01,$03				; $C2F3 ........
			defb $02,$01,$01,$02,$03,$04,$05,$01				; $C2FB ........
			defb $02,$03,$04,$05,$15,$01,$01,$02				; $C303 ........
			defb $03,$04,$34,$36,$34,$35,$36,$37				; $C30B ..464567
			defb $35,$36,$37,$37,$15,$03,$04,$03				; $C313 5677....
			defb $02,$01,$FF,$0A,$00,$15,$03,$01				; $C31B ........
			defb $02,$03,$04,$FF,$0A,$00,$15,$04				; $C323 ........
			defb $04,$03,$02,$01,$FF,$0A,$00,$12				; $C32B ........
			defb $FF,$05,$14,$97,$98,$FF,$0F,$00				; $C333 ........
			defb $91,$FF,$08,$00,$91,$00,$91,$00				; $C33B ........
			defb $91,$00,$0C,$92,$0E,$0E,$80,$81				; $C343 ........
			defb $82,$0E,$0D,$0C,$92,$93,$92,$93				; $C34B ........
			defb $92,$93,$01,$02,$03,$04,$02,$02				; $C353 ........
			defb $03,$04,$05,$01,$02,$01,$04,$03				; $C35B ........
			defb $02,$01,$01,$02,$03,$04,$04,$01				; $C363 ........
			defb $02,$03,$04,$05,$01,$03,$04,$03				; $C36B ........
			defb $02,$03,$01,$02,$15,$FF,$0B,$00				; $C373 ........
			defb $15,$01,$03,$04,$15,$FF,$07,$00				; $C37B ........
			defb $8D,$8F,$8D,$00,$15,$02,$01,$02				; $C383 ........
			defb $4A,$FF,$05,$14,$11,$FF,$05,$8D				; $C38B J.......
			defb $9D,$03,$03,$04,$01,$02,$03,$04				; $C393 ........
			defb $05,$01,$15,$8D,$8F,$8D,$8F,$8D				; $C39B ........
			defb $9E,$04,$14,$14,$9A,$9B,$9B,$9C				; $C3A3 ........
			defb $14,$14,$13,$00,$8D,$00,$8D,$00				; $C3AB ........
			defb $9E,$05,$FF,$0C,$00,$94,$95,$9F				; $C3B3 ........
			defb $01,$91,$00,$91,$00,$91,$FF,$07				; $C3BB ........
			defb $00,$93,$00,$15,$02,$92,$93,$92				; $C3C3 ........
			defb $93,$92,$FF,$07,$00,$93,$00,$15				; $C3CB ........
			defb $03,$FF,$05,$A8,$9A,$9B,$9B,$9B				; $C3D3 ........
			defb $9C,$FF,$04,$A8,$4B,$04,$01,$02				; $C3DB ....K...
			defb $03,$04,$05,$01,$02,$03,$04,$05				; $C3E3 ........
			defb $01,$02,$03,$04,$05,$03						; $C3EB 


			defb $00,$00,$00,$00,$00,$00,$00,$00	; SPACE
			defb $00,$10,$10,$10,$10,$00,$10,$00	; !
			defb $00,$24,$24,$00,$00,$00,$00,$00	; " 
			defb $00,$10,$00,$00,$00,$00,$00,$00	; #
			defb $00,$10,$00,$00,$00,$00,$00,$00	; $ 
			defb $00,$10,$00,$00,$00,$00,$00,$00	; % 
			defb $00,$10,$00,$00,$00,$00,$00,$00	; & 
			defb $08,$08,$10,$00,$00,$00,$00,$00	; ' 
			defb $00,$1C,$10,$10,$10,$10,$1C,$00	; ( 
			defb $00,$38,$08,$08,$08,$08,$38,$00	; )
			defb $FF,$81,$BD,$A1,$A1,$BD,$81,$FF	; * 
			defb $00,$00,$08,$08,$3E,$08,$08,$00	; + 
			defb $00,$00,$00,$00,$00,$08,$08,$10	; ' 
			defb $00,$00,$00,$7E,$00,$00,$00,$00	; -
			defb $00,$00,$00,$00,$00,$00,$18,$00	; . 
			defb $00,$02,$04,$08,$10,$20,$40,$00	; / 
			defb $00,$7E,$46,$4A,$52,$62,$7E,$00	; 0 
			defb $00,$10,$30,$10,$10,$10,$7C,$00	; 1 
			defb $00,$7E,$02,$7E,$40,$40,$7E,$00	; 2 
			defb $00,$7E,$02,$3C,$02,$02,$7E,$00	; 3 
			defb $00,$42,$42,$7E,$02,$02,$02,$00	; 4 
			defb $00,$7E,$40,$7E,$02,$02,$7E,$00	; 5 
			defb $00,$7E,$40,$7E,$42,$42,$7E,$00	; 6 
			defb $00,$7E,$02,$02,$02,$02,$02,$00	; 7 
			defb $00,$7E,$42,$7E,$42,$42,$7E,$00	; 8 
			defb $00,$7E,$42,$42,$7E,$02,$02,$00	; 9 
			defb $00,$00,$00,$38,$38,$00,$38,$38	; : 
			defb $00,$00,$38,$38,$00,$38,$38,$70	; ; 
			defb $00,$1C,$38,$70,$E0,$70,$38,$1C	; < 
			defb $00,$00,$FE,$00,$00,$FE,$00,$00	; = 
			defb $00,$70,$38,$1C,$0E,$1C,$38,$70	; > 
			defb $00,$7C,$E6,$0C,$38,$38,$00,$38	; ? 
			defb $00,$7C,$E6,$EE,$EA,$EE,$E0,$7C	; @
			defb $00,$7E,$42,$7E,$42,$42,$42,$00	; A 
			defb $00,$7E,$42,$7C,$42,$42,$7E,$00	; B 
			defb $00,$7E,$40,$40,$40,$40,$7E,$00	; C 
			defb $00,$7C,$42,$42,$42,$42,$7E,$00	; D 
			defb $00,$7E,$40,$7E,$40,$40,$7E,$00	; E 
			defb $00,$7E,$40,$7E,$40,$40,$40,$00	; F 
			defb $00,$7E,$42,$40,$46,$42,$7E,$00	; G 
			defb $00,$42,$42,$7E,$42,$42,$42,$00	; H 
			defb $00,$7C,$10,$10,$10,$10,$7C,$00	; I 		
			defb $00,$7C,$10,$10,$10,$10,$70,$00	; J 		
			defb $00,$44,$48,$70,$48,$44,$44,$00	; K 		
			defb $00,$40,$40,$40,$40,$40,$7C,$00	; L 
			defb $00,$42,$66,$5A,$42,$42,$42,$00	; M 
			defb $00,$42,$62,$52,$4A,$46,$42,$00	; N 
			defb $00,$7E,$42,$42,$42,$42,$7E,$00	; O 
			defb $00,$7E,$42,$42,$7E,$40,$40,$00	; P 
			defb $00,$7E,$42,$42,$42,$44,$7A,$00	; Q 
			defb $00,$7E,$42,$7E,$48,$44,$42,$00	; R 
			defb $00,$7E,$40,$7E,$02,$02,$7E,$00	; S 
			defb $00,$7C,$10,$10,$10,$10,$10,$00	; T 		
			defb $00,$42,$42,$42,$42,$42,$7E,$00	; U
			defb $00,$42,$42,$42,$42,$24,$18,$00	; V
			defb $00,$42,$42,$42,$5A,$66,$42,$00	; W	
			defb $00,$42,$24,$18,$18,$24,$42,$00	; X	
			defb $00,$44,$28,$10,$10,$10,$10,$00	; Y	
			defb $00,$7E,$04,$08,$10,$20,$7E,$00	; Z
			
			defb $63,$63,$63,$63
			defb $63,$63,$63,$63,$0E,$3E				 
			defb $7E,$FE,$00,$FF,$7F,$0F,$C0,$50				; $C5D3 ~......P
			defb $AC,$55,$00,$FF,$FC,$E0,$00,$77				; $C5DB .U.....w
			defb $EF,$5F,$00,$7B,$FB,$7B,$00,$C0				; $C5E3 ._.{.{..
			defb $BA,$00,$00,$00,$6A,$00,$00,$40				; $C5EB ....j..@
			defb $20,$10,$08,$04,$02,$01,$00,$02				; $C5F3  .......
			defb $04,$08,$10,$20,$40,$00,$00,$02				; $C5FB ... @...
			defb $3C,$1C,$0C,$24,$40,$00,$80,$40				; $C603 <..$@..@
			defb $3C,$38,$30,$24,$02,$00,$00,$00				; $C60B <80$....
			defb $00,$00,$7F,$00,$00,$00,$00,$00				; $C613 ........
			defb $60,$78,$7E,$78,$60,$00,$00,$07				; $C61B `x~x`...
			defb $0F,$18,$32,$36,$36,$34,$00,$C0				; $C623 ..2664..
			defb $E0,$30,$18,$18,$18,$18,$34,$30				; $C62B .0....40
			defb $30,$30,$18,$0F,$07,$00,$18,$58				; $C633 00.....X
			defb $58,$98,$30,$E0,$C0,$00,$1F,$05				; $C63B X.0.....
			defb $05,$05,$02,$02,$01,$00,$FF,$84				; $C643 ........
			defb $84,$84,$C8,$C8,$10,$E0,$01,$02				; $C64B ........
			defb $02,$04,$04,$05,$1F,$00,$10,$08				; $C653 ........
			defb $08,$44,$E4,$F4,$FF,$00,$00,$00				; $C65B .D......
			defb $00,$00,$0C,$3C,$FC,$FC,$0C,$3C				; $C663 ...<...<
			defb $FC,$FC,$FC,$FC,$FC,$FC,$00,$00				; $C66B ........
			defb $00,$00,$0C,$3C,$FC,$00,$0C,$3C				; $C673 ...<...<
			defb $FC,$FC,$FC,$FC,$FC,$00,$FC,$FC				; $C67B ........
			defb $FC,$FC,$FC,$FC,$FC,$00,$FC,$FC				; $C683 ........
			defb $FC,$FC,$FC,$FC,$FC,$00,$0E,$3E				; $C68B .......>
			defb $5E,$6E,$F6,$FA,$FC,$00,$00,$FF				; $C693 ^n......
			defb $00,$FF,$AA,$55,$00,$00,$70,$7C				; $C69B ...U..p|
			defb $7A,$76,$6F,$5F,$3F,$00,$00,$FC				; $C6A3 zvo_?...
			defb $FA,$F6,$6E,$5E,$3E,$0E,$00,$00				; $C6AB ..n^>...
			defb $FF,$00,$FF,$55,$AA,$00,$00,$3F				; $C6B3 ...U...?
			defb $5F,$6F,$76,$7A,$7C,$70,$5A,$5C				; $C6BB _ovz|pZ\
			defb $5A,$5C,$5A,$5C,$5A,$5C,$7E,$40				; $C6C3 Z\Z\Z\~@
			defb $4A,$54,$4A,$54,$4A,$54,$00,$34				; $C6CB JTJTJT.4
			defb $38,$34,$38,$34,$38,$34,$38,$34				; $C6D3 84848484
			defb $38,$34,$28,$14,$28,$00,$7E,$40				; $C6DB 84(.(.~@
			defb $4A,$54,$4A,$54,$4A,$54,$00,$BF				; $C6E3 JTJTJT..
			defb $00,$5F,$AA,$55,$00,$00,$00,$00				; $C6EB ._.U....
			defb $BF,$00,$AF,$55,$AA,$00						; $C6F3 ...U....


;----------------------------------------------------------------------------------
; Sprite Graphics 24x16 
; Note: frames are bit-rotated sprites for pre-calculated X position movement

SPRITE24x16_DATA
			; 00 - 4 blank frames  
			defb $00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; $C6F9
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C703
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C70B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C713
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C71B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C723
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C72B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C733
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C73B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C743
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C74B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C753
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C75B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C763
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C76B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C773
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C77B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C783
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C78B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C793
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C79B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C7A3
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $C7AB
			defb $00,$00,$00,$00,$00,$00						; $C7B3
			;----------------------------------------------------------
			; 01 - Player Ship facing Right (4 rotate frames)
			defb $0E,$C0,$00,$3E,$50,$00,$7E,$AC,$00,$FE		; $C7B9 
			defb $55,$00,$00,$00,$00,$FF,$FF,$00				; $C7C3 
			defb $7F,$FC,$00,$0F,$E0,$00,$00,$00				; $C7CB 
			defb $00,$77,$C0,$00,$EF,$BA,$00,$5F				; $C7D3 
			defb $00,$00,$00,$00,$00,$7B,$00,$00				; $C7DB 
			defb $FB,$6A,$00,$7B,$00,$00,$03,$B0				; $C7E3 
			defb $00,$0F,$94,$00,$1F,$AB,$00,$3F				; $C7EB 
			defb $95,$40,$00,$00,$00,$3F,$FF,$C0				; $C7F3 
			defb $1F,$FF,$00,$03,$F8,$00,$00,$00				; $C7FB 
			defb $00,$1D,$F0,$00,$3B,$EE,$80,$17				; $C803 
			defb $C0,$00,$00,$00,$00,$1E,$C0,$00				; $C80B 
			defb $3E,$DA,$80,$1E,$C0,$00,$00,$EC				; $C813 
			defb $00,$03,$E5,$00,$07,$EA,$C0,$0F				; $C81B 
			defb $E5,$50,$00,$00,$00,$0F,$FF,$F0				; $C823 
			defb $07,$FF,$C0,$00,$FE,$00,$00,$00				; $C82B 
			defb $00,$07,$7C,$00,$0E,$FB,$A0,$05				; $C833 
			defb $F0,$00,$00,$00,$00,$07,$B0,$00				; $C83B 
			defb $0F,$B6,$A0,$07,$B0,$00,$00,$3B				; $C843 
			defb $00,$00,$F9,$40,$01,$FA,$B0,$03				; $C84B 
			defb $F9,$54,$00,$00,$00,$03,$FF,$FC				; $C853 
			defb $01,$FF,$F0,$00,$3F,$80,$00,$00				; $C85B 
			defb $00,$01,$DF,$00,$03,$BE,$E8,$01				; $C863 
			defb $7C,$00,$00,$00,$00,$01,$EC,$00				; $C86B 
			defb $03,$ED,$A8,$01,$EC,$00						; $C873 
			;------------------------------------------------------------------
			; 02 - Player Ship facing left (4 rotate frames)
			defb $03,$70,$00,$0A,$7C,$00,$35,$7E,$00,$AA		; $C879
			defb $7F,$00,$00,$00,$00,$FF,$FF,$00				; $C883
			defb $3F,$FE,$00,$07,$F0,$00,$00,$00				; $C88B
			defb $00,$03,$EE,$00,$5D,$F7,$00,$00				; $C893
			defb $FA,$00,$00,$00,$00,$00,$DE,$00				; $C89B
			defb $56,$DF,$00,$00,$DE,$00,$00,$DC				; $C8A3
			defb $00,$02,$9F,$00,$0D,$5F,$80,$2A				; $C8AB
			defb $9F,$C0,$00,$00,$00,$3F,$FF,$C0				; $C8B3
			defb $0F,$FF,$80,$01,$FC,$00,$00,$00				; $C8BB
			defb $00,$00,$FB,$80,$17,$7D,$C0,$00				; $C8C3
			defb $3E,$80,$00,$00,$00,$00,$37,$80				; $C8CB
			defb $15,$B7,$C0,$00,$37,$80,$00,$37				; $C8D3
			defb $00,$00,$A7,$C0,$03,$57,$E0,$0A				; $C8DB
			defb $A7,$F0,$00,$00,$00,$0F,$FF,$F0				; $C8E3
			defb $03,$FF,$E0,$00,$7F,$00,$00,$00				; $C8EB
			defb $00,$00,$3E,$E0,$05,$DF,$70,$00				; $C8F3
			defb $0F,$A0,$00,$00,$00,$00,$0D,$E0				; $C8FB
			defb $05,$6D,$F0,$00,$0D,$E0,$00,$0D				; $C903
			defb $C0,$00,$29,$F0,$00,$D5,$F8,$02				; $C90B
			defb $A9,$FC,$00,$00,$00,$03,$FF,$FC				; $C913
			defb $00,$FF,$F8,$00,$1F,$C0,$00,$00				; $C91B
			defb $00,$00,$0F,$B8,$01,$77,$DC,$00				; $C923
			defb $03,$E8,$00,$00,$00,$00,$03,$78				; $C92B
			defb $01,$5B,$7C,$00,$03,$78						; $C933
			;------------------------------------------------------------------
			; 03 - Worm segment facing left on ground (4 rotate frames)
			defb $07,$E0,$00,$1F,$E8,$00,$3F,$F4,$00,$7F		; $C939
			defb $EA,$00,$7F,$D6,$00,$9F,$E9,$00				; $C943
			defb $E7,$A7,$00,$F8,$1F,$00,$FF,$FF				; $C94B
			defb $00,$3C,$3C,$00,$DB,$DB,$00,$DB				; $C953
			defb $DB,$00,$00,$00,$00,$00,$00,$00				; $C95B
			defb $00,$00,$00,$00,$00,$00,$01,$F8				; $C963
			defb $00,$07,$FA,$00,$0F,$FD,$00,$1F				; $C96B
			defb $FA,$80,$1F,$F5,$80,$27,$FA,$40				; $C973
			defb $39,$E9,$C0,$3E,$07,$C0,$0F,$FF				; $C97B
			defb $C0,$37,$0F,$00,$36,$F6,$C0,$06				; $C983
			defb $F6,$C0,$00,$00,$00,$00,$00,$00				; $C98B
			defb $00,$00,$00,$00,$00,$00,$00,$7E				; $C993
			defb $00,$01,$FE,$80,$03,$FF,$40,$07				; $C99B
			defb $FE,$A0,$07,$FD,$60,$09,$FE,$90				; $C9A3
			defb $0E,$7A,$70,$0F,$81,$F0,$0F,$C3				; $C9AB
			defb $F0,$03,$BD,$C0,$0D,$BD,$B0,$0D				; $C9B3
			defb $81,$B0,$00,$00,$00,$00,$00,$00				; $C9BB
			defb $00,$00,$00,$00,$00,$00,$00,$1F				; $C9C3
			defb $80,$00,$7F,$A0,$00,$FF,$D0,$01				; $C9CB
			defb $FF,$A8,$01,$FF,$58,$02,$7F,$A4				; $C9D3
			defb $03,$9E,$9C,$03,$E0,$7C,$03,$FF				; $C9DB
			defb $F0,$00,$F0,$EC,$03,$6F,$6C,$03				; $C9E3
			defb $6F,$60,$00,$00,$00,$00,$00,$00				; $C9EB
			defb $00,$00,$00,$00,$00,$00						; $C9F3
			;------------------------------------------------------------------
			; 04 - Worm segment climbing right wall (4 rotate frames)
			defb $07,$B0,$00,$1B,$B0,$00,$3B,$C0,$00,$7D		; $C9FB
			defb $F0,$00,$7D,$F0,$00,$FE,$C0,$00				; $CA03
			defb $FE,$B0,$00,$FE,$B0,$00,$FE,$B0				; $CA0B
			defb $00,$FC,$B0,$00,$F6,$C0,$00,$29				; $CA13
			defb $F0,$00,$55,$F0,$00,$2B,$C0,$00				; $CA1B
			defb $1B,$B0,$00,$07,$B0,$00,$01,$EC				; $CA23
			defb $00,$06,$EC,$00,$0E,$F0,$00,$1F				; $CA2B
			defb $7C,$00,$1F,$7C,$00,$3F,$B0,$00				; $CA33
			defb $3F,$AC,$00,$3F,$AC,$00,$3F,$AC				; $CA3B
			defb $00,$3F,$2C,$00,$3D,$B0,$00,$0A				; $CA43
			defb $7C,$00,$15,$7C,$00,$0A,$F0,$00				; $CA4B
			defb $06,$EC,$00,$01,$EC,$00,$00,$7B				; $CA53
			defb $00,$01,$BB,$00,$03,$BC,$00,$07				; $CA5B
			defb $DF,$00,$07,$DF,$00,$0F,$EC,$00				; $CA63
			defb $0F,$EB,$00,$0F,$EB,$00,$0F,$EB				; $CA6B
			defb $00,$0F,$CB,$00,$0F,$6C,$00,$02				; $CA73
			defb $9F,$00,$05,$5F,$00,$02,$BC,$00				; $CA7B
			defb $01,$BB,$00,$00,$7B,$00,$00,$1E				; $CA83
			defb $C0,$00,$6E,$C0,$00,$EF,$00,$01				; $CA8B 
			defb $F7,$C0,$01,$F7,$C0,$03,$FB,$00				; $CA93 
			defb $03,$FA,$C0,$03,$FA,$C0,$03,$FA				; $CA9B 
			defb $C0,$03,$F2,$C0,$03,$DB,$00,$00				; $CAA3 
			defb $A7,$C0,$01,$57,$C0,$00,$AF,$00				; $CAAB 
			defb $00,$6E,$C0,$00,$1E,$C0						; $CAB3
			;------------------------------------------------------------------
			; 05 - Worm segment on ceiling wall (4 rotate frames)
			defb $00,$00, $00,$00,$00,$00,$00,$00,$00,$00		; $CAB9
			defb $00,$00,$DB,$DB,$00,$DB,$DB,$00				; $CAC3 
			defb $3C,$3C,$00,$FF,$FF,$00,$F8,$1F				; $CACB 
			defb $00,$E7,$A7,$00,$9F,$E9,$00,$7F				; $CAD3 
			defb $D6,$00,$7F,$EA,$00,$3F,$F4,$00				; $CADB 
			defb $1F,$E8,$00,$07,$E0,$00,$00,$00				; $CAE3 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CAEB 
			defb $00,$00,$06,$F6,$C0,$36,$F6,$C0				; $CAF3 
			defb $37,$0F,$00,$0F,$FF,$C0,$3E,$07				; $CAFB 
			defb $C0,$39,$E9,$C0,$27,$FA,$40,$1F				; $CB03 
			defb $F5,$80,$1F,$FA,$80,$0F,$FD,$00				; $CB0B 
			defb $07,$FA,$00,$01,$F8,$00,$00,$00				; $CB13 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CB1B 
			defb $00,$00,$0D,$81,$B0,$0D,$BD,$B0				; $CB23 
			defb $03,$BD,$C0,$0F,$C3,$F0,$0F,$81				; $CB2B 
			defb $F0,$0E,$7A,$70,$09,$FE,$90,$07				; $CB33 
			defb $FD,$60,$07,$FE,$A0,$03,$FF,$40				; $CB3B 
			defb $01,$FE,$80,$00,$7E,$00,$00,$00				; $CB43 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CB4B 
			defb $00,$00,$03,$6F,$60,$03,$6F,$6C				; $CB53 
			defb $00,$F0,$EC,$03,$FF,$F0,$03,$E0				; $CB5B 
			defb $7C,$03,$9E,$9C,$02,$7F,$A4,$01				; $CB63 
			defb $FF,$58,$01,$FF,$A8,$00,$FF,$D0				; $CB6B 
			defb $00,$7F,$A0,$00,$1F,$80						; $CB73 
			;------------------------------------------------------------------
			; 06 - Worm segment climbing left wall (4 rotate frames)	
			defb $0D,$E0,$00,$0D,$D8,$00,$03,$DC,$00,$0F		; $CB79
			defb $BE,$00,$0F,$BE,$00,$03,$7F,$00				; $CB83 
			defb $0D,$7F,$00,$0D,$7F,$00,$0D,$7F				; $CB8B 
			defb $00,$0D,$3F,$00,$03,$6F,$00,$0F				; $CB93 
			defb $94,$00,$0F,$AA,$00,$03,$D4,$00				; $CB9B 
			defb $0D,$D8,$00,$0D,$E0,$00,$03,$78				; $CBA3 
			defb $00,$03,$76,$00,$00,$F7,$00,$03				; $CBAB 
			defb $EF,$80,$03,$EF,$80,$00,$DF,$C0				; $CBB3 
			defb $03,$5F,$C0,$03,$5F,$C0,$03,$5F				; $CBBB 
			defb $C0,$03,$4F,$C0,$00,$DB,$C0,$03				; $CBC3 
			defb $E5,$00,$03,$EA,$80,$00,$F5,$00				; $CBCB 
			defb $03,$76,$00,$03,$78,$00,$00,$DE				; $CBD3 
			defb $00,$00,$DD,$80,$00,$3D,$C0,$00				; $CBDB 
			defb $FB,$E0,$00,$FB,$E0,$00,$37,$F0				; $CBE3 
			defb $00,$D7,$F0,$00,$D7,$F0,$00,$D7				; $CBEB 
			defb $F0,$00,$D3,$F0,$00,$36,$F0,$00				; $CBF3 
			defb $F9,$40,$00,$FA,$A0,$00,$3D,$40				; $CBFB 
			defb $00,$DD,$80,$00,$DE,$00,$00,$37				; $CC03 
			defb $80,$00,$37,$60,$00,$0F,$70,$00				; $CC0B 
			defb $3E,$F8,$00,$3E,$F8,$00,$0D,$FC				; $CC13 
			defb $00,$35,$FC,$00,$35,$FC,$00,$35				; $CC1B 
			defb $FC,$00,$34,$FC,$00,$0D,$BC,$00				; $CC23 
			defb $3E,$50,$00,$3E,$A8,$00,$0F,$50				; $CC2B 
			defb $00,$37,$60,$00,$37,$80						; $CC33 
			;------------------------------------------------------------------
			; 07 - BackShot Facing left
			defb $00,$50,$00,$00,$22,$00,$03,$05,$00,$07		; $CC39
			defb $56,$00,$BB,$76,$00,$07,$56,$00				; $CC43 
			defb $03,$05,$00,$00,$22,$00,$00,$50				; $CC4B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CC53 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CC5B 
			defb $00,$00,$00,$00,$00,$00,$00,$14				; $CC63 
			defb $00,$00,$1C,$80,$00,$C9,$40,$01				; $CC6B 
			defb $C1,$80,$2E,$D5,$80,$01,$DD,$80				; $CC73 
			defb $00,$D5,$40,$00,$00,$80,$00,$1C				; $CC7B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CC83 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CC8B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CC93 
			defb $00,$00,$05,$20,$00,$37,$50,$00				; $CC9B 
			defb $75,$60,$0B,$B0,$60,$00,$75,$60				; $CCA3 
			defb $00,$37,$50,$00,$05,$20,$00,$00				; $CCAB 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CCB3 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CCBB 
			defb $00,$00,$00,$00,$00,$00,$00,$01				; $CCC3 
			defb $C0,$00,$00,$08,$00,$0D,$54,$00				; $CCCB 
			defb $1D,$D8,$02,$ED,$58,$00,$1C,$18				; $CCD3 
			defb $00,$0C,$94,$00,$01,$C8,$00,$01				; $CCDB 
			defb $40,$00,$00,$00,$00,$00,$00,$00				; $CCE3 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CCEB 
			defb $00,$00,$00,$00,$00,$00						; $CCF3 
			;------------------------------------------------------------------
			; 08 - BackShot Facing right				
			defb $0E,$00,$00,$40,$00,$00,$AA,$C0,$00,$6E		; $CCF9 
			defb $E0,$00,$6A,$DD,$00,$60,$E0,$00				; $CD03 
			defb $A4,$C0,$00,$4E,$00,$00,$0A,$00				; $CD0B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CD13 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CD1B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CD23 
			defb $00,$12,$80,$00,$2B,$B0,$00,$1A				; $CD2B 
			defb $B8,$00,$18,$37,$40,$1A,$B8,$00				; $CD33 
			defb $2B,$B0,$00,$12,$80,$00,$00,$00				; $CD3B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CD43 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CD4B 
			defb $00,$00,$00,$00,$00,$00,$00,$A0				; $CD53 
			defb $00,$04,$E0,$00,$0A,$4C,$00,$06				; $CD5B 
			defb $0E,$00,$06,$AD,$D0,$06,$EE,$00				; $CD63 
			defb $0A,$AC,$00,$04,$00,$00,$00,$E0				; $CD6B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CD73 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CD7B 
			defb $00,$00,$00,$00,$00,$00						; $CD83 
			;------------------------------------------------------------------
			; 09 - Explosion 1
			defb $00,$28,$00,$01,$10,$00,$02,$83,$00,$01		; $CD89
			defb $AB,$80,$01,$BB,$74,$01,$AB,$80				; $CD93 
			defb $02,$83,$00,$01,$10,$00,$00,$28				; $CD9B 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CDA3 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $CDAB 
			defb $00,$00,$00,$00,$00,$00,$07,$00				; $CDB3 
			defb $00,$1E,$C0,$00,$1F,$CA,$00,$2F				; $CDBB 
			defb $DD,$00,$FE,$3A,$00,$FE,$FD,$00				; $CDC3 
			defb $78,$FA,$00,$02,$FA,$00,$F6,$78				; $CDCB 
			defb $00,$FF,$63,$00,$FF,$6E,$00,$BC				; $CDD3 
			defb $0B,$00,$73,$BD,$00,$0F,$BA,$00				; $CDDB 
			defb $3D,$B4,$00,$3A,$1C,$00,$01,$C0				; $CDE3 
			defb $00,$07,$B0,$00,$07,$F2,$80,$0B				; $CDEB 
			defb $F7,$40,$3F,$8E,$80,$3F,$BF,$40				; $CDF3 
			defb $1E,$3E,$80,$00,$BE,$80,$3D,$9E				; $CDFB 
			defb $00,$3F,$D8,$C0,$3F,$DB,$80,$2F				; $CE03 
			defb $02,$C0,$1C,$EF,$40,$03,$EE,$80				; $CE0B 
			defb $0F,$6D,$00,$0E,$87,$00,$00,$70				; $CE13 
			defb $00,$01,$EC,$00,$01,$FC,$A0,$02				; $CE1B 
			defb $FD,$D0,$0F,$E3,$A0,$0F,$EF,$D0				; $CE23 
			defb $07,$8F,$A0,$00,$2F,$A0,$0F,$67				; $CE2B 
			defb $80,$0F,$F6,$30,$0F,$F6,$E0,$0B				; $CE33 
			defb $C0,$B0,$07,$3B,$D0,$00,$FB,$A0				; $CE3B 
			defb $03,$DB,$40,$03,$A1,$C0,$00,$1C				; $CE43 
			defb $00,$00,$7B,$00,$00,$7F,$28,$00				; $CE4B 
			defb $BF,$74,$03,$F8,$E8,$03,$FB,$F4				; $CE53 
			defb $01,$E3,$E8,$00,$0B,$E8,$03,$D9				; $CE5B 
			defb $E0,$03,$FD,$8C,$03,$FD,$B8,$02				; $CE63 
			defb $F0,$2C,$01,$CE,$F4,$00,$3E,$E8				; $CE6B 
			defb $00,$F6,$D0,$00,$E8,$70,$05,$00				; $CE73 
			;------------------------------------------------------------------
			; 10 - Explosion 2
			defb $00,$1E,$C0,$00,$1B,$CA,$00,$2D				; $CE7B 
			defb $4D,$00,$B0,$2A,$00,$94,$2D,$00				; $CE83 
			defb $78,$1A,$00,$00,$0A,$00,$F0,$10				; $CE8B 
			defb $00,$A8,$03,$00,$D4,$2A,$00,$AC				; $CE93 
			defb $0B,$00,$72,$B5,$00,$0B,$8A,$00				; $CE9B 
			defb $35,$B4,$00,$2A,$1C,$00,$01,$40				; $CEA3 
			defb $00,$07,$B0,$00,$06,$F2,$80,$0B				; $CEAB 
			defb $53,$40,$2C,$0A,$80,$25,$0B,$40				; $CEB3 
			defb $1E,$06,$80,$00,$02,$80,$3C,$04				; $CEBB 
			defb $00,$2A,$00,$C0,$35,$0A,$80,$2B				; $CEC3 
			defb $02,$C0,$1C,$AD,$40,$02,$E2,$80				; $CECB 
			defb $0D,$6D,$00,$0A,$87,$00,$00,$50				; $CED3 
			defb $00,$01,$EC,$00,$01,$BC,$A0,$02				; $CEDB 
			defb $D4,$D0,$0B,$02,$A0,$09,$42,$D0				; $CEE3 
			defb $07,$81,$A0,$00,$00,$A0,$0F,$01				; $CEEB 
			defb $00,$0A,$80,$30,$0D,$42,$A0,$0A				; $CEF3 
			defb $C0,$B0,$07,$2B,$50,$00,$B8,$A0				; $CEFB 
			defb $03,$5B,$40,$02,$A1,$C0,$00,$14				; $CF03 
			defb $00,$00,$7B,$00,$00,$6F,$28,$00				; $CF0B 
			defb $B5,$34,$02,$C0,$A8,$02,$50,$B4				; $CF13 
			defb $01,$E0,$68,$00,$00,$28,$03,$C0				; $CF1B 
			defb $40,$02,$A0,$0C,$03,$50,$A8,$02				; $CF23 
			defb $B0,$2C,$01,$CA,$D4,$00,$2E,$28				; $CF2B 
			defb $00,$D6,$D0,$00,$A8,$70						; $CF33 
			;------------------------------------------------------------------
			; 11 - Explosion 3
			defb $07,$00,$00,$16,$C0,$00,$10,$0A,$00,$21		; $CF3B 
			defb $1D,$00,$E8,$0A,$00,$E0,$11,$00				; $CF43 
			defb $20,$02,$00,$00,$0A,$00,$C0,$00				; $CF4B 
			defb $00,$D0,$01,$00,$C0,$24,$00,$A4				; $CF53 
			defb $03,$00,$70,$05,$00,$08,$2A,$00				; $CF5B 
			defb $39,$B4,$00,$3A,$1C,$00,$01,$C0				; $CF63 
			defb $00,$05,$B0,$00,$04,$02,$80,$08				; $CF6B 
			defb $47,$40,$3A,$02,$80,$38,$04,$40				; $CF73 
			defb $08,$00,$80,$00,$02,$80,$30,$00				; $CF7B 
			defb $00,$34,$00,$40,$30,$09,$00,$29				; $CF83 
			defb $00,$C0,$1C,$01,$40,$02,$0A,$80				; $CF8B 
			defb $0E,$6D,$00,$0E,$87,$00,$00,$70				; $CF93 
			defb $00,$01,$6C,$00,$01,$00,$A0,$02				; $CF9B 
			defb $11,$D0,$0E,$80,$A0,$0E,$01,$10				; $CFA3 
			defb $02,$00,$20,$00,$00,$A0,$0C,$00				; $CFAB 
			defb $00,$0D,$00,$10,$0C,$02,$40,$0A				; $CFB3 
			defb $40,$30,$07,$00,$50,$00,$82,$A0				; $CFBB 
			defb $03,$9B,$40,$03,$A1,$C0,$00,$1C				; $CFC3 
			defb $00,$00,$5B,$00,$00,$40,$28,$00				; $CFCB 
			defb $84,$74,$03,$A0,$28,$03,$80,$44				; $CFD3 
			defb $00,$80,$08,$00,$00,$28,$03,$00				; $CFDB 
			defb $00,$03,$40,$04,$03,$00,$90,$02				; $CFE3 
			defb $90,$0C,$01,$C0,$14,$00,$20,$A8				; $CFEB 
			defb $00,$E6,$D0,$00,$E8,$70						; $CFF3 
			;------------------------------------------------------------------
			; 12 - Explosion 4
			defb $02,$00,$00,$04,$40,$00,$20,$08,$00,$01		; $CFF9
			defb $02,$00,$08,$08,$00,$A0,$00,$00				; $D003 
			defb $00,$02,$00,$00,$00,$00,$80,$01				; $D00B 
			defb $00,$00,$04,$00,$80,$01,$00,$00				; $D013 
			defb $00,$00,$50,$02,$00,$08,$20,$00				; $D01B 
			defb $20,$84,$00,$0A,$10,$00,$00,$80				; $D023 
			defb $00,$01,$10,$00,$08,$02,$00,$00				; $D02B 
			defb $40,$80,$02,$02,$00,$28,$00,$00				; $D033 
			defb $00,$00,$80,$00,$00,$00,$20,$00				; $D03B 
			defb $40,$00,$01,$00,$20,$00,$40,$00				; $D043 
			defb $00,$00,$14,$00,$80,$02,$08,$00				; $D04B 
			defb $08,$21,$00,$02,$84,$00,$00,$20				; $D053 
			defb $00,$00,$44,$00,$02,$00,$80,$00				; $D05B 
			defb $10,$20,$00,$80,$80,$0A,$00,$00				; $D063 
			defb $00,$00,$20,$00,$00,$00,$08,$00				; $D06B 
			defb $10,$00,$00,$40,$08,$00,$10,$00				; $D073 
			defb $00,$00,$05,$00,$20,$00,$82,$00				; $D07B 
			defb $02,$08,$40,$00,$A1,$00,$00,$08				; $D083 
			defb $00,$00,$11,$00,$00,$80,$20,$00				; $D08B 
			defb $04,$08,$00,$20,$20,$02,$80,$00				; $D093 
			defb $00,$00,$08,$00,$00,$00,$02,$00				; $D09B 
			defb $04,$00,$00,$10,$02,$00,$04,$00				; $D0A3 
			defb $00,$00,$01,$40,$08,$00,$20,$80				; $D0AB 
			defb $00,$82,$10,$00,$28,$40						; $D0B3 
			;------------------------------------------------------------------
			; 13 - Enemy 1
			defb $03,$C0,$00,$0F,$D0,$00,$1F,$E8,$00,$3F		; $D0B9
			defb $D4,$00,$7F,$AA,$00,$00,$00,$00				; $D0C3 
			defb $DC,$E7,$00,$DC,$E7,$00,$DC,$E7				; $D0CB 
			defb $00,$00,$00,$00,$7F,$EA,$00,$FF				; $D0D3 
			defb $55,$00,$00,$00,$00,$7B,$DA,$00				; $D0DB 
			defb $00,$00,$00,$19,$98,$00,$00,$F0				; $D0E3 
			defb $00,$03,$F4,$00,$07,$FA,$00,$0F				; $D0EB 
			defb $F5,$00,$1F,$EA,$80,$00,$00,$00				; $D0F3 
			defb $2E,$73,$80,$2E,$73,$80,$2E,$73				; $D0FB 
			defb $80,$00,$00,$00,$1F,$FA,$80,$3F				; $D103 
			defb $D5,$40,$00,$00,$00,$1E,$F6,$80				; $D10B 
			defb $00,$00,$00,$0C,$63,$00,$00,$3C				; $D113 
			defb $00,$00,$FD,$00,$01,$FE,$80,$03				; $D11B 
			defb $FD,$40,$07,$FA,$A0,$00,$00,$00				; $D123 
			defb $07,$39,$D0,$07,$39,$D0,$07,$39				; $D12B 
			defb $D0,$00,$00,$00,$07,$FE,$A0,$0F				; $D133 
			defb $F5,$50,$00,$00,$00,$0F,$3C,$D0				; $D13B 
			defb $00,$00,$00,$06,$18,$60,$00,$0F				; $D143 
			defb $00,$00,$3F,$40,$00,$7F,$A0,$00				; $D14B 
			defb $FF,$50,$01,$FE,$A8,$00,$00,$00				; $D153 
			defb $03,$9C,$EC,$03,$9C,$EC,$03,$9C				; $D15B 
			defb $EC,$00,$00,$00,$01,$FF,$A8,$03				; $D163 
			defb $FD,$54,$00,$00,$00,$01,$EF,$68				; $D16B 
			defb $00,$00,$00,$00,$C6,$30						; $D173 
			;------------------------------------------------------------------
			; 14 - Enemy 2
			defb $05,$A0,$00,$1D,$B8,$00,$3D,$B4,$00,$7D		; $D179
			defb $BA,$00,$7D,$BA,$00,$FD,$B5,$00				; $D183 
			defb $FD,$BB,$00,$03,$C0,$00,$7F,$EA				; $D18B 
			defb $00,$00,$00,$00,$7F,$EA,$00,$FF				; $D193 
			defb $F5,$00,$00,$00,$00,$3F,$D4,$00				; $D19B 
			defb $0F,$D0,$00,$03,$40,$00,$01,$68				; $D1A3 
			defb $00,$07,$6E,$00,$0F,$6D,$00,$1F				; $D1AB 
			defb $6E,$80,$1F,$6E,$80,$3F,$6D,$40				; $D1B3 
			defb $3F,$6E,$C0,$00,$F0,$00,$1F,$FA				; $D1BB 
			defb $80,$00,$00,$00,$1F,$FA,$80,$3F				; $D1C3 
			defb $FD,$40,$00,$00,$00,$0F,$F5,$00				; $D1CB 
			defb $03,$F4,$00,$00,$D0,$00,$00,$5A				; $D1D3 
			defb $00,$01,$DB,$80,$03,$DB,$40,$07				; $D1DB 
			defb $DB,$A0,$07,$DB,$A0,$0F,$DB,$50				; $D1E3 
			defb $0F,$DB,$B0,$00,$3C,$00,$07,$FE				; $D1EB 
			defb $A0,$00,$00,$00,$07,$FE,$A0,$0F				; $D1F3 
			defb $FF,$50,$00,$00,$00,$03,$FD,$40				; $D1FB 
			defb $00,$FD,$00,$00,$34,$00,$00,$16				; $D203 
			defb $80,$00,$76,$E0,$00,$F6,$D0,$01				; $D20B 
			defb $F6,$E8,$01,$F6,$E8,$03,$F6,$D4				; $D213 
			defb $03,$F6,$EC,$00,$0F,$00,$01,$FF				; $D21B 
			defb $A8,$00,$00,$00,$01,$FF,$A8,$03				; $D223 
			defb $FF,$D4,$00,$00,$00,$00,$FF,$50				; $D22B 
			defb $00,$3F,$40,$00,$0D,$00						; $D233 
			;------------------------------------------------------------------
			; 15 - Enemy 3
			defb $07,$A0,$00,$1F,$E8,$00,$3F,$D4,$00,$7F		; $D239 
			defb $EA,$00,$7F,$D6,$00,$FF,$E9,$00				; $D243 
			defb $FF,$D5,$00,$00,$00,$00,$2F,$D4				; $D24B 
			defb $00,$4F,$D2,$00,$80,$01,$00,$87				; $D253 
			defb $A1,$00,$80,$01,$00,$91,$89,$00				; $D25B 
			defb $63,$C6,$00,$33,$CC,$00,$01,$E8				; $D263 
			defb $00,$07,$FA,$00,$0F,$F5,$00,$1F				; $D26B 
			defb $FA,$80,$1F,$F5,$80,$3F,$FA,$40				; $D273 
			defb $3F,$F5,$40,$00,$00,$00,$0B,$F5				; $D27B 
			defb $00,$13,$F4,$80,$20,$00,$40,$21				; $D283 
			defb $E8,$40,$20,$00,$40,$12,$64,$80				; $D28B 
			defb $0C,$F3,$00,$06,$F6,$00,$00,$7A				; $D293 
			defb $00,$01,$FE,$80,$03,$FD,$40,$07				; $D29B 
			defb $FE,$A0,$07,$FD,$60,$0F,$FE,$90				; $D2A3 
			defb $0F,$FD,$50,$00,$00,$00,$02,$FD				; $D2AB 
			defb $40,$04,$FD,$20,$08,$00,$10,$08				; $D2B3 
			defb $7A,$10,$04,$00,$20,$02,$5A,$40				; $D2BB 
			defb $01,$BD,$80,$00,$FF,$00,$00,$1E				; $D2C3 
			defb $80,$00,$7F,$A0,$00,$FF,$50,$01				; $D2CB 
			defb $FF,$A8,$01,$FF,$58,$03,$FF,$A4				; $D2D3 
			defb $03,$FF,$54,$00,$00,$00,$00,$BF				; $D2DB 
			defb $50,$01,$3F,$48,$02,$00,$04,$02				; $D2E3 
			defb $1E,$84,$02,$00,$04,$01,$26,$48				; $D2EB 
			defb $00,$CF,$30,$00,$6F,$60						; $D2F3 
			;------------------------------------------------------------------
			; 16 - Enemy 4
			defb $05,$A0,$00,$1D,$B8,$00,$3D,$B4,$00,$7D		; $D2F9 
			defb $BA,$00,$7D,$BA,$00,$FD,$B5,$00				; $D303 
			defb $FD,$BB,$00,$03,$C0,$00,$3F,$FC				; $D30B 
			defb $00,$3F,$FC,$00,$0E,$70,$00,$55				; $D313 
			defb $AA,$00,$BB,$DD,$00,$BB,$DA,$00				; $D31B 
			defb $BB,$DD,$00,$51,$8A,$00,$01,$68				; $D323 
			defb $00,$07,$6E,$00,$0F,$6D,$00,$1F				; $D32B 
			defb $6E,$80,$1F,$6E,$80,$3F,$6D,$40				; $D333 
			defb $3F,$6E,$C0,$00,$F0,$00,$0F,$FF				; $D33B 
			defb $00,$0F,$FF,$00,$03,$9C,$00,$15				; $D343 
			defb $6A,$80,$2E,$F7,$40,$2E,$F6,$80				; $D34B 
			defb $2E,$F7,$40,$14,$62,$80,$00,$5A				; $D353 
			defb $00,$01,$DB,$80,$03,$DB,$40,$07				; $D35B 
			defb $DB,$A0,$07,$DB,$A0,$0F,$DB,$50				; $D363 
			defb $0F,$DB,$B0,$00,$3C,$00,$03,$FF				; $D36B 
			defb $C0,$03,$FF,$C0,$00,$E7,$00,$05				; $D373 
			defb $5A,$A0,$0B,$BD,$D0,$0B,$BD,$A0				; $D37B 
			defb $0B,$BD,$D0,$05,$18,$A0,$00,$16				; $D383 
			defb $80,$00,$76,$E0,$00,$F6,$D0,$01				; $D38B 
			defb $F6,$E8,$01,$F6,$E8,$03,$F6,$D4				; $D393 
			defb $03,$F6,$EC,$00,$0F,$00,$00,$FF				; $D39B 
			defb $F0,$00,$FF,$F0,$00,$39,$C0,$01				; $D3A3 
			defb $56,$A8,$02,$EF,$74,$02,$EF,$68				; $D3AB 
			defb $02,$EF,$74,$01,$46,$28						; $D3B3 
			;------------------------------------------------------------------
			; 17 - Mace 
			defb $81,$02,$00,$6D,$6C,$00,$4B,$A4,$00,$1C		; $D3B9
			defb $70,$00,$7F,$FC,$00,$5E,$F4,$00				; $D3C3 
			defb $2D,$68,$00,$ED,$6E,$00,$2D,$68				; $D3CB 
			defb $00,$5E,$F4,$00,$7F,$FC,$00,$1C				; $D3D3 
			defb $70,$00,$4B,$A4,$00,$6D,$6C,$00				; $D3DB 
			defb $81,$02,$00,$00,$00,$00,$20,$40				; $D3E3 
			defb $80,$1B,$5B,$00,$12,$E9,$00,$07				; $D3EB 
			defb $1C,$00,$1F,$FF,$00,$17,$BD,$00				; $D3F3 
			defb $0B,$5A,$00,$3B,$5B,$80,$0B,$5A				; $D3FB 
			defb $00,$17,$BD,$00,$1F,$FF,$00,$07				; $D403 
			defb $1C,$00,$12,$E9,$00,$1B,$5B,$00				; $D40B 
			defb $20,$40,$80,$00,$00,$00,$08,$10				; $D413 
			defb $20,$06,$D6,$C0,$04,$BA,$40,$01				; $D41B 
			defb $C7,$00,$07,$FF,$C0,$05,$EF,$40				; $D423 
			defb $02,$D6,$80,$0E,$D6,$E0,$02,$D6				; $D42B 
			defb $80,$05,$EF,$40,$07,$FF,$C0,$01				; $D433 
			defb $C7,$00,$04,$BA,$40,$06,$D6,$C0				; $D43B 
			defb $08,$10,$20,$00,$00,$00,$02,$04				; $D443 
			defb $08,$01,$B5,$B0,$01,$2E,$90,$00				; $D44B 
			defb $71,$C0,$01,$FF,$F0,$01,$7B,$D0				; $D453 
			defb $00,$B5,$A0,$03,$B5,$B8,$00,$B5				; $D45B 
			defb $A0,$01,$7B,$D0,$01,$FF,$F0,$00				; $D463 
			defb $71,$C0,$01,$2E,$90,$01,$B5,$B0				; $D46B 
			defb $02,$04,$08,$00,$00,$00						; $D473 
			;------------------------------------------------------------------

TITLE16X16_DATA:
			; Tile 000
			defb $00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; $D479
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $D483 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $D48B 
			defb $00,$00,$00,$00,$00,$00						; $D493
			;------------------------------------------------------------------
			; Tile 001
			defb $C1,$93,$F5,$8B,$39,$A3,$93,$86,$43,$3E		; $D499
			defb $8E,$78,$3C,$80,$F0,$C7,$C8,$CF				; $D4A3
			defb $1D,$DC,$4E,$99,$86,$1A,$1B,$59				; $D4AB
			defb $7B,$1C,$E1,$8F,$C9,$A3						; $D4B3
			;------------------------------------------------------------------
			; Tile 002
			defb $C9,$A3,$E5,$93,$70,$C7,$3A,$FE,$18,$38		; $D4B9
			defb $9D,$02,$1C,$40,$F8,$1F,$E4,$BB				; $D4C3
			defb $0E,$30,$26,$32,$4B,$1C,$1B,$AE				; $D4CB
			defb $39,$86,$F1,$A3,$C5,$83						; $D4D3
			;------------------------------------------------------------------
			; Tile 003
			defb $C5,$A3,$F1,$87,$38,$DE,$5A,$D8,$98,$62		; $D4DB
			defb $59,$70,$3B,$B8,$F3,$13,$E3,$0F				; $D4E3
			defb $01,$3C,$9E,$70,$7C,$C2,$61,$C8				; $D4EB
			defb $C9,$9C,$D1,$8F,$C5,$A3						; $D4F3
			;------------------------------------------------------------------
			; Tile 004
			defb $C5,$A3,$D1,$8F,$61,$9C,$75,$D9,$38,$D2		; $D4FB
			defb $4C,$61,$0C,$70,$DC,$27,$F8,$1F				; $D503
			defb $02,$38,$40,$BA,$1C,$18,$7F,$5C				; $D50B
			defb $E3,$0E,$C1,$A7,$C9,$83						; $D513
			;------------------------------------------------------------------
			; Tile 005
			defb $C1,$83,$E5,$8F,$7B,$1C,$1B,$59,$86,$18		; $D51B
			defb $4E,$99,$1D,$DC,$C8,$CF,$F0,$C7				; $D523
			defb $3C,$80,$8E,$79,$43,$3E,$93,$86				; $D52B
			defb $39,$93,$F1,$AB,$C1,$83						; $D533
			;------------------------------------------------------------------
			; Tile 006
			defb $00,$01,$00,$01,$00,$03,$00,$06,$00,$06		; $D53B
			defb $00,$00,$00,$1D,$00,$1D,$00,$00				; $D543
			defb $00,$3B,$00,$77,$00,$77,$18,$77				; $D54B
			defb $00,$77,$34,$77,$7A,$3B						; $D553
			;------------------------------------------------------------------
			; Tile 007
			defb $00,$00, $B6,$AA,$7F,$FD,$EF,$FE,$FF,$AA		; $D55B
			defb $00,$00,$DF,$FF,$FF,$FF,$00,$00				; $D563
			defb $BF,$F5,$FF,$FE,$7F,$FD,$FF,$FE				; $D56B
			defb $FF,$FD,$7F,$FA,$DF,$55,$80,$00				; $D573
			;------------------------------------------------------------------
			defb $80,$00,$40,$00,$20,$00,$A0,$00				; $D57B
			defb $00,$00,$48,$00,$A8,$00,$00,$00				; $D583
			defb $54,$00,$AA,$00,$54,$00,$AA,$18				; $D58B
			defb $54,$00,$AA,$34,$54,$7A,$00,$00				; $D593
			defb $6D,$FA,$DF,$FD,$DB,$FA,$DF,$FD				; $D59B
			defb $DB,$FA,$DF,$FD,$DB,$FA,$DF,$FD				; $D5A3
			defb $DB,$FA,$DF,$FD,$DB,$FA,$DF,$FD				; $D5AB
			defb $DB,$FA,$DF,$F5,$6D,$AA,$30,$08				; $D5B3
			defb $36,$64,$34,$48,$34,$44,$30,$08				; $D5BB
			defb $36,$64,$34,$48,$34,$44,$30,$08				; $D5C3
			defb $36,$64,$34,$48,$34,$44,$30,$08				; $D5CB
			defb $36,$64,$34,$48,$34,$44,$6D,$FA				; $D5D3
			defb $DF,$FD,$DB,$FA,$DF,$FD,$DB,$FA				; $D5DB
			defb $DF,$FD,$DB,$FA,$DF,$FD,$DB,$FA				; $D5E3
			defb $DF,$FD,$DB,$FA,$DF,$FD,$DB,$FA				; $D5EB
			defb $DF,$F5,$6D,$AA,$00,$00,$80,$00				; $D5F3
			defb $40,$00,$40,$00,$20,$C0,$20,$20				; $D5FB
			defb $20,$10,$60,$00,$60,$0F,$60,$30				; $D603
			defb $60,$66,$C0,$C6,$C0,$C6,$C1,$83				; $D60B
			defb $C5,$A3,$D1,$8B,$C1,$83,$00,$00				; $D613
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $D61B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $D623
			defb $00,$18,$08,$04,$10,$02,$62,$22				; $D62B
			defb $61,$03,$C9,$93,$C1,$83,$80,$00				; $D633
			defb $80,$00,$80,$00,$40,$00,$40,$00				; $D63B
			defb $60,$E0,$27,$80,$0C,$00,$18,$00				; $D643
			defb $30,$00,$36,$08,$63,$04,$6B,$06				; $D64B
			defb $C1,$A3,$D5,$93,$C1,$83,$00,$00				; $D653
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $D65B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $D663
			defb $00,$00,$00,$00,$00,$01,$08,$81				; $D66B
			defb $85,$12,$91,$03,$C1,$A3,$00,$06				; $D673
			defb $00,$3E,$00,$7C,$01,$BE,$03,$BC				; $D67B
			defb $07,$DE,$07,$DC,$0F,$EA,$0F,$EC				; $D683
			defb $17,$F2,$19,$F4,$3E,$FA,$3F,$3A				; $D68B
			defb $7F,$DC,$7F,$E4,$00,$00,$60,$00				; $D693
			defb $7C,$00,$7E,$00,$7D,$80,$7D,$40				; $D69B
			defb $7B,$A0,$7B,$E0,$77,$D0,$77,$F0				; $D6A3
			defb $6F,$E8,$6F,$98,$5F,$74,$5C,$F4				; $D6AB
			defb $3B,$FA,$27,$EA,$00,$00,$00,$00				; $D6B3
			defb $FF,$F8,$FF,$E6,$7F,$9C,$7E,$7C				; $D6BB
			defb $79,$FA,$27,$F6,$1F,$F4,$17,$EE				; $D6C3
			defb $0B,$DC,$06,$DA,$01,$FC,$00,$66				; $D6CB
			defb $00,$18,$00,$06,$00,$00,$00,$00				; $D6D3
			defb $1F,$FF,$67,$FF,$39,$FE,$3E,$7E				; $D6DB
			defb $5F,$9E,$6F,$E4,$6F,$F8,$77,$E8				; $D6E3
			defb $7B,$D0,$7B,$60,$3D,$80,$66,$00				; $D6EB
			defb $18,$00,$60,$00,$00,$00,$00,$00				; $D6F3
			defb $FF,$FF,$55,$55,$00,$00,$FF,$FF				; $D6FB
			defb $BF,$FD,$E0,$07,$E5,$57,$E2,$AF				; $D703
			defb $E5,$57,$BF,$FD,$FF,$FF,$00,$00				; $D70B
			defb $FF,$FF,$55,$55,$00,$00,$4F,$F4				; $D713
			defb $6B,$D6,$4F,$F4,$6C,$36,$4C,$34				; $D71B
			defb $6D,$76,$4C,$B4,$6D,$76,$4C,$B4				; $D723
			defb $6D,$76,$4C,$B4,$6D,$76,$4C,$B4				; $D72B
			defb $6F,$F6,$4B,$D4,$6F,$F6,$07,$80				; $D733
			defb $1F,$7F,$3F,$7F,$7F,$6F,$7F,$7F				; $D73B
			defb $FF,$7F,$FF,$7F,$FF,$7F,$FF,$7F				; $D743
			defb $FF,$7F,$FF,$7F,$7F,$7F,$7F,$6F				; $D74B
			defb $3F,$2A,$1F,$55,$07,$80,$01,$E0				; $D753
			defb $FA,$F8,$FC,$FC,$EA,$FE,$FC,$FE				; $D75B
			defb $FA,$FD,$F4,$FE,$FA,$FD,$F4,$FE				; $D763
			defb $FA,$FD,$F4,$FD,$EA,$F6,$54,$EA				; $D76B
			defb $AA,$F4,$54,$C8,$01,$A0,$00,$00				; $D773
			defb $00,$00,$00,$00,$00,$00,$41,$82				; $D77B
			defb $07,$E0,$60,$06,$6F,$F6,$6F,$F6				; $D783
			defb $60,$06,$07,$E0,$41,$82,$00,$00				; $D78B
			defb $00,$00,$00,$00,$00,$00,$07,$E0				; $D793
			defb $1F,$F8,$3C,$3C,$70,$0E,$0C,$30				; $D79B
			defb $EA,$57,$C6,$E2,$C1,$C3,$C3,$82				; $D7A3
			defb $C7,$63,$EA,$57,$0C,$30,$70,$0E				; $D7AB
			defb $3C,$34,$1F,$E8,$06,$A0,$00,$00				; $D7B3
			defb $00,$FE,$01,$02,$02,$78,$7A,$7A				; $D7BB
			defb $4B,$00,$73,$FE,$73,$FC,$73,$FA				; $D7C3
			defb $6B,$D4,$43,$02,$6A,$78,$02,$7A				; $D7CB
			defb $01,$00,$00,$AA,$00,$00,$00,$00				; $D7D3
			defb $FF,$FF,$00,$00,$33,$33,$00,$00				; $D7DB
			defb $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF				; $D7E3
			defb $AA,$AA,$55,$55,$00,$00,$33,$33				; $D7EB
			defb $00,$00,$AA,$AA,$00,$00,$00,$00				; $D7F3
			defb $7F,$00,$40,$80,$5E,$40,$5E,$5E				; $D7FB
			defb $40,$D2,$7E,$9C,$7F,$5A,$7E,$9C				; $D803
			defb $75,$5A,$40,$90,$5E,$5A,$5E,$40				; $D80B
			defb $40,$80,$55,$00,$00,$00,$0F,$D0				; $D813
			defb $2F,$E4,$2F,$D4,$2F,$E4,$0F,$D0				; $D81B
			defb $00,$00,$07,$A0,$07,$C0,$07,$A0				; $D823
			defb $00,$00,$01,$80,$01,$80,$00,$00				; $D82B
			defb $03,$40,$03,$80,$03,$40,$0F,$D0				; $D833
			defb $6F,$E6,$6F,$D6,$6F,$E6,$0F,$D0				; $D83B
			defb $00,$00,$07,$A0,$07,$C0,$07,$A0				; $D843
			defb $00,$00,$01,$80,$00,$00,$03,$40				; $D84B
			defb $03,$80,$03,$40,$00,$00,$0F,$D0				; $D853
			defb $EF,$E7,$EF,$D7,$EF,$E7,$0F,$D0				; $D85B
			defb $00,$00,$07,$A0,$07,$C0,$07,$A0				; $D863
			defb $00,$00,$00,$00,$03,$40,$03,$80				; $D86B
			defb $03,$40,$00,$00,$00,$00,$03,$40				; $D873
			defb $03,$80,$03,$40,$00,$00,$01,$80				; $D87B
			defb $01,$80,$00,$00,$07,$A0,$07,$C0				; $D883
			defb $07,$A0,$00,$00,$0F,$D0,$2F,$E4				; $D88B
			defb $2F,$D4,$2F,$E4,$0F,$D0,$00,$00				; $D893
			defb $03,$40,$03,$80,$03,$40,$00,$00				; $D89B
			defb $01,$80,$00,$00,$07,$A0,$07,$C0				; $D8A3
			defb $07,$A0,$00,$00,$0F,$D0,$6F,$E6				; $D8AB
			defb $6F,$D6,$6F,$E6,$0F,$D0,$00,$00				; $D8B3
			defb $00,$00,$03,$40,$03,$80,$03,$40				; $D8BB
			defb $00,$00,$00,$00,$07,$A0,$07,$C0				; $D8C3
			defb $07,$A0,$00,$00,$0F,$D0,$EF,$E7				; $D8CB
			defb $EF,$D7,$EF,$E7,$0F,$D0,$01,$E0				; $D8D3
			defb $02,$D0,$0F,$70,$1F,$64,$1C,$52				; $D8DB
			defb $33,$D2,$31,$A1,$64,$01,$64,$01				; $D8E3
			defb $44,$01,$42,$02,$43,$02,$81,$86				; $D8EB
			defb $00,$CC,$00,$58,$00,$38,$00,$01				; $D8F3
			defb $00,$01,$00,$02,$00,$0C,$00,$78				; $D8FB
			defb $17,$C0,$31,$00,$39,$00,$14,$00				; $D903
			defb $2A,$00,$14,$00,$01,$00,$10,$80				; $D90B
			defb $08,$80,$08,$80,$04,$40,$00,$68				; $D913
			defb $00,$50,$00,$E0,$00,$D0,$01,$E0				; $D91B
			defb $01,$D0,$02,$A8,$03,$51,$07,$AB				; $D923
			defb $07,$D3,$0B,$E9,$1D,$D5,$1D,$A8				; $D92B
			defb $3A,$EB,$66,$D7,$C1,$03,$04,$40				; $D933
			defb $04,$40,$0C,$40,$08,$80,$19,$80				; $D93B
			defb $33,$00,$C6,$00,$AA,$00,$D4,$00				; $D943
			defb $A8,$00,$DA,$00,$A7,$00,$9D,$00				; $D94B
			defb $3E,$80,$C3,$20,$78,$55,$06,$5A				; $D953
			defb $19,$6D,$21,$6D,$41,$6D,$43,$6D				; $D95B
			defb $86,$ED,$DD,$DD,$73,$DB,$0F,$3B				; $D963
			defb $FC,$F7,$63,$EE,$1F,$9E,$FC,$7D				; $D96B
			defb $33,$FB,$8F,$E7,$7F,$1E,$00,$00				; $D973
			defb $00,$00,$80,$00,$A0,$00,$A0,$00				; $D97B
			defb $A0,$00,$B0,$00,$B0,$00,$70,$00				; $D983
			defb $68,$00,$68,$00,$E8,$00,$D0,$00				; $D98B
			defb $D8,$00,$30,$00,$D0,$00,$00,$FD				; $D993
			defb $1F,$E3,$07,$9F,$00,$74,$00,$03				; $D99B
			defb $00,$3F,$00,$3F,$00,$1E,$00,$0F				; $D9A3
			defb $00,$00,$00,$1F,$00,$1F,$00,$0F				; $D9AB
			defb $00,$73,$01,$7C,$DF,$AD,$A0,$00				; $D9B3
			defb $40,$00,$80,$00,$40,$00,$80,$00				; $D9BB
			defb $40,$00,$80,$00,$80,$00,$21,$F0				; $D9C3
			defb $D3,$0C,$A3,$86,$D5,$FC,$A2,$D0				; $D9CB
			defb $95,$20,$2A,$C8,$55,$B7,$7B,$FF				; $D9D3
			defb $FD,$BF,$FE,$FF,$FF,$7F,$FF,$B7				; $D9DB
			defb $FF,$DF,$7F,$EF,$00,$07,$7F,$AA				; $D9E3
			defb $FF,$F5,$FF,$FA,$7F,$F4,$77,$FA				; $D9EB
			defb $3B,$F4,$1C,$D8,$07,$E0,$F1,$54				; $D9F3
			defb $D8,$AA,$FC,$55,$FE,$2A,$FB,$15				; $D9FB
			defb $FF,$8A,$81,$C4,$60,$E0,$C0,$70				; $DA03
			defb $90,$38,$38,$5C,$78,$EE,$35,$67				; $DA0B
			defb $0E,$A2,$0F,$40,$0F,$A0,$17,$D0				; $DA13
			defb $3B,$D0,$1D,$E8,$00,$D8,$00,$34				; $DA1B
			defb $00,$0E,$00,$06,$00,$01,$00,$00				; $DA23
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $DA2B
			defb $00,$00,$00,$00,$00,$00,$FF,$FE				; $DA33
			defb $80,$00,$BB,$BA,$A2,$20,$A2,$22				; $DA3B
			defb $80,$00,$BB,$BA,$A2,$20,$A2,$22				; $DA43
			defb $80,$00,$BB,$BA,$A2,$20,$A2,$22				; $DA4B
			defb $80,$00,$AA,$AA,$00,$00,$FF,$FE				; $DA53
			defb $80,$00,$BF,$FA,$A0,$00,$AA,$AA				; $DA5B
			defb $A5,$50,$AA,$AA,$A5,$50,$AA,$AA				; $DA63
			defb $A5,$50,$AA,$AA,$A5,$50,$AA,$AA				; $DA6B
			defb $80,$00,$AA,$AA,$00,$00,$DF,$AD				; $DA73
			defb $01,$7C,$00,$73,$00,$0F,$00,$1F				; $DA7B
			defb $00,$1F,$00,$00,$00,$0F,$00,$1E				; $DA83
			defb $00,$3F,$00,$3F,$00,$03,$00,$74				; $DA8B
			defb $07,$9F,$1F,$E3,$00,$FD,$55,$B7				; $DA93
			defb $2A,$C8,$95,$20,$A2,$D0,$D5,$FC				; $DA9B
			defb $A3,$86,$D3,$0C,$21,$F0,$80,$00				; $DAA3
			defb $80,$00,$40,$00,$80,$00,$40,$00				; $DAAB
			defb $80,$00,$40,$00,$A0,$00,$7F,$1E				; $DAB3
			defb $8F,$E7,$33,$FB,$FC,$7D,$1F,$9E				; $DABB
			defb $63,$EE,$FC,$F7,$0F,$3B,$73,$DB				; $DAC3
			defb $DD,$DD,$86,$ED,$43,$6D,$41,$6D				; $DACB
			defb $21,$6D,$19,$6D,$06,$5A,$D0,$00				; $DAD3
			defb $30,$00,$D8,$00,$D0,$00,$E8,$00				; $DADB
			defb $68,$00,$68,$00,$70,$00,$B0,$00				; $DAE3
			defb $B0,$00,$A0,$00,$A0,$00,$A0,$00				; $DAEB
			defb $80,$00,$00,$00,$00,$00,$C1,$83				; $DAF3
			defb $D1,$8B,$C5,$A3,$C1,$83,$C0,$C6				; $DAFB
			defb $C0,$C6,$60,$66,$60,$30,$60,$0F				; $DB03
			defb $60,$00,$20,$10,$20,$20,$20,$C0				; $DB0B
			defb $40,$00,$40,$00,$80,$00,$C1,$83				; $DB13
			defb $C9,$93,$61,$03,$62,$22,$10,$02				; $DB1B
			defb $08,$04,$00,$18,$00,$00,$00,$00				; $DB23
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $DB2B
			defb $00,$00,$00,$00,$00,$00,$C1,$83				; $DB33
			defb $D5,$93,$C1,$A3,$6B,$06,$63,$04				; $DB3B
			defb $36,$08,$30,$00,$18,$00,$0C,$00				; $DB43
			defb $27,$80,$60,$E0,$40,$00,$40,$00				; $DB4B
			defb $80,$00,$80,$00,$80,$00,$C1,$A3				; $DB53
			defb $91,$03,$85,$12,$08,$81,$00,$01				; $DB5B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $DB63
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $DB6B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $DB73
			defb $00,$00,$00,$00,$63,$8E,$E6,$DB				; $DB7B
			defb $66,$DB,$66,$DB,$66,$DB,$66,$DB				; $DB83
			defb $66,$DB,$66,$DB,$66,$DB,$F3,$8E				; $DB8B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $DB93
			defb $00,$00,$00,$00,$63,$CE,$F3,$1B				; $DB9B
			defb $B3,$1B,$33,$1B,$33,$9B,$60,$DB				; $DBA3
			defb $C0,$DB,$C0,$DB,$C2,$DB,$F1,$8E				; $DBAB
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $DBB3
			defb $00,$00,$00,$00,$F3,$8E,$C6,$DB				; $DBBB
			defb $C6,$DB,$C6,$DB,$E6,$DB,$36,$DB				; $DBC3
			defb $36,$DB,$36,$DB,$B6,$DB,$E3,$8E				; $DBCB
			defb $00,$00,$00,$00,$00,$00,$6F,$DA				; $DBD3
			defb $6F,$F4,$6F,$DA,$6F,$F4,$6F,$DA				; $DBDB
			defb $6F,$F4,$6F,$DA,$6F,$F4,$6F,$DA				; $DBE3
			defb $6F,$F4,$6F,$DA,$6F,$F4,$6F,$DA				; $DBEB
			defb $6F,$F4,$6F,$DA,$6F,$F4,$80,$01				; $DBF3
			defb $D5,$55,$DA,$AB,$00,$00,$6D,$5A				; $DBFB
			defb $6E,$B4,$6F,$5A,$6E,$B4,$6F,$5A				; $DC03
			defb $6F,$B4,$6F,$5A,$6F,$B4,$6F,$DA				; $DC0B
			defb $6F,$B4,$6F,$DA,$6F,$F4,$6F,$F4				; $DC13
			defb $6F,$DA,$6F,$B4,$6F,$DA,$6F,$B4				; $DC1B
			defb $6F,$5A,$6F,$B4,$6F,$5A,$6E,$B4				; $DC23
			defb $6F,$5A,$6E,$B4,$6D,$5A,$00,$00				; $DC2B
			defb $DA,$AB,$D5,$55,$80,$01,$35,$54				; $DC33
			defb $7F,$EA,$00,$00,$DC,$E7,$DC,$E7				; $DC3B
			defb $DC,$E7,$00,$00,$6F,$EA,$6F,$F6				; $DC43
			defb $00,$00,$2F,$D4,$37,$EC,$5B,$DA				; $DC4B
			defb $4F,$56,$33,$CC,$80,$01,$35,$54				; $DC53
			defb $7F,$EA,$00,$00,$B9,$CE,$B9,$CE				; $DC5B
			defb $B9,$CE,$00,$00,$6F,$EA,$6F,$F6				; $DC63
			defb $00,$00,$2F,$D4,$37,$EC,$5B,$DA				; $DC6B
			defb $4F,$56,$33,$CC,$80,$01,$35,$54				; $DC73
			defb $7F,$EA,$00,$00,$73,$9D,$73,$9D				; $DC7B
			defb $73,$9D,$00,$00,$6F,$EA,$6F,$F6				; $DC83
			defb $00,$00,$2F,$D4,$37,$EC,$5B,$DA				; $DC8B
			defb $4F,$56,$33,$CC,$80,$01,$35,$54				; $DC93
			defb $7F,$EA,$00,$00,$E7,$3B,$E7,$3B				; $DC9B
			defb $E7,$3B,$00,$00,$6F,$EA,$6F,$F6				; $DCA3
			defb $00,$00,$2F,$D4,$37,$EC,$5B,$DA				; $DCAB
			defb $4F,$56,$33,$CC,$80,$01,$80,$01				; $DCB3
			defb $33,$CC,$4F,$56,$5B,$DA,$37,$EC				; $DCBB
			defb $2F,$D4,$00,$00,$6F,$F6,$6F,$EA				; $DCC3
			defb $00,$00,$E7,$3B,$E7,$3B,$E7,$3B				; $DCCB
			defb $00,$00,$7F,$EA,$35,$54,$80,$01				; $DCD3
			defb $33,$CC,$4F,$56,$5B,$DA,$37,$EC				; $DCDB
			defb $2F,$D4,$00,$00,$6F,$F6,$6F,$EA				; $DCE3
			defb $00,$00,$73,$9D,$73,$9D,$73,$9D				; $DCEB
			defb $00,$00,$7F,$EA,$35,$54,$80,$01				; $DCF3
			defb $33,$CC,$4F,$56,$5B,$DA,$37,$EC				; $DCFB
			defb $2F,$D4,$00,$00,$6F,$F6,$6F,$EA				; $DD03
			defb $00,$00,$B9,$CE,$B9,$CE,$B9,$CE				; $DD0B
			defb $00,$00,$7F,$EA,$35,$54,$80,$01				; $DD13
			defb $33,$CC,$4F,$56,$5B,$DA,$37,$EC				; $DD1B
			defb $2F,$D4,$00,$00,$6F,$F6,$6F,$EA				; $DD23
			defb $00,$00,$DC,$E7,$DC,$E7,$DC,$E7				; $DD2B
			defb $00,$00,$7F,$EA,$35,$54,$01,$00				; $DD33
			defb $00,$00,$03,$80,$03,$80,$00,$00				; $DD3B
			defb $03,$80,$07,$40,$07,$80,$07,$40				; $DD43
			defb $07,$80,$07,$40,$10,$10,$17,$D0				; $DD4B
			defb $3B,$B8,$7B,$BC,$79,$3C,$79,$3C				; $DD53
			defb $7B,$BC,$3B,$B8,$17,$D0,$10,$10				; $DD5B
			defb $07,$40,$07,$80,$07,$40,$07,$80				; $DD63
			defb $07,$40,$03,$80,$00,$00,$03,$80				; $DD6B
			defb $03,$80,$00,$00,$01,$00,$00,$00				; $DD73
			defb $0F,$FE,$3F,$7E,$3F,$7E,$7F,$BE				; $DD7B
			defb $7F,$DC,$7F,$DA,$7F,$EC,$1F,$E2				; $DD83
			defb $67,$F4,$79,$FA,$7E,$78,$7F,$94				; $DD8B
			defb $7F,$A6,$7D,$58,$00,$00,$00,$00				; $DD93
			defb $7E,$F0,$7E,$FC,$7D,$FC,$7D,$FE				; $DD9B
			defb $7B,$FC,$7B,$FA,$77,$FC,$77,$F2				; $DDA3
			defb $6F,$EC,$6F,$9A,$5E,$74,$5C,$FA				; $DDAB
			defb $33,$F4,$27,$AA,$00,$00,$00,$00				; $DDB3
			defb $55,$E4,$2F,$CC,$5F,$3A,$2E,$7A				; $DDBB
			defb $59,$F6,$37,$F6,$4F,$EC,$3F,$EE				; $DDC3
			defb $5F,$DC,$3F,$DA,$7F,$BC,$3F,$BA				; $DDCB
			defb $3F,$74,$0F,$6A,$00,$00,$00,$00				; $DDD3
			defb $1F,$FE,$67,$FE,$39,$FE,$1E,$7E				; $DDDB
			defb $5F,$9C,$6F,$E6,$67,$F8,$77,$FE				; $DDE3
			defb $7B,$FC,$7B,$FA,$7D,$FC,$7E,$FA				; $DDEB
			defb $7E,$F4,$7F,$68,$00,$00,$00,$00				; $DDF3
			defb $DF,$FF,$DF,$FF,$DF,$FF,$00,$00				; $DDFB
			defb $6F,$FF,$6F,$FF,$6F,$FF,$00,$00				; $DE03
			defb $1B,$FF,$1B,$FF,$1B,$FF,$1B,$FF				; $DE0B
			defb $1B,$FF,$1B,$FF,$1B,$FF,$00,$00				; $DE13
			defb $FD,$55,$FE,$AA,$FD,$55,$00,$00				; $DE1B
			defb $FE,$AA,$FD,$54,$FE,$AA,$00,$00				; $DE23
			defb $FE,$A8,$FD,$50,$FE,$A8,$FD,$50				; $DE2B
			defb $FA,$A8,$F5,$50,$AA,$A8,$00,$00				; $DE33
			defb $EF,$FF,$EE,$FF,$EF,$FF,$76,$FF				; $DE3B
			defb $77,$FF,$3B,$7F,$00,$00,$0D,$DF				; $DE43
			defb $0D,$FF,$0D,$DF,$0D,$FF,$0D,$DF				; $DE4B
			defb $0D,$FF,$0D,$DF,$0D,$FF,$00,$00				; $DE53
			defb $F5,$55,$FA,$AA,$F5,$55,$FA,$AA				; $DE5B
			defb $F5,$56,$EA,$A8,$00,$00,$55,$50				; $DE63
			defb $AA,$A0,$D5,$50,$EA,$A0,$D5,$50				; $DE6B
			defb $EA,$A0,$D5,$50,$EA,$A0,$0D,$DF				; $DE73
			defb $0D,$FF,$0D,$DF,$0D,$FF,$0D,$DF				; $DE7B
			defb $0D,$FF,$0D,$DF,$00,$00,$37,$7F				; $DE83
			defb $37,$FF,$37,$7F,$00,$00,$EE,$FF				; $DE8B
			defb $EF,$FF,$EE,$FF,$00,$00,$D5,$50				; $DE93
			defb $EA,$A0,$D5,$50,$EA,$A0,$D5,$50				; $DE9B
			defb $AA,$A0,$55,$50,$00,$00,$D5,$54				; $DEA3
			defb $EA,$A8,$F5,$54,$00,$00,$F5,$55				; $DEAB
			defb $FA,$AA,$F5,$55,$00,$00,$FF,$7F				; $DEB3
			defb $FF,$5F,$FF,$7F,$FF,$7F,$7F,$7F				; $DEBB
			defb $7F,$7F,$7F,$7F,$3F,$7F,$3F,$7F				; $DEC3
			defb $1F,$7F,$0F,$7F,$07,$7F,$03,$7F				; $DECB
			defb $01,$5F,$00,$7F,$00,$0F,$FE,$AB				; $DED3
			defb $FA,$D5,$FE,$AA,$FE,$D5,$FE,$AA				; $DEDB
			defb $FE,$D4,$FE,$AA,$FE,$D4,$FE,$94				; $DEE3
			defb $FE,$A8,$FE,$D0,$FE,$A0,$FE,$C0				; $DEEB
			defb $FA,$80,$FE,$00,$F0,$00,$FF,$54				; $DEF3
			defb $FF,$2B,$FF,$57,$FF,$00,$7F,$7F				; $DEFB
			defb $7F,$5F,$7F,$7F,$3F,$7F,$3F,$7F				; $DF03
			defb $1F,$7F,$0F,$7F,$07,$7F,$03,$7F				; $DF0B
			defb $01,$7F,$00,$7F,$00,$0F,$14,$AB				; $DF13
			defb $CA,$D5,$E4,$AA,$00,$D5,$FE,$AA				; $DF1B
			defb $FA,$D4,$FE,$AA,$FE,$D4,$FE,$94				; $DF23
			defb $FE,$A8,$FE,$D0,$FE,$A0,$FE,$C0				; $DF2B
			defb $FE,$80,$FE,$00,$F0,$00,$FF,$54				; $DF33
			defb $FF,$2B,$FF,$57,$FF,$24,$7F,$48				; $DF3B
			defb $7F,$28,$7F,$48,$3F,$00,$3F,$7F				; $DF43
			defb $1F,$5F,$0F,$7F,$07,$7F,$03,$7F				; $DF4B
			defb $01,$7F,$00,$7F,$00,$0F,$14,$AB				; $DF53
			defb $CA,$D5,$E4,$AA,$22,$D5,$10,$AA				; $DF5B
			defb $12,$D4,$10,$AA,$00,$D4,$FE,$94				; $DF63
			defb $FA,$A8,$FE,$D0,$FE,$A0,$FE,$C0				; $DF6B
			defb $FE,$80,$FE,$00,$F0,$00,$FF,$54				; $DF73
			defb $FF,$2B,$FF,$57,$FF,$24,$7F,$48				; $DF7B
			defb $7F,$28,$7F,$48,$3F,$28,$3F,$44				; $DF83
			defb $1F,$23,$0F,$54,$07,$00,$03,$7F				; $DF8B
			defb $01,$5F,$00,$7F,$00,$0F,$14,$AB				; $DF93
			defb $CA,$D5,$E4,$AA,$22,$D5,$10,$AA				; $DF9B
			defb $12,$D4,$10,$AA,$12,$D4,$20,$94				; $DFA3
			defb $C2,$A8,$04,$D0,$00,$A0,$FE,$C0				; $DFAB
			defb $FA,$80,$FE,$00,$F0,$00,$FF,$FF				; $DFB3
			defb $7F,$FF,$3F,$FF,$1F,$FF,$0F,$FF				; $DFBB
			defb $07,$E0,$03,$F0,$01,$F8,$00,$FC				; $DFC3
			defb $00,$7E,$00,$3F,$00,$1F,$00,$0F				; $DFCB
			defb $00,$07,$00,$03,$00,$01,$FF,$DF				; $DFD3
			defb $FF,$BF,$FF,$1F,$FE,$0F,$FC,$0F				; $DFDB
			defb $00,$0F,$00,$0F,$00,$0F,$00,$0F				; $DFE3
			defb $00,$0F,$00,$0F,$80,$0F,$C0,$0F				; $DFEB
			defb $E0,$0F,$F0,$0F,$F8,$0F,$F0,$3F				; $DFF3
			defb $E0,$7F,$C0,$FF,$81,$F8,$83,$F0				; $DFFB
			defb $87,$E0,$8F,$FF,$9F,$FF,$BF,$FF				; $E003
			defb $BE,$0F,$BC,$1F,$B8,$3F,$BF,$FF				; $E00B
			defb $BF,$FF,$BF,$FF,$BF,$FE,$F8,$01				; $E013
			defb $FC,$03,$FE,$07,$3F,$0F,$7E,$1F				; $E01B
			defb $FC,$3F,$F8,$7F,$F0,$FF,$C1,$FF				; $E023
			defb $E3,$F0,$F7,$E0,$EF,$C0,$DF,$FF				; $E02B
			defb $BF,$FF,$7F,$FF,$FF,$FF,$FF,$FB				; $E033
			defb $FF,$F7,$FF,$EF,$FF,$DF,$80,$3F				; $E03B
			defb $00,$7E,$FE,$FF,$FD,$FF,$FB,$FF				; $E043
			defb $07,$FF,$0F,$CF,$1F,$87,$FF,$03				; $E04B
			defb $FE,$01,$FC,$00,$F8,$00,$FF,$80				; $E053
			defb $FF,$C1,$FF,$E3,$83,$F7,$07,$EF				; $E05B
			defb $0F,$DF,$FF,$BF,$FF,$7E,$FE,$FC				; $E063
			defb $81,$F8,$C3,$F0,$E7,$E0,$FF,$C1				; $E06B
			defb $FF,$83,$FF,$07,$7E,$0F,$FF,$E0				; $E073
			defb $FF,$F0,$FF,$F8,$E0,$FD,$C1,$FB				; $E07B
			defb $83,$F7,$07,$EF,$0F,$DF,$1F,$BF				; $E083
			defb $3F,$7E,$7E,$FC,$FD,$F8,$FB,$FF				; $E08B
			defb $F1,$FF,$E0,$FF,$C0,$7F,$3F,$F8				; $E093
			defb $7F,$FC,$FF,$FE,$F8,$3F,$F0,$7E				; $E09B
			defb $E0,$FD,$C1,$FB,$83,$F7,$07,$EF				; $E0A3
			defb $0F,$DF,$1F,$BF,$3F,$7E,$FE,$FD				; $E0AB
			defb $FD,$FB,$FB,$F7,$F7,$EF,$0F,$CF				; $E0B3
			defb $1F,$8F,$3F,$4F,$7E,$EF,$01,$FF				; $E0BB
			defb $FB,$FF,$F7,$FF,$EF,$DF,$DF,$8F				; $E0C3
			defb $BF,$0F,$7E,$0F,$FC,$0F,$FF,$FF				; $E0CB
			defb $FF,$FF,$FF,$FF,$FF,$FF,$80,$00				; $E0D3
			defb $80,$00,$80,$00,$80,$00,$80,$00				; $E0DB
			defb $80,$00,$80,$00,$80,$00,$80,$00				; $E0E3
			defb $80,$00,$80,$00,$80,$00,$80,$00				; $E0EB
			defb $80,$00,$80,$00,$80,$00,$FF,$EF				; $E0F3
			defb $7F,$EF,$3F,$EF,$1F,$EF,$0F,$EF				; $E0FB
			defb $07,$EF,$03,$EF,$01,$EF,$00,$0F				; $E103
			defb $00,$7F,$00,$3F,$00,$1F,$00,$0F				; $E10B
			defb $00,$07,$00,$03,$00,$01,$80,$00				; $E113
			defb $80,$00,$80,$00,$80,$00,$80,$00				; $E11B
			defb $83,$ED,$87,$DB,$83,$36,$86,$7D				; $E123
			defb $8C,$FB,$99,$B6,$B3,$6F,$A6,$DE				; $E12B
			defb $80,$00,$80,$00,$80,$00,$00,$00				; $E133
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E13B
			defb $BC,$0F,$78,$1E,$C0,$30,$E0,$7B				; $E143
			defb $C0,$F6,$01,$8D,$03,$1B,$06,$31				; $E14B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E153
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E15B
			defb $6E,$36,$DF,$6D,$36,$D8,$61,$F1				; $E163
			defb $D3,$63,$B6,$C6,$ED,$8C,$DB,$19				; $E16B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E173
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E17B
			defb $FB,$71,$F6,$FB,$C1,$B6,$9B,$6C				; $E183
			defb $36,$DA,$6D,$B6,$DB,$7C,$B6,$38				; $E18B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E193
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E19B
			defb $C0,$31,$E0,$7F,$C0,$D6,$01,$8D				; $E1A3
			defb $03,$1B,$06,$36,$0C,$6D,$18,$DB				; $E1AB
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E1B3
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E1BB
			defb $BC,$E3,$7D,$F6,$DB,$6D,$B6,$1F				; $E1C3
			defb $EC,$3E,$D8,$6D,$BE,$DB,$1D,$B6				; $E1CB
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E1D3
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E1DB
			defb $6D,$C7,$DB,$EF,$86,$D8,$6D,$BC				; $E1E3
			defb $DB,$78,$B6,$C0,$6D,$E0,$DB,$C0				; $E1EB
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E1F3
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E1FB
			defb $80,$00,$00,$00,$00,$00,$00,$00				; $E203
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E20B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E213
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E21B
			defb $00,$00,$00,$00,$00,$00,$7F,$E0				; $E223
			defb $3F,$C0,$1F,$80,$0F,$C0,$07,$E0				; $E22B
			defb $03,$F0,$01,$F8,$00,$1D,$00,$00				; $E233
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E23B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E243
			defb $00,$00,$FF,$C0,$7F,$80,$3F,$00				; $E24B
			defb $7E,$00,$FC,$00,$F8,$00,$00,$00				; $E253
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E25B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E263
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E26B
			defb $00,$00,$00,$0F,$00,$0F,$00,$00				; $E273
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E27B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E283
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E28B
			defb $00,$00,$E0,$00,$C0,$00,$00,$00				; $E293
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E29B
			defb $00,$00,$00,$00,$00,$50,$00,$22				; $E2A3
			defb $03,$05,$07,$56,$BB,$76,$07,$56				; $E2AB
			defb $03,$05,$00,$22,$00,$50,$03,$C0				; $E2B3
			defb $0F,$F0,$1C,$38,$3B,$1C,$37,$0C				; $E2BB
			defb $36,$0C,$34,$04,$34,$08,$30,$04				; $E2C3
			defb $34,$08,$30,$04,$30,$08,$38,$14				; $E2CB
			defb $1C,$28,$0E,$D0,$03,$40,$03,$C0				; $E2D3
			defb $07,$E0,$0F,$F0,$0C,$30,$19,$18				; $E2DB
			defb $1B,$18,$1B,$18,$1A,$08,$18,$10				; $E2E3
			defb $1A,$08,$18,$10,$18,$08,$0C,$30				; $E2EB
			defb $0F,$50,$07,$A0,$03,$40,$01,$80				; $E2F3
			defb $03,$C0,$07,$E0,$0E,$70,$1C,$38				; $E2FB
			defb $39,$1C,$73,$0E,$E7,$07,$E0,$05				; $E303
			defb $70,$0A,$38,$14,$1C,$28,$0E,$50				; $E30B
			defb $06,$A0,$03,$40,$01,$80,$01,$80				; $E313
			defb $03,$40,$07,$A0,$0F,$50,$1F,$A8				; $E31B
			defb $3F,$54,$7F,$AA,$FF,$55,$AA,$01				; $E323
			defb $55,$02,$2A,$04,$15,$08,$0A,$10				; $E32B
			defb $05,$20,$02,$40,$01,$80,$0F,$D0				; $E333
			defb $08,$10,$00,$00,$17,$E8,$2F,$F4				; $E33B
			defb $2F,$E8,$2F,$D4,$00,$00,$5F,$EA				; $E343
			defb $5F,$F4,$5F,$EA,$5F,$F4,$5F,$EA				; $E34B
			defb $5F,$F4,$5F,$EA,$2F,$D4,$00,$00				; $E353
			defb $81,$02,$6D,$6C,$4B,$A4,$1C,$70				; $E35B
			defb $7F,$FC,$5E,$F4,$2D,$68,$ED,$6E				; $E363
			defb $2D,$68,$5E,$F4,$7F,$FC,$1C,$70				; $E36B
			defb $4B,$A4,$6D,$6C,$81,$02,$00,$00				; $E373
			defb $FF,$FF,$3F,$FF,$55,$55,$00,$00				; $E37B
			defb $AA,$AA,$55,$55,$AA,$AA,$55,$55				; $E383
			defb $AA,$AA,$55,$55,$00,$00,$FF,$FF				; $E38B
			defb $3F,$FF,$55,$55,$00,$00,$7F,$FE				; $E393
			defb $7F,$FC,$60,$06,$6D,$B4,$69,$26				; $E39B
			defb $69,$24,$60,$06,$6F,$F4,$6C,$06				; $E3A3
			defb $60,$04,$6D,$B6,$69,$24,$69,$26				; $E3AB
			defb $60,$04,$7F,$FE,$55,$54,$72,$AE				; $E3B3
			defb $65,$4C,$72,$AE,$65,$4C,$72,$AE				; $E3BB
			defb $65,$4C,$72,$AE,$65,$4C,$72,$AE				; $E3C3
			defb $65,$4C,$72,$AE,$65,$4C,$72,$AE				; $E3CB
			defb $65,$4C,$52,$AA,$45,$48,$00,$00				; $E3D3
			defb $7E,$F8,$9B,$F5,$C7,$FE,$70,$7D				; $E3DB
			defb $FF,$6E,$7F,$1D,$EF,$7E,$FE,$FD				; $E3E3
			defb $BF,$FE,$7F,$FD,$DD,$F4,$FF,$F9				; $E3EB
			defb $6F,$FE,$BF,$FD,$FD,$FE,$BF,$FD				; $E3F3
			defb $DD,$FA,$FB,$FD,$7F,$FA,$1F,$FC				; $E3FB
			defb $6E,$F8,$FF,$F5,$F9,$FA,$EF,$FD				; $E403
			defb $BF,$FA,$7B,$FC,$FF,$FA,$9F,$FD				; $E40B
			defb $7F,$FA,$FB,$FD,$BF,$FA,$BF,$DD				; $E413
			defb $DF,$FA,$FF,$F5,$77,$EA,$BF,$FC				; $E41B
			defb $EF,$FA,$F8,$FC,$FF,$BA,$AF,$F9				; $E423
			defb $FF,$FA,$7E,$FD,$7F,$FA,$9F,$F5				; $E42B
			defb $FF,$EA,$F7,$FD,$7F,$FA,$EF,$FD				; $E433
			defb $7E,$F8,$9B,$F5,$C7,$FE,$70,$7D				; $E43B
			defb $FF,$6E,$7F,$1D,$EF,$7E,$FE,$FD				; $E443
			defb $BF,$FE,$7F,$FD,$DD,$F4,$FF,$F9				; $E44B
			defb $6F,$FE,$BF,$FD,$FD,$FE,$BF,$DD				; $E453
			defb $DF,$FA,$FF,$F5,$77,$EA,$BF,$FC				; $E45B
			defb $EF,$FA,$F8,$FC,$FF,$BA,$AF,$F9				; $E463
			defb $FF,$FA,$7E,$FD,$7F,$FA,$9F,$F5				; $E46B
			defb $FF,$EA,$F4,$0D,$00,$00,$00,$00				; $E473
			defb $00,$00,$00,$01,$00,$03,$00,$06				; $E47B
			defb $00,$04,$00,$04,$00,$0C,$00,$39				; $E483
			defb $00,$33,$00,$F7,$03,$F6,$07,$9E				; $E48B
			defb $3E,$7A,$7D,$E6,$E1,$C3,$00,$00				; $E493
			defb $A0,$02,$90,$12,$2A,$46,$60,$5B				; $E49B
			defb $72,$0D,$6E,$F5,$E6,$E6,$C6,$66				; $E4A3
			defb $0C,$63,$5D,$71,$18,$65,$30,$E3				; $E4AB
			defb $65,$CB,$D1,$A3,$C1,$83,$00,$00				; $E4B3
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E4BB
			defb $00,$00,$80,$00,$C0,$00,$60,$00				; $E4C3
			defb $30,$00,$BE,$00,$9A,$00,$9B,$60				; $E4CB
			defb $70,$FC,$6A,$C7,$C0,$D3,$00,$00				; $E4D3
			defb $FF,$FF,$7F,$F5,$00,$00,$0F,$C0				; $E4DB
			defb $00,$00,$07,$80,$03,$00,$C3,$00				; $E4E3
			defb $C3,$00,$DD,$00,$CE,$00,$D7,$00				; $E4EB
			defb $DF,$00,$C0,$00,$C0,$00,$00,$00				; $E4F3
			defb $FF,$FF,$55,$56,$00,$00,$03,$F0				; $E4FB
			defb $00,$00,$01,$E0,$00,$C0,$00,$C3				; $E503
			defb $00,$C2,$00,$BB,$00,$72,$00,$EB				; $E50B
			defb $00,$FA,$00,$03,$00,$02,$07,$00				; $E513
			defb $1F,$78,$3F,$34,$7F,$7A,$7F,$34				; $E51B
			defb $FF,$7A,$FF,$34,$FE,$7A,$00,$34				; $E523
			defb $45,$7A,$6F,$F4,$6F,$FA,$6F,$F4				; $E52B
			defb $6F,$FA,$6F,$F4,$6F,$FA,$00,$E0				; $E533
			defb $2E,$F8,$6E,$FC,$6E,$FE,$6E,$FE				; $E53B
			defb $6E,$FF,$6E,$FF,$6E,$7F,$6E,$00				; $E543
			defb $6E,$AA,$6F,$D4,$6F,$EA,$6F,$F4				; $E54B
			defb $6F,$EA,$6F,$F4,$6F,$EA,$6F,$F4				; $E553
			defb $6F,$EA,$6F,$F4,$6F,$EA,$6F,$F4				; $E55B
			defb $6F,$EA,$6F,$F4,$6F,$EA,$6F,$F4				; $E563
			defb $6F,$EA,$6F,$F4,$6F,$EA,$6F,$F4				; $E56B
			defb $6F,$EA,$6F,$F4,$6F,$EA,$00,$00				; $E573
			defb $FF,$FF,$80,$00,$95,$55,$AA,$AA				; $E57B
			defb $95,$55,$AA,$AA,$95,$55,$AA,$AA				; $E583
			defb $95,$55,$AA,$AA,$95,$55,$AA,$AA				; $E58B
			defb $95,$55,$AA,$AA,$95,$55,$00,$00				; $E593
			defb $00,$00,$00,$00,$00,$00,$00,$1F				; $E59B
			defb $00,$00,$00,$3F,$00,$00,$00,$7F				; $E5A3
			defb $00,$7F,$00,$70,$00,$78,$00,$7C				; $E5AB
			defb $00,$7E,$00,$FF,$1F,$FD,$00,$00				; $E5B3
			defb $00,$00,$00,$00,$00,$00,$A8,$00				; $E5BB
			defb $00,$00,$D4,$00,$00,$00,$EA,$00				; $E5C3
			defb $F4,$00,$0A,$00,$14,$00,$2A,$00				; $E5CB
			defb $74,$00,$EA,$00,$55,$F8,$00,$00				; $E5D3
			defb $FF,$FD,$F3,$CA,$F3,$CD,$F3,$CA				; $E5DB
			defb $E1,$CD,$DE,$CA,$E1,$CD,$F3,$CA				; $E5E3
			defb $F3,$85,$F3,$7A,$F3,$85,$F3,$CA				; $E5EB
			defb $F3,$C5,$FF,$EA,$00,$00,$0E,$C0				; $E5F3
			defb $3E,$50,$7E,$AC,$FE,$55,$00,$00				; $E5FB
			defb $FF,$FF,$7F,$FC,$0F,$E0,$00,$00				; $E603
			defb $77,$C0,$EF,$BA,$5F,$00,$00,$00				; $E60B
			defb $7B,$00,$FB,$6A,$7B,$00,$06,$E0				; $E613
			defb $1F,$F8,$3E,$F4,$7F,$FA,$00,$00				; $E61B
			defb $FE,$FD,$FF,$FA,$FD,$F5,$F7,$FA				; $E623
			defb $5F,$F5,$FF,$EA,$00,$00,$7F,$EA				; $E62B
			defb $3F,$D4,$1F,$68,$06,$A0,$00,$00				; $E633
			defb $00,$00,$00,$00,$00,$00,$07,$E0				; $E63B
			defb $04,$20,$70,$0A,$75,$6C,$72,$AA				; $E643
			defb $70,$0E,$04,$20,$06,$A0,$00,$00				; $E64B
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $E653
			defb $03,$C0,$01,$80,$00,$00,$07,$E0				; $E65B
			defb $04,$20,$70,$0A,$75,$6C,$72,$AA				; $E663
			defb $70,$0E,$04,$20,$06,$A0,$00,$00				; $E66B
			defb $01,$80,$03,$C0,$00,$00,$00,$00				; $E673
			defb $03,$40,$03,$80,$03,$40,$00,$00				; $E67B
			defb $0D,$B0,$09,$00,$09,$90,$09,$00				; $E683
			defb $09,$90,$0D,$30,$00,$00,$03,$40				; $E68B
			defb $03,$80,$03,$40,$00,$00,$37,$F4				; $E693
			defb $6F,$FA,$6F,$FA,$6F,$F4,$6F,$FA				; $E69B
			defb $6F,$F4,$40,$02,$37,$F4,$37,$E8				; $E6A3
			defb $37,$F4,$37,$E8,$37,$F4,$37,$E8				; $E6AB
			defb $37,$F4,$37,$E8,$37,$F4,$37,$E8				; $E6B3
			defb $37,$F4,$37,$E8,$37,$F4,$37,$E8				; $E6BB
			defb $37,$F4,$37,$E8,$37,$F4,$37,$E8				; $E6C3
			defb $37,$D4,$37,$E8,$37,$D4,$37,$E8				; $E6CB
			defb $37,$D4,$37,$A8,$37,$54,$00,$00				; $E6D3
			defb $DF,$FF,$DF,$F5,$00,$00,$77,$EA				; $E6DB
			defb $00,$00,$1B,$E8,$1B,$F0,$1B,$E8				; $E6E3
			defb $1B,$F0,$1B,$E8,$1B,$F0,$1B,$E8				; $E6EB
			defb $00,$00,$77,$EA,$EF,$55,$4F,$F4				; $E6F3
			defb $F3,$F9,$3C,$F5,$CF,$39,$73,$CC				; $E6FB
			defb $28,$F0,$35,$3C,$2A,$8F,$35,$57				; $E703
			defb $2A,$AB,$35,$53,$6A,$AB,$D5,$53				; $E70B
			defb $00,$00,$FF,$FF,$3F,$FC,$00,$00				; $E713
			defb $80,$00,$B0,$00,$B8,$00,$78,$00				; $E71B
			defb $20,$00,$0C,$00,$3C,$00,$5C,$00				; $E723
			defb $60,$00,$78,$00,$70,$00,$40,$00				; $E72B
			defb $00,$00,$00,$00,$00,$00,$C0,$03				; $E733
			defb $FF,$FF,$00,$00,$6F,$F6,$4B,$D4				; $E73B
			defb $6F,$F6,$4F,$F4,$6F,$F6,$4F,$F4				; $E743
			defb $6F,$F6,$4F,$F4,$6F,$F6,$4F,$F4				; $E74B
			defb $6B,$D6,$4F,$F4,$6F,$F6,$00,$00				; $E753
			defb $00,$01,$00,$0D,$00,$1D,$00,$1E				; $E75B
			defb $00,$04,$00,$30,$00,$3C,$00,$3A				; $E763
			defb $00,$06,$00,$1E,$00,$0E,$00,$02				; $E76B
			defb $00,$00,$00,$00,$00,$00,$2F,$F2				; $E773
			defb $9F,$CF,$AF,$3C,$9C,$F3,$33,$CE				; $E77B
			defb $0F,$14,$3C,$AC,$F1,$54,$EA,$AC				; $E783
			defb $D5,$54,$CA,$AC,$D5,$56,$CA,$AB				; $E78B
			defb $00,$00,$FF,$FF,$3F,$FC,$6F,$F6				; $E793
			defb $4F,$F4,$6B,$D6,$4F,$F4,$6F,$F6				; $E79B
			defb $4F,$F4,$6F,$F6,$4F,$F4,$6F,$F6				; $E7A3
			defb $4F,$F4,$6F,$F6,$4B,$D4,$6F,$F6				; $E7AB
			defb $00,$00,$FF,$FF,$C0,$03,$00,$00				; $E7B3
			defb $7F,$FF,$5F,$FF,$60,$00,$60,$03				; $E7BB
			defb $60,$0C,$6C,$30,$63,$00,$60,$C0				; $E7C3
			defb $6C,$30,$60,$0C,$60,$03,$60,$00				; $E7CB
			defb $5F,$FF,$55,$55,$00,$00,$00,$00				; $E7D3
			defb $FF,$FF,$FF,$FF,$00,$00,$C0,$03				; $E7DB
			defb $30,$0C,$0C,$30,$03,$00,$00,$C0				; $E7E3
			defb $0C,$30,$30,$0C,$C0,$03,$00,$00				; $E7EB
			defb $FF,$FF,$55,$55,$00,$00,$00,$00				; $E7F3
			defb $FF,$FE,$FF,$FA,$00,$06,$C0,$06				; $E7FB
			defb $30,$06,$0C,$34,$00,$C6,$03,$04				; $E803
			defb $0C,$32,$30,$04,$C0,$02,$00,$04				; $E80B
			defb $FF,$FA,$55,$54,$00,$00,$00,$00				; $E813
			defb $7F,$FE,$5F,$F8,$60,$06,$62,$44				; $E81B
			defb $62,$46,$61,$04,$61,$06,$60,$84				; $E823
			defb $60,$86,$62,$44,$62,$46,$64,$24				; $E82B
			defb $64,$26,$68,$14,$68,$16,$68,$14				; $E833
			defb $68,$16,$64,$24,$64,$26,$62,$44				; $E83B
			defb $62,$46,$61,$04,$61,$06,$60,$84				; $E843
			defb $60,$86,$62,$44,$62,$46,$64,$24				; $E84B
			defb $64,$26,$68,$14,$68,$16,$68,$14				; $E853
			defb $68,$16,$64,$24,$64,$26,$62,$44				; $E85B
			defb $62,$46,$60,$84,$60,$86,$61,$04				; $E863
			defb $61,$06,$62,$44,$62,$46,$60,$04				; $E86B
			defb $5F,$AA,$7D,$54,$00,$00,$00,$00				; $E873
			defb $00,$00,$00,$00,$00,$00,$00,$01				; $E87B
			defb $00,$01,$00,$01,$00,$00,$00,$00				; $E883
			defb $00,$04,$00,$08,$00,$10,$00,$10				; $E88B
			defb $00,$20,$00,$20,$00,$20,$20,$00				; $E893
			defb $40,$00,$80,$00,$80,$00,$08,$00				; $E89B
			defb $04,$00,$02,$00,$83,$00,$C1,$00				; $E8A3
			defb $41,$00,$61,$00,$21,$00,$32,$00				; $E8AB
			defb $18,$00,$0C,$00,$34,$00,$00,$20				; $E8B3
			defb $00,$13,$00,$1A,$00,$0C,$00,$36				; $E8BB
			defb $00,$76,$00,$63,$00,$C3,$00,$C3				; $E8C3
			defb $00,$C6,$00,$AE,$00,$E4,$00,$D0				; $E8CB
			defb $00,$68,$00,$74,$00,$BD,$C6,$00				; $E8D3
			defb $06,$00,$02,$00,$03,$00,$02,$00				; $E8DB
			defb $03,$00,$02,$00,$07,$00,$06,$00				; $E8E3
			defb $0D,$00,$0A,$00,$1E,$00,$34,$00				; $E8EB
			defb $7C,$00,$E8,$00,$F0,$00,$03,$BB				; $E8F3
			defb $0F,$D7,$1F,$EF,$1F,$EF,$3F,$9F				; $E8FB
			defb $3F,$3F,$3E,$7F,$1E,$FF,$1A,$FE				; $E903
			defb $0D,$7D,$0B,$BE,$07,$BD,$0F,$B2				; $E90B
			defb $1F,$69,$7E,$16,$E8,$C0,$D0,$00				; $E913
			defb $F3,$00,$A5,$C0,$A9,$A0,$D7,$50				; $E91B
			defb $8F,$A0,$57,$D0,$4F,$E8,$4F,$D0				; $E923
			defb $AB,$E8,$A5,$D0,$52,$E8,$A9,$90				; $E92B
			defb $54,$60,$AA,$90,$41,$5A,$00,$00				; $E933
			defb $0D,$DF,$0D,$FF,$0D,$DF,$0D,$FF				; $E93B
			defb $0D,$DF,$0D,$FF,$0D,$DF,$00,$00				; $E943
			defb $3B,$7F,$77,$FF,$76,$FF,$EF,$FF				; $E94B
			defb $EE,$FF,$EF,$FF,$00,$00,$00,$00				; $E953
			defb $D5,$50,$EA,$A0,$D5,$50,$EA,$A0				; $E95B
			defb $D5,$50,$AA,$A0,$55,$50,$00,$00				; $E963
			defb $EA,$A8,$F5,$56,$FA,$AA,$F5,$55				; $E96B
			defb $FA,$AA,$F5,$55,$00,$00,$01,$80				; $E973
			defb $FD,$3F,$FD,$BF,$55,$15,$01,$80				; $E97B
			defb $07,$E0,$04,$20,$F5,$6F,$54,$A5				; $E983
			defb $05,$60,$07,$E0,$01,$80,$FD,$3F				; $E98B
			defb $A9,$AA,$55,$35,$01,$80,$61,$0C				; $E993
			defb $71,$8A,$61,$0C,$71,$8A,$60,$0C				; $E99B
			defb $77,$EA,$04,$20,$FD,$7F,$AC,$B5				; $E9A3
			defb $05,$60,$67,$EE,$70,$0A,$61,$0C				; $E9AB
			defb $71,$8A,$61,$0C,$71,$8A						; $E9B3
			; END OF TILE GRAPHICS
			;--------------------------------------------------------------------------

			defb $00											; $E9B9
			defb $00											; $E9BA
			defb $00,$00,$43,$43,$42,$43,$43,$42				; $E9BB
			defb $42,$43,$43,$42,$42,$43,$43,$42				; $E9C3 BCCBBCCB
			defb $43,$43,$43,$42,$42,$43,$00,$44				; $E9CB CCCBBC.D
			defb $44,$44,$44,$04,$44,$04,$04,$00				; $E9D3 DDD.D...
			defb $04,$04,$47,$45,$47,$45,$44,$04				; $E9DB ..GEGED.
			defb $44,$04,$47,$45,$47,$45,$42,$43				; $E9E3 D.GEGEBC
			defb $43,$42,$00,$00,$43,$42,$42,$43				; $E9EB CB..CBBC
			defb $43,$42,$00,$00,$43,$42,$47,$45				; $E9F3 CB..CBGE
			defb $47,$45,$47,$45,$47,$45,$47,$45				; $E9FB GEGEGEGE
			defb $47,$45,$47,$45,$47,$45,$46,$46				; $EA03 GEGEGEFF
			defb $06,$06,$46,$06,$46,$06,$47,$45				; $EA0B ..F.F.GE
			defb $47,$05,$45,$07,$05,$07,$47,$46				; $EA13 G.E...GF
			defb $06,$06,$43,$43,$42,$42,$43,$43				; $EA1B ..CCBBCC
			defb $42,$42,$43,$43,$42,$42,$43,$43				; $EA23 BBCCBBCC
			defb $42,$42,$47,$07,$47,$07,$47,$07				; $EA2B BBG.G.G.
			defb $47,$07,$47,$07,$47,$07,$47,$07				; $EA33 G.G.G.G.
			defb $47,$07,$47,$07,$47,$07,$47,$07				; $EA3B G.G.G.G.
			defb $47,$07,$44,$44,$44,$44,$04,$04				; $EA43 G.DDDD..
			defb $04,$04,$44,$44,$44,$44,$04,$04				; $EA4B ..DDDD..
			defb $04,$04,$47,$46,$46,$46,$06,$00				; $EA53 ..GFFF..
			defb $06,$00,$06,$06,$47,$46,$06,$00				; $EA5B ....GF..
			defb $06,$06,$47,$46,$45,$05,$46,$06				; $EA63 ..GFE.F.
			defb $46,$06,$46,$47,$00,$00,$05,$44				; $EA6B F.FG...D
			defb $44,$04,$05,$04,$44,$04,$47,$06				; $EA73 D...D.G.
			defb $06,$06,$06,$06,$06,$00,$46,$46				; $EA7B ......FF
			defb $47,$46,$06,$00,$06,$00,$43,$42				; $EA83 GF....CB
			defb $42,$43,$43,$42,$00,$00,$43,$42				; $EA8B BCCB..CB
			defb $42,$43,$43,$42,$00,$00,$47,$47				; $EA93 BCCB..GG
			defb $47,$47,$47,$47,$47,$47,$47,$47				; $EA9B GGGGGGGG
			defb $47,$47,$45,$04,$45,$04,$45,$04				; $EAA3 GGE.E.E.
			defb $45,$04,$45,$04,$45,$04,$47,$47				; $EAAB E.E.E.GG
			defb $47,$47,$47,$47,$47,$47,$47,$47				; $EAB3 GGGGGGGG
			defb $47,$47,$47,$47,$47,$47,$47,$47				; $EABB GGGGGGGG
			defb $47,$47,$47,$47,$47,$47,$47,$47				; $EAC3 GGGGGGGG
			defb $47,$47,$47,$47,$47,$47,$47,$45				; $EACB GGGGGGGE
			defb $47,$45,$47,$45,$47,$45,$47,$45				; $EAD3 GEGEGEGE
			defb $47,$05,$47,$45,$47,$05,$47,$45				; $EADB G.GEG.GE
			defb $47,$05,$47,$45,$47,$05,$47,$46				; $EAE3 G.GEG.GF
			defb $47,$46,$06,$06,$06,$06,$47,$45				; $EAEB GF....GE
			defb $45,$44,$44,$04,$04,$04,$45,$44				; $EAF3 EDD...ED
			defb $47,$05,$04,$04,$44,$04,$47,$07				; $EAFB G...D.G.
			defb $47,$07,$07,$07,$07,$07,$47,$07				; $EB03 G.....G.
			defb $47,$07,$07,$07,$07,$07,$47,$07				; $EB0B G.....G.
			defb $47,$07,$07,$07,$07,$07,$47,$07				; $EB13 G.....G.
			defb $47,$07,$07,$07,$07,$07,$47,$47				; $EB1B G.....GG
			defb $00,$46,$46,$46,$06,$06,$46,$46				; $EB23 .FFF..FF
			defb $06,$06,$46,$46,$06,$06,$46,$46				; $EB2B ..FF..FF
			defb $06,$06,$46,$46,$06,$06,$46,$46				; $EB33 ..FF..FF
			defb $06,$06,$46,$46,$06,$06,$46,$46				; $EB3B ..FF..FF
			defb $06,$06,$46,$00,$06,$00,$06,$06				; $EB43 ..F.....
			defb $00,$06,$06,$46,$06,$06,$46,$46				; $EB4B ...F..FF
			defb $06,$06,$46,$46,$06,$06,$46,$46				; $EB53 ..FF..FF
			defb $06,$06,$46,$46,$06,$06,$46,$46				; $EB5B ..FF..FF
			defb $06,$06,$46,$46,$06,$06,$46,$00				; $EB63 ..FF..F.
			defb $00,$00,$00,$00,$47,$47,$00,$00				; $EB6B ....GG..
			defb $47,$47,$00,$00,$00,$47,$00,$00				; $EB73 GG...G..
			defb $47,$00,$00,$47,$47,$47,$45,$04				; $EB7B G..GGGE.
			defb $45,$04,$43,$42,$43,$42,$47,$46				; $EB83 E.CBCBGF
			defb $47,$46,$45,$05,$45,$05,$47,$46				; $EB8B GFE.E.GF
			defb $47,$46,$47,$07,$47,$07,$44,$44				; $EB93 GFG.G.DD
			defb $04,$04,$45,$44,$04,$04,$44,$04				; $EB9B ..ED..D.
			defb $44,$04,$47,$45,$47,$45,$47,$45				; $EBA3 D.GEGEGE
			defb $47,$45,$47,$45,$47,$45,$47,$45				; $EBAB GEGEGEGE
			defb $47,$45,$47,$45,$47,$45,$00,$42				; $EBB3 GEGEGE.B
			defb $42,$43,$43,$42,$42,$43,$43,$00				; $EBBB BCCBBCC.
			defb $42,$43,$47,$47,$47,$00,$47,$07				; $EBC3 BCGGG.G.
			defb $00,$07,$46,$04,$44,$04,$44,$06				; $EBCB ..F.D.D.
			defb $44,$04,$44,$04,$44,$04,$44,$04				; $EBD3 D.D.D.D.
			defb $44,$04,$00,$47,$47,$47,$47,$00				; $EBDB D..GGGG.
			defb $47,$07,$47,$45,$47,$45,$47,$47				; $EBE3 G.GEGEGG
			defb $47,$47,$47,$07,$07,$07,$47,$07				; $EBEB GGG...G.
			defb $07,$07,$47,$07,$07,$07,$47,$07				; $EBF3 ..G...G.
			defb $47,$07,$44,$04,$44,$04,$44,$04				; $EBFB G.D.D.D.
			defb $44,$04,$44,$04,$44,$04,$47,$07				; $EC03 D.D.D.G.
			defb $47,$07,$07,$00,$07,$00,$47,$46				; $EC0B G.....GF
			defb $46,$06,$00,$47,$00,$47,$47,$07				; $EC13 F..G.GG.
			defb $47,$07,$46,$06,$46,$06,$44,$44				; $EC1B G.F.F.DD
			defb $04,$04,$44,$44,$04,$04,$44,$44				; $EC23 ..DD..DD
			defb $04,$04,$44,$04,$44,$04,$44,$04				; $EC2B ..D.D.D.
			defb $44,$04,$44,$04,$44,$04,$00,$47				; $EC33 D.D.D..G
			defb $00,$47,$45,$00,$45,$00,$00,$45				; $EC3B .GE.E..E
			defb $00,$44,$44,$00,$44,$00,$45,$44				; $EC43 .DD.D.ED
			defb $45,$44,$04,$04,$04,$04,$45,$44				; $EC4B ED....ED
			defb $47,$45,$04,$04,$44,$04,$45,$45				; $EC53 GE..D.EE
			defb $44,$44,$45,$44,$45,$44				; $EC5B DDEDED..


;---------------------------------------------------------------
SPRITE_DATA:		
; Each sprite data frame is 16x8.
; Missile, Rocks, Trails, Mines, Balls, Explosions, blanks & Swirls
;---------------------------------------------------------------
			; 00 : Missile facing right (4 rotate frames)
			defb $C0,$00										; $EC61
			defb $E0,$00,$14,$00,$77,$00,$14,$00				; $EC63 
			defb $E0,$00,$C0,$00,$00,$00,$30,$00				; $EC6B 
			defb $38,$00,$05,$00,$1D,$C0,$05,$00				; $EC73 
			defb $38,$00,$30,$00,$00,$00,$0C,$00				; $EC7B 
			defb $0E,$00,$01,$40,$07,$70,$01,$40				; $EC83 
			defb $0E,$00,$0C,$00,$00,$00,$03,$00				; $EC8B 
			defb $03,$80,$00,$50,$01,$DC,$00,$50				; $EC93 
			defb $03,$80,$03,$00,$00,$00
			; 01 : Missile facing left (4 rotate frames) 
			defb $00,$00,$03,$00,$07,$00,$28,$00,$EE,$00		; $ECA1
			defb $28,$00,$07,$00,$03,$00,$00,$00				; $ECAB 
			defb $00,$C0,$01,$C0,$0A,$00,$3B,$80				; $ECB3 
			defb $0A,$00,$01,$C0,$00,$C0,$00,$00				; $ECBB 
			defb $00,$30,$00,$70,$02,$80,$0E,$E0				; $ECC3 
			defb $02,$80,$00,$70,$00,$30,$00,$00				; $ECCB 
			defb $00,$0C,$00,$1C,$00,$A0,$03,$B8				; $ECD3 
			defb $00,$A0,$00,$1C,$00,$0C						; $ECDB 
			; 02 : Rocks (4 rotate frames)
			defb $1D,$10,$7B,$84,$7E,$A1,$FD,$48,$FE,$81		; $ECE1
			defb $FD,$50,$3A,$82,$35,$08,$07,$40				; $ECEB 
			defb $5E,$E2,$1F,$A0,$BF,$54,$3F,$A0				; $ECF3 
			defb $3F,$52,$0E,$A4,$2D,$40,$01,$D4				; $ECFB 
			defb $27,$B8,$07,$E9,$4F,$D4,$0F,$E8				; $ED03 
			defb $2F,$D5,$03,$A8,$03,$50,$00,$74				; $ED0B 
			defb $45,$EE,$11,$FA,$03,$F5,$AB,$FA				; $ED13 
			defb $03,$F5,$08,$EA,$12,$D4						; $ED1B 
			; 03 Sparkle Trail (4 rotate frames)
			defb $08,$00, $49,$00,$1C,$00,$FF,$80,$1C,$00		; $ED21
			defb $1C,$00,$49,$00,$08,$00,$02,$00				; $ED2B 
			defb $12,$40,$17,$40,$2D,$A0,$07,$00				; $ED33 
			defb $07,$80,$12,$40,$02,$00,$00,$80				; $ED3B 
			defb $06,$90,$01,$C0,$0E,$D8,$01,$80				; $ED43 
			defb $03,$C8,$04,$90,$00,$80,$00,$20				; $ED4B 
			defb $01,$28,$00,$70,$03,$EE,$00,$30				; $ED53 
			defb $01,$74,$00,$20,$00,$20						; $ED5B 
			; 04 (mines 4 rotate frames)
			defb $18,$00,$42,$00,$18,$00,$BD,$00,$BD,$00		; $ED61
			defb $18,$00,$42,$00,$18,$00,$06,$00				; $ED6B 
			defb $10,$80,$06,$00,$2F,$40,$2F,$40				; $ED73 
			defb $06,$00,$10,$80,$06,$00,$01,$80				; $ED7B 
			defb $04,$20,$01,$80,$0B,$D0,$0B,$D0				; $ED83 
			defb $01,$80,$04,$20,$01,$80,$00,$60				; $ED8B 
			defb $01,$08,$00,$60,$02,$F4,$02,$F4				; $ED93 
			defb $00,$60,$01,$08,$00,$60						; $ED9B 
			; 05 (balls 4 rotate frames)
			defb $3C,$00,$4E,$00,$BF,$00,$BF,$00,$FF,$00		; $EDA1 
			defb $FF,$00,$7E,$00,$3C,$00,$0F,$00				; $EDAB 
			defb $13,$80,$2F,$C0,$2F,$C0,$3F,$C0				; $EDB3 
			defb $3F,$C0,$1F,$80,$0F,$00,$00,$00				; $EDBB 
			defb $03,$C0,$06,$E0,$05,$E0,$07,$E0				; $EDC3 
			defb $07,$E0,$03,$C0,$00,$00,$00,$00				; $EDCB 
			defb $00,$F0,$01,$B8,$01,$78,$01,$F8				; $EDD3 
			defb $01,$F8,$00,$F0,$00,$00						; $EDDB 
			; 06 (explode 4 rotate frames)
			defb $14,$00,$40,$00,$15,$00,$88,$00,$54,$00		; $EDE1 
			defb $81,$00,$24,$00,$08,$00,$05,$00				; $EDEB 
			defb $10,$00,$05,$40,$22,$00,$15,$00				; $EDF3 
			defb $20,$40,$09,$00,$02,$00,$01,$40				; $EDFB 
			defb $04,$00,$01,$50,$08,$80,$05,$40				; $EE03 
			defb $08,$10,$02,$40,$00,$80,$00,$50				; $EE0B 
			defb $01,$00,$00,$54,$02,$20,$01,$50				; $EE13 
			defb $02,$04,$00,$90,$00,$20						; $EE1B 
			; 07 (small explode 4 rotate frames )
			defb $10,$00,$04,$00,$28,$00,$52,$00,$08,$00		; $EE21 
			defb $50,$00,$04,$00,$00,$00,$04,$00				; $EE2B 
			defb $01,$00,$0A,$00,$14,$80,$02,$00				; $EE33 
			defb $14,$00,$01,$00,$00,$00,$01,$00				; $EE3B 
			defb $00,$40,$02,$80,$05,$20,$00,$80				; $EE43 
			defb $05,$00,$00,$40,$00,$00,$00,$40				; $EE4B 
			defb $00,$10,$00,$A0,$01,$48,$00,$20				; $EE53 
			defb $01,$40,$00,$10,$00,$00						; $EE5B 
			; 08 (tiny explode 4 rotate frames )
			defb $00,$00,$08,$00,$00,$00,$2A,$00,$10,$00		; $EE61 
			defb $08,$00,$00,$00,$00,$00,$00,$00				; $EE6B 
			defb $02,$00,$00,$00,$0A,$80,$04,$00				; $EE73 
			defb $02,$00,$00,$00,$00,$00,$00,$00				; $EE7B 
			defb $00,$80,$00,$00,$02,$A0,$01,$00				; $EE83 
			defb $00,$80,$00,$00,$00,$00,$00,$00				; $EE8B 
			defb $00,$20,$00,$00,$00,$A8,$00,$40				; $EE93 
			defb $00,$20,$00,$00,$00,$00						; $EE9B 
			; 09 (4 blank frames)
			defb $00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; $EEA1
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $EEAB 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $EEB3 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $EEBB 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $EEC3 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $EECB 
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $EED3 
			defb $00,$00,$00,$00,$00,$00						; $EEDB 
			; 10 Swirl (4 frames)
			defb $3E,$00,$41,$00,$9C,$00,$A2,$00,$AA,$00		; $EEE1 
			defb $92,$00,$42,$00,$3C,$00,$0F,$00				; $EEEB 
			defb $10,$80,$26,$40,$29,$40,$25,$40				; $EEF3 
			defb $21,$40,$1E,$40,$00,$80,$03,$C0				; $EEFB 
			defb $04,$20,$04,$90,$05,$50,$04,$50				; $EF03 
			defb $03,$90,$08,$20,$07,$C0,$01,$00				; $EF0B 
			defb $02,$78,$02,$84,$02,$A4,$02,$94				; $EF13 
			defb $02,$64,$01,$08,$00,$F0						; $EF1B 
			;---------------------------------------------------------------
			defb $00,$00,$00,$00,$00,$00,$00,$00,$00,$00		; $EF21
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $EF2B 
			defb $00,$00,$00,$00,$00                            ; $EF33 
									   
; ==============================================================================

AY_MUSIC:			
			JP MUSIC_UPDATE				; $EF38  ; Main music entry (48k=RET to disable)
AY_RESET_MUSIC:		
			JP AY_RESET					; $EF3B  ; Music reset routine (48k=RET)
			; Both above are jump instructions, and both lead to routines that return with RET

			LD E, $01					; $EF3E  ; Appears unused
			LD A, $01					; $EF40  ; Appears unused

; E=effect_number, A=priority 
PLAY_SFX:	LD C,A						; $EF42 ; Self-modifying: Can be replaced with RET
			CALL CALC_ENVELOPE_ADDR		; $EF43  
			LD A,(HL)					; $EF46 ; get data
			CP $09						; $EF47 
			JP NC,L_EF4E				; $EF49  ; >= $09, skip adjustment
			LD C,A						; $EF4C  ; channel selector
			INC HL						; $EF4D  ; next data
L_EF4E:		LD A,C						; $EF4E  ; for channel selection
			LD IX,CHANNEL1 				; $EF4F  ; default
			DEC A						; $EF53
			JP Z,SKIP_CH				; $EF54  ; using channel 1
			LD IX,CHANNEL2				; $EF57
			DEC A						; $EF5B
			JP Z,SKIP_CH				; $EF5C  ; using channel 2
			LD IX,CHANNEL3				; $EF5F  ; else channel 3.
SKIP_CH:	LD A,(HL)					; $EF63  ; get data
			CP $F4						; $EF64  ; WHAT IS THIS MARKER ???? 
			LD A,$0A					; $EF66
			JP NZ,SKIP_NO_F4			; $EF68  
			INC HL						; $EF6B  ; next data  (path reads extra byte)
			LD A,(HL)					; $EF6C	 ; get data
			INC HL						; $EF6D  ; next data
SKIP_NO_F4: CP (IX+ch_status)			; $EF6E  ; still active (exit) 
			RET C						; $EF71  ; 

			LD (IX+ch_status),A					; $EF72
			LD (IX+current_data_ptr),L			; $EF75
			LD (IX+current_data_ptr+1),H		; $EF78
			LD (IX+loop_start_ptr),L			; $EF7B
			LD (IX+loop_start_ptr+1),H			; $EF7E
			LD (IX+phrase_start_ptr),L			; $EF81
			LD (IX+phrase_start_ptr+1),H		; $EF84
			LD (IX+duration_counter),$01		; $EF87
			XOR A								; $EF8B
			LD (IX+transposition),A				; $EF8C
			LD (IX+vibrato_control),A			; $EF8F
			RET									; $EF92  ; SFX channel now setup

; AY Chip Reset and Register Initialization
AY_RESET:	XOR A						; $EF93
			LD ($F224),A				; $EF94  ; Reset channel 1 tone register
			LD ($F247),A				; $EF97  ; Reset channel 2 tone register
			LD ($F26A),A				; $EF9A  ; Reset channel 3 tone register
			LD (AY_R8),A				; $EF9D  ; Reset channel A amplitude
			LD (AY_R9),A				; $EFA0  ; Reset channel B amplitude
			LD (AY_R10),A				; $EFA3  ; Reset channel C amplitude
			LD A,$3F					; $EFA6
			LD (AY_R7),A				; $EFA8   ; mixer reg, enable all channels
			; Setup AY register shadow buffer in reverse order (13 to 0)
UPDATE_ALL_CHANS:		
			LD HL,AY_R13				; $EFAB  ; Highest shadow buffer register
			LD E,$0D					; $EFAE  ; count down for 14 registers
L_EFB0:		LD BC,$FFFD					; $EFB0  ; AY address port
			OUT (C),E					; $EFB3	 ; Select an AY register (via port)
			LD BC,$BFFD					; $EFB5  ; Data port for the AY chip.
			LD A,(HL)					; $EFB8  ; Get shadow value 
			DEC HL						; $EFB9
			OUT (C),A					; $EFBA	 ; Write the value to the AY chip.
			DEC E						; $EFBC
			JP P,L_EFB0					; $EFBD  ; do all 14 registers
			RET							; $EFC0  ; reset done

; SFX: Envelope
; 1st lookup table: $F3A6 to $F4A4.
; 2nd 
CALC_ENVELOPE_ADDR:		
			LD A,E						; $EFC1  ; Envelope index
			ADD A,A						; $EFC2  ; X2
			ADD A,$A6					; $EFC3  ; Low part, offset (1st table)
			LD L,A						; $EFC5  ; Low part ready (2×E+$A6)
			ADC A,$F3					; $EFC6  ; high part, offset (1st table)
			SUB L						; $EFC8  ; keep carry (doing 16‑bit addition)
			LD H,A						; $EFC9  ; HL = 16‑bit base pointer
			LD E,(HL)					; $EFCA  ; get low byte 
			INC HL						; $EFCB	 ; next byte
			LD D,(HL)					; $EFCC  ; DE = offset into 2nd table
			LD HL,ENVELOPE_DATA			; $EFCD  ; Base of Envelope data
			ADD HL,DE					; $EFD0  ; 
			RET							; $EFD1


; Get vibrato/Portamento Calculation Routine 
CALC_VIBRA_PORTA_ADDR:		
			LD A,E						; $EFD2
			ADD A,A						; $EFD3
			ADD A,$56					; $EFD4
			LD E,A						; $EFD6
			ADC A,$F3					; $EFD7
			SUB E						; $EFD9
			LD D,A						; $EFDA
			LD A,(DE)					; $EFDB
			ADD A,$8E					; $EFDC
			LD C,A						; $EFDE
			INC DE						; $EFDF
			LD A,(DE)					; $EFE0
			ADC A,$F2					; $EFE1
			LD B,A						; $EFE3
			RET							; $EFE4

; Main Music Update Routine
MUSIC_UPDATE:		
			CALL UPDATE_ALL_CHANS		; $EFE5
			LD IX,CHANNEL1 				; $EFE8
			LD HL,(AY_R0)				; $EFEC
			CALL PROCESS_CHAN			; $EFEF  ;  channel update routine
			LD HL,(STORE_AY)			; $EFF2
			LD (AY_R0),HL				; $EFF5
			LD HL,(AY_R2)				; $EFF8
			LD IX,CHANNEL2				; $EFFB
			CALL PROCESS_CHAN			; $EFFF  ;  channel update routine
			LD HL,(STORE_AY)			; $F002
			LD (AY_R2),HL				; $F005
			LD HL,(AY_R4)				; $F008
			LD IX,CHANNEL3				; $F00B
			CALL PROCESS_CHAN			; $F00F  ;  channel update routine
			LD HL,(STORE_AY)			; $F012
			LD (AY_R4),HL				; $F015
			JP NOISE_MIXER				; $F018  
PROCESS_CHAN:		 					; Channel Update Routine (Processes Music Data Commands)			
			LD (STORE_AY),HL			; $F01B
			LD A,(IX+ch_status)			; $F01E
			OR A						; $F021
			RET Z						; $F022
			DEC (IX+duration_counter)		; $F023
			JP NZ,L_F162					; $F026  ; If duration is not finished, branch to envelope update
			LD (IX+env_release_rate),$14	; $F029  ; Set a default envelope release rate.

GET_NEXT_DATA:	
			LD H,(IX+current_data_ptr+1)		; $F02D
			LD L,(IX+current_data_ptr)			; $F030
NEW_SOUND_COMMAND:
			LD A,(HL)							; $F033  ; Get command from music data
			INC HL								; $F034	 ;
			LD E,(HL)							; $F035
			INC HL								; $F036
			LD (IX+current_data_ptr+1),H		; $F037
			LD (IX+current_data_ptr),L			; $F03A
			DEC (IX+env_release_rate)			; $F03D  ; valid command value
			RET Z								; $F040  ; Rate hits zero, exit.

			CP $00							; $F041
			JP Z,NOTE_OFF					; $F043  ; off (A==0)
			CP $09							; $F046
			JP C,LOW_PRIORITY_SFX			; $F048  ; (A<9) trigger SFX, implicit priority
			CP $65							; $F04B
			JP C,NOTE_EVENT					; $F04D  ; A+=transposition, set duration, update volume
			CP $E4							; $F050  
			JP Z,SET_NOISE					; $F052  ; Set noise period
			CP $E3							; $F055  
			JP Z,SET_TRANSPOSITION			; $F057  ; transposition
			CP $E1							; $F05A
			JP Z,STOP_CHAN					; $F05C  ; Sets ch_status=0, clears tone reg
			CP $E9							; $F05F 
			JP Z,SET_PORTA					; $F061  ; Set portamento
			CP $E8							; $F064
			JP Z,SET_VIBRATO				; $F066  ; Set vibrato 
			CP $EA							; $F069
			JP Z,CONTINUE_MODULATION		; $F06B  ; contiune last and store BC in ($F212)
			CP $E2							; $F06E
			JP Z,NOISE_EFFECTS				; $F070  ; modifies code, noise effects
			CP $E5							; $F073  
			JP Z,LOOP_START					; $F075  ; Set loop point
			CP $E6							; $F078
			JP Z,SET_TRANS					; $F07A  ; Set transposition
			CP $F0							; $F07D
			JP Z,VIBRATO_CTL				; $F07F	 ; Simple vibrato_control = E.
			CP $FF							; $F082
			JP Z,LOOP_PHRASE_START			; $F084  ; use new loop and or phrase start
			JR NEW_SOUND_COMMAND			; $F087

LOW_PRIORITY_SFX:		
			PUSH IX								; $F089
			CALL PLAY_SFX						; $F08B  ; channel stealing
			POP IX								; $F08E
			JP GET_NEXT_DATA					; $F090	 ; sfx triggered, loop

SET_NOISE:
			LD A,E								; $F093
			LD (AY_R6),A						; $F094 
			LD (IX+env_override_flag),$01		; $F097  
			JP NEW_SOUND_COMMAND				; $F09B
SET_TRANS:
			LD (IX+transposition),E				; $F09E
			JP NEW_SOUND_COMMAND				; $F0A1
SET_PORTA:
			CALL CALC_VIBRA_PORTA_ADDR			; $F0A4 
			LD (IX+portamento_target),C			; $F0A7
			LD (IX+portamento_speed),B			; $F0AA
			JP NEW_SOUND_COMMAND				; $F0AD
SET_VIBRATO:
			CALL CALC_VIBRA_PORTA_ADDR			; $F0B0 
			LD (IX+vibrato_depth),C				; $F0B3
			LD (IX+vibrato_speed),B				; $F0B6
			JP NEW_SOUND_COMMAND				; $F0B9
CONTINUE_MODULATION:
			CALL CALC_VIBRA_PORTA_ADDR			; $F0BC 
			LD ($F212),BC						; $F0BF
			JP NEW_SOUND_COMMAND				; $F0C3
LOOP_START: 
		LD (IX+loop_start_ptr+1),H         		; $F0C6 ; high byte
         	LD (IX+loop_start_ptr),L           	; $F0C9 ; low byte
        	CALL CALC_ENVELOPE_ADDR            	; $F0CC ; calc envelope: index (in E), (out HL)
        	JP NEW_SOUND_COMMAND               	; $F0CF ; Jump to the next routine
LOOP_PHRASE_START:		
			LD H,(IX+loop_start_ptr+1)			; $F0D2
			LD L,(IX+loop_start_ptr)			; $F0D5
			LD A,(HL)							; $F0D8
			INC A								; $F0D9
			JP NZ,NEW_SOUND_COMMAND				; $F0DA
			LD H,(IX+phrase_start_ptr+1)		; $F0DD
			LD L,(IX+phrase_start_ptr)			; $F0E0
			JP NEW_SOUND_COMMAND				; $F0E3	
STOP_CHAN:
			LD (IX+ch_status),$00				; $F0E6
			LD H,(IX+tone_register_ptr+1)		; $F0EA
			LD L,(IX+tone_register_ptr)			; $F0ED
			LD (HL),$00							; $F0F0
			RET									; $F0F2
VIBRATO_CTL:
			LD (IX+vibrato_control),E			; $F0F3
			JP NEW_SOUND_COMMAND				; $F0F6

NOISE_EFFECTS:
WRD_OPCODE: LD HL,$28B2				; $F0F9 ; noise seed value 
			LD C,L					; $F0FC
			LD B,H					; $F0FD
			ADD HL,HL				; $F0FE	; X2 (to shift left for a mix)
			ADD HL,HL				; $F0FF	; X4
			ADD HL,BC				; $F100
			ADD HL,HL				; $F101	; X2
			ADD HL,HL				; $F102 ; X4
			ADD HL,HL				; $F103 ; X8
			ADD HL,BC				; $F104 ; mixing rotate done
			LD (WRD_OPCODE+1),HL	; $F105 ; Re-seed operand (overwrites 2 bytes)
			LD A,H					; $F108
			AND E					; $F109  ; Mask value range (E=last data read)
			INC A					; $F10A  ; keep above zero
			LD (BYTE_OPCODE+1),A	; $F10B  ; save random value, modifies code
			JP GET_NEXT_DATA			; $F10E  ; loop get more data

SET_TRANSPOSITION:
BYTE_OPCODE:	LD A,$2A					; $F111  ; '+N' (modified operand)
NOTE_EVENT: ADD A,(IX+transposition)		; $F113
NOTE_OFF:	LD (IX+duration_counter),E		; $F116
			LD (IX+vol_fade_speed),A		; $F119
			CALL LOOKUP_CRL_TABLE						; $F11C
			LD H,(IX+tone_register_ptr+1)	; $F11F
			LD L,(IX+tone_register_ptr)		; $F122
			LD (HL),$00						; $F125
			PUSH IX							; $F127
			POP DE							; $F129
			LD HL,$0008						; $F12A
			ADD HL,DE						; $F12D
			; copy 8 items (16 bit each)
			LDI								; $F12E ; (HL)->(DE), inc HL/DE, dec BC
			LDI								; $F130
			LDI								; $F132
			LDI								; $F134
			LDI								; $F136
			LDI								; $F138
			LDI								; $F13A
			LDI								; $F13C
			DEC (IX+env_override_flag)		; $F13E
			LD (IX+env_override_flag),$00	; $F141
			LD L,(IX+custom_env_ptr)		; $F145
			JR NZ,L_F156			; $F148
			LD HL,($F212)			; $F14A
			LD ($F20A),HL			; $F14D
			LD HL,$0000				; $F150
			LD (CRL_BLOCK),HL			; $F153
L_F156:		LD A,(AY_R7)			; $F156
			AND (IX+custom_env_ptr+1)			; $F159
			OR L					; $F15C
			AND $3F					; $F15D
			LD (AY_R7),A			; $F15F
L_F162:		CALL ENVELOPE_MODULATION				; $F162  ; Envelope generator
			LD H,(IX+tone_register_ptr+1)			; $F165
			LD L,(IX+tone_register_ptr)			; $F168
			LD A,(HL)				; $F16B
			ADD A,C					; $F16C
			SUB $80					; $F16D
			LD (HL),A				; $F16F
			LD HL,(STORE_AY)		; $F170
			LD A,H					; $F173
			OR L					; $F174
			RET Z					; $F175
			LD A,(IX+vibrato_control)	; $F176
			OR A						; $F179
			JP NZ,DO_FADE_VIBTA				; $F17A
			INC IX						; $F17D
			INC IX						; $F17F
			CALL ENVELOPE_MODULATION		; $F181  ; Envelope generator
			LD HL,(STORE_AY)			; $F184
			LD B,$00					; $F187
			ADD HL,BC					; $F189
			LD C,$80					; $F18A
			SBC HL,BC					; $F18C
			LD (STORE_AY),HL			; $F18E
			RET							; $F191

DO_FADE_VIBTA:		
			DEC (IX+vol_fade_target)			; $F192
			LD A,(IX+vol_fade_speed)			; $F195
			JR Z,LOOKUP_CRL_TABLE				; $F198
			ADD A,(IX+vibrato_control)			; $F19A
			LD (IX+vol_fade_target),$01			; $F19D

LOOKUP_CRL_TABLE:		
			ADD A,A					; $F1A1  ; A=Index (each item is 2 bytes)
			ADD A,$8E				; $F1A2  ; Table base offset (low byte)
			LD L,A					; $F1A4
			ADC A,$F2				; $F1A5  ; High byte + carry
			SUB L					; $F1A7  ; Isolate high byte (H=$F2+carry)
			LD H,A					; $F1A8	 ; HL=Table entry
			LD DE,STORE_AY			; $F1A9  ; (HL)->(DE), inc HL/DE, dec BC
			LDI						; $F1AC  ; 2xbytes into STORE_AY
			LDI						; $F1AE  ; 2xbytes into STORE_AY
			RET						; $F1B0  ; HL = $F28E+(A*2) or has carry HL=$F38E+(A*2) 


; Noise Period Range: The AY-3-8910 noise period is 5-bit (max $1F).
; Here values less than $11 are ignored!
NOISE_MIXER:
			LD IX,CRL_BLOCK				; $F1B1  ; noise chan control block (set around transposition time)
			CALL ENVELOPE_MODULATION	; $F1B5 
			LD HL,AY_R6					; $F1B8  ; Noise period reg
			LD A,(HL)					; $F1BB  ; get noise period
			ADD A,C						; $F1BC  ; Apply modulation offset
			SUB $80						; $F1BD  ; Center the offset (signed)
			LD (HL),A					; $F1BF  ; AY_R6 = period
			CP $11						; $F1C0  ; 
			RET C						; $F1C2  ; Period<$11, exit.
			INC HL						; $F1C3  ; onto "AY_R7" mixer 
			LD A,(HL)					; $F1C4  ; get mixer value
			OR $38						; $F1C5  ; %00111000 (enable noise on channels A,B,C)
			LD (HL),A					; $F1C7  ; update "AY_R7"
			RET							; $F1C8

; Generate Envelope Modulation
ENVELOPE_MODULATION:		
			PUSH IX							; $F1C9
			POP HL							; $F1CB
			LD D,(IX+env_data_ptr+1)		; $F1CC
			LD E,(IX+env_data_ptr+0)		; $F1CF
			INC (HL)						; $F1D2
			LD A,(DE)						; $F1D3
			SUB (HL)						; $F1D4  ; Compare with counter
			LD C,$80						; $F1D5 
			RET NZ							; $F1D7  ; Envelope still progressing, return
			LD (HL),A						; $F1D8  ; Reset the envelope counter
			INC DE							; $F1D9  ; Next envelope data
			LD A,(DE)						; $F1DA
			LD C,A							; $F1DB  ; new envelope value
			INC DE							; $F1DC
			INC HL							; $F1DD
			INC (HL)						; $F1DE
			LD A,(DE)						; $F1DF
			SUB (HL)						; $F1E0
			RET NZ							; $F1E1
			LD (HL),A						; $F1E2
			INC DE							; $F1E3
			LD A,(DE)						; $F1E4
			INC A							; $F1E5
			JP NZ,SKIP_VIBRA				; $F1E6 
			LD D,(IX+vibrato_speed)			; $F1E9
			LD E,(IX+vibrato_depth)			; $F1EC
SKIP_VIBRA:	LD (IX+env_data_ptr+1),D		; $F1EF
			LD (IX+env_data_ptr+0),E		; $F1F2
			RET								; $F1F5

; AY Register Shadow Buffer
AY_R0: 		defb $A8	;* $F1F6 ; R0 Channel A tone period - Fine (8 bit)
AY_R1: 		defb $01	; $F1F7 ; R1 Channel A tone period - Coarse (4 bit)
AY_R2: 		defb $00	;* $F1F8 ; R2 Channel B tone period - Fine (8 bit)
AY_R3: 		defb $00	; $F1F9 ; R3 Channel B tone period - Coarse (4 bit)
AY_R4: 		defb $00	;* $F1FA ; R4 Channel C tone period - Fine (8 bit)
AY_R5: 		defb $00	; $F1FB ; R5 Channel C tone period - Coarse (4 bit)
AY_R6: 		defb $2F	;* $F1FC ; R6 Noise period (5 bit)
AY_R7: 		defb $3F	;* $F1FD ; R7 Enables (inverted) for I/O, Noise, Tone (8 bit)
AY_R8: 		defb $00	;* $F1FE ; R8 Channel A amplitude (5 bit)
AY_R9: 		defb $00	;* $F1FF ; R9 Channel B amplitude (5 bit)
AY_R10:		defb $00	;* $F200 ; R10 Channel C amplitude (5 bit)
AY_R11:		defb $64	; $F201 ; R11 Envelope period - Fine (8bit)
AY_R12:		defb $00	; $F202 ; R12 Envelope period - Coarse (8bit)
AY_R13:		defb $0A	;* $F203 ; R13 Envelope shape (4bit)

STORE_AY:	defb $00,$00							; $F204 
CRL_BLOCK:	defb $4A,$01							; $F206 
			defb $0A,$00,$00
			defb $00,$04,$00,$00,$00,$12,$00,$00	; $F20B
			defb $00								; $F213

; 35-byte Channel Control Block (same for all channels)
CHANNEL1: 						   ;  $F214
ENVELOPE_STEP       defb $00       ; +$00  Current envelope position
ENVELOPE_SUBSTEP    defb $02       ; +$01  Sub-step counter
ENV_PHASE           defb $00       ; +$02  Envelope phase (0=attack,1=decay,etc)
RESERVED        	defb $00       ; +$03  Unused
ENV_DATA_PTR        defw $F41B     ; +$04  Active envelope data pointer (little-endian)
ENV_BASE_SPEED      defb $71       ; +$06  Envelope base speed
ENV_SPEED_MOD       defb $F4       ; +$07  Speed modifier
ENV_LOOP_COUNTER    defb $00       ; +$08  Envelope loop counter
RESERVED_09         defb $00       ; +$09  
ARP_INDEX           defb $00       ; +$0A  Arpeggio index
ARP_SPEED           defb $00       ; +$0B  Arpeggio speed
VIBRATO_DEPTH       defb $18       ; +$0C  Vibrato depth
VIBRATO_SPEED       defb $F4       ; +$0D  Vibrato speed
PORTAMENTO_TARGET   defb $71       ; +$0E  Portamento target note
PORTAMENTO_SPEED    defb $F4       ; +$0F  Portamento rate
CH_STATUS           defb $00       ; +$10  Channel status (bit 7=active)
DURATION_COUNTER    defb $0A       ; +$11  Current note duration
CURRENT_DATA_PTR    defw $F65E     ; +$12  Current playback position (little-endian)
LOOP_START_PTR      defw $F575     ; +$14  Loop point
PHRASE_START_PTR    defw $F56F     ; +$16  Phrase start position  (musical pattern)
TRANSPOSITION       defb $07       ; +$18  Key transposition
ENV_OVERRIDE_FLAG   defb $00       ; +$19  Envelope override flag
CUSTOM_ENV_PTR      defw $3608     ; +$1A  Custom volume envelope pointer (little-endian)
TONE_REGISTER_PTR   defw $F1FE     ; +$1C  AY register pointer (e.g. AY_R8 for vol)
ENV_RELEASE_RATE    defb $12       ; +$1E  Envelope release rate
RESERVED_1F         defb $00       ; +$1F  
VIBRATO_CONTROL     defb $10       ; +$20  Vibrato control (depth|speed)
VOL_FADE_SPEED      defb $29       ; +$21  Volume fade speed
VOL_FADE_TARGET     defb $01       ; +$22  Volume fade target

CHANNEL2:	defb $00,$00,$00,$00								; $F237 ; IX Base
			defb $00,$00,$00,$00,$00,$00,$00,$00				;  
			defb $00,$00,$00,$00,$00,$00,$00,$00				;  
			defb $00,$00,$00,$00,$00,$00,$10,$2D				;  
			defb $FF,$F1,$00,$00,$00,$00,$00					; 

CHANNEL3:	defb $00,$00,$00,$00								; $F25A ; IX Base
			defb $00,$00,$00,$00,$00,$00,$00,$00				;
			defb $00,$00,$00,$00,$00,$00,$00,$00				;  
			defb $00,$00,$00,$00,$00,$00,$20,$1B				;  
			defb $00,$F2,$00,$00,$00,$00,$00					;  

			defb $2A,$00,$00,$00,$00,$00						; $F27D
			defb $00,$00,$00,$00,$00,$00,$00,$00				; $F283 
			defb $00,$00,$00									; $F28B 


ENVELOPE_DATA:			
			defb $00,$00,$17,$2A,$BA							; $F28E
			defb $27,$80,$25,$65,$23,$68,$21,$88				; $F293 '.%e#h!.
			defb $1F,$C3,$1D,$18,$1C,$84,$1A,$07				; $F29B ........
			defb $19,$9F,$17,$4C,$16,$0C,$15,$DD				; $F2A3 ...L....
			defb $13,$C0,$12,$B2,$11,$B4,$10,$C4				; $F2AB ........
			defb $0F,$E2,$0E,$0C,$0E,$42,$0D,$84				; $F2B3 .....B..
			defb $0C,$D0,$0B,$26,$0B,$86,$0A,$EF				; $F2BB ...&....
			defb $09,$60,$09,$D9,$08,$5A,$08,$E2				; $F2C3 .`...Z..
			defb $07,$71,$07,$06,$07,$A1,$06,$42				; $F2CB .q.....B
			defb $06,$E8,$05,$93,$05,$43,$05,$F7				; $F2D3 .....C..
			defb $04,$B0,$04,$6D,$04,$2D,$04,$F1				; $F2DB ...m.-..
			defb $03,$B8,$03,$83,$03,$50,$03,$21				; $F2E3 .....P.!
			defb $03,$F4,$02,$CA,$02,$A1,$02,$7C				; $F2EB .......|
			defb $02,$58,$02,$36,$02,$17,$02,$F9				; $F2F3 .X.6....
			defb $01,$DC,$01,$C1,$01,$A8,$01,$90				; $F2FB ........
			defb $01,$7A,$01,$65,$01,$51,$01,$3E				; $F303 .z.e.Q.>
			defb $01,$2C,$01,$1B,$01,$0B,$01,$FC				; $F30B .,......
			defb $00,$EE,$00,$E1,$00,$D4,$00,$C8				; $F313 ........
			defb $00,$BD,$00,$B2,$00,$A8,$00,$9F				; $F31B ........
			defb $00,$96,$00,$8E,$00,$86,$00,$7E				; $F323 .......~
			defb $00,$77,$00,$70,$00,$6A,$00,$64				; $F32B .w.p.j.d
			defb $00,$5E,$00,$59,$00,$54,$00,$4F				; $F333 .^.Y.T.O
			defb $00,$4B,$00,$47,$00,$43,$00,$3F				; $F33B .K.G.C.?
			defb $00,$3C,$00,$38,$00,$35,$00,$32				; $F343 .<.8.5.2
			defb $00,$2F,$00,$2D,$00,$2A,$00,$28				; $F34B ./.-.*.(
			defb $00,$00,$00,$7C,$01,$80,$01,$8A				; $F353 ...|....
			defb $01,$94,$01,$95,$01,$9C,$01,$A9				; $F35B ........
			defb $01,$B6,$01,$C3,$01,$CD,$01,$CE				; $F363 ........
			defb $01,$CF,$01,$D9,$01,$E3,$01,$ED				; $F36B ........
			defb $01,$F7,$01,$01,$02,$0B,$02,$12				; $F373 ........
			defb $02,$28,$02,$2C,$02,$30,$02,$3A				; $F37B .(.,.0.:
			defb $02,$47,$02,$48,$02,$58,$02,$5F				; $F383 .G.H.X._
			defb $02,$66,$02,$67,$02,$6B,$02,$78				; $F38B .f.g.k.x
			defb $02,$7F,$02,$80,$02,$81,$02,$82				; $F393 ........
			defb $02,$8C,$02,$A5,$02,$BE,$02,$CE				; $F39B ........
			defb $02,$00,$00									; $F3A3 ........
			
			; (102 bytes) 16‑bit "offset" values into table F28E
			defb $DA,$02,$E0,$02,$9C							; $F3A6
			defb $03,$A5,$03,$B0,$03,$E5,$03,$6E				; $F3AB .......n
			defb $04,$F1,$04,$18,$05,$3F,$05,$6C				; $F3B3 .....?.l
			defb $05,$77,$05,$7C,$05,$97,$05,$1A				; $F3BB .w.|....
			defb $06,$1D,$06,$32,$06,$C3,$06,$E0				; $F3C3 ...2....
			defb $06,$F9,$06,$14,$07,$87,$07,$8C				; $F3CB ........
			defb $07,$96,$07,$A4,$07,$AE,$07,$B8				; $F3D3 ........
			defb $07,$C8,$07,$D8,$07,$E2,$07,$F0				; $F3DB ........
			defb $07,$FE,$07,$08,$08,$18,$08,$2A				; $F3E3 .......*
			defb $08,$38,$08,$3B,$08,$48,$08,$5B				; $F3EB .8.;.H.[
			defb $08,$94,$08,$A7,$08,$C5,$08,$E2				; $F3F3 ........
			defb $08,$4A,$1A,$58,$1A,$62,$1A,$AE				; $F3FB .J.X.b..
			defb $1A,$CA,$1A,$E5,$1A,$00,$00,$C8				; $F403 ........
			defb $80											; $F40B ........

MUSIC_DATA:  ;  LENGTH  ($FB86-$F40C) 77A (1,914)
			DEFB $C8,$FF,$01,$81,$0D,$09,$7F					; $F40C
			defb $09,$C8,$80,$C8,$FF,$01,$8D,$01				; $F413 ........
			defb $01,$7F,$04,$01,$77,$01,$FF,$FF				; $F41B ....w...
			defb $01,$87,$01,$C8,$80,$C8,$FF,$01				; $F423 ........
			defb $8C,$01,$0A,$7F,$08,$14,$7F,$04				; $F42B ........
			defb $C8,$80,$C8,$FF,$01,$8D,$01,$02				; $F433 ........
			defb $7F,$07,$0C,$7F,$06,$C8,$80,$C8				; $F43B ........
			defb $FF,$01,$8D,$01,$01,$7F,$0B,$09				; $F443 ........
			defb $7F,$02,$C8,$80,$C8,$FF,$01,$88				; $F44B ........
			defb $01,$01,$82,$01,$C8,$80,$C8,$FF				; $F453 ........
			defb $FF,$FF,$01,$77,$01,$01,$83,$03				; $F45B ...w....
			defb $C8,$80,$C8,$FF,$02,$81,$02,$02				; $F463 ........
			defb $7F,$03,$02,$81,$01,$FF,$01,$81				; $F46B ........
			defb $02,$01,$7F,$04,$01,$81,$02,$FF				; $F473 ........
			defb $01,$89,$01,$01,$79,$01,$C8,$80				; $F47B ....y...
			defb $C8,$FF,$01,$82,$02,$01,$7E,$04				; $F483 ......~.
			defb $01,$82,$02,$FF,$01,$87,$03,$01				; $F48B ........
			defb $79,$06,$01,$87,$03,$FF,$01,$88				; $F493 y.......
			defb $0A,$01,$96,$C8,$FF,$01,$93,$01				; $F49B ........
			defb $01,$6D,$01,$01,$7F,$02,$01,$81				; $F4A3 .m......
			defb $04,$01,$7F,$04,$01,$81,$02,$C8				; $F4AB ........
			defb $80,$C8,$FF,$02,$81,$C8,$FF,$02				; $F4B3 ........
			defb $7F,$C8,$FF,$01,$80,$01,$01,$B4				; $F4BB ........
			defb $01,$C8,$80,$C8,$FF,$01,$80,$01				; $F4C3 ........
			defb $01,$8B,$01,$01,$B4,$01,$C8,$80				; $F4CB ........
			defb $C8,$FF,$FF,$01,$85,$03,$01,$71				; $F4D3 .......q
			defb $01,$01,$80,$01,$01,$8F,$01,$01				; $F4DB ........
			defb $7B,$03,$FF,$01,$85,$03,$01,$71				; $F4E3 {......q
			defb $01,$FF,$01,$96,$01,$02,$79,$02				; $F4EB ......y.
			defb $FF,$FF,$01,$A1,$C8,$FF,$01,$85				; $F4F3 ........
			defb $03,$09,$7D,$04,$0E,$7F,$03,$C8				; $F4FB ..}.....
			defb $80,$C8,$FF,$01,$84,$01,$01,$7F				; $F503 ........
			defb $01,$FF,$FF,$FF,$FF,$02,$8D,$01				; $F50B ........
			defb $02,$67,$01,$C8,$80,$C8,$FF,$01				; $F513 .g......
			defb $8F,$01,$08,$80,$01,$02,$7F,$01				; $F51B ........
			defb $04,$7F,$01,$07,$7F,$02,$0C,$7F				; $F523 ........
			defb $04,$16,$7F,$07,$C8,$80,$C8,$FF				; $F52B ........
			defb $01,$79,$01,$01,$8B,$01,$01,$6F				; $F533 .y.....o
			defb $01,$01,$9B,$01,$01,$5B,$01,$01				; $F53B .....[..
			defb $AF,$01,$01,$47,$01,$01,$C3,$01				; $F543 ...G....
			defb $FF,$01,$8F,$01,$01,$7A,$01,$01				; $F54B .....z..
			defb $86,$01,$01,$7F,$09,$08,$7F,$06				; $F553 ........
			defb $FF,$01,$99,$03,$01,$79,$07,$0A				; $F55B .....y..
			defb $7E,$C8,$FF,$01,$9B,$E1,$FF,$FF				; $F563 ~.......
			defb $FF,$FF,$AF,$01,$E8,$00,$00,$30				; $F56B .......0
			defb $E5,$04,$02,$02,$E5,$04,$02,$03				; $F573 ........
			defb $E5,$04,$02,$08,$00,$54,$02,$04				; $F57B .....T..
			defb $E5,$05,$02,$04,$E5,$06,$02,$04				; $F583 ........
			defb $E5,$05,$02,$04,$E5,$06,$02,$00				; $F58B ........
			defb $E4,$06,$00,$06,$E4,$06,$00,$06				; $F593 ........
			defb $E5,$0D,$E5,$10,$E5,$0D,$E5,$10				; $F59B ........
			defb $E5,$08,$E5,$08,$E5,$08,$E5,$0C				; $F5A3 ........
			defb $02,$04,$E5,$05,$02,$04,$E5,$06				; $F5AB ........
			defb $02,$04,$E5,$05,$02,$04,$E5,$06				; $F5B3 ........
			defb $02,$00,$F0,$00,$E4,$06,$3A,$06				; $F5BB ......:.
			defb $E4,$06,$39,$06,$E5,$0D,$E5,$10				; $F5C3 ..9.....
			defb $E5,$0D,$E5,$10,$02,$25,$E5,$26				; $F5CB .....%.&
			defb $E4,$06,$00,$06,$E4,$06,$00,$06				; $F5D3 ........
			defb $E5,$09,$E5,$07,$E5,$09,$E5,$08				; $F5DB ........
			defb $E6,$13,$02,$13,$E5,$14,$E4,$01				; $F5E3 ........
			defb $00,$0C,$02,$13,$E5,$14,$E4,$01				; $F5EB ........
			defb $00,$0C,$E6,$15,$02,$15,$E5,$14				; $F5F3 ........
			defb $E4,$01,$00,$0C,$02,$15,$E5,$14				; $F5FB ........
			defb $02,$0F,$E5,$05,$02,$0F,$E5,$05				; $F603 ........
			defb $02,$0F,$E5,$05,$02,$0F,$E5,$05				; $F60B ........
			defb $E4,$06,$00,$06,$E4,$06,$00,$06				; $F613 ........
			defb $E5,$0D,$E5,$0D,$E5,$10,$02,$25				; $F61B .......%
			defb $E5,$26,$E5,$07,$E5,$0B,$FF,$E8				; $F623 .&......
			defb $00,$00,$60,$E5,$07,$E5,$07,$FF				; $F62B ..`.....
			defb $E5,$09,$E8,$00,$00,$30,$E5,$07				; $F633 .....0..
			defb $E5,$07,$FF,$E6,$07,$E8,$02,$E9				; $F63B ........
			defb $0D,$F0,$00,$1F,$0C,$1F,$0C,$22				; $F643 ......."
			defb $0C,$24,$0C,$26,$0C,$F0,$0F,$26				; $F64B .$.&...&
			defb $0C,$F0,$0E,$26,$0C,$26,$0C,$F0				; $F653 ...&.&..
			defb $10,$22,$0C,$F0,$00,$22,$0C,$16				; $F65B ."..."..
			defb $0C,$22,$0C,$16,$0C,$F0,$10,$24				; $F663 .".....$
			defb $0C,$F0,$00,$18,$0C,$24,$0C,$FF				; $F66B .....$..
			defb $E6,$07,$E8,$06,$F0,$18,$03,$27				; $F673 .......'
			defb $EA,$16,$E4,$01,$30,$06,$E4,$01				; $F67B ....0...
			defb $31,$06,$E4,$01,$32,$06,$E4,$01				; $F683 1...2...
			defb $30,$06,$E4,$01,$32,$06,$E4,$01				; $F68B 0...2...
			defb $35,$06,$EA,$00,$E4,$06,$3A,$0C				; $F693 5.....:.
			defb $EA,$16,$E4,$01,$3C,$06,$E4,$01				; $F69B ....<...
			defb $39,$06,$E4,$01,$00,$06,$E4,$01				; $F6A3 9.......
			defb $00,$06,$E4,$01,$00,$06,$E4,$01				; $F6AB ........
			defb $00,$06,$EA,$00,$E4,$06,$00,$0C				; $F6B3 ........
			defb $EA,$16,$E4,$01,$00,$06,$E4,$01				; $F6BB ........
			defb $00,$06,$E4,$01,$00,$06,$E4,$01				; $F6C3 ........
			defb $00,$06,$E4,$01,$2E,$06,$E4,$01				; $F6CB ........
			defb $00,$06,$EA,$00,$E4,$06,$30,$0C				; $F6D3 ......0.
			defb $EA,$16,$E4,$01,$32,$06,$E4,$01				; $F6DB ....2...
			defb $30,$06,$E4,$01,$00,$06,$E4,$01				; $F6E3 0.......
			defb $00,$06,$E4,$01,$00,$06,$E4,$01				; $F6EB ........
			defb $00,$06,$EA,$00,$E4,$06,$00,$0C				; $F6F3 ........
			defb $FF,$03,$27,$EA,$16,$E4,$01,$30				; $F6FB ..'....0
			defb $06,$E4,$01,$31,$06,$E4,$01,$32				; $F703 ...1...2
			defb $06,$E4,$01,$30,$06,$E4,$01,$32				; $F70B ...0...2
			defb $06,$E4,$01,$35,$06,$EA,$00,$E4				; $F713 ...5....
			defb $06,$3A,$0C,$EA,$16,$E4,$01,$3C				; $F71B .:.....<
			defb $06,$E4,$01,$39,$06,$E4,$01,$00				; $F723 ...9....
			defb $06,$E4,$01,$00,$06,$E4,$01,$00				; $F72B ........
			defb $06,$E4,$01,$00,$06,$EA,$00,$E4				; $F733 ........
			defb $06,$39,$0C,$EA,$16,$E4,$01,$35				; $F73B .9.....5
			defb $06,$E4,$01,$00,$06,$E4,$01,$00				; $F743 ........
			defb $06,$E4,$01,$00,$06,$E4,$01,$00				; $F74B ........
			defb $06,$E4,$01,$00,$06,$EA,$00,$E4				; $F753 ........
			defb $06,$37,$0C,$EA,$16,$E4,$01,$34				; $F75B .7.....4
			defb $06,$E4,$01,$00,$06,$E4,$01,$00				; $F763 ........
			defb $06,$E4,$01,$00,$06,$E4,$01,$00				; $F76B ........
			defb $06,$E4,$01,$00,$06,$EA,$00,$E4				; $F773 ........
			defb $06,$00,$0C,$FF,$E8,$07,$EA,$15				; $F77B ........
			defb $03,$00,$E4,$01,$00,$06,$E4,$01				; $F783 ........
			defb $00,$06,$E4,$01,$00,$06,$E4,$01				; $F78B ........
			defb $00,$06,$EA,$00,$E4,$06,$00,$0C				; $F793 ........
			defb $EA,$15,$E4,$01,$00,$06,$E4,$01				; $F79B ........
			defb $00,$06,$FF,$E8,$07,$EA,$16,$03				; $F7A3 ........
			defb $00,$E4,$01,$00,$06,$E4,$01,$00				; $F7AB ........
			defb $06,$E4,$01,$00,$06,$E4,$01,$00				; $F7B3 ........
			defb $06,$EA,$00,$E4,$06,$00,$0C,$EA				; $F7BB ........
			defb $16,$E4,$01,$00,$06,$E4,$01,$00				; $F7C3 ........
			defb $06,$FF,$E6,$13,$E8,$07,$EA,$00				; $F7CB ........
			defb $E9,$00,$03,$00,$EA,$16,$E4,$01				; $F7D3 ........
			defb $43,$06,$E4,$01,$41,$06,$E4,$0E				; $F7DB C...A...
			defb $3C,$06,$E4,$01,$3E,$06,$EA,$00				; $F7E3 <...>...
			defb $E4,$06,$00,$0C,$EA,$16,$E4,$06				; $F7EB ........
			defb $00,$06,$E4,$06,$00,$06,$FF,$E6				; $F7F3 ........
			defb $13,$E8,$04,$E9,$10,$00,$0C,$48				; $F7FB .......H
			defb $A8,$E1,$00,$F0,$00,$F0,$FF,$E8				; $F803 ........
			defb $07,$EA,$16,$E4,$01,$00,$06,$E4				; $F80B ........
			defb $01,$00,$06,$E4,$01,$00,$06,$E4				; $F813 ........
			defb $01,$00,$06,$EA,$00,$E4,$06,$00				; $F81B ........
			defb $0C,$FF,$E6,$07,$E8,$06,$E9,$0F				; $F823 ........
			defb $F0,$18,$1F,$06,$F0,$00,$1F,$06				; $F82B ........
			defb $F0,$18,$1F,$06,$F0,$00,$1F,$06				; $F833 ........
			defb $EA,$14,$E4,$06,$00,$06,$1F,$06				; $F83B ........
			defb $F0,$18,$1F,$06,$F0,$00,$1F,$06				; $F843 ........
			defb $F0,$1B,$1E,$06,$F0,$00,$1E,$06				; $F84B ........
			defb $F0,$1B,$1E,$06,$F0,$00,$1E,$06				; $F853 ........
			defb $E4,$06,$00,$06,$1E,$06,$F0,$1B				; $F85B ........
			defb $1E,$06,$F0,$00,$1E,$06,$F0,$1B				; $F863 ........
			defb $1F,$06,$F0,$00,$1F,$06,$F0,$1B				; $F86B ........
			defb $1F,$06,$F0,$00,$1F,$06,$EA,$14				; $F873 ........
			defb $E4,$06,$00,$06,$1F,$06,$F0,$1B				; $F87B ........
			defb $1F,$06,$F0,$00,$1F,$06,$F0,$1D				; $F883 ........
			defb $21,$06,$F0,$00,$21,$06,$F0,$1D				; $F88B !...!...
			defb $21,$06,$F0,$00,$21,$06,$E4,$06				; $F893 !...!...
			defb $21,$06,$21,$06,$F0,$1B,$21,$06				; $F89B !.!...!.
			defb $F0,$00,$21,$06,$FF,$00,$06,$FF				; $F8A3 ..!.....
			defb $E4,$06,$00,$06,$E4,$06,$00,$06				; $F8AB ........
			defb $E5,$0D,$E8,$04,$3C,$30,$48,$90				; $F8B3 ....<0H.
			defb $3C,$30,$48,$90,$FF,$02,$11,$F0				; $F8BB <0H.....
			defb $18,$22,$06,$F0,$00,$22,$06,$F0				; $F8C3 ."..."..
			defb $18,$22,$06,$F0,$00,$22,$06,$EA				; $F8CB ."..."..
			defb $01,$E4,$06,$00,$06,$22,$06,$F0				; $F8D3 ....."..
			defb $18,$22,$06,$F0,$00,$22,$06,$F0				; $F8DB ."..."..
			defb $28,$1D,$06,$F0,$00,$1D,$06,$F0				; $F8E3 (.......
			defb $28,$1D,$06,$F0,$00,$1D,$06,$E4				; $F8EB (.......
			defb $06,$00,$06,$1D,$06,$F0,$29,$E4				; $F8F3 ......).
			defb $06,$1D,$06,$F0,$00,$1D,$06,$02				; $F8FB ........
			defb $12,$EA,$01,$F0,$21,$E4,$01,$24				; $F903 ....!..$
			defb $06,$F0,$00,$E4,$01,$24,$06,$F0				; $F90B .....$..
			defb $1F,$E4,$01,$24,$06,$F0,$00,$E4				; $F913 ...$....
			defb $01,$24,$06,$F0,$1F,$E4,$06,$24				; $F91B .$.....$
			defb $06,$F0,$00,$24,$06,$24,$06,$24				; $F923 ...$.$.$
			defb $06,$F0,$1F,$E4,$0E,$24,$06,$E4				; $F92B .....$..
			defb $0A,$24,$06,$E4,$07,$24,$06,$E4				; $F933 .$...$..
			defb $04,$24,$06,$F0,$00,$E4,$01,$24				; $F93B .$.....$
			defb $06,$E4,$04,$24,$06,$E4,$0A,$29				; $F943 ...$...)
			defb $06,$E4,$0E,$2B,$06,$FF,$E6,$1F				; $F94B ...+....
			defb $E8,$08,$E9,$0C,$00,$0C,$22,$0C				; $F953 ......".
			defb $24,$0C,$26,$0C,$2D,$06,$00,$06				; $F95B $.&.-...
			defb $2D,$06,$00,$06,$2D,$0C,$2E,$0C				; $F963 -...-...
			defb $00,$30,$E1,$E6,$1F,$E8,$08,$E9				; $F96B .0......
			defb $0C,$2D,$0C,$2B,$06,$00,$06,$2B				; $F973 .-.+...+
			defb $06,$00,$06,$2B,$24,$E9,$11,$37				; $F97B ...+$..7
			defb $24,$00,$60,$E1,$E8,$02,$E9,$0D				; $F983 $.`.....
			defb $24,$18,$27,$18,$2B,$18,$2E,$18				; $F98B $.'.+...
			defb $27,$24,$28,$0C,$29,$18,$2D,$0C				; $F993 '$(.).-.
			defb $2E,$06,$30,$06,$00,$60,$E1,$E8				; $F99B ..0..`..
			defb $05,$F0,$00,$E9,$0C,$03,$27,$EA				; $F9A3 ......'.
			defb $16,$E4,$01,$30,$06,$2E,$06,$E4				; $F9AB ...0....
			defb $01,$2C,$06,$29,$06,$EA,$00,$E4				; $F9B3 .,.)....
			defb $06,$27,$06,$24,$06,$E4,$01,$22				; $F9BB .'.$..."
			defb $06,$24,$06,$EA,$16,$E4,$01,$27				; $F9C3 .$.....'
			defb $06,$00,$06,$E4,$01,$24,$06,$00				; $F9CB .....$..
			defb $06,$EA,$00,$E4,$06,$2B,$06,$00				; $F9D3 .....+..
			defb $06,$E4,$01,$27,$06,$27,$06,$EA				; $F9DB ...'.'..
			defb $16,$E4,$01,$00,$06,$00,$06,$E4				; $F9E3 ........
			defb $01,$00,$06,$00,$06,$EA,$00,$E4				; $F9EB ........
			defb $06,$29,$06,$00,$06,$E4,$01,$26				; $F9F3 .).....&
			defb $06,$26,$06,$EA,$16,$E4,$01,$00				; $F9FB .&......
			defb $06,$00,$06,$E4,$01,$00,$06,$00				; $FA03 ........
			defb $06,$EA,$00,$E4,$06,$00,$06,$00				; $FA0B ........
			defb $06,$FF,$E6,$02,$E5,$13,$FF,$02				; $FA13 ........
			defb $F4,$0F,$E8,$19,$E9,$18,$5D,$48				; $FA1B ......]H
			defb $E1,$02,$F4,$0F,$E8,$01,$F0,$3C				; $FA23 .......<
			defb $EA,$05,$E4,$02,$24,$48,$E1,$02				; $FA2B ....$H..
			defb $F4,$0F,$E8,$1D,$E9,$1E,$4F,$4D				; $FA33 ......OM
			defb $E1,$03,$F4,$0F,$E8,$06,$E9,$19				; $FA3B ........
			defb $53,$0F,$E1,$03,$F4,$0F,$E8,$07				; $FA43 S.......
			defb $E9,$01,$EA,$01,$E4,$07,$5E,$10				; $FA4B ......^.
			defb $EA,$16,$E1,$03,$F4,$0F,$E8,$05				; $FA53 ........
			defb $E9,$1C,$EA,$27,$E4,$03,$4F,$14				; $FA5B ...'..O.
			defb $EA,$16,$E1,$02,$F4,$0F,$E8,$15				; $FA63 ........
			defb $E9,$10,$43,$14,$E1,$03,$F4,$0F				; $FA6B ..C.....
			defb $E2,$0F,$E8,$25,$E9,$26,$E6,$3E				; $FA73 ...%.&.>
			defb $E3,$19,$E1,$02,$F4,$0F,$E8,$23				; $FA7B .......#
			defb $E9,$24,$EA,$00,$E4,$0E,$56,$63				; $FA83 .$....Vc
			defb $E1,$03,$F4,$0F,$E8,$12,$E9,$24				; $FA8B .......$
			defb $61,$20,$E1,$02,$F4,$0F,$E8,$1D				; $FA93 a ......
			defb $E9,$1A,$EA,$0B,$E4,$0C,$39,$40				; $FA9B ......9@
			defb $E9,$0C,$E1,$03,$F4,$0F,$E8,$06				; $FAA3 ........
			defb $E9,$22,$EA,$00,$E4,$0E,$5E,$02				; $FAAB ."....^.
			defb $5E,$10,$EA,$16,$E1,$01,$F4,$0F				; $FAB3 ^.......
			defb $02,$24,$00,$12,$03,$24,$00,$12				; $FABB .$...$..
			defb $E5,$24,$E1,$00,$03,$E1,$F4,$0F				; $FAC3 .$......
			defb $E8,$02,$E9,$1A,$EA,$15,$E4,$07				; $FACB ........
			defb $5E,$5A,$E1,$E6,$07,$E8,$02,$E9				; $FAD3 ^Z......
			defb $0F,$20,$48,$22,$18,$23,$48,$E8				; $FADB . H".#H.
			defb $05,$25,$78,$E5,$0A,$E1,$E6,$07				; $FAE3 .%x.....
			defb $E8,$07,$F0,$0C,$37,$06,$37,$06				; $FAEB ....7.7.
			defb $35,$0C,$EA,$16,$E4,$04,$33,$0C				; $FAF3 5.....3.
			defb $30,$18,$32,$0C,$E4,$04,$33,$0C				; $FAFB 0.2...3.
			defb $E4,$04,$35,$0C,$36,$06,$36,$06				; $FB03 ..5.6.6.
			defb $35,$0C,$E4,$04,$33,$0C,$2F,$18				; $FB0B 5...3./.
			defb $31,$0C,$EA,$14,$E4,$06,$33,$0C				; $FB13 1.....3.
			defb $E8,$05,$35,$60,$F0,$00,$FF,$E6				; $FB1B ..5`....
			defb $37,$E8,$0E,$E9,$00,$E2,$1F,$E3				; $FB23 7.......
			defb $06,$13,$06,$E3,$06,$1F,$06,$E3				; $FB2B ........
			defb $06,$FF,$01,$F4,$0F,$E8,$08,$E9				; $FB33 ........
			defb $0F,$E2,$0E,$EA,$13,$02,$2A,$03				; $FB3B ......*.
			defb $29,$E6,$1E,$E3,$18,$E4,$01,$00				; $FB43 ).......
			defb $18,$E3,$18,$E4,$01,$00,$18,$FF				; $FB4B ........
			defb $F4,$0F,$E8,$08,$E9,$0C,$E6,$31				; $FB53 .......1
			defb $E3,$06,$E6,$36,$E3,$06,$E6,$38				; $FB5B ...6...8
			defb $E3,$06,$E6,$3A,$E3,$06,$E6,$38				; $FB63 ...:...8
			defb $E3,$2A,$00,$0C,$FF,$F4,$0F,$E8				; $FB6B .*......
			defb $08,$E9,$0C,$E6,$1E,$E3,$18,$E3				; $FB73 ........
			defb $18,$E3,$18,$E3,$18,$FF,$E6,$34				; $FB7B .......4
			defb $1A,$00,$00                                    ; $FB83 ...

			; AY-MUSIC DATA END
; ==================================================================================

START_BEEP_MUSIC:	LD HL,BEEPER_DATA		; $FB86
					LD (ReadLocation),HL	; $FB89
					RET						; $FB8C

; Note: This beeper routine runs independently with interrupts disabled.
; Thus, the keyboard is polled directly by the playback routine.
BEEP_MUSIC_LOOP:	JP L_FB97				; $FB8D
L_FB90:				IN A,(C)				; $FB90  ; keyboard input
					AND $1F					; $FB92  ; keyboard row bits
					CP $1F					; $FB94  ; no keys
					RET						; $FB96

L_FB97:				LD BC,$FEFE				; $FB97  ; Select row 0 (SHIFT, Z, X, C, V)
					CALL L_FB90				; $FB9A
					RET NZ					; $FB9D
					LD BC,$FDFE				; $FB9E  ; Select row 1 (A, S, D, F, G)
					CALL L_FB90				; $FBA1
					RET NZ					; $FBA4
					LD BC,$FBFE				; $FBA5  ; Select row 2 (Q, W, E, R, T)
					CALL L_FB90				; $FBA8
					RET NZ					; $FBAB
					LD BC,$F7FE				; $FBAC  ; Select row 3 (1, 2, 3, 4, 5)
					CALL L_FB90				; $FBAF
					RET NZ					; $FBB2
					LD BC,$EFFE				; $FBB3  ; Select row 4 (0, 9, 8, 7, 6)
					CALL L_FB90				; $FBB6
					RET NZ					; $FBB9
					LD BC,$DFFE				; $FBBA  ; Select row 5 (P, O, I, U, Y)
					CALL L_FB90				; $FBBD
					RET NZ					; $FBC0
					LD BC,$BFFE				; $FBC1  ; Select row 6 (ENTER, L, K, J, H)
					CALL L_FB90				; $FBC4
					RET NZ					; $FBC7
					LD BC,$7FFE				; $FBC8  ; Select row 7 (SPACE, SYM SHIFT, M, N, B)
					CALL L_FB90				; $FBCB
					RET NZ					; $FBCE

					XOR A					; $FBCF
					LD (BeeperCounter),A			; $FBD0  ; zero counter
					LD HL,(ReadLocation)		; $FBD3
					LD A,(HL)				; $FBD6
					CP $FF					; $FBD7  ; end-of-music marker
					JP NZ,SKIP_BEEP_RESTART ; $FBD9  ;
					LD HL,BEEPER_DATA		; $FBDC  ; 
					LD A,(HL)				; $FBDF  ; restart music
SKIP_BEEP_RESTART:	LD (Duration1st),A		; $FBE0  ; store duration
					INC HL					; $FBE3  ; next data
					LD A,(HL)				; $FBE4  ; 
					LD (Duration2nd),A		; $FBE5  ; Store next duration
					INC HL					; $FBE8  ; next data
					LD D,(HL)				; $FBE9
					LD E,$00				; $FBEA  ; Clear E (DE = delay count)
					INC HL					; $FBEC  ; next data
					LD (ReadLocation),HL		; $FBED  ; music position

	
				; $5C48 is always zero - looks like these 6 lines do nothing!
				; so "Pattern1st" is allows zero
				LD A,($5C48)			; $FBF0  ; keep border colours
				RRA						; $FBF3  ; /2
				RRA						; $FBF4  ; /4
				RRA						; $FBF5  ; /8
				AND $07					; $FBF6
				LD (Pattern1st),A	; $FBF8 ; beeper pattern 1

					LD C,A					; $FBFB
					LD A,(Duration1st)		; $FBFC ; tone duration
					OR A					; $FBFF
					LD A,C					; $FC00
					JR Z,SKIP_PATTERN		; $FC01 
					OR $10					; $FC03 ;  Modify beeper pattern
SKIP_PATTERN:		LD (Pattern2nd),A	; $FC05 ; beeper pattern 2 
					LD HL,Duration1st		; $FC08 ; delay counter
BEEPLOOP:			LD B,(HL)				; $FC0B ; tone duration
DELAY1BEEP:			DEC DE					; $FC0C ; frequency delay loop
					LD A,D					; $FC0D
					OR E					; $FC0E
					JP Z,EXIT1bitMUSIC		; $FC0F 
					DJNZ DELAY1BEEP			; $FC12

					; note:	Beeper is bit 5 of port &FE
					; 1st 1/2 square wave
					LD A,(Pattern1st)		; $FC14 ; NOTE: VALUE HERE IS ALLWAYS ZERO
					OUT ($FE),A				; $FC17 ; beeper music

					LD B,(HL)				; $FC19
DELAY2BEEP:			DEC DE					; $FC1A ; frequency delay loop
					LD A,D					; $FC1B
					OR E					; $FC1C
					JP Z,EXIT1bitMUSIC		; $FC1D
					DJNZ DELAY2BEEP			; $FC20

					; 2nd 1/2 square wave
					LD A,(Pattern2nd)		; $FC22
					OUT ($FE),A				; $FC25	 ; beeper music

					LD A,(BeeperCounter)	; $FC27 ; get counter 
					INC A					; $FC2A
					CP $08					; $FC2B ; next after 8
					JR Z,NEXT_DATA			; $FC2D
					CP $10					; $FC2F ; zero counter after 10
					JR Z,BACK_ZERO_COUNTER	; $FC31

SET_COUNTER:		LD (BeeperCounter),A	; $FC33 ; save counter 
					JR BEEPLOOP				; $FC36

NEXT_DATA:			INC HL					; $FC38 ; DURATION_2ND next
					JR SET_COUNTER			; $FC39

BACK_ZERO_COUNTER:	DEC HL					; $FC3B ; DURATION_1ST next
					LD A,$00				; $FC3C
					JR SET_COUNTER 			; $FC3E

EXIT1bitMUSIC:		JP BEEP_MUSIC_LOOP		; $FC40

; ----------------------------------------------------------------------------------

; Music playback variables for 1bit beeper music
Pattern1st:			defb $07				; $FC43
Pattern2nd			defb $17				; $FC44
; NOTE: Cache of read music data - playback alternates between DURATION_1ST and DURATION_2ND  
; It's hard to follow, but looking at INC HL at "NEXT_DATA" ($FC38), this shifts between them.
Duration1st: 		defb $49				; $FC45
Duration2nd:		defb $4A				; $FC46
ReadLocation:		defb $08,$FD			; $FC47
BeeperCounter:		defb $09				; $FC49
					defb $00				; $FC4A
					defb $00,$00,$1A		; $FC4B

; ===============================================================================			
; Beeper Music Data - 1 bit music when running as 48k spectrum (without AY chp)
BEEPER_DATA:
			defb $DD,$DD									; $FC4E
			defb $2A,$AF,$AF	
			defb $2A,$95,$95,$FC,$A6,$A6,$2A,$84			; $FC53 
			defb $84,$2A,$6E,$6E,$FC,$84,$84,$2A			; $FC5B 
			defb $6E,$6E,$2A,$62,$62,$2A,$57,$57			; $FC63 
			defb $2A,$62,$62,$2A,$6E,$6E,$2A,$84			; $FC6B 
			defb $84,$2A,$95,$95,$2A,$AF,$AF,$2A			; $FC73 
			defb $95,$95,$2A,$84,$84,$FC,$6E,$6F			; $FC7B 
			defb $2A,$62,$63,$2A,$57,$58,$FC,$6E			; $FC83 
			defb $6F,$2A,$57,$58,$2A,$49,$4A,$FC			; $FC8B 
			defb $57,$58,$2A,$49,$4A,$2A,$41,$42			; $FC93 
			defb $2A,$36,$37,$2A,$41,$42,$2A,$49			; $FC9B 
			defb $4A,$2A,$57,$58,$2A,$41,$42,$2A			; $FCA3 
			defb $49,$4A,$2A,$2B,$2C,$2A,$30,$31			; $FCAB 
			defb $2A,$30,$31,$2A,$30,$31,$2A,$30			; $FCB3 
			defb $31,$2A,$30,$31,$2A,$00,$FF,$2A			; $FCBB 
			defb $28,$29,$2A,$2B,$2C,$2A,$30,$31			; $FCC3 
			defb $9E,$00,$FF,$0A,$30,$31,$9E,$00			; $FCCB 
			defb $FF,$0A,$30,$31,$2A,$36,$37,$2A			; $FCD3 
			defb $30,$31,$2A,$2B,$2C,$2A,$30,$31			; $FCDB 
			defb $2A,$00,$FF,$2A,$49,$4A,$2A,$39			; $FCE3 
			defb $3A,$2A,$36,$37,$2A,$39,$3A,$2A			; $FCEB 
			defb $49,$4A,$2A,$52,$53,$2A,$41,$42			; $FCF3 
			defb $2A,$36,$37,$2A,$41,$42,$2A,$57			; $FCFB 
			defb $58,$2A,$49,$4A,$2A,$39,$3A,$2A			; $FD03 
			defb $49,$4A,$2A,$62,$63,$2A,$52,$53			; $FD0B 
			defb $2A,$41,$42,$2A,$52,$53,$2A,$76			; $FD13 
			defb $77,$2A,$62,$63,$2A,$52,$53,$2A			; $FD1B 
			defb $62,$63,$2A,$76,$77,$2A,$62,$63			; $FD23 
			defb $2A,$52,$53,$2A,$62,$63,$2A,$76			; $FD2B 
			defb $77,$2A,$62,$63,$2A,$45,$46,$2A			; $FD33 
			defb $57,$58,$2A,$76,$77,$2A,$57,$58			; $FD3B 
			defb $2A,$45,$46,$2A,$57,$58,$2A,$76			; $FD43 
			defb $77,$2A,$41,$42,$54,$57,$58,$54			; $FD4B 
			defb $52,$53,$54,$41,$42,$54,$49,$4A			; $FD53 
			defb $9E,$00,$FF,$0A,$49,$4A,$54,$00			; $FD5B 
			defb $FF,$2A,$49,$4A,$2A,$52,$6D,$54			; $FD63 
			defb $62,$83,$54,$57,$74,$54,$52,$6D			; $FD6B 
			defb $54,$57,$74,$9E,$00,$FF,$0A,$57			; $FD73 
			defb $74,$9E,$00,$FF,$0A,$45,$44,$15			; $FD7B 
			defb $41,$40,$15,$45,$44,$15,$41,$40			; $FD83 
			defb $15,$45,$44,$15,$41,$40,$15,$45			; $FD8B 
			defb $44,$15,$41,$40,$15,$45,$44,$15			; $FD93 
			defb $41,$40,$15,$45,$44,$15,$41,$40			; $FD9B 
			defb $15,$45,$44,$15,$41,$40,$15,$45			; $FDA3 
			defb $44,$15,$41,$40,$15,$45,$44,$54			; $FDAB 
			defb $41,$40,$54,$39,$38,$54,$45,$44			; $FDB3 
			defb $54,$33,$32,$9E,$00,$FF,$0A,$33			; $FDBB 
			defb $32,$74,$00,$FF,$0A,$33,$32,$20			; $FDC3 
			defb $00,$FF,$0A,$33,$32,$A8,$00,$FF			; $FDCB 
			defb $A8,$00,$FF,$A8,$00,$FF,$A8				; $FDD3
			; need to $FF, 2nd $FF is the true end mark
			defb $FF,$FF	; x2 $FF, END-OF-MUSIC-MARKERS		; $FDDA
; ===============================================================================			
			
			defb $00,$00,$00,$00,$00,$00,$00				; $FDEC ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FDE3 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FDEB ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FDF3 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FDFB ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE03 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE0B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE13 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE1B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE23 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE2B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE33 ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE3B ........
			defb $00,$00,$00,$00,$00,$00,$00,$00			; $FE43 ........
			defb $00,$F5,$3E,$FF,$D3,$7F,$D3,$3F			; $FE4B ..>....?
			defb $3E,$3F,$D3,$7F,$3C,$32,$86,$FE			; $FE53 >?..<2..
			defb $3E,$FF,$D3,$5F,$D3,$5F,$F1                ; $FE5B >.._._.
L_FE62:
			DI				; $FE62
			LD ($FF9C),HL				; $FE63
			LD ($FFA0),SP				; $FE66
			POP HL				; $FE6A
			LD ($FF9E),HL				; $FE6B
			LD SP,$FF9C				; $FE6E
			PUSH DE				; $FE71
			PUSH BC				; $FE72
			EXX				; $FE73
			PUSH HL				; $FE74
			PUSH DE				; $FE75
			PUSH BC				; $FE76
			PUSH IX				; $FE77
			PUSH IY				; $FE79
			PUSH AF				; $FE7B
			LD A,I				; $FE7C
			LD H,A				; $FE7E
			LD A,R				; $FE7F
			LD L,A				; $FE81
			PUSH HL				; $FE82
			EX AF,AF'				; $FE83
			PUSH AF				; $FE84
			LD D,$40				; $FE85
L_FE87:		CALL L_FF67				; $FE87
			LD A,E				; $FE8A
			CP $B4				; $FE8B
			JR Z,L_FEBC				; $FE8D
			CP $BA				; $FE8F
			JP Z,L_FF2D				; $FE91
			CP $B8				; $FE94
			JR Z,L_FEE2				; $FE96
			CP $B9				; $FE98
			JR Z,L_FEEA				; $FE9A
			CP $B7				; $FE9C
			JR Z,L_FED8				; $FE9E
			CP $B6				; $FEA0
			JR Z,L_FEF2				; $FEA2
			CP $B5				; $FEA4
			JR NZ,L_FE87				; $FEA6
			CALL L_FF67				; $FEA8
			LD H,E				; $FEAB
			CALL L_FF67				; $FEAC
			LD L,E				; $FEAF
			LD ($FF62),HL				; $FEB0
			LD HL,$CD00				; $FEB3
			LD ($FF60),HL				; $FEB6
			JP L_FF43				; $FEB9
L_FEBC:		CALL L_FF67				; $FEBC
			LD H,E				; $FEBF
			CALL L_FF67				; $FEC0
			LD L,E				; $FEC3
			CALL L_FF67				; $FEC4
			LD B,E				; $FEC7
			CALL L_FF67				; $FEC8
			LD C,E				; $FECB
L_FECC:
L_FECC:
			CALL L_FF67				; $FECC
			LD (HL),E				; $FECF
			INC HL				; $FED0
			DEC BC				; $FED1
			LD A,B				; $FED2
			OR C				; $FED3
			JR NZ,L_FECC				; $FED4
			JR L_FE87				; $FED6

L_FED8:
			CALL L_FF67				; $FED8
			LD BC,$7FFD				; $FEDB
			OUT (C),E				; $FEDE
			JR L_FE87				; $FEE0

L_FEE2:
			LD HL,$FF88				; $FEE2
			LD BC,$001A				; $FEE5
			JR L_FF02				; $FEE8

L_FEEA:
			LD HL,$FF88				; $FEEA
			LD BC,$001A				; $FEED
			JR L_FECC				; $FEF0

L_FEF2:
			CALL L_FF67				; $FEF2
			LD H,E				; $FEF5
			CALL L_FF67				; $FEF6
			LD L,E				; $FEF9
			CALL L_FF67				; $FEFA
			LD B,E				; $FEFD
			CALL L_FF67				; $FEFE
			LD C,E				; $FF01
L_FF02:
			IN A,($3F)				; $FF02
			XOR D				; $FF04
			RRCA				; $FF05
			JR C,L_FF02				; $FF06
			LD A,$FF				; $FF08
			OUT ($5F),A				; $FF0A
			INC A				; $FF0C
			OUT ($5F),A				; $FF0D
			LD A,D				; $FF0F
			XOR $41				; $FF10
			LD D,A				; $FF12
L_FF13:
			LD A,(HL)				; $FF13
			CALL L_FF77				; $FF14
			INC HL				; $FF17
			DEC BC				; $FF18
			LD A,B				; $FF19
			OR C				; $FF1A
			JR NZ,L_FF13				; $FF1B
			DEC A				; $FF1D
			OUT ($5F),A				; $FF1E
			OUT ($5F),A				; $FF20
			LD A,D				; $FF22
			XOR $40				; $FF23
			OUT ($3F),A				; $FF25
			XOR $80				; $FF27
			LD D,A				; $FF29
			JP L_FE87				; $FF2A

L_FF2D:
			CALL L_FF67				; $FF2D
			LD L,E				; $FF30
			CALL L_FF67				; $FF31
			LD H,E				; $FF34
			LD ($FF60),HL				; $FF35
			CALL L_FF67				; $FF38
			LD L,E				; $FF3B
			CALL L_C067				; $FF3C
			LD H,D				; $FF3F
			LD ($FF62),HL				; $FF40
L_FF43:
			LD A,D				; $FF43
			LD ($FE86),A				; $FF44
			POP AF				; $FF47
			EX AF,AF'				; $FF48
			POP HL				; $FF49
			LD A,H				; $FF4A
			LD I,A				; $FF4B
			LD A,L				; $FF4D
			LD R,A				; $FF4E
			POP AF				; $FF50
			POP IY				; $FF51
			POP IX				; $FF53
			POP BC				; $FF55
			POP DE				; $FF56
			POP HL				; $FF57
			EXX				; $FF58
			POP BC				; $FF59
			POP DE				; $FF5A
			POP HL				; $FF5B
			LD SP,($FFA0)				; $FF5C
			NOP				; $FF60
			CALL L_6501				; $FF61
			JP L_FE62				; $FF64
L_FF67:
			IN A,($3F)				; $FF67
			XOR D				; $FF69
			RRCA				; $FF6A
			JR C,L_FF67				; $FF6B
			IN A,($1F)				; $FF6D
			LD E,A				; $FF6F
			LD A,D				; $FF70
			OUT ($3F),A				; $FF71
			XOR $81				; $FF73
			LD D,A				; $FF75
			RET				; $FF76

L_FF77:
			OUT ($1F),A				; $FF77
			LD A,D				; $FF79
			OUT ($3F),A				; $FF7A
			XOR $81				; $FF7C
			LD D,A				; $FF7E
L_FF7F:
			IN A,($3F)				; $FF7F
			XOR D				; $FF81
			RRCA				; $FF82
			JR NC,L_FF7F				; $FF83
			RET				; $FF85

			defb $AF,$FE                         ; $FF86 
			defb $44,$00,$75   					 ; $FF88 
			defb $3F,$54,$4C,$3A,$5C,$04,$5D,$21				; $FF8B ?TL:\.]!
			defb $17,$9B,$36,$58,$27,$4C,$FE,$43				; $FF93 ..6X'L.C
			defb $5D,$2B,$2D,$2B,$2D,$E8,$FF,$02				; $FF9B ]+-+-...
			defb $02,$42,$42,$3C,$00,$00,$44,$48				; $FFA3 .BB<..DH
			defb $70,$48,$44,$42,$00,$00,$40,$40				; $FFAB pHDB..@@
			defb $40,$40,$40,$7E,$00,$00,$42,$66				; $FFB3 @@@~..Bf
			defb $5A,$42,$42,$E0,$57,$F3,$0D,$CE				; $FFBB ZBB.W...
			defb $0B,$D3,$50,$CE,$0B,$D4,$50,$0D				; $FFC3 ..P...P.
			defb $17,$DC,$0A,$CE,$0B,$E6,$50,$DB				; $FFCB ......P.
			defb $02,$DB,$02,$7C,$38,$72,$5D,$4D				; $FFD3 ...|8r]M
			defb $00,$E1,$50,$06,$03,$07,$5C,$7C				; $FFDB ..P...\|
			defb $38,$C0,$57,$DB,$02,$7C,$38,$72				; $FFE3 8.W..|8r
			defb $5D,$4D,$00,$FF,$FF,$0E,$01,$00				; $FFEB ]M......
			defb $00,$51,$00,$92,$09,$3F,$05,$76				; $FFF3 .Q...?.v
			defb $1B,$03,$13,$3C                                ; $FFFB ...<

CODE2END equ $ ; Marker to show end of object code

#end ; terminate #target
