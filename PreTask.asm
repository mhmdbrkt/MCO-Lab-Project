; export symbols
            XDEF Entry, _Startup    ; export 'Entry' symbol
            ABSENTRY Entry          ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
            INCLUDE 'derivative.inc' 

ROMStart    EQU  $4000              ; absolute address to place code/constant data

; variable/data section
            ORG RAMStart
DATA        DS.B 1

pass1       DC.B "Enter Password"   ;

; code section
            ORG   ROMStart

Entry:
_Startup:
            LDS   #RAMEnd+1         ; initialize the stack pointer
            CLI                     ; enable interrupts

;**************************************************************
;*            Hardware & LCD Initialization                   *
;**************************************************************
            MOVB  #$F0, DDRB        ; Configure upper 4 bits of PORTB as outputs (LEDs)
            MOVB  #$FF, PORTB       ; Turn all LEDs OFF initially (active-low)
                               
            MOVB  #$10, MODRR       ; Route SPI0 to Port M
            MOVB  #$38, DDRM        ; Configure PM3, PM4, PM5 as outputs (SS, MOSI, SCK)
            MOVB  #$52, SPI0CR1     ; Enable SPI, Master mode, SS output enabled
            MOVB  #$10, SPI0CR2     ; Mode fault enable (MODFEN = 1)
            MOVB  #$00, SPI0BR      ; Set SPI baud rate

            ; LCD 4-bit initialization sequence
            LDAA  #%00110011 
            JSR   SENDINST 
            LDAA  #%00110010 
            JSR   SENDINST 
            LDAA  #%00101000        ; 4-bit mode, 2 lines, 5x7 font
            JSR   SENDINST 
            LDAA  #%00001000        ; Display OFF
            JSR   SENDINST 
            LDAA  #%00000001        ; Clear display
            JSR   SENDINST 
            LDAA  #%00000110        ; Entry mode: increment cursor, no shift
            JSR   SENDINST 
            LDAA  #%00001110        ; Display ON, cursor ON, blink OFF
            JSR   SENDINST 

;**************************************************************
;*                 Main Program                               *
;**************************************************************
mainLoop:
            LDX   #pass1            ; Load starting address of string
            LDY   #5                ; Print first 5 characters ("Enter")
            JSR   PRINT_CHAR

            INX                     ; Skip the space character (' ') in the table

            LDAA  #%11000000        ; Move cursor to beginning of second line ($C0)
            PSHX                    ; Save pointer X before calling SENDINST/Delay
            JSR   SENDINST
            PULX                    ; Restore pointer X

            LDY   #8                ; Print remaining 8 characters ("Password")
            JSR   PRINT_CHAR

DONE:       BRA   DONE              ; Infinite loop to prevent crashing

;**************************************************************
;*                 Print String Subroutine                    *
;**************************************************************
PRINT_CHAR:
            LDAA  1,X+              ; Read the current character, then advance X
            PSHX                    ; Save pointer X (Delay overwrites X)
            JSR   SENDDATA          ; Send character to LCD
            PULX                    ; Restore pointer X
            DEY                     ; Decrement character counter
            BNE   PRINT_CHAR        ; Repeat until Y = 0
            RTS                     ; Return to main program

;**************************************************************
;*                 SPI & LCD Subroutines                      *
;**************************************************************
SENDSPI:    PSHA                    ; Save Accumulator A
            STAA  SPI0DR            ; Start SPI transmission
            BRCLR SPI0SR, #$80, *   ; Wait until SPIF (bit 7) is set
            MOVB  SPI0DR, DATA      ; Read SPI0DR to clear the SPIF flag
            PULA                    ; Restore Accumulator A
            RTS            
            
SENDINST:   TAB                     ; Save original byte in B
            LSRA                    ; Shift upper nibble to lower 4 bits
            LSRA
            LSRA
            LSRA
            ORAA  #%10000000        ; EN = 1, RS = 0 (Instruction mode)
            ANDA  #%10001111        ; Mask unused upper bits
            JSR   SENDSPI
            ANDA  #%00001111        ; EN = 0, RS = 0 (Latch data)
            JSR   SENDSPI
            JSR   Delay

            TBA                     ; Restore original byte from B for lower nibble
            ORAA  #%10000000        ; EN = 1, RS = 0
            ANDA  #%10001111
            JSR   SENDSPI
            ANDA  #%00001111        ; EN = 0, RS = 0
            JSR   SENDSPI
            JSR   Delay
            RTS

SENDDATA:   TAB                     ; Save original byte in B
            LSRA                    ; Shift upper nibble to lower 4 bits
            LSRA
            LSRA
            LSRA
            ORAA  #%11000000        ; EN = 1, RS = 1 (Data mode)
            ANDA  #%11001111        ; Mask unused upper bits
            JSR   SENDSPI
            ANDA  #%01001111        ; EN = 0, RS = 1 (Latch data)
            JSR   SENDSPI
            JSR   Delay

            TBA                     ; Restore original byte from B for lower nibble
            ORAA  #%11000000        ; EN = 1, RS = 1
            ANDA  #%11001111
            JSR   SENDSPI
            ANDA  #%01001111        ; EN = 0, RS = 1
            JSR   SENDSPI
            JSR   Delay
            RTS

;**************************************************************
;*                 Delay Subroutines                          *
;**************************************************************
Delay:      LDX   #4231             ; Load X register with delay count
AGAIN:      PSHB                    ; Burn clock cycles
            PULB
            PSHB
            PULB
            PSHB
            PULB
            DEX                     ; Decrement loop counter
            BNE   AGAIN             ; Repeat until X = 0
            RTS                     ; Return from subroutine

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry             ; Reset Vector
