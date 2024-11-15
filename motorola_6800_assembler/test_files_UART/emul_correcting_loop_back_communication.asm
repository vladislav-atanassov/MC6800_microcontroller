; Define UART registers
RBTHR .equ $2000            ; UART Transmit Holding Register
IER   .equ $2001            ; Interrupt Enable Register
IIR   .equ $2002            ; Interrupt Identification Register
LCR   .equ $2003            ; Line Control Register
MCR   .equ $2004            ; MODEM Control Register  
LSRg  .equ $2005            ; Line Status Register

; Define UART errors
UART_CODE_THRE  .equ $02    ; Code for UART Transmiter Holding register Empty
UART_CODE_RDA   .equ $04    ; Code for Recieved Data Available
UART_CODE_ERR   .equ $06    ; Code for UART error in IIR

bufferSize  .equ 20         ; Define buffer size    
SRAMAddr    .equ $0000      ; Define SRAM address for storing received data

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

; TODO: Main problem to solve:
; TODO: Branch instructions not pushing into the stack 
; TODO: so how to use the condtional calling of subroutines correctly

; TODO: Mentions in the next Git Commit:
; TODO: Solution to the main problem
; TODO: Added wait for the HDL_RBA with waitRDA
; TODO: Renaming of labels

; Main loop
mainLoop ldaa IIR               ; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     ; Check for UART error
    ;? May be possible to use the stack and not to approach the problem with an extra label
    beq __HDL_UartErr       ; Handle UART error

    ; TODO: Think where HDL_UartErr should be called
    ;       - in HDL_RDA
    ;       - before HDL_RDA
    ;       - before and in HDL_RDA

    jsr waitRDA

    jsr HDL_RBA          ; Handle Recieved Data Available

    bra mainLoop                ; Repeat loop

; Wait until interrupt flag for RDA rises
waitRDA ldaa IIR            ; Read Interrupt Identification Register
    cmpa #UART_CODE_RDA     ; Check for recieved data
    bne waitRDA             ; Continue waiting
    
    rts                     ; When data recieved return 

; Handle UART Error 
;* Concluded that the Error is hadled good enough 
; TODO: Add couter to reset the chip (with MR for ex.) 
; TODO: if the validation fails too many times
HDL_UartErr ldaa LSRg       ; Read Line Status Register
    clra                    ; Clear accumulator (error handling can be improved)
    rts                     ; Return from subroutine

; Call the HDL_UartErr
;* Used to push the subrotine address to the stack correctly
__HDL_UartErr jsr HDL_UartErr    
    bra loop                     ; Return to the main loop

; Handle Received Data      
HDL_RBA ldaa RBTHR          ; Read received character
    staa SRAMAddr           ; Store in SRAM at $0000
    inc SRAMAddr            ; Move to the next position in SRAM
    
    cmpa #$0A               ; Check if the character is a newline (ASCII 10)
    ;! Same problem as for calling HDL_RDA
    beq TX_String           ; If newline, transmit the string
    
    cmpa #$0D               ; Check if the character is a carriage return (ASCII 13)
    ;! Here too
    beq TX_String           ; If carriage return, transmit the string
    
    ldx #SRAMAddr           ; Load the address of the buffer
    ldaa SRAMAddr           ; Load the current buffer position
    
    cmpa #bufferSize        ; Check if buffer is full
    ;! Here too
    bne HDL_RBA             ; If not full, continue receiving
    rts                     ; Return from subroutine

; Transmit Character
TX_Char ldaa SRAMAddr       ; Load character from SRAM into accumulator

; TODO: waitTxEmpty to be moved out as a subroutine
waitTxEmpty ldaa IIR        ; Read Interrupt Identification Register
    cmpa #UART_CODE_THRE    ; Check if TX holding register is empty
    bne waitTxEmpty         ; Wait until empty

    staa RBTHR              ; Send character
    rts                     ; Return from subroutine

; Transmit String
TX_String ldx #SRAMAddr    ; Load address of the string buffer
    ldab #bufferSize        ; Load the buffer size into ACCB

txLoop ldaa ,x              ; Load character from buffer in ACCA
    ;! Probably wrong
    ; TODO: Reconsider the usage of that approach 
    beq TX_Done             ; If null terminator, we're done
    jsr TX_Char             ; Transmit the character

    inx                     ; Move to the next character
    decb                    ; Decrement the buffer size counter (ACCB)
    bne txLoop              ; Repeat until done

TX_Done rts











mainLoop()
{
    if(a = 6)
    {
        handleUARTErr()
    }

    if(a = 4)
    {
        readDataAv()
    }


    mainLoop()
}








