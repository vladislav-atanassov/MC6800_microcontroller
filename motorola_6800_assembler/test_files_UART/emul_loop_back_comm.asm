; Define UART registers
RBTHR           .equ $2000  ; UART Transmit Holding Register
IER             .equ $2001  ; Interrupt Enable Register
IIR             .equ $2002  ; Interrupt Identification Register
LCR             .equ $2003  ; Line Control Register
MCR             .equ $2004  ; MODEM Control Register  
LSRg            .equ $2005  ; Line Status Register

; Define UART Interrupt flags
UARTCODETHRE    .equ $02    ; Code for UART Transmiter Holding register Empty
UARTCODERDA     .equ $04    ; Code for Recieved Data Available
UARTCODEERR     .equ $06    ; Code for UART error in IIR

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
; Define variables, flags, constants needed for the program
BUFFERSTARTADR  .equ $00    ; Define the staring address of the buffer to store the received data
BUFFERSIZEMAX   .equ $0f    ; Define buffer max size   
CONSTSSTARTADR  .equ $12    ; Define the start of the constants memory space   
BUFFERCCOFF     .equ $00    ; Define offset from CONSTSSTARTADR for buffercurrcap
BUFFERFULLOFF   .equ $01    ; Define offset from CONSTSSTARTADR for bufferfull
BUFFERCPOFF     .equ $02    ; Define offset from CONSTSSTARTADR for a variable that keeps track of where the last data is stored in buffer    
RXDONEOFF       .equ $03    ; Define offset from CONSTSSTARTADR for flag indicating if recieve has ended (0-F, 1-T)
TXDONEOFF       .equ $04    ; Define offset from CONSTSSTARTADR for flag indicating if transmit has ended (0-F, 1-T)
BUFLASTBYTE     .equ $05    ; Defite offset from CONSTSSTARTADR for buffering the last transmitted/recieved byte

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
CALCADRIDXR     .equ $10
CALCADRACC	    .equ $11

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
SPADR           .equ $ff    ; Define the SP address

;! This is not the real address! That address is for testing in SDK6800 Emulator
    .org $0100              ; Start address of the program in the EPROM

; Initialize UART
inituart ldaa #$07          ; Enable RDA, THRE interrupt flags
    staa IER                ; Write to Interrupt Enable Register

    ldaa #$83               ; Set line control register (8 bits, no parity, 1 stop bit)
    staa LCR                ; Write to Line Control Register

    ldaa #$0D               ; Set divisor latch for 9600 baud rate
    staa $2000              ; Set low byte of baud rate
    ldaa #$00
    staa $2001              ; Set high byte of baud rate

    ldaa #$03               ; Clear DLAB
    staa LCR                ; Write to Line Control Register

; Initialize SP
    lds #SPADR

; Push all of the vars/flag into the stack before the start of the program
storevars ldx #CONSTSSTARTADR    
    ldaa #BUFFERSIZEMAX     ; BUFFERCC = BUFFERSIZEMAX
    staa BUFFERCCOFF,x      ; Store the default value for variable for the buffer current capacity (max size)
    
    ldaa #$00               ; BUFFERFULL = 0
    staa BUFFERFULLOFF,x    ; Store the default value for flag for indicating if buffer is full (F)
    
    ldaa #$00               ; BUFFERCP = 0
    staa BUFFERCPOFF,x      ; Store the default value for variable for the current position of the buffer (0)
    
    ldaa #$00               ; RXDONE = 0
    staa RXDONEOFF,x        ; Store the default value for flag for indicating if recieving is done (F)
    
    ldaa #$00               ; TXDONE = 0
    staa TXDONEOFF,x        ; Store the default value for flag for indicating if transmiting is done (F)
    
    ldaa #$00               ; BUFLASTBYTE = 0
    staa BUFLASTBYTE,x      ; Store the default value for the last byte transmitted/recieved (00)


;! Used for testing the program's logic
testinput ldaa #UARTCODERDA
    staa IIR
    ldaa #$aa
    staa RBTHR

; Main loop
mainloop jsr rxloop         ; Start the RX loop
    
;!  Used for testing the program's logic
    ldaa #UARTCODETHRE
    staa IIR

    jsr txloop              ; Start the TX loop

    bra mainloop            ; Continue waiting for next data 

; Buffers the last transmitted/recieved byte 
bufferlastbyte ldx #CONSTSSTARTADR
    staa BUFLASTBYTE,x      ; Store the last byte into the constants buffer at index BUFLASTBYTE

    rts

; Recieve loop 
rxloop jsr waitrda          ; Wait for data to be recieved
    jsr hdlirfrda           ; Handle Recieved Data Available

    jsr valirferrrx         ; Check for communication error

    ldx #CONSTSSTARTADR
    ldaa RXDONEOFF,x       
    cmpa #01                ; Check if recieving is done
    beq rtrxloop            ; If done return from subroutine
	
;!  More test data
	ldaa #UARTCODERDA
    staa IIR
    ldaa #$bb
    staa RBTHR	

    bra rxloop              ; If not done continue with the loop

rtrxloop rts                ; Return from subroutine rxloop

; Wait until the interrupt flag RDA is raised
waitrda ldaa IIR            ; Read Interrupt Identification Register
    cmpa #UARTCODERDA       ; Check for recieved data
    bne waitrda             ; If nothing recieved continue waiting
    
    rts                     ; When data recieved continue with mainloop

