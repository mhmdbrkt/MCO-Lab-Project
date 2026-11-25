; COE324 Final Project - integrated HCS12 program
; MC9S12DT256 / APS12DT256SLK, assumed 2 MHz bus
; AN5 = potentiometer, AN4 = photoresistor/phototransistor
; PB7..PB4 = active-low LEDs, PB3..PB0 = active-low DIP inputs
; PA0 = password success LED, PA1 = darkness LED (active-high)
; PP0 = PB1 external IRQ button

            XDEF  Entry, _Startup
            ABSENTRY Entry
            INCLUDE 'derivative.inc'

ROMStart    EQU   $4000

            ORG   RAMStart
DATA        DS.B  1
mode       DS.B  1       ; 1=Task1, 2=Tasks2/3
TICKS       DS.B  1       ; interrupts in current phase
STOPFLAG    DS.B  1       ; PB1 requested ending
OLDMODE     DS.B  1
LIGHT       DS.B  1
LEDBIT      DS.B  1
STEPWAIT    DS.B  1
FRAMEPOS    DS.B  1
COLPOS      DS.B  1

            ORG   ROMStart
Entry:
_Startup:
            LDS   #RAMEnd+1
            SEI
            CLR   STOPFLAG
            CLR   TICKS
            CLR   MODE
            CLR   OLDMODE
            MOVB  #$FF,PORTB
            MOVB  #$F0,DDRB
            BSET  PUCR,#$02
            BCLR  PORTA,#$03
            BSET  DDRA,#$03
            MOVB  #$FE,DDRP   ; PP0 input (PB1 IRQ)
            MOVB  #$C0,INTCR  ; enable IRQ, edge-sensitive
            MOVB  #$C0,ATD0CTL2
            MOVB  #$08,ATD0CTL3
            MOVB  #$80,ATD0CTL4   ; 8-bit mode

            MOVB  #$10,MODRR
            BSET  PTM,#$08
            MOVB  #$38,DDRM
            MOVB  #$52,SPI0CR1
            MOVB  #$10,SPI0CR2
            MOVB  #$00,SPI0BR
            JSR   Delay40
            CLRA
            JSR   SENDSPI

; LCD initialization specified in the lab
            LDAA  #$33
            JSR   SENDINST
            LDAA  #$32
            JSR   SENDINST
            LDAA  #$28
            JSR   SENDINST
            LDAA  #$08
            JSR   SENDINST
            LDAA  #$01
            JSR   SENDINST
            JSR   Delay2
            LDAA  #$06
            JSR   SENDINST
            LDAA  #$0E
            JSR   SENDINST

; Password display from PASS via indexed addressing
            LDX   #PASS
            LDY   #5
            JSR   PRINT_CHAR
            INX                  ; skip space
            PSHX
            LDAA  #$C0
            JSR   SENDINST
            PULX
            LDY   #8
            JSR   PRINT_CHAR

WAIT_PWD:   LDAA  PORTB
            ANDA  #$0F
            EORA  #$0F         ; active-low DIP -> binary password
            CMPA  PWD_Q3
            BNE   WAIT_PWD

            BSET  PORTA,#$01
            LDAA  #$01
            JSR   SENDINST
            JSR   Delay2
            LDX   #OKMSG
            LDY   #7
            JSR   PRINT_CHAR

; Keep CORRECT visible for approximately 2 seconds.
; Interrupts remain masked, and PA0 stays ON.
            LDY   #40
SHOW_OK:    JSR   Delay50
            DEY
            BNE   SHOW_OK

; Timer: 500 ms with 2 MHz bus / 16 and MCCNT=62500
            MOVB  #1,MODE
            CLR   TICKS
            MOVB  #$80,MCFLG
            MOVB  #$C7,MCCTL
            MOVW  #62500,MCCNT
            CLI

MAIN:       TST   STOPFLAG
            LBNE  TASK4
            LDAA  MODE
            CMPA  OLDMODE
            BEQ   RUN_CURRENT
            STAA  OLDMODE
            CMPA  #1
            BEQ   ENTER_TASK1
            JMP   ENTER_TASK23

ENTER_TASK1:
            BCLR  PORTA,#$02
            MOVB  #$80,LEDBIT
            MOVB  #$FF,PORTB
            LDAA  #$01
            JSR   SENDINST
            JSR   Delay2
            JMP   RUN_CURRENT

ENTER_TASK23:
            MOVB  #$FF,PORTB
            LDAA  #$01
            JSR   SENDINST
            JSR   Delay2

