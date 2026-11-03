
; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point



; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

ROMStart    EQU  $4000  ; absolute address to place my code/constant data

; variable/data section

            ORG RAMStart
 ; Insert here your data definition.
Word        DC.B  'Program has Ended ' ; Message to scroll 
MaxSize     DC.B  8              
Size        DC.B  18             
Counter     DC.B  0              
Shift       DC.B  0  
Printed     DS.B  1 
DATA        DS.B  1 

  
             


; code section
            ORG   ROMStart


Entry:
_Startup:
            LDS   #RAMEnd+1       ; initialize the stack pointer

            CLI                     ; enable interrupts


;-------------------------------------------------- 
;  Configure SPI 
;-------------------------------------------------- 
            MOVB  #$10,MODRR 
            MOVB  #$38,DDRM 
            MOVB  #$52,SPI0CR1 
            MOVB  #$10,SPI0CR2 
            MOVB  #$00,SPI0BR 
;-------------------------------------------------- 
;  Initialize LCD 
;-------------------------------------------------- 

            LDAA  #%00110011 
            JSR   SENDINST 
            LDAA  #%00110010 
            JSR   SENDINST 
            LDAA  #%00101000 
            JSR   SENDINST 
            LDAA  #%00001000 
            JSR   SENDINST 
            LDAA  #%00000001 
            JSR   SENDINST 
            LDAA  #%00000110 
            JSR   SENDINST 
            LDAA  #%00001110 
            JSR   SENDINST 
 
            ; Display COE in middle of first line 
            LDAA  #%10000010     ; Move cursor to position 3 
            JSR   SENDINST 
 
            LDAA  #'C' 
            JSR   SENDDATA 
            LDAA  #'O' 
            JSR   SENDDATA 
            LDAA  #'E' 
            JSR   SENDDATA 
 
;-------------------------------------------------- 
; Start a new scrolling frame on second line 
;-------------------------------------------------- 
FRAME       LDAA  #%11000000     ; Cursor to beginning of line 2 
            JSR   SENDINST 
 
 
            MOVB  Shift,Counter  ; Begin at current scrolling offset 
            CLR   Printed        ; Reset displayed character count 
 
;-------------------------------------------------- 
; Display 8 consecutive characters 
;-------------------------------------------------- 
NEXTCHAR    LDX   #Word          ; Point X to the message table 
            LDAB  Counter 
            ABX                  ; X = address of current character 
            LDAA  0,X            ; Load character 
            JSR   SENDDATA       ; Display it 
 
            INC   Counter        ; Move to next character 
            LDAB  Counter 
            CMPB  Size           ; Check if end of message reached 
            BNE   NO_WRAP 
            CLR   Counter        ; Restart from first character 
 
NO_WRAP     INC   Printed        ; Count displayed characters 
            LDAB  Printed 
            CMPB  MaxSize 
            BNE   NEXTCHAR       ; Continue until 8 characters 
 
            JSR   FRAMEWAIT      ; Pause before scrolling 
 
            INC   Shift          ; Move scrolling offset by one 
            LDAB  Shift 
            CMPB  Size 
            BNE   FRAME 
 
            CLR   Shift          ; Restart full message 
            BRA   OUT 
;-------------------------------------------------- 
; Delay between scrolling frames 
;-------------------------------------------------- 
FRAMEWAIT   LDY   #1            
SCROLL_DLY  JSR   DELAY 
            DEY 
            BNE   SCROLL_DLY 
            RTS
         
SENDSPI     STAA  SPI0DR 
 
            BRCLR SPI0SR,#$20,*  ; Wait for SPI transfer 
            MOVB  SPI0DR,DATA 
            MOVB  SPI0SR,DATA 
            RTS
            
SENDINST    TAB                  ; Save instruction 
 
            ; Upper nibble 
            RORA 
            RORA 
            RORA 
            RORA 
            ORAA  #%10000000     ; EN = 1, RS = 0 
            ANDA  #%10001111 
            JSR   SENDSPI 
            ANDA  #%00001111     ; EN = 0 
            JSR   SENDSPI 
            JSR   DELAY 
 
            ; Lower nibble 
            TBA 
            ORAA  #%10000000 
            ANDA  #%10001111 
            JSR   SENDSPI 
            ANDA  #%00001111 
            JSR   SENDSPI 
            JSR   DELAY 
            RTS 
 
 
;-------------------------------------------------- 
; SENDDATA: Display character 
;-------------------------------------------------- 
SENDDATA    TAB                  ; Save character 
 
            ; Upper nibble 
            RORA 
            RORA 
            RORA 
            RORA 
            ORAA  #%11000000     ; EN = 1, RS = 1 
            ANDA  #%11001111 
            JSR   SENDSPI 
            ANDA  #%01001111     ; EN = 0 
            JSR   SENDSPI 
            JSR   DELAY 
 
            ; Lower nibble 
            TBA 
            ORAA  #%11000000 
            ANDA  #%11001111 
            JSR   SENDSPI 
            ANDA  #%01001111 
            JSR   SENDSPI 
            JSR   DELAY 
            RTS            
            
            
            
           
DELAY       LDX   #4210 
AGAIN       PSHB 
            PULB 
            PSHB 
            PULB 
            PSHB 
            PULB 
            DEX 
            BNE   AGAIN 
            RTS 

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector
