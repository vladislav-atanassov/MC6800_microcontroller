; Define UART registers
RBTHR .equ $2000            ; UART Transmit Holding Register
IER   .equ $2001            ; Interrupt Enable Register
IIR   .equ $2002            ; Interrupt Identification Register
LCR   .equ $2003            ; Line Control Register
MCR   .equ $2004            ; MODEM Control Register  
LSRg  .equ $2005            ; Line Status Register

; Define UART Interrupt flags
UARTCODETHRE  .equ $02      ; Code for UART Transmiter Holding register Empty
UARTCODERDA   .equ $04      ; Code for Recieved Data Available
UARTCODEERR   .equ $06      ; Code for UART error in IIR

; TODO: Are BUFFERCCOFF and BUFFERCURRPOFF really needed both
;?      - they make it easier for the programmer tho are representing the same just negatively inverted as a value
; Define variables, flags, constants needed for the program
BUFFERSIZEMAX .equ $0f      ; Define buffer max size   
BUFFERCCOFF   .equ $0d      ; Define offset from SP for buffercurrcap
BUFFERFULLOFF .equ $0c      ; Define offset from SP for bufferfull
BUFFERSTARTADR .equ $00     ; Define the staring address of the buffer to store the received data
BUFFERCURRPOFF .equ $0b     ; Define offset from SP for a variable that keeps track of where the last data is stored in buffer    

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
SPTOPADR       .equ $ff     ; Define the SP address
SPBOTADR       .equ $f0     ; Define the Bottom address of the stack 

RXDONEOFF      .equ $0a     ; Define offset for flag indicating if recieve has ended (0-F, 1-T)
TXDONEOFF      .equ $09     ; Define offset for flag indicating if transmit has ended (0-F, 1-T)

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
CALCADRACC	   .equ $ff
CALCADRIDXR    .equ $fe

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
    lds #SPTOPADR

; Push all of the vars/flag into the stack before the start of the program
pushvarsstack ldaa #$00     ; Allocate memory for CALCADRACC, CALCADRIDXR
	psha                    
	psha
	ldaa #BUFFERSIZEMAX     ; BUFFERCC = BUFFERSIZEMAX
    psha                    ; Push the default value for variable for the buffer current capacity in the stack (max size)
    ldaa #$00               ; BUFFERFULL = 0
    psha                    ; Push the default value for flag for indicating if buffer is full (F)
    ldaa #BUFFERSTARTADR    ; SRAMCURR = BUFFERSTARTADR
    psha                    ; Push the default value for variable for the current position of the buffer (begining of SRAM)
    ldaa #$00               ; RXDONE = 0
    psha                    ; Push the default value for flag for indicating if recieving is done (F)
    ldaa #$00               ; TXDONE = 0
    psha                    ; Push the default value for flag for indicating if transmiting is done (F)

;! Used for testing the program's logic
testinput ldaa #UARTCODERDA
    staa IIR
    ldaa #$aa
    staa RBTHR

; Main loop
mainloop jsr rxLoop         ; Start the RX loop
    jsr valirferrrx         ; Check for RX communication error
    
;   TODO: Create test data for the transmit and test
    jsr txLoop              ; Start the TX loop
    jsr valirferrrx         ; Check for TX communication error

    bra mainloop            ; Continue waiting for next data 

; Recieve loop 
rxLoop jsr waitrda          ; Wait for data to be recieved
    jsr hdlirfrda           ; Handle Recieved Data Available

    jsr valirferrrx         ; Check for communication error

    ldx #SPBOTADR
    ldaa RXDONEOFF,x       
    cmpa #01                ; Check if recieving is done
    beq rtrxloop            ; If done return from subroutine
	
;!  More test data
	ldaa #UARTCODERDA
    staa IIR
    ldaa #$bb
    staa RBTHR	

    bra rxLoop              ; If not done continue with the loop

rtrxloop rts                ; Return from subroutine rxLoop

; Wait until the interrupt flag RDA is raised
waitrda ldaa IIR            ; Read Interrupt Identification Register
    cmpa #UARTCODERDA       ; Check for recieved data
    bne waitrda             ; If nothing recieved continue waiting
    
    rts                     ; When data recieved continue with mainloop

