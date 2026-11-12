; export symbols
            XDEF Entry, _Startup    ; export 'Entry' symbol
            ABSENTRY Entry          ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
            INCLUDE 'derivative.inc' 

ROMStart    EQU  $4000              ; absolute address to place code/constant data

; variable/data section
            ORG RAMStart
DATA        DS.B 1

pass1       DC.B "Enter Password"   ; "Enter" (5) + " " (1) + "Password" (8)
msg_ok      DC.B "Correct"          ; 7 characters total

COUNTER     DC.B  20

; code section
            ORG   ROMStart

Entry:
_Startup:
            LDS   #RAMEnd+1         ; initialize the stack pointer
            CLI                     ; enable interrupts

;           Hardware & LCD Initialization                   

            MOVB  #$F0, DDRB        ; Upper 4 bits of PORTB = outputs (LEDs)
                                    ; Lower 4 bits of PORTB = inputs (DIP switches 1-4)
            BSET  PUCR, #$02        ; Enable internal pull-ups on Port B inputs
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

;                 Main Program                               

mainLoop:
            LDX   #pass1            ; Load starting address of string
            LDY   #5                ; Print first 5 characters ("Enter")
            JSR   PRINT_CHAR

            INX                     ; Skip the space character (' ') in the table
            MOVB  #$02,PUCR        
            LDAA  #%11000000                        
            MOVB  #$01, PORTA
            MOVB  #$01, DDRA
            MOVB  #$C7, MCCTL
            MOVW #62500, MCCNT
            MOVB  #$80, MCCTL
            MOVB  #$80, MCFLG
            
            
            
            ; Move cursor to beginning of second line ($C0)
            PSHX                    ; Save pointer X before calling SENDINST
            JSR   SENDINST
            PULX                    ; Restore pointer X

            LDY   #8                ; Print remaining 8 characters ("Password")
            JSR   PRINT_CHAR


;                 Check DIP Switch 1 (Active Low)            

WAIT_SW:
            LDAA  PORTB
            ANDA  #$0F         ; Keep only PB3–PB0
            EORA  #$0F         ; Convert active-low inputs to 1 = ON
            CMPA  #$01         ; password
            BNE   WAIT_SW
            BRA   SHOW_CORRECT

SHOW_CORRECT:
            MOVB  #$01,PORTA
            LDAA  #%00000001        ; Clear display instruction (resets cursor to line 1)
            JSR   SENDINST

            LDX   #msg_ok           ; Load starting address of "Correct"
            LDY   #7                ; Load character count ("Correct" = 7 chars)
            JSR   PRINT_CHAR

DONE:       BRA   DONE              ; Halt safely after displaying "Correct"

;                 Print String Subroutine                    

PRINT_CHAR:
            LDAA  1,X+              ; Read the current character, then advance X
            PSHX                    ; Save pointer X (Delay overwrites X)
            JSR   SENDDATA          ; Send character to LCD
            PULX                    ; Restore pointer X
            DEY                     ; Decrement character counter
            BNE   PRINT_CHAR        ; Repeat until Y = 0
            RTS                     ; Return to main program

;                 SPI & LCD Subroutines                      

SENDSPI:
SPI_READY:
            BRCLR SPI0SR, #$20, SPI_READY ; Wait for SPTEF before writing
            STAA  SPI0DR
SPI_DONE:
            BRCLR SPI0SR, #$80, SPI_DONE  ; Wait for SPIF
            MOVB  SPI0DR, DATA            ; Read data to clear SPIF
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
            
MOD_COUNTER_ISR:
                MOVB  #$80, MCFLG
                RTI

;                Delay Subroutine                          

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

;                 Interrupt Vectors                          

                  ORG   $FFFE
            DC.W  Entry             ; Reset Vector
                  ORG   $FFCA             ; Add this before your reset vector
            DC.W  MOD_COUNTER_ISR
