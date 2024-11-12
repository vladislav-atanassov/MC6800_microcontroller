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

    .org $E200              ; EPROM selected

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
loop jsr handleUartIrt      ; Check for UART interrupts
    ldaa #$04               ;! Adding value for debuging to activate the hadleUARTErr
    staa $IIR               ;! Storing the value into the IIR
    bra loop                ; Repeat the loop

; Transmit Character
transmitChar ldaa SRAMAddr  ; Load character from SRAM into accumulator

waitTxEmpty ldaa IIR        ; Read Interrupt Identification Register
    cmpa #$02               ; Check if TX holding register is empty
    beq waitTxEmpty         ; Wait until empty ; TODO Correct to bne in order to be a loop

    staa RBTHR              ; Send character
    rts                     ; Return from subroutine

; Transmit String
transmitString ldx #SRAMAddr    ; Load address of the string buffer
    ldab #bufferSize            ; Load the buffer size into ACCB

transmitLoop ldaa ,x        ; Load character from buffer in ACCA
    beq doneTransmit        ; If null terminator, we're done
    jsr transmitChar        ; Transmit the character

    inx                     ; Move to the next character
    decb                    ; Decrement the buffer size counter (ACCB)
    bne transmitLoop        ; Repeat until done

doneTransmit rts

; Handle Received Data
handleDataRb ldaa RBTHR     ; Read received character
    staa SRAMAddr           ; Store in SRAM at $0000
    inc SRAMAddr            ; Move to the next position in SRAM
    
    cmpa #$0A               ; Check if the character is a newline (ASCII 10)
    beq transmitString      ; If newline, transmit the string
    
    cmpa #$0D               ; Check if the character is a carriage return (ASCII 13)
    beq transmitString      ; If carriage return, transmit the string
    
    ldx #SRAMAddr           ; Load the address of the buffer
    ldaa SRAMAddr           ; Load the current buffer position
    
    cmpa #bufferSize        ; Check if buffer is full
    bne handleDataRb        ; If not full, continue receiving
    rts                     ; Return from subroutine

; Handle UART Interrupts
handleUartIrt ldaa IIR      ; Read Interrupt Identification Register
    cmpa #$04               ; Check for Received Data Available
    beq handleUartErr       ; If not, check for errors

    jsr handleDataRb        ; Handle received data
    rts                     ; Return from subroutine

; Handle UART Errors
handleUartErr ldaa LSRg     ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts                     ; Return from subroutine

    .end