; Handle Received Data Available   
hdlirfrda ldaa RBTHR        ; Read received character
    cmpa #$00               ; Check for NULL terminator 
    beq markrxdone          ; If NULL terminator mark RX as done

;   Store the data at the next position in the SRAM
	ldx #SPBOTADR           ; Load the base address (stack bottom) into X
	ldab BUFFERCURRPOFF,x   ; Load the offset into accumulator B
	stab CALCADRACC         ; Store the offset  
	ldx CALCADRIDXR         ; Load the offset into the index register
	staa BUFFERSTARTADR,x   ; Store the recieved data in the current position of the buffer

    ldx #SPBOTADR
    inc BUFFERCURRPOFF,x    ; Move to the next position in SRAM

    dec BUFFERCCOFF,x       ; Decrement the buffer current capacity 

; Check if buffer is full
	ldx #SPBOTADR 
    ldaa BUFFERCCOFF,x      
    cmpa #$00 
    beq hdlbufferfull   

    bra rthdlirfrda

markrxdone ldaa #$01            
    ldx #SPBOTADR
    staa RXDONEOFF,x        ; Setting the flag for recieve done to true

;! Here to indicate future idea for diodes indication for exit states of the program
;  ldaa #$04                ; Set /OUT1 low and /OUT2 high to indicate end of RX
;  staa MCR                 ; Store in MCR

;   TODO: Create a routine that cleans up the values of variables (set to default values)  
;   Set the value of the current position of the buffer in the SRAM to default (the start address - $0000)
    ldaa #BUFFERSTARTADR
    ldx #SPBOTADR         
    staa BUFFERCURRPOFF,x

    clra                    ; Clear ACCA

rthdlirfrda rts             ; Return from subroutine    

; TODO: Implement the hdlbufferfull subroutine
; Handle buffer full
hdlbufferfull nop
;! Here to indicate future idea for diodes indication for exit states of the program
; ldaa #$01                 ; Set /DTR low to indicate that the buffer is full 
; staa MCR

    bra hdlbufferfull

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

;   Check if transmitting is done
    ldx #SPBOTADR
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
hdlirfthre ldx #SPBOTADR    ; Load the base address (stack bottom) into X
	ldab BUFFERCURRPOFF,x   ; Load the offset into accumulator B
	stab CALCADRACC         ; Store the offset  
	ldx CALCADRIDXR         ; Load the offset into the index register
	
    ldaa BUFFERSTARTADR,x   ; Load the current data in the buffer into ACCA
    cmpa #$00               ; Check for NULL terminator
    beq marktxdone          ; If NULL terminator mark TX as done

    staa RBTHR              ; Store the data into the Transmit Holding Register

    ldx #SPBOTADR
    inc BUFFERCURRPOFF,x    ; Move to the next position in SRAM

    inc BUFFERCCOFF,x       ; Increment the buffer current capacity 

;   Check is the whole buffer is read
    ldaa BUFFERCCOFF,x
    cmpa BUFFERSIZEMAX    
    beq marktxdone          ; If the buffer is read mark TX as done

    bra rthdlirfthre        ; Return from subroutine

marktxdone ldx #SPBOTADR
    ldaa #01                
    staa TXDONEOFF,x            ; Set the transmit done flag

;! Here to indicate future idea for diodes indication for exit states of the program
;  ldaa #$0C               ; Set /OUT1 high and /OUT2 high to indicate end of TX 
;  staa MCR

    clra                    ; Clear the ACCA

rthdlirfthre rts                     ; Return from subroutine

; Error validation for IRF for communication error
valirferrtx ldaa IIR                ; Read Interrupt Identification Register
    cmpa #UARTCODEERR     ; Check for UART error
    bne rtvalerrtx      ; If no error return 

    jsr hdlirferrtx     ;  Handle TX communication error 

rtvalerrtx rts

; TODO  better logic for handling TX error
;? TODO  couter to reset the chip (with MR for ex.) 
;?       if the validation fails too many times
;  Handle TX communication error 
hdlirferrtx ldaa LSRg               ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts