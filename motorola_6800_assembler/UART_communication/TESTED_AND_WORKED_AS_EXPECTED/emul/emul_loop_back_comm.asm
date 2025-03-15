; Define UART registers
RBTHR           .equ $2000  ; Receiver Buffer / Transmit Holding Register
IER             .equ $2001  ; Interrupt Enable Register
IIR             .equ $2002  ; Interrupt Identification Register
LCR             .equ $2003  ; Line Control Register
MCR             .equ $2004  ; MODEM Control Register  
LSRg            .equ $2005  ; Line Status Register

; Line Status Register Bits
LSRDR           .equ $01    ; Data Ready Bit
LSRTHRE         .equ $20    ; Transmitter Holding Register Empty Bit

; Define UART Interrupt flags
UARTCODEERR     .equ $06    ; Code for UART error in IIR

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
; Define variables, flags, constants needed for the program
BUFFERSTARTADR  .equ $0000  ; Define the staring address of the buffer to store the received data
BUFFERSIZEMAX   .equ $0f    ; Define buffer max size
CONSTSSTARTADR  .equ $12    ; Define the start of the constants memory space
; Define offset from CONSTSSTARTADR for the values:
BUFFERCCOFF     .equ $00    ; Buffer currect capacity
BUFFERFULLOFF   .equ $01    ; Buffer Full Flag
BUFFERCPOFF     .equ $02    ; Buffer currect position
RXDONEOFF       .equ $03    ; Flag indicating if recieve has ended (0-F, 1-T)
TXDONEOFF       .equ $04    ; Flag indicating if transmit has ended (0-F, 1-T)
BUFLASTBYTEOFF  .equ $05    ; Buffering the last transmitted/recieved byte

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
CALCADRIDXR     .equ $10
CALCADRACC	    .equ $11

;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
SPADR           .equ $ff    ; Define the SP address

;! This is not the real address! That address is for testing in SDK6800 Emulator
    .org $0100              ; Start address of the program in the EPROM

; Initialize UART
inituart ldaa #$07          ; Enable RDA, THRE, Reciever Line Status interrupt flags
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

; Main loop
mainloop ldaa #LSRDR       ; Simulating data recieved (flag RDA up)
    staa LSRg
    
    jsr initvars            

    jsr rxloop              ; Start the RX loop
    
;   Simulate data is to be tranmitted (flag THRE up)
    ldaa #LSRTHRE
    staa LSRg

    jsr txloop              ; Start the TX loop

    bra mainloop            ; Continue waiting for next data 

; Initialize all of the vars/flag with default values
initvars ldx #CONSTSSTARTADR    
    ldaa #BUFFERSIZEMAX     ; BUFFERCC = BUFFERSIZEMAX
    staa BUFFERCCOFF,x      ; Store the default value for variable for the buffer current capacity (max size)

    clr BUFFERCPOFF,x       ; Buffer Position = 0
    clr BUFFERFULLOFF,x     ; Buffer Full Flag = 0
    clr RXDONEOFF,x         ; Receive Done = 0
    clr TXDONEOFF,x         ; Transmit Done = 0
    clr BUFLASTBYTEOFF,x    ; Last Byte = 0
    clr CALCADRACC          ; Value in calculation address for accumulators = 0
    clr CALCADRIDXR         ; Value in calculation address for the X register = 0
    rts

; Simulate increasing input pattern (01, 02, 03, ...)
simulateinput ldaa #'1'
    ldx #CONSTSSTARTADR
    adda BUFFERCPOFF,x
    staa RBTHR
    rts

; Buffers the last transmitted/recieved byte 
buflastbyte ldx #CONSTSSTARTADR
    staa BUFLASTBYTEOFF,x   ; Store the last byte into the constants buffer at index BUFLASTBYTEOFF
    rts

; Storing the the current position of the buffer into the X register
bufcurrptox ldx #CONSTSSTARTADR ; Load the start of the constants memory space into the X register 
	ldab BUFFERCPOFF,x      ; Load the offset into accumulator B
	stab CALCADRACC         ; Store the offset  
	ldx CALCADRIDXR         ; Load the offet into the X register
    rts

; Recieve loop 
rxloop jsr pollrda          ; Wait for data to be recieved

;   Simulating input
    jsr simulateinput

    jsr hdlrda              ; Handle Recieved Data Available

    jsr valrxerror          ; Check for communication error

    ldx #CONSTSSTARTADR
    ldaa RXDONEOFF,x       
    cmpa #01                ; Check if recieving is done
    beq rtsrxloop           ; If done return from subroutine
	
    bra rxloop              ; If not done continue with the loop

rtsrxloop rts               ; Return from subroutine rxloop

; Poll for RDA
pollrda ldaa LSRg           ; Read Line Status Register
    anda #LSRDR            ; Check if RDA bit is set
    beq pollrda             ; Wait until RDA is set
    rts

