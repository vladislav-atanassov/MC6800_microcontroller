*; Define UART registers
RBTHR               equ $2000   *; UART Transmit Holding Register
IER                 equ $2001   *; Interrupt Enable Register
IIR                 equ $2002   *; Interrupt Identification Register
LCR                 equ $2003   *; Line Control Register
MCR                 equ $2004   *; MODEM Control Register  
LSRg                equ $2005   *; Line Status Register

*; Define UART Interrupt flags
UART_CODE_THRE      equ $02     *; Code for UART Transmiter Holding register Empty
UART_CODE_RDA       equ $04     *; Code for Recieved Data Available
UART_CODE_ERR       equ $06     *; Code for UART error in IIR

*;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
*; Define variables, flags, constants needed for the program
BUFFER_START_ADR    equ $00     *; Define the staring address of the buffer to store the received data
BUFFER_SIZE_MAX     equ $ff     *; Define buffer max size   
CONSTS_START_ADR    equ $102    *; Define the start of the constants memory space   
BUFFER_C_C_OFF      equ $00     *; Define offset from CONSTS_START_ADR for buffercurrcap
BUFFER_FULL_OFF     equ $01     *; Define offset from CONSTS_START_ADR for bufferfull
BUFFER_C_P_OFF      equ $02     *; Define offset from CONSTS_START_ADR for a variable that keeps track of where the last data is stored in buffer    
RX_DONE_OFF         equ $03     *; Define offset from CONSTS_START_ADR for flag indicating if recieve has ended (0-F, 1-T)
TX_DONE_OFF         equ $04     *; Define offset from CONSTS_START_ADR for flag indicating if transmit has ended (0-F, 1-T)
BUF_LAST_BYTE       equ $05     *; Defite offset from CONSTS_START_ADR for buffering the last transmitted/recieved byte

*;! These are not the real addresses! These addresses are for testing in SDK6800 Emulator
CALC_ADR_IDXR       equ $100    *; Hardcoded address used for calculations with accumulators (for 8-bits)
CALC_ADR_ACC	    equ $101    *; Hardcoded address used for calculations with the index register (fro 16-bits)

SP_ADR              equ $1fff   *; Define the SP address

    org $1f00               *; Start address of the program in the EPROM

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
    lds #SP_ADR

*; Push all of the vars/flag into the stack before the start of the program
_load_vars:
    ldx #CONSTS_START_ADR

    ldaa #BUFFER_SIZE_MAX   *; BUFFERCC = BUFFER_SIZE_MAX
    staa BUFFER_C_C_OFF,x   *; Store the default value for variable for the buffer current capacity (max size)
    
    ldaa #$00               *; BUFFERFULL = 0
    staa BUFFER_FULL_OFF,x  *; Store the default value for flag for indicating if buffer is full (F)
    
    ldaa #$00               *; BUFFERCP = 0
    staa BUFFER_C_P_OFF,x   *; Store the default value for variable for the current position of the buffer (0)
    
    ldaa #$00               *; RXDONE = 0
    staa RX_DONE_OFF,x      *; Store the default value for flag for indicating if recieving is done (F)
    
    ldaa #$00               *; TXDONE = 0
    staa TX_DONE_OFF,x      *; Store the default value for flag for indicating if transmiting is done (F)
    
    ldaa #$00               *; BUF_LAST_BYTE = 0
    staa BUF_LAST_BYTE,x    *; Store the default value for the last byte transmitted/recieved (00)

*; Main loop
_main_loop:
    jsr _rx_loop            *; Start the RX loop
    
    jsr _tx_loop            *; Start the TX loop

    bra _main_loop          *; Continue waiting for next data 

*; Buffers the last transmitted/recieved byte 
_buffer_last_b:
    ldx #CONSTS_START_ADR
    staa BUF_LAST_BYTE,x    *; Store the last byte into the constants buffer at index BUF_LAST_BYTE

    rts

*; Recieve loop 
_rx_loop:
    jsr _wait_rda           *; Wait for data to be recieved
    jsr _hdl_irf_rda        *; Handle Recieved Data Available

    jsr _val_irf_err_rx     *; Check for communication error

    ldx #CONSTS_START_ADR
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
    jsr _buffer_last_b      *; Buffer the last recieved byte

    cmpa #$00               *; Check for NULL terminator 
    beq _mark_rx_done       *; If NULL terminator mark RX as done

