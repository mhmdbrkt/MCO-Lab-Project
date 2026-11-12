; export symbols
            XDEF Entry, _Startup    ; export 'Entry' symbol
            ABSENTRY Entry          ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
            INCLUDE 'derivative.inc' 

ROMStart    EQU  $4000              ; absolute address to place code/constant data

; variable/data section
            ORG RAMStart
Counter     DS.W 1
FiboRes     DS.W 1

; code section
            ORG   ROMStart

Entry:
_Startup:
            LDS   #RAMEnd+1         ; initialize the stack pointer
            CLI                     ; enable interrupts

mainLoop:
            MOVB #$F0,DDRB          ; Configure upper 4 bits of PORTB as outputs (LEDs)
            MOVB #$FF,PORTB         ; Turn all LEDs OFF initially (active-low)
            
            ; Configure ATD0 (Analog-to-Digital Converter)
            MOVB #$C0,ATD0CTL2      ; Power up ATD0
            MOVB #$08,ATD0CTL3      ; 1 conversion per sequence
            MOVB #$80,ATD0CTL4      ; 8-bit resolution, 2-cycle sample time
            MOVB #$A5,ATD0CTL5      ; Right-justified, unsigned, continuous scan, channel 5

CONT        LDY  #4                 ; Load Y = 4 for the four LEDs
            LDAA #%11101111         ; Load pattern with LED1 ON (PB4 = 0)
            
LOOP        STAA PORTB              ; Send the current LED pattern to PORTB
            PSHA                    ; Save LED pattern onto stack before using A for ADC
            
            BSR  DELAY3             ; Wait approximately 300 ms
            
CHECK       BRCLR ATD0STAT0,#$80,*  ; Wait until ADC conversion is complete
            
            LDAA ATD0DR0L           ; Load 8-bit converted value into Accumulator A
            
            CMPA #63                ; Compare ADC value with 63
            BHI  CHK2               ; If > 63, check next threshold
            BSR  DELAY1             ; <= 63: call 900 ms delay
            BRA  NEXT_LED           ; Move to next LED
            
CHK2        CMPA #125               ; Compare ADC value with 125
            BHI  CHK3               ; If > 125, check next threshold
            BSR  DELAY2             ; 64 to 125: call 600 ms delay
            BRA  NEXT_LED           ; Move to next LED
            
CHK3        CMPA #180               ; Compare ADC value with 180
            BHI  CHK4               ; If > 180, use fastest delay
            BSR  DELAY3             ; 126 to 180: call 300 ms delay
            BRA  NEXT_LED           ; Move to next LED
            
CHK4        BSR  DELAY4             ; > 180: call 100 ms delay
            
NEXT_LED    PULA                    ; Restore LED pattern from stack into Accumulator A
            LSLA                    ; Shift the active-low bit to the next LED
            ORAA #%00001111         ; Keep lower 4 bits high
            DEY                     ; Decrement LED counter Y
            BNE  LOOP               ; Repeat until all 4 LEDs have lit
            BRA  CONT               ; Restart the 4-LED sequence continuously

;**************************************************************
;*                 Delay Subroutines                          *
;**************************************************************

DELAY1      LDAB #2                 ; Outer loop counter (2 x 47368 = 94736 cycles)
OUTER1      LDX  #47368             ; Fits within 16-bit limit (<= 65535) for ~900 ms total
AGAIN1      PSHB
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE  AGAIN1
            DECB
            BNE  OUTER1
            RTS
            
DELAY2      LDX  #52631            ; Load X for ~500 ms delay
AGAIN2      PSHB
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE  AGAIN2
            RTS

DELAY3      LDX  #21052             ; Load X for ~200 ms delay
AGAIN3      PSHB
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE  AGAIN3
            RTS

DELAY4      LDX  #5275             ; Load X for ~50 ms delay
AGAIN4      PSHB
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX
            BNE  AGAIN4
            RTS

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry             ; Reset Vector
