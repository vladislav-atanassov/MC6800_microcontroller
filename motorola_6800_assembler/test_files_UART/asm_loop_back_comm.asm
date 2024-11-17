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

*; Define variables and flags needed for the program
BUFFER_SIZE_MAX equ $ff     *; Define buffer max size   
buffer_curr_cap equ $ff     *; Define current buffer capacity variable
BUFFER_C_C_ADDR equ $1fff   *; Define where buffer_curr_cap is stored in the SRAM
buffer_full     equ $00     *; Define a flag to indicate if the buffer is filled
BUFFER_F_ADDR   equ $1ffe   *; Define where buffer_full is stored in the SRAM

SRAM_ADDR       equ $0000   *; Define SRAM address for storing received data
SP_ADDR         equ $1fff   *; Define the SP address

rx_done         equ $00     *; Define flag for indicating if recieve has ended (0-F, 1-T)
tx_done         equ $00     *; Define flag for indicating if transmit has ended (0-F, 1-T)
RX_DONE_ADDR    equ $1ffd   *; Define where rx_done is stored in the SRAM
TX_DONE_ADDR    equ $1ffc   *; Define where rx_done is stored in the SRAM

    org $1C00               *; Start address of the program in the EPROM

_init_sp:
    ldx SP_ADDR             *; Store the SP address in register X
    txs                     *; Initialize the SP with the value in register X

*; Main loop
_main_loop:

    jsr _push_vars_stack    *; Push the vars/flags into the stack with default values

    jsr _rx_Loop

*; TODO: Implement logic for _tx_Loop
    jsr _tx_Loop

    bra _main_loop           *; Continue waiting for next data 

*; TODO: Decide on the question below and finish the subroutine
_push_vars_stack:
    ldaa #buffer_curr_cap   *; Storing the current buffer capacity in the stack
*;? TODO: staa ADDRESS or psha? 
*;? The concern here is that with staa ADDRESS
*;? there will be no future confusion about how the variables/flags are stored 
*;? and more can be added with the only condition they are directly after the last one alredy defined 
*;? but with this approach it is not so clear where the vars/flags are stored (currently in the stack)
    staa BUFFER_C_C_ADDR

    ldaa #buffer_full       


    ldaa #rx_done


    ldaa #tx_done


    rts                     *; Return from subroutine

_rx_Loop:
    jsr _wait_rda           *; Wait for data to be recieved
    jsr _hdl_irf_rda        *; Handle Recieved Data Available

    jsr _val_irf_err_rx     *; Check for communication error

    ldaa RX_DONE_ADDR       
    cmpa #01                *; Check if recieving is done
    beq _rts_rx_loop

    bra _rx_Loop

_rts_rx_loop:
    rts

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

_rts_hdl_irf_rda:
    rts                     *; Return from subroutine    

*; Signaling that the buffer is filled
_hdl_buffer_full:   
    ldaa #$01               *; Setting /DTR to low to indicate that the buffer is full 
    staa MCR
    bra _hdl_buffer_full

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

_rts_val_err_rx:
    rts

*; Waits until the interrupt flag THRE is raised
_wait_thre:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_THRE    *; Check if TX holding register is empty
    bne _wait_thre          *; Wait until empty

    rts                     *; Return from subroutine

*; Handle Transmiter Holding Register Empty
_hdl_irf_thre:
    nop
