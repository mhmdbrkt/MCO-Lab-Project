; MC9S12DT256, 2 MHz bus clock

            XDEF  Entry, _Startup
            ABSENTRY Entry
            INCLUDE 'derivative.inc'

ROMStart    EQU   $4000

            ORG   RAMStart
DATA        DS.B  1
COUNTER     DS.B  1                 ; 500 ms interrupts remaining in Task 1

            ORG   ROMStart

Entry:
_Startup:
            LDS   #RAMEnd+1
            SEI                     ; Enable interrupts after timer setup

            MOVB  #$FF, PORTB       ; Start with all active-low LEDs off
            MOVB  #$F0, DDRB        ; PB7-PB4 outputs, PB3-PB0 inputs
            BSET  PUCR, #$02        ; Pull-ups for the active-low DIP switches
            BCLR  PORTA, #$01       ; Start with the active-high PA0 LED off
            BSET  DDRA,  #$01       ; Configure PA0 as an output

            ; Power up ATD0 now. The LCD startup wait lets it settle.
            MOVB  #$C0, ATD0CTL2
            MOVB  #$08, ATD0CTL3     ; One conversion per sequence
            MOVB  #$80, ATD0CTL4     ; 8-bit conversion

            MOVB  #$10, MODRR       ; Route SPI0 to Port M
            BSET  PTM,  #$08        ; Keep SS high before SPI takes control
            MOVB  #$38, DDRM
            MOVB  #$52, SPI0CR1
            MOVB  #$10, SPI0CR2
            MOVB  #$00, SPI0BR

            JSR   Delay             ; Wait about 40 ms after power-up
            CLRA
            JSR   SENDSPI           ; Start with LCD E low

            ; The first two writes send startup nibbles 3, 3, 3, 2.
            LDAA  #$33
            JSR   SENDINST
            LDAA  #$32
            JSR   SENDINST
            LDAA  #$28             ; 4-bit mode, two lines, 5x8 font
            JSR   SENDINST
            LDAA  #$08             ; Display off
            JSR   SENDINST
            LDAA  #$01             ; Clear display and return cursor to line 1
            JSR   SENDINST
            LDAA  #$06             ; Advance cursor after each character
            JSR   SENDINST
            LDAA  #$0E             ; Display on, cursor on, blink off
            JSR   SENDINST

mainLoop:
            LDX   #pass1
            LDY   #5               ; Print "Enter" on line 1
            JSR   PRINT_CHAR
            INX                    ; Skip the space in "Enter Password"

            LDAA  #$C0             ; Move the cursor to line 2
            PSHX                   ; SENDINST calls Delay, which changes X
            JSR   SENDINST
            PULX
            LDY   #8               ; Print "Password" on line 2
            JSR   PRINT_CHAR

WAIT_SW:
            LDAA  PORTB
            ANDA  #$0F             ; Keep the four DIP switch bits
            EORA  #$0F             ; Convert to 1 = ON
            CMPA  #$01             ; SW3-1 ON and SW3-2 through SW3-4 OFF
            BNE   WAIT_SW

SHOW_CORRECT:
            BSET  PORTA, #$01      ; Turn on the external PA0 LED
            LDAA  #$01
            JSR   SENDINST
            LDX   #msg_ok
            LDY   #7
            JSR   PRINT_CHAR

TASK1:
            MOVB  #$A5, ATD0CTL5   ; Continuous scan of the potentiometer on AN05
            MOVB  #20, COUNTER
            BCLR  MCCTL, #$04      ; Stop the counter before setting its mode
            MOVB  #$C7, MCCTL      ; Interrupt enabled, modulus mode, /16, counter on
            MOVW  #62500, MCCNT    ; 500 ms at 2 MHz with /16 prescaler
            BSET  MCCTL, #$08      ; Force-load the first count
            MOVB  #$80, MCFLG      ; Clear the pending flag
            CLI

CONT:
            LDY   #4
            LDAA  #$EF             ; LED1 on (PB4 low)

LOOP:
            TST   COUNTER
            BEQ   DONE
            STAA  PORTB
            PSHA                   ; Save LED pattern while A holds the ADC result
            JSR   DELAY3           ; Preserve the original base delay of 200 ms