*;  Store the data at the next position in the SRAM
	ldx #CONSTS_START_ADR   *; Load the base address (stack bottom) into X
	ldab BUFFER_C_P_OFF,x   *; Load the offset into accumulator B
	stab CALC_ADR_ACC       *; Store the offset  
	ldx CALC_ADR_IDXR       *; Load the offset into the index register
	staa BUFFER_START_ADR,x *; Store the recieved data in the current position of the buffer

	ldx #CONSTS_START_ADR   *; Load the start of the constants memory space into the X register 
    inc BUFFER_C_P_OFF,x    *; Move to the next position in SRAM

    dec BUFFER_C_C_OFF,x    *; Decrement the buffer current capacity 

*;  Check if buffer is full
    ldaa BUFFER_C_C_OFF,x      
    cmpa #$00 
    beq _hdl_buffer_full   

    bra rthdlirfrda

_mark_rx_done:
    ldx #CONSTS_START_ADR
    ldaa #$01            
    staa RX_DONE_OFF,x      *; Setting the flag for recieve done to true

*;! Here to indicate future idea for diodes indication for exit states of the program
*;  ldaa #$04               *; Set /OUT1 low and /OUT2 high to indicate end of RX
*;  staa MCR                *; Store in MCR

*;  TODO: Create a routine that cleans up the values of variables (set to default values)  
*;  Set the value of the current position of the buffer in the SRAM to default (the start address - $0000)
    ldx #CONSTS_START_ADR         
    ldaa #BUFFER_START_ADR
    staa BUFFER_C_P_OFF,x   

    clra                    *; Clear ACCA

rthdlirfrda:
    rts                     *; Return from subroutine    

*; TODO: Implement the _hdl_buffer_full subroutine
*; Handle buffer full
*;! Just for testing 
_hdl_buffer_full:
    bra _mark_rx_done
*;! Here to indicate future idea for diodes indication for exit states of the program
*; ldaa #$01                *; Set /DTR low to indicate that the buffer is full 
*; staa MCR

*;    bra _hdl_buffer_full

*; Error validation for IRF for communication error
_val_irf_err_rx:
    ldaa IIR                *; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     *; Check for UART error
    bne _rt_val_err_rx      *; If no error return 

    jsr _hdl_irf_err_rx     *; Handle RX communication error 

_rt_val_err_rx:
    rts

*; TODO  better logic for handling RX error
*;? TODO  couter to reset the chip (with MR for ex ) 
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

    jsr _val_irf_err_tx     *; Check for communication error

*;  Check if transmitting is done
    ldx #CONSTS_START_ADR
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
    ldx #CONSTS_START_ADR   *; Load the base address (stack bottom) into X
	ldab BUFFER_C_P_OFF,x   *; Load the offset into accumulator B
	stab CALC_ADR_ACC       *; Store the offset  
	ldx CALC_ADR_IDXR       *; Load the offset into the index register
	
    ldaa BUFFER_START_ADR,x *; Load the current data in the buffer into ACCA
    jsr _buffer_last_b      *; Buffer the last transmitted byte

    cmpa #$00               *; Check for NULL terminator
    beq _mark_tx_done          *; If NULL terminator mark TX as done

    staa RBTHR              *; Store the data into the Transmit Holding Register

    ldx #CONSTS_START_ADR
    inc BUFFER_C_P_OFF,x    *; Move to the next position in SRAM

    inc BUFFER_C_C_OFF,x    *; Increment the buffer current capacity 

*;  Check is the whole buffer is read
    ldaa BUFFER_C_C_OFF,x
    cmpa BUFFER_SIZE_MAX    
    beq _mark_tx_done       *; If the buffer is read mark TX as done

    bra rthdlirfthre        *; Return from subroutine

_mark_tx_done:
    ldx #CONSTS_START_ADR
    ldaa #01                
    staa TX_DONE_OFF,x      *; Set the transmit done flag

*;! Here to indicate future idea for diodes indication for exit states of the program
*;  ldaa #$0C               *; Set /OUT1 high and /OUT2 high to indicate end of TX 
*;  staa MCR

    clra                    *; Clear the ACCA

rthdlirfthre:
    rts                     *; Return from subroutine

*; Error validation for IRF for communication error
_val_irf_err_tx:
    ldaa IIR        *; Read Interrupt Identification Register
    cmpa #UART_CODE_ERR     *; Check for UART error
    bne rtvalerrtx          *; If no error return 

    jsr hdlirferrtx         *; Handle TX communication error 

rtvalerrtx:
    rts

*; TODO  better logic for handling TX error
*;? TODO  couter to reset the chip (with MR for ex ) 
*;?       if the validation fails too many times
*;  Handle TX communication error 
hdlirferrtx:
    ldaa LSRg               *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    
    rts