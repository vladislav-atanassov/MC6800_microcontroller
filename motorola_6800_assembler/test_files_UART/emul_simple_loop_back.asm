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

;!  Used for testing the program's logic
    ldaa #UARTCODERDA
    staa IIR                ; Simulate the flag Recieved Data Available is up
    ldaa #$41               ; Simulate data input (keyboard input: A (hex code in ascii 41)) 
    staa RBTHR              ; Load data into the Read Buffer/Tranmit Holding Register

; Wait until the interrupt flag RDA is raised
waitrda ldaa IIR            ; Read Interrupt Identification Register
    cmpa #UARTCODERDA       ; Check for recieved data (flag RDA is up)
    bne waitrda             ; If nothing recieved continue waiting
    
    ldaa RBTHR              ; Load the recieved data into ACCA
    psha                    ; Push the data into the stack

;!  Used for testing the program's logic
    ldaa #$00   
    staa RBTHR

;!  Used for testing the program's logic
    ldaa #UARTCODETHRE
    staa IIR                ; Simulate the flag THRE is up

; Wait until the interrupt flag THRE is raised
waitthre ldaa IIR           ; Read Interrupt Identification Register
    cmpa #UARTCODETHRE      ; Check if data is ready to be accepted for transmit (flag THRE is up)
    bne waitthre            ; Wait until empty

    pula                    ; When THRE is up store the recieved data into ACCA
    staa RBTHR              ; Store tha data into THR

    .end