RUN_CURRENT:
            LDAA  MODE
            CMPA  #1
            BEQ   DO_TASK1
            JMP   DO_TASK23

DO_TASK1:
; Show one lit LED, then wait depending on potentiometer AN5
            LDAA  LEDBIT
            EORA  #$F0
            ORAA  #$0F
            STAA  PORTB
            MOVB  #$85,ATD0CTL5   ; 8-bit, single AN5 conversion
T1_ADC:     BRCLR ATD0STAT0,#$80,T1_ADC
            LDAA  ATD0DR0L
            CMPA  #64
            BHS   T1_MED1
            MOVB  #20,STEPWAIT   ; approximately 1000 ms
            BRA   T1_WAIT
T1_MED1:    CMPA  #128
            BHS   T1_MED2
            MOVB  #12,STEPWAIT   ; approximately 600 ms
            BRA   T1_WAIT
T1_MED2:    CMPA  #192
            BHS   T1_FAST
            MOVB  #6,STEPWAIT    ; approximately 300 ms
            BRA   T1_WAIT
T1_FAST:    MOVB  #2,STEPWAIT    ; approximately 100 ms
T1_WAIT:    TST   STOPFLAG
            LBNE  TASK4
            LDAA  MODE
            CMPA  #1
            LBNE  MAIN
            JSR   Delay50
            DEC   STEPWAIT
            BNE   T1_WAIT
            LSR   LEDBIT
            LDAA  LEDBIT
            CMPA  #$08
            BNE   T1_REPEAT
            MOVB  #$80,LEDBIT
T1_REPEAT:  JMP   MAIN

DO_TASK23:
            MOVB  #$84,ATD0CTL5   ; single AN4 conversion
T23_ADC:    BRCLR ATD0STAT0,#$80,T23_ADC
            LDAA  ATD0DR0L
            STAA  LIGHT
                        CMPA  #$30
            BHI   T23_DARK

            BCLR  PORTA,#$02    ; Light: LED OFF
            BRA   T23_DISPLAY

T23_DARK:   BSET  PORTA,#$02    ; Darkness: LED ON
T23_DISPLAY:
            LDAA  #$80          ; beginning of LCD first line
            JSR   SENDINST
            LDX   #VALUE_MSG   ; write "Val:"
            LDY   #4
            JSR   PRINT_CHAR
            LDAA  #$20        ; send ASCII space explicitly
            JSR   SENDDATA
            LDAA  LIGHT        ; write the two hexadecimal digits
            JSR   HEX_LCD
            LDAA  #$20        ; clear final LCD character position
            JSR   SENDDATA
            JMP   MAIN

;**************************************************************
;* TASK 4: PB1 PRESSED - SCROLL ONCE, THEN HALT
;**************************************************************
; IRQ service routine sets STOPFLAG. Main loop enters here.
; Use the same LCD, no reinitialization or second reset vector.
TASK4:      SEI
            MOVB  #$00,INTCR       ; disable IRQ
            MOVB  #$00,MCCTL       ; stop 500 ms interrupt timer
            MOVB  #$80,MCFLG       ; clear pending timer flag
            MOVB  #$FF,PORTB       ; LEDs on PB7..PB4 OFF
            BCLR  PORTA,#$03      ; PA0, PA1 OFF

            LDAA  #$01            ; LCD clear
            JSR   SENDINST
            JSR   Delay2

; Timer polling, 200 ms: MCCNT=25000 @ 2MHz / 16.
; Reconfigure timer without interrupt enable (MCCTL=$47).
            MOVB  #$47,MCCTL
            CLR   FRAMEPOS

; Frame p=0 is blank, then string enters from the right.
; Each frame writes 8 character positions on the second row.
FRAME:      MOVB  #$80,MCFLG
            MOVW  #25000,MCCNT

            LDAA  #$C0            ; DDRAM start, second line
            JSR   SENDINST
            CLR   COLPOS

COLUMN:     LDAB  FRAMEPOS
            ADDB  COLPOS
            CMPB  #8
            BLO   PUT_SPACE
            CMPB  #25            ; 8 + 17 characters
            BHS   PUT_SPACE
            SUBB  #8
            LDX   #ENDMSG
            ABX
            LDAA  0,X
            BRA   PUT_CHAR
PUT_SPACE:  LDAA  #' '
PUT_CHAR:   JSR   SENDDATA
            INC   COLPOS
            LDAA  COLPOS
            CMPA  #8
            BNE   COLUMN