CHECK:
            TST   COUNTER
            BEQ   NEXT_LED
            BRCLR ATD0STAT0, #$80, CHECK
            LDAA  ATD0DR0L

            CMPA  #63
            BHI   CHK2
            JSR   DELAY1           ; 900 ms extra
            BRA   NEXT_LED

CHK2:
            CMPA  #125
            BHI   CHK3
            JSR   DELAY2           ; 500 ms extra
            BRA   NEXT_LED

CHK3:
            CMPA  #180
            BHI   CHK4
            JSR   DELAY3           ; 200 ms extra
            BRA   NEXT_LED

CHK4:
            JSR   DELAY4           ; 50 ms extra

NEXT_LED:
            PULA                   ; Balance PSHA before checking for exit
            TST   COUNTER
            BEQ   DONE
            LSLA                   ; Move the active-low bit from PB4 toward PB7
            ORAA  #$0F
            DEY
            BNE   LOOP
            BRA   CONT

DONE:
            BRA   DONE             ; Task 1 is complete. Task 2 can start here.

PRINT_CHAR:
            LDAA  1,X+
            PSHX
            JSR   SENDDATA
            PULX
            DEY
            BNE   PRINT_CHAR
            RTS

SENDSPI:
SPI_READY:
            BRCLR SPI0SR, #$20, SPI_READY
            STAA  SPI0DR
SPI_DONE:
            BRCLR SPI0SR, #$80, SPI_DONE
            MOVB  SPI0DR, DATA     ; Read after SPIF to acknowledge the transfer
            RTS

SENDNIBBLE:
            JSR   SENDSPI          ; Establish data and RS with E low
            ORAA  #$80
            JSR   SENDSPI          ; E high
            ANDA  #$7F
            JSR   SENDSPI          ; E low, LCD latches the nibble
            JSR   Delay
            RTS

SENDINST:
            TAB                    ; Preserve the original instruction in B
            LSRA
            LSRA
            LSRA
            LSRA
            JSR   SENDNIBBLE       ; High nibble, RS = 0
            TBA
            ANDA  #$0F
            JSR   SENDNIBBLE       ; Low nibble, RS = 0
            RTS

SENDDATA:
            TAB                    ; Preserve the original character in B
            LSRA
            LSRA
            LSRA
            LSRA
            ORAA  #$40
            JSR   SENDNIBBLE       ; High nibble, RS = 1
            TBA
            ANDA  #$0F
            ORAA  #$40
            JSR   SENDNIBBLE       ; Low nibble, RS = 1
            RTS

MOD_COUNTER_ISR:
            MOVB  #$80, MCFLG
            TST   COUNTER
            BEQ   ISR_DONE
            DEC   COUNTER
ISR_DONE:
            RTI

; Original LCD delay, approximately 40 ms at a 2 MHz bus clock.
Delay:
            LDX   #4231
AGAIN:
            PSHB
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE   AGAIN
            RTS

; Task 1 speed delays, using the original counts.
DELAY1:
            LDAB  #2
OUTER1:
            LDX   #47368
            JSR   TASK1_DELAY
            TST   COUNTER
            BEQ   DELAY1_DONE
            DECB
            BNE   OUTER1
DELAY1_DONE:
            RTS

DELAY2:
            LDX   #52631
            BRA   TASK1_DELAY
DELAY3:
            LDX   #21052
            BRA   TASK1_DELAY
DELAY4:
            LDX   #5275

TASK1_DELAY:
            TST   COUNTER
            BEQ   TASK1_DELAY_DONE
            NOP                    ; TST, BEQ, and NOP replace one PSHB/PULB pair
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE   TASK1_DELAY
TASK1_DELAY_DONE:
            RTS

; Keep constant strings in ROM so they are present after reset.
pass1       DC.B  "Enter Password"
msg_ok      DC.B  "CORRECT"

            ORG   $FFCA
            DC.W  MOD_COUNTER_ISR
            ORG   $FFFE
            DC.W  Entry

            END
