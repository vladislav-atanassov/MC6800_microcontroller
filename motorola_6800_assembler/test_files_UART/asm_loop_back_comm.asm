*; Define UART registers
RBTHR           equ $2000   *; UART Transmit Holding Register
IER             equ $2001   *; Interrupt Enable Register
IIR             equ $2002   *; Interrupt Identification Register
LCR             equ $2003   *; Line Control Register
MCR             equ $2004   *; MODEM Control Register  
LSRg            equ $2005   *; Line Status Register

*; Define UART Interrupt flags
UART_CODE_THRE  equ $02     *; Code for UART Transmiter Holding register Empty
UART_CODE_RDA   equ $04     *; Code for Recieved Data Available
UART_CODE_ERR   equ $06     *; Code for UART error in IIR

*; Define variables, flags, constants needed for the program
BUFFER_SIZE_MAX equ $ff     *; Define buffer max size   
BUFFER_C_C_OFF  equ $fd     *; Define offset from SP for buffercurrcap
BUFFER_FULL_OFF equ $fc     *; Define offset from SP for bufferfull
BUFFER_STR_ADR  equ $00     *; Define the starting address of the buffer to store the received data
BUFFER_C_P_OFF  equ $fb     *; Define offset from SP for a variable that keeps track of where the last data is stored in buffer    

SP_TOP_ADR      equ $1fff   *; Define the SP address
SP_BOT_ADR      equ $1f00   *; Define the Bottom address of the stack 

RX_DONE_OFF     equ $fa     *; Define offset for flag indicating if recieve has ended (0-F, 1-T)
TX_DONE_OFF     equ $f9     *; Define offset for flag indicating if transmit has ended (0-F, 1-T)

CALC_ADR_ACC    equ $1fff   *; Define addresses that will be allocated for calculation between ACCA,B and X register
CALC_ADR_IDXR   equ $1ffe   *; Define addresses that will be allocated for calculation between ACCA,B and X register

    org $1C00               *; Start address of the program in the EPROM

*; Initialize UART
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

*; Initialize SP
    lds #SP_TOP_ADR

*; Push all of the vars/flag into the stack before the start of the program
_push_vars_stack:
    ldaa #$00               *; Allocate memory for CALC_ADR_ACC, CALC_ADR_IDXR
	psha                    
	psha
	ldaa #BUFFER_SIZE_MAX   *; BUFFERCC = BUFFER_SIZE_MAX
    psha                    *; Push the default value for variable for the buffer current capacity in the stack (max size)
    ldaa #$00               *; BUFFER_FULL = 0
    psha                    *; Push the default value for flag for indicating if buffer is full (F)
    ldaa #$00               *; BUFFER_C_P = 0
    psha                    *; Push the default value for variable for the current position of the buffer (0)
    ldaa #$00               *; R_DONE = 0
    psha                    *; Push the default value for flag for indicating if recieving is done (F)
    ldaa #$00               *; TX_DONE = 0
    psha                    *; Push the default value for flag for indicating if transmiting is done (F)

*; Main loop
_main_loop:
    jsr _rx_loop            *; Start the RX loop
    
    jsr _tx_loop            *; Start the TX loop

    bra _main_loop          *; Continue waiting for next data 

*; Recieve loop 
_rx_loop:
    jsr _wait_rda           *; Wait for data to be recieved
    jsr _hdl_irf_rda        *; Handle Recieved Data Available

    jsr _val_irf_err_rx     *; Check for communication error

    ldx #SP_BOT_ADR
    ldaa RX_DONE_OFF,x       
    cmpa #01                *; Check if recieving is done
    beq _rt_rx_loop         *; If done return from subroutine

    bra _rx_loop            *; If not done continue with the loop

_rt_rx_loop:
    rts                     *; Return from subroutine _rx_loop

*; Wait until the interrupt flag RDA is raised
_wait_rda:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_RDA     *; Check for recieved data
    bne _wait_rda           *; If nothing recieved continue waiting
    
    rts                     *; When data recieved continue with _main_loop

*; Handle Received Data Available   
_hdl_irf_rda:
    ldaa RBTHR              *; Read received character
    cmpa #$00               *; Check for NULL terminator 
    beq _mark_rx_done       *; If NULL terminator mark RX as done