; Handle Received Data Available   
hdlirfrda ldaa RBTHR        ; Read received character
    jsr bufferlastbyte      ; Buffer the last recieved byte

    cmpa #$00               ; Check for NULL terminator 
    beq markrxdone          ; If NULL terminator mark RX as done

;   Store the data at the next position in the SRAM
	ldx #CONSTSSTARTADR     ; Load the base address (stack bottom) into X
	ldab BUFFERCPOFF,x      ; Load the offset into accumulator B
	stab CALCADRACC         ; Store the offset  
	ldx CALCADRIDXR         ; Load the offset into the index register
	staa BUFFERSTARTADR,x   ; Store the recieved data in the current position of the buffer

	ldx #CONSTSSTARTADR     ; Load the start of the constants memory space into the X register 
    inc BUFFERCPOFF,x       ; Move to the next position in SRAM

    dec BUFFERCCOFF,x       ; Decrement the buffer current capacity 

;   Check if buffer is full
    ldaa BUFFERCCOFF,x      
    cmpa #$00 
    beq hdlbufferfull   

    bra rthdlirfrda

markrxdone ldx #CONSTSSTARTADR
    ldaa #$01            
    staa RXDONEOFF,x        ; Setting the flag for recieve done to true

;! Here to indicate future idea for diodes indication for exit states of the program
;  ldaa #$04                ; Set /OUT1 low and /OUT2 high to indicate end of RX
;  staa MCR                 ; Store in MCR

;   TODO: Create a routine that cleans up the values of variables (set to default values)  
;   Set the value of the current position of the buffer in the SRAM to default (the start address - $0000)
    ldx #CONSTSSTARTADR         
    ldaa #BUFFERSTARTADR
    staa BUFFERCPOFF,x   

    clra                    ; Clear ACCA

rthdlirfrda rts             ; Return from subroutine    

; TODO: Implement the hdlbufferfull subroutine
; Handle buffer full
;! Just for testing 
hdlbufferfull bra markrxdone
;! Here to indicate future idea for diodes indication for exit states of the program
; ldaa #$01                 ; Set /DTR low to indicate that the buffer is full 
; staa MCR

;    bra hdlbufferfull

; Error validation for IRF for communication error
valirferrrx ldaa IIR        ; Read Interrupt Identification Register
    cmpa #UARTCODEERR       ; Check for UART error
    bne rtvalerrrx          ; If no error return 

    jsr hdlirferrrx         ; Handle RX communication error 

rtvalerrrx rts

; TODO  better logic for handling RX error
;? TODO  couter to reset the chip (with MR for ex.) 
;?       if the validation fails too many times
; Handle RX communication error 
hdlirferrrx ldaa LSRg       ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts

; Transmit loop
txloop jsr waitthre         ; Wait until the transmitter holding register is empty
    jsr hdlirfthre          ; Handle Transmitter Holding Register Empty

    jsr valirferrtx         ; Check for communication error

;   Check if transmitting is done
    ldx #CONSTSSTARTADR
    ldaa TXDONEOFF,x
    cmpa #01                    
    beq rttxloop            ; If done return from subroutine

    bra txloop              ; If not done continue with the loop

rttxloop rts                ; Return from subroutine txloop

; Wait until the interrupt flag THRE is raised
waitthre ldaa IIR           ; Read Interrupt Identification Register
    cmpa #UARTCODETHRE      ; Check if TX holding register is empty
    bne waitthre            ; Wait until empty

    rts                     ; Return from subroutine

; Handle Transmitter Holding Register Empty
hdlirfthre ldx #CONSTSSTARTADR    ; Load the base address (stack bottom) into X
	ldab BUFFERCPOFF,x      ; Load the offset into accumulator B
	stab CALCADRACC         ; Store the offset  
	ldx CALCADRIDXR         ; Load the offset into the index register
	
    ldaa BUFFERSTARTADR,x   ; Load the current data in the buffer into ACCA
    jsr bufferlastbyte      ; Buffer the last transmitted byte

    cmpa #$00               ; Check for NULL terminator
    beq marktxdone          ; If NULL terminator mark TX as done

    staa RBTHR              ; Store the data into the Transmit Holding Register

    ldx #CONSTSSTARTADR
    inc BUFFERCPOFF,x       ; Move to the next position in SRAM

    inc BUFFERCCOFF,x       ; Increment the buffer current capacity 

;   Check is the whole buffer is read
    ldaa BUFFERCCOFF,x
    cmpa BUFFERSIZEMAX    
    beq marktxdone          ; If the buffer is read mark TX as done

    bra rthdlirfthre        ; Return from subroutine

marktxdone ldx #CONSTSSTARTADR
    ldaa #01                
    staa TXDONEOFF,x        ; Set the transmit done flag

;! Here to indicate future idea for diodes indication for exit states of the program
;  ldaa #$0C                ; Set /OUT1 high and /OUT2 high to indicate end of TX 
;  staa MCR

    clra                    ; Clear the ACCA

rthdlirfthre rts            ; Return from subroutine

; Error validation for IRF for communication error
valirferrtx ldaa IIR        ; Read Interrupt Identification Register
    cmpa #UARTCODEERR       ; Check for UART error
    bne rtvalerrtx          ; If no error return 

    jsr hdlirferrtx         ; Handle TX communication error 

rtvalerrtx rts

; TODO  better logic for handling TX error
;? TODO  couter to reset the chip (with MR for ex.) 
;?       if the validation fails too many times
;  Handle TX communication error 
hdlirferrtx ldaa LSRg       ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts