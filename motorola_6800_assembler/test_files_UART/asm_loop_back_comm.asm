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

*; TODO: Think about the variables and if they should even be there o just renamed
*;?      They should only be used for defauld initialization and then become overhead
*;?      because you only need to read from the addresses in the SRAM
*; Define variables and flags needed for the program
BUFFER_SIZE_MAX equ $ff     *; Define buffer max size   
buffer_curr_cap equ $ff     *; Define current buffer capacity variable
BUFFER_C_C_OFF  equ $00     *; Define offset from SP for buffer_curr_cap
buffer_full     equ $00     *; Define a flag to indicate if the buffer is filled
BUFFER_FULL_OFF equ $02     *; Define offset from SP for buffer_full

SRAM_ADDR       equ $0000   *; Define SRAM address for storing received data
sram_curr_addr  equ $00     *; Define a variable for the current position of the buffer
SP_ADDR         equ $1fff   *; Define the SP address

rx_done         equ $00     *; Define flag for indicating if recieve has ended (0-F, 1-T)
tx_done         equ $00     *; Define flag for indicating if transmit has ended (0-F, 1-T)
RX_DONE_OFF     equ $04     *; Define offset from SP for rx_done
TX_DONE_OFF     equ $06     *; Define offset from SP for tx_done

    org $1C00               *; Start address of the program in the EPROM

*; UART Initialization
_init_uart:
    ldaa #$07               *; Enable RDA, THRE interrupt flags
    staa IER                *; Write to Interrupt Enable Register

    ldaa #$83               *; Set line control register (8 bits, no parity, 1 stop bit)
    staa LCR                *; Write to Line Control Register

    ldaa #$0D               *; Set divisor latch for 9600 baud rate
    staa $2000              *; Set low byte of baud rate
    ldaa #$00
    staa $2001              *; Set high byte of baud rate

    ldaa #$03               *; Clear DLAB
    staa LCR                *; Write to Line Control Register

_init_sp:
    ldx SP_ADDR             *; Store the SP address in register X
    txs                     *; Initialize the SP with the value in register X

*; Main loop
_main_loop:

    jsr _push_vars_stack    *; Push the vars/flags into the stack with default values

    jsr _rx_Loop            *; Start the RX loop
    jsr _val_irf_err_rx     *; Check for RX communication error
    
    jsr _tx_Loop            *; Start the TX loop
    jsr _val_irf_err_rx     *; Check for TX communication error

    bra _main_loop           *; Continue waiting for next data 

*; Push all of the vars/flag into the stack before the start of the program
_push_vars_stack:
    ldaa #buffer_curr_cap   
    psha                    *; Push the variable for the current buffer capacity in the stack
    ldaa #buffer_full       
    psha                    *; Push the flag for indicating if buffer is full
    ldaa #rx_done           
    psha                    *; Push the flag for indicating if recieving is done
    ldaa #tx_done           
    psha                    *; Push the flag for indicating if transmiting is done
    ldaa #sram_curr_addr    
    psha                    *; Push the variable for the current position of the buffer

    rts                     *; Return from subroutine

*; Recieve loop 
_rx_Loop:
    jsr _wait_rda           *; Wait for data to be recieved
    jsr _hdl_irf_rda        *; Handle Recieved Data Available

    jsr _val_irf_err_rx     *; Check for communication error

    ldaa SP_ADDR + RX_DONE_OFF       
    cmpa #01                *; Check if recieving is done
    beq _rt_rx_loop         *; If done return from subroutine

    bra _rx_Loop            *; If not done continue with the loop

_rt_rx_loop:
    rts                     *; Return from subroutine _rx_Loop

*; Wait until the interrupt flag RDA is raised
_wait_rda:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_RDA     *; Check for recieved data
    bne _wait_rda           *; If nothing recieved continue waiting
    
    rts                     *; When data recieved continue with _main_loop

*; Handle Received Data Available   
_hdl_irf_rda:
    ldaa SP_ADDR + BUFFER_C_C_OFF
    cmpa #$00               *; Check if buffer is full
    beq _hdl_buffer_full    *;* Branch without push stack operation because this is a critical state 

    ldx RBTHR               *; Read received character
    
    ldaa ,x                 *; Load the x register into ACCA to compare
    cmpa #$00               *; Check for NULL terminator 
    beq _mark_rx_done       *; If NULL terminator mark RX as done

    staa sram_curr_addr     *; Store the recieved data in SRAM
    inc sram_curr_addr      *; Move to the next position in SRAM

    dec SP_ADDR + BUFFER_C_C_OFF    *;  Decrement the buffer current capacity 

    bra _rt_hdl_irf_rda

_mark_rx_done:
    ldaa #$01               *; Setting ht eflag for recieve done to true
    staa SP_ADDR + RX_DONE_OFF

*;! Here to indicate future idea for diodes indication for exit states of the program
    ldaa #$04               *; Set /OUT1 low and /OUT2 high to indicate end of RX
    staa MCR                *; Store in MCR

    clra                    *; Clear ACCA

_rt_hdl_irf_rda:
    rts                     *; Return from subroutine    

*; Handle buffer full
_hdl_buffer_full:   
*;  Set the flag buffer full to true
    ldaa #$01   
    staa SP_ADDR + BUFFER_FULL_OFF

*;! Here to indicate future idea for diodes indication for exit states of the program
    ldaa #$01               *; Set /DTR low to indicate that the buffer is full 
    staa MCR

    bra _hdl_buffer_full

*; Error validation for IRF for communication error
_val_irf_err_rx:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     *; Check for UART error
    bne _rt_val_err_rx      *; If no error return 

    jsr _hdl_irf_err_rx     *;  Handle RX communication error 

_rt_val_err_rx:
    rts

*; TODO: Implement better logic for handling RX error
*;? TODO: Add couter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*;  Handle RX communication error 
_hdl_irf_err_rx:
    ldaa LSRg               *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    rts

*; Transmit loop
_tx_loop:
    jsr _wait_thre          *; Wait until the transmitter holding register is empty
    jsr _hdl_irf_thre       *; Handle Transmitter Holding Register Empty

    ldaa SP_ADDR + TX_DONE_OFF
    cmpa #01                *; Check if transmitting is done
    beq _rt_tx_loop         *; If done return from subroutine

    bra _tx_loop            *; If not done continue with the loop

_rt_tx_loop:
    rts                     *; Return from subroutine _tx_loop

*; Wait until the interrupt flag THRE is raised
_wait_thre:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_THRE    *; Check if TX holding register is empty
    bne _wait_thre          *; Wait until empty

    rts                     *; Return from subroutine

*; Handle Transmitter Holding Register Empty
_hdl_irf_thre:
    ldaa SP_ADDR + BUFFER_C_C_OFF
    cmpa BUFFER_SIZE_MAX    *; Check is the whole buffer is read
    beq _mark_tx_done       *; If the buffer is read mark TX as done

    ldx sram_curr_addr      *; Load the current address of the data to transmit from SRAM
    ldaa ,x                 *; Load the data at the address into ACCA

    cmpa #$00               *; Check for NULL terminator
    beq _mark_tx_done       *; If NULL terminator mark TX as done

    staa RBTHR              *; Store the data into the Transmit Holding Register
    inc sram_curr_addr      *; Move to the next position in SRAM

    inc SP_ADDR + BUFFER_C_C_OFF    *;  Increment the buffer current capacity

    bra _rt_hdl_irf_thre    *; Return from subroutine

_mark_tx_done:
    ldaa #01                *; Set the transmit done flag
    staa SP_ADDR + TX_DONE_OFF

*;! Here to indicate future idea for diodes indication for exit states of the program
    ldaa #$0C               *; Set /OUT1 high and /OUT2 high to indicate end of TX 
    staa MCR

    clra                    *; Clear the ACCA

_rt_hdl_irf_thre:
    rts                     *; Return from subroutine

*; Error validation for IRF for communication error
_val_irf_err_tx:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     *; Check for UART error
    bne _rt_val_err_tx      *; If no error return 

    jsr _hdl_irf_err_tx     *;  Handle TX communication error 

_rt_val_err_tx:
    rts

*; TODO: Implement better logic for handling TX error
*;? TODO: Add couter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*;  Handle TX communication error 
_hdl_irf_err_tx:
    ldaa LSRg               *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    rts