; Time since start of this frame >= 200 ms (includes LCD writes).
WAIT200:    BRCLR MCFLG,#$80,WAIT200
            INC   FRAMEPOS
            LDAA  FRAMEPOS
            CMPA  #26            ; blank final frame p=25
            BNE   FRAME

; All characters have left the display: shut down permanently.
            MOVB  #$00,MCCTL
            LDAA  #$01
            JSR   SENDINST
            JSR   Delay2
            LDAA  #$08
            JSR   SENDINST
            MOVB  #$FF,PORTB
            BCLR  PORTA,#$03
FOREVER:    BRA   FOREVER

; MC timer ISR: 20 ticks Task1, 40 ticks Task2+3, repeat
MYISR1:   MOVB  #$80,MCFLG
            INC   TICKS
            LDAA  MODE
            CMPA  #1
            BNE   MC_TASK23
            LDAA  TICKS
            CMPA  #20
            BLO   MC_DONE
            CLR   TICKS
            MOVB  #2,MODE
            BRA   MC_DONE
MC_TASK23:  LDAA  TICKS
            CMPA  #40
            BLO   MC_DONE
            CLR   TICKS
            MOVB  #1,MODE
MC_DONE:    RTI

; IRQ on PP0, triggered by PB1
MYISR2:    MOVB  #1,STOPFLAG
            RTI

; Send Y characters from address X, using indexed mode
PRINT_CHAR: LDAA  1,X+
            PSHX
            PSHY
            JSR   SENDDATA
            PULY
            PULX
            DEY
            BNE   PRINT_CHAR
            RTS

; Convert unsigned 8-bit ADC value to ASCII hexadecimal
HEX_LCD:    PSHA
            LSRA
            LSRA
            LSRA
            LSRA
            BSR   HEX_ASCII
            JSR   SENDDATA
            PULA
            ANDA  #$0F
            BSR   HEX_ASCII
            JSR   SENDDATA
            RTS
HEX_ASCII:  CMPA  #10
            BLO   HEX_DIGIT
            ADDA  #7
HEX_DIGIT:  ADDA  #$30
            RTS

; SPI/LCD code: matching repository wiring (RS=$40, E=$80)
SENDSPI:    BRCLR SPI0SR,#$20,*
            STAA  SPI0DR
SPI_DONE:   BRCLR SPI0SR,#$80,SPI_DONE
            MOVB  SPI0DR,DATA
            RTS

SENDINST:   TAB
            LSRA
            LSRA
            LSRA
            LSRA
            JSR   SENDNIB
            TBA
            ANDA  #$0F
            JSR   SENDNIB
            RTS
SENDDATA:   TAB
            LSRA
            LSRA
            LSRA
            LSRA
            ORAA  #$40
            JSR   SENDNIB
            TBA
            ANDA  #$0F
            ORAA  #$40
            JSR   SENDNIB
            RTS
SENDNIB:    JSR   SENDSPI       ; E=0
            ORAA  #$80
            JSR   SENDSPI       ; E=1
            ANDA  #$7F
            JSR   SENDSPI       ; E=0
            JSR   LCDWAIT       ; short delay per nibble
            RTS

; Standard LCD instruction settling delay (conservative).
; LCD data writes must NOT consume 40ms per nibble, otherwise
; Task 4 can never show one full 8-character frame per 200ms.
LCDWAIT:    PSHX
            LDX   #100
LCD_LOOP:   PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE   LCD_LOOP
            PULX
            RTS

; Extra delay after LCD clear, which needs longer than data write.
Delay2:     PSHY
            LDY   #10
D2_LOOP:    JSR   LCDWAIT
            DEY
            BNE   D2_LOOP
            PULY
            RTS

; ~40ms startup delay at assumed 2MHz bus.
Delay40:    PSHX
            LDX   #4231
D40_LOOP:   PSHB
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE   D40_LOOP
            PULX
            RTS

; ~50ms, based on the same loop timing
Delay50:    PSHX
            LDX   #5263
D50_LOOP:   PSHB
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE   D50_LOOP
            PULX
            RTS

; Required ROM labels
PWD_Q3      DC.B  1
PASS      DC.B  'Enter Password'
OKMSG       DC.B  'CORRECT'
VALUE_MSG   DC.B  'Val:'
ENDMSG      DC.B  'Program has Ended'

            ORG   $FFCA
            DC.W  MYISR1
            ORG   $FFF2
            DC.W  MYISR2
            ORG   $FFFE
            DC.W  Entry
            END