*;  Store the data at the next position in the SRAM
	ldx #SP_BOT_ADR         *; Load the base address (stack bottom) into X
	ldab BUFFER_C_P_OFF,x   *; Load the offset into accumulator B
	stab CALC_ADR_ACC       *; Store the offset  
	ldx CALC_ADR_IDXR       *; Load the offset into the index register
	staa BUFFER_STR_ADR,x   *; Store the recieved data in the current position of the buffer

    ldx #SP_BOT_ADR
    inc BUFFER_C_P_OFF,x    *; Move to the next position in SRAM

    dec BUFFER_C_C_OFF,x    *; Decrement the buffer current capacity 

	ldx #SP_BOT_ADR         *;  Check if buffer is full
    ldaa BUFFER_C_C_OFF,x      
    cmpa #$00 
    beq _hdl_buffer_full    *; If full handle it

    bra _rt_hdl_irf_rda     *; If not full continue 

_mark_rx_done:
    ldaa #$01            
    ldx #SP_BOT_ADR
    staa RX_DONE_OFF,x      *; Setting the flag for recieve done to true

*;! Here to indicate future idea for diodes indication for exit states of the program
*;  ldaa #$04                *; Set /OUT1 low and /OUT2 high to indicate end of RX
*;  staa MCR                 *; Store in MCR

*;  TODO: Create a routine that cleans up the values of variables (set to default values)  
*;  Set the value of the current position of the buffer in the SRAM to default (the start address - $0000)
    ldaa #BUFFER_STR_ADR
    ldx #SP_BOT_ADR         
    staa BUFFER_C_P_OFF,x

    clra                    *; Clear ACCA

_rt_hdl_irf_rda:
    rts                     *; Return from subroutine    

*; TODO: Implement the _hdl_buffer_full subroutine
*; Handle buffer full
_hdl_buffer_full:
    ldaa #$04   *; Setting /OUT1 to low and /OUT2 to high to indicate buffer full
    staa MCR

    bra _hdl_buffer_full

*; Error validation for IRF for communication error
_val_irf_err_rx:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     *; Check for UART error
    bne _rt_val_err_rx      *; If no error return 

    jsr _hdl_irf_err_rx     *; Handle RX communication error 

_rt_val_err_rx:
    rts                     *; Return from subroutine

*; TODO  better logic for handling RX error
*;? TODO  counter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*; Handle RX communication error 
_hdl_irf_err_rx:
    ldaa LSRg               *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    rts

*; Transmit loop
_tx_loop:
    jsr _wait_thre          *; Wait until the transmitter holding register is empty
    jsr _hdl_irf_thre       *; Handle Transmitter Holding Register Empty

    ldx #SP_BOT_ADR         *; Check if transmitting is done
    ldaa TX_DONE_OFF,x
    cmpa #01                    
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
    ldx #SP_BOT_ADR         *; Load the base address (stack bottom) into X
	ldab BUFFER_C_P_OFF,x   *; Load the offset into accumulator B
	stab CALC_ADR_ACC       *; Store the offset  
	ldx CALC_ADR_IDXR       *; Load the offset into the index register
	
    ldaa BUFFER_STR_ADR,x   *; Load the current data in the buffer into ACCA
    cmpa #$00               *; Check for NULL terminator
    beq _mark_tx_done       *; If NULL terminator mark TX as done

    staa RBTHR              *; Store the data into the Transmit Holding Register

    ldx #SP_BOT_ADR
    inc BUFFER_C_P_OFF,x    *; Move to the next position in SRAM

    inc BUFFER_C_C_OFF,x    *; Increment the buffer current capacity 

    ldaa BUFFER_C_C_OFF,x   *; Check is the whole buffer is read
    cmpa BUFFER_SIZE_MAX    
    beq _mark_tx_done       *; If the buffer is read mark TX as done

    bra _rt_hdl_irf_thre    *; Return from subroutine

_mark_tx_done:
    ldx #SP_BOT_ADR
    ldaa #01                
    staa TX_DONE_OFF,x      *; Set the transmit done flag

*;! Here to indicate future idea for diodes indication for exit states of the program
*;  ldaa #$0C               *; Set /OUT1 high and /OUT2 high to indicate end of TX 
*;  staa MCR

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
    rts                     *; Return from subroutine

*; TODO  better logic for handling TX error
*;? TODO  couter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*;  Handle TX communication error 
_hdl_irf_err_tx:
    ldaa LSRg               *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    rts
