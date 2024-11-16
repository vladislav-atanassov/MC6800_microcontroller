*; Define UART registers
RBTHR equ $2000            *; UART Transmit Holding Register
IER   equ $2001            *; Interrupt Enable Register
IIR   equ $2002            *; Interrupt Identification Register
LCR   equ $2003            *; Line Control Register
MCR   equ $2004            *; MODEM Control Register  
LSRg  equ $2005            *; Line Status Register

*; Define UART errors
UART_CODE_THRE  equ $02    *; Code for UART Transmiter Holding register Empty
UART_CODE_RDA   equ $04    *; Code for Recieved Data Available
UART_CODE_ERR   equ $06    *; Code for UART error in IIR

bufferSize  equ $ff        *; Define buffer size    
SRAMAddr    equ $0000      *; Define SRAM address for storing received data

    org $1C00

    ldx #$1fff              *; Initiliazing the SP at the top of the SRAM
    txs            
    
    ldab #bufferSize        *; Storing the buffer size at ACCB

*; Main loop
MAIN_Loop:

RX_Loop:
    ldaa MCR                *; Reading the MODEM Control Register 
    cmpa #$04               *; Checking if that the recieving has ended
    beq TX_Loop             *; Exit the recieving loop and go to the transmiting loop

    jsr waitRDA             *; Wait for data to be recieved
    jsr HDL_IRF_RDA         *; Handle Recieved Data Available

    jsr VAL_IRF_ERR_RX      *; Checking for communication error
    bra RX_Loop

*; TODO: Implement logic for TX_Loop
TX_Loop:
    nop

    bra MAIN_Loop            *; Continue waiting for next data 

*; Signaling that the buffer is filled
HDL_BufferFull:   
    ldaa #$01              *; Setting /DTR to low to indicate that the buffer is full 
    staa MCR
    bra HDL_BufferFull

*; Wait until interrupt flag for RDA rises
waitRDA:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_RDA     *; Check for recieved data
    bne waitRDA             *; If nothing recieved continue waiting
    
    rts                     *; When data recieved continue with MAIN_Loop

*; Handle Received Data Available   
HDL_IRF_RDA:
    ldx RBTHR               *; Read received character
    stx SRAMAddr            *; Store the recieved data in SRAM
    inc SRAMAddr            *; Move to the next position in SRAM
    decb                    *; Decrement the buffer size counter (ACCB)

    cmpb #$00               *; Check if buffer is full
    beq HDL_BufferFull      *;* Branch without push stack operation because this is a critical state 
    
    ldaa ,x                 *; Load the x register into ACCA to compare
    cmpa #$00               *; Check for NULL terminator 
    bne RTS_HDL_IRF_RDA     

    ldaa #$04               *; Set /OUT1 to low and /OUT2 to high to indicate end of RX
    staa MCR                *; Store in MCR
    bra RTS_HDL_IRF_RDA     

RTS_HDL_IRF_RDA:
    rts                     *; Return from subroutine    

*; Waits until the interrupt flag THRE is raised
waitTHRE:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_THRE    *; Check if TX holding register is empty
    bne waitTHRE            *; Wait until empty

    rts                     *; Return from subroutine

*; Handle Transmiter Holding Register Empty
HDL_IRF_THRE:


*; Error validation for IRF for communication error
VAL_IRF_ERR_RX:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     *; Check for UART error
    bne RTS_ERR_VAL         *; If no error return 

*; TODO: Implement correct logic for handling RX error
*;? TODO: Add couter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*; Handle RX communication error 
    ldaa LSRg               *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    bra RTS_ERR_VAL

RTS_ERR_VAL:
    rts