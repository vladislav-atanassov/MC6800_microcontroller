; Define UART registers
IER   .equ $2001    ; Interrupt Enable Register
LCR   .equ $2003    ; Line Control Register
MCR   .equ $2004    ; MODEM Control Register  

    .org $0C00      ; Address to store the program in the EPROM
    
    staa IER        ; Write to Interrupt Enable Register

    ldaa #$83       ; Set line control register (8 bits, no parity, 1 stop bit)
    staa LCR        ; Write to Line Control Register

    ldaa #$0D       ; Set divisor latch for 9600 baud rate
    staa $2000      ; Set low byte of baud rate
    ldaa #$00
    staa $2001      ; Set high byte of baud rate

    ldaa #$03       ; Clear DLAB
    staa LCR        ; Write to Line Control Register

; Testing if the previous code did not "break" something 
; and the last test still works as expected 
    ldaa #$04       ; Setting /OUT1 to low and /OUT2 to high 
    staa MCR

loop nop            ; "while(true)" loop to prevent reading other memory after the instructions
    bra loop   

    .end
