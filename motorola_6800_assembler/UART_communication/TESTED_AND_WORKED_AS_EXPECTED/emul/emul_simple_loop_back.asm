; Define UART registers
RBTHR           .equ $2000  ; UART Transmit Holding Register
IER             .equ $2001  ; Interrupt Enable Register
IIR             .equ $2002  ; Interrupt Identification Register
LCR             .equ $2003  ; Line Control Register
MCR             .equ $2004  ; MODEM Control Register  
LSRg            .equ $2005  ; Line Status Register

*; Define UART Line Status flags
UARTFLAGRDA    equ $01      *; Received Data Available (RDA) flag (bit 0 of LSR)
UARTFLAGTHRE   equ $20      *; Transmitter Holding Register Empty (THRE) flag (bit 5 of LSR)

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
    ldaa #UARTFLAGRDA
    staa LSRg               ; Simulate the flag Recieved Data Available is up
    ldaa #$41               ; Simulate data input (keyboard input: A (hex code in ascii 41)) 
    staa RBTHR              ; Load data into the Read Buffer/Tranmit Holding Register

; Poll until the interrupt flag RDA is raised
pollrda ldaa LSRg           ; Read Line Status Register
    anda #UARTFLAGRDA       ; Mask RDA flag (bit 0)
    beq pollrda             ; If RDA is not set, continue polling
    
    ldaa RBTHR              ; Load the recieved data into ACCA
    psha                    ; Push the data into the stack

;!  Used for testing the program's logic
    ldaa #$00   
    staa RBTHR

;!  Used for testing the program's logic
    ldaa #UARTFLAGTHRE
    staa LSRg               ; Simulate the flag THRE is up

; Poll until the interrupt flag THRE is raised
pollthre ldaa LSRg          ; Read Interrupt Identification Register
    anda #UARTFLAGTHRE      ; Check if data is ready to be accepted for transmit (flag THRE is up)
    beq pollthre            ; Poll until empty

    pula                    ; When THRE is up store the recieved data into ACCA
    staa RBTHR              ; Store tha data into THR

    .end

;!
;* TESTED AND WORKED AS EXPECTED