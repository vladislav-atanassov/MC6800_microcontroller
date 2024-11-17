*; Define UART registers
RBTHR equ $2000            *; UART Transmit Holding Register
IER   equ $2001            *; Interrupt Enable Register
IIR   equ $2002            *; Interrupt Identification Register
LCR   equ $2003            *; Line Control Register
MCR   equ $2004            *; MODEM Control Register  
LSRg  equ $2005            *; Line Status Register

*; Define UART Interrupt flags
UART_CODE_THRE  equ $02    *; Code for UART Transmiter Holding register Empty
UART_CODE_RDA   equ $04    *; Code for Recieved Data Available
UART_CODE_ERR   equ $06    *; Code for UART error in IIR

BUFFER_SIZE_MAX equ $ff     *; Define buffer size   
BUFFER_CURR_CAP equ $ff     *; Define current buffer capacity variable 
SRAM_ADDR       equ $0000   *; Define SRAM address for storing received data

    org $1C00

    ldx #$1fff              *; Initiliazing the SP at the top of the SRAM
    txs            
    
    ldab #BUFFER_SIZE_MAX   *; Storing the buffer size at ACCB

*; Main loop
_main_loop:

; TODO: Get the validation for RX out
_rx_Loop:
    ldaa MCR                *; Reading the MODEM Control Register 
    cmpa #$04               *; Checking if that the recieving has ended
    beq _tx_Loop            *; Exit the recieving loop and go to the transmiting loop

    jsr _wait_rda           *; Wait for data to be recieved
    jsr _hdl_irf_rda        *; Handle Recieved Data Available

    jsr _val_irf_err_rx      *; Checking for communication error
    bra _rx_Loop

*; TODO: Implement logic for _tx_Loop
_tx_Loop:
    nop

    bra _main_loop           *; Continue waiting for next data 

*; Signaling that the buffer is filled
_hdl_buffer_full:   
    ldaa #$01               *; Setting /DTR to low to indicate that the buffer is full 
    staa MCR
    bra _hdl_buffer_full

*; Wait until interrupt flag for RDA rises
_wait_rda:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_RDA     *; Check for recieved data
    bne _wait_rda           *; If nothing recieved continue waiting
    
    rts                     *; When data recieved continue with _main_loop

*; Handle Received Data Available   
_hdl_irf_rda:
    ldx RBTHR               *; Read received character
    stx SRAM_ADDR           *; Store the recieved data in SRAM
    inc SRAM_ADDR           *; Move to the next position in SRAM
    decb                    *; Decrement the buffer size counter (ACCB)

    cmpb #$00               *; Check if buffer is full
    beq _hdl_buffer_full    *;* Branch without push stack operation because this is a critical state 
    
    ldaa ,x                 *; Load the x register into ACCA to compare
    cmpa #$00               *; Check for NULL terminator 
    bne _rts_hdl_irf_rda     

    ldaa #$04               *; Set /OUT1 to low and /OUT2 to high to indicate end of RX
    staa MCR                *; Store in MCR
; TODO: Check if needed to branch to _rts_hdl_irf_rda or leave it as it is now
_rts_hdl_irf_rda:
    rts                     *; Return from subroutine    

*; Waits until the interrupt flag THRE is raised
_wait_thre:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_THRE    *; Check if TX holding register is empty
    bne _wait_thre          *; Wait until empty

    rts                     *; Return from subroutine

*; Handle Transmiter Holding Register Empty
_hdl_irf_thre:


*; Error validation for IRF for communication error
_val_irf_err_rx:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     *; Check for UART error
    bne _rts_val_err_rx     *; If no error return 

*; TODO: Implement correct logic for handling RX error
*;? TODO: Add couter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*; Handle RX communication error 
    ldaa LSRg               *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    bra _rts_val_err_rx

_rts_val_err_rx:
    rts