; Handle Data Ready   
hdlrda ldaa RBTHR           ; Read received character
    jsr buflastbyte      ; Buffer the last recieved byte

;   Store the data at the next position in the SRAM
    jsr bufcurrptox
	staa BUFFERSTARTADR,x   ; Store the recieved data in the current position of the buffer

	ldx #CONSTSSTARTADR     ; Load the start of the constants memory space into the X register 
    inc BUFFERCPOFF,x       ; Move to the next position in SRAM

    dec BUFFERCCOFF,x       ; Decrement the buffer current capacity 

    ldaa BUFLASTBYTEOFF,x   ; Load the last transmitted byte into ACCA
    cmpa #'9'               ; Check for NULL terminator 
    beq markrxdone          ; If NULL terminator mark RX as done

;   Check if buffer is full
    ldaa BUFFERCCOFF,x      
    cmpa #$00 
    beq hdlbufferfull   

    bra rtshdlrda

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

rtshdlrda rts    

; TODO: Implement the hdlbufferfull subroutine
; Handle buffer full
;! Just for testing 
hdlbufferfull bra markrxdone
;! Here to indicate future idea for diodes indication for exit states of the program
; ldaa #$01                 ; Set /DTR low to indicate that the buffer is full 
; staa MCR

;    bra hdlbufferfull

; Error validation for IRF for communication error
valrxerror ldaa IIR         ; Read Interrupt Identification Register
    cmpa #UARTCODEERR       ; Check for UART error
    bne rtsvalrxerror       ; If no error return 

    jsr hdlrxerror          ; Handle RX communication error 

rtsvalrxerror rts

; TODO  better logic for handling RX error
;? TODO  couter to reset the chip (with MR for ex.) 
;?       if the validation fails too many times
; Handle RX communication error 
hdlrxerror ldaa LSRg        ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts

; Transmit loop
txloop jsr pollthre         ; Wait until the transmitter holding register is empty
    jsr hdlthre             ; Handle Transmitter Holding Register Empty

    jsr valtxerror          ; Check for communication error

;   Check if transmitting is done
    ldx #CONSTSSTARTADR
    ldaa TXDONEOFF,x
    cmpa #01                    
    beq rtstxloop           ; If done return from subroutine

    bra txloop              ; If not done continue with the loop

rtstxloop rts               ; Return from subroutine txloop

; Poll for THRE
pollthre ldaa LSRg          ; Read Line Status Register
    anda #LSRTHRE           ; Check if THRE bit is set
    beq pollthre            ; Wait until THRE is set
    rts

; Handle Transmitter Holding Register Empty
hdlthre jsr bufcurrptox
    ldaa BUFFERSTARTADR,x   ; Load the current data in the buffer into ACCA
    
    jsr buflastbyte      ; Buffer the last transmitted byte

    staa RBTHR              ; Store the data into the Transmit Holding Register

    ldx #CONSTSSTARTADR
    inc BUFFERCPOFF,x       ; Move to the next position in buffer

    ldaa BUFLASTBYTEOFF,x   *; Load the last transmitted byte into ACCA
    cmpa #'9'               ; Check for NULL terminator 
    beq marktxdone          ; If NULL terminator mark RX as done

;   Check is the whole buffer is read
    ldaa BUFFERCPOFF,x
    cmpa #BUFFERSIZEMAX    
    beq marktxdone          ; If the buffer is read mark TX as done
    rts

marktxdone ldx #CONSTSSTARTADR
    ldaa #01                
    staa TXDONEOFF,x        ; Set the transmit done flag

;! Here to indicate future idea for diodes indication for exit states of the program
;  ldaa #$0C                ; Set /OUT1 high and /OUT2 high to indicate end of TX 
;  staa MCR

    ldx #CONSTSSTARTADR
    clr BUFFERCPOFF,x       ; Buffer Position = 0   

clrbufferloop jsr bufcurrptox
	clr BUFFERSTARTADR,x    ; Clear data at the current position of the buffer

    ldx #CONSTSSTARTADR
    ldaa BUFFERCPOFF,x
    cmpa #BUFFERSIZEMAX     ; Check if the counter is at the end of the buffer
    beq rtshdlthre          ; Return to mainloop

    inc BUFFERCPOFF,x       ; Move to the next position of the buffer

    bra clrbufferloop

rtshdlthre rts

; Error validation for IRF for communication error
valtxerror ldaa IIR        ; Read Interrupt Identification Register
    cmpa #UARTCODEERR       ; Check for UART error
    bne rtsvaltxerror          ; If no error return 

    jsr hdltxerror         ; Handle TX communication error 

rtsvaltxerror rts

; TODO  better logic for handling TX error
;? TODO  couter to reset the chip (with MR for ex.) 
;?       if the validation fails too many times
;  Handle TX communication error 
hdltxerror ldaa LSRg       ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts

;!
;* TESTED AND WORKED AS EXPECTED