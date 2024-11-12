; Define UART registers
RBTHR .equ $2000    ; UART Transmit Holding Register
IER   .equ $2001    ; Interrupt Enable Register
IIR   .equ $2002    ; Interrupt Identification Register
LCR   .equ $2003    ; Line Control Register
MCR   .equ $2004    ; MODEM Control Register  
LSRg  .equ $2005    ; Line Status Register

; Define SRAM address for storing received data
bufferSize  .equ 20
SRAMAddr    .equ $0000         ; Start of SRAM for received data

    .org $E200

    ldx #$1fff              ; Initiliazing the SP at the top of the SRAM
    txs

; UART Initialization
initUART ldaa #$07          ; Enable RDA, THRE interrupt flags
    staa IER                ; Write to Interrupt Enable Register

    ldaa #$83               ; Set line control register (8 bits, no parity, 1 stop bit)
    staa LCR                ; Write to Line Control Register

    ldaa #$0D               ; Set divisor latch for 9600 baud rate
    staa $2000              ; Set low byte of baud rate
    ldaa #$00
    staa $2001              ; Set high byte of baud rate

    ldaa #$03               ; Clear DLAB
    staa LCR                ; Write to Line Control Register

; Main loop
loop ldaa IIR               ; Read Interrupt Identification Register
    cmpa #$04               ; Check for Received Data Available
    psha                    ;? Push to stack
    beq handleUartErr       ; If not, check for errors

    jsr handleDataRb        ; Handle received data

    bra loop                ; Repeat the loop

; TODO: Check how the Errors are handled
;? Handle UART Errors
handleUartErr ldaa LSRg     ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts                     ; Return from subroutine

