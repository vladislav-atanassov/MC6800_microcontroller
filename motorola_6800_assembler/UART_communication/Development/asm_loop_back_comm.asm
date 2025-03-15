*; Define UART registers
RBTHR           equ $2000  *; UART Transmit Holding Register
IER             equ $2001  *; Interrupt Enable Register
IIR             equ $2002  *; Interrupt Identification Register
LCR             equ $2003  *; Line Control Register
MCR             equ $2004  *; MODEM Control Register  
LSRg            equ $2005  *; Line Status Register

*; Line Status Register Bits
LSR_FLAG_DR     equ $01    *; Received Data Available Bit
LSR_FLAG_THRE   equ $20    *; Transmitter Holding Register Empty Bit

*; Define UART Interrupt Identification Register flags
IIR_FLAG_RLS    equ $06     *; Reciever Line Status (RLS) flag IIR
IIR_FLAG_RDA    equ $04     *; Received Data Available (RDA) flag IIR
IIR_FLAG_THRE   equ $02     *; Transmitter Holding Register Empty (THRE) flag IIR

*; Define variables, flags, constants needed for the program
BUFFER_S_ADR    equ $0000   *; Define the staring address of the buffer to store the received data
BUFFER_SIZE_MAX equ $FF     *; Define buffer max size   
CONSTS_S_ADR    equ $102    *; Define the start of the constants memory space   
BUFFER_C_C_OFF  equ $00     *; Define offset from CONSTS_S_ADR for buffercurrcap
BUFFER_FULL_OFF equ $01     *; Define offset from CONSTS_S_ADR for bufferfull
BUFFER_C_P_OFF  equ $02     *; Define offset from CONSTS_S_ADR for the last data is stored in buffer    
RX_DONE_OFF     equ $03     *; Define offset from CONSTS_S_ADR for flag indicating if recieve has ended (0-F, 1-T)
TX_DONE_OFF     equ $04     *; Define offset from CONSTS_S_ADR for flag indicating if transmit has ended (0-F, 1-T)
BUF_L_BYTE_OFF  equ $05     *; Defite offset from CONSTS_S_ADR for buffering the last transmitted/recieved byte

CALC_ADR_IDXR   equ $100
CALC_ADR_ACC    equ $101

SP_ADR          equ $1FFF   *; Define the SP address

    org $0E00               *; Start address of the program in the EPROM

    org $0E00               *; Start address of the program in the EPROM

*; Initialize 
_init_uart:
    ldaa #$83               *; Set line control register (8 bits, no parity, 1 stop bit)
    staa LCR                *; Write to Line Control Register

    ldaa #$0D               *; Set low byte of baud rate divisor (9600 baud)
    staa RBTHR              *; Write to Divisor Latch Low Byte
    ldaa #$00               *; Set high byte of baud rate divisor
    staa IER                *; Write to Divisor Latch High Byte

    ldaa #$03               *; Clear DLAB, set 8-bit data, no parity, 1 stop bit
    staa LCR                *; Write to Line Control Register

    ldaa #$03               *; Enable RDA and THRE interrupt flags
    staa IER                *; Write to Interrupt Enable Register

*; Initialize SP
    lds #SP_ADR

*; Main loop
_main_loop:
    jsr _init_vars          *; Initialize variables

    jsr _rx_loop            *; Start the RX loop

    jsr _tx_loop            *; Start the TX loop

    bra _main_loop          *; Continue waiting for next data 

*; Initialize all of the vars/flag with default values
_init_vars:
    ldx #C_START_ADR    
    ldaa #BUFFER_SIZE_MAX   *; BUFFERCC = BUFFER_SIZE_MAX
    staa BUFFER_C_C_OFF,x   *; Store the default value for variable for the buffer current capacity (max size)

    clr BUFFER_C_P_OFF,x    *; Buffer Position = 0
    clr BUFFER_FULL_OFF,x   *; Buffer Full Flag = 0
    clr RX_DONE_OFF,x       *; Receive Done = 0
    clr TX_DONE_OFF,x       *; Transmit Done = 0
    clr BUF_L_BYTE_OFF,x    *; Last Byte = 0
    clr CALC_ADR_ACC        *; Value in calculation address for accumulators = 0
    clr CALC_ADR_IDXR       *; Value in calculation address for the X register = 0
    rts

*; Buffers the last transmitted/recieved byte 
_buf_last_byte:
    ldx #C_START_ADR
    staa BUF_L_BYTE_OFF,x   *; Store the last byte into the constants buffer at index BUF_L_BYTE_OFF
    rts

*; Storing the the current position of the buffer into the X register
_buf_curr_p_to_x:
    ldx #C_START_ADR        *; Load the start of the constants memory space into the X register 
	ldab BUFFER_C_P_OFF,x   *; Load the offset into accumulator B
	stab CALC_ADR_ACC       *; Store the offset  
	ldx CALC_ADR_IDXR       *; Load the offet into the X register
    rts

*; Recieve loop 
_rx_loop:
    jsr _poll_rda           *; Wait for data to be recieved

    jsr _hdl_rda            *; Handle Recieved Data Available

    jsr _val_rx_error       *; Check for communication error

    ldx #C_START_ADR
    ldaa RX_DONE_OFF,x       
    cmpa #01                *; Check if recieving is done
    beq _r_rx_loop          *; If done return from subroutine
	
    bra _rx_loop            *; If not done continue with the loop

_r_rx_loop:
    rts                     *; Return from subroutine _rx_loop

*; Poll for received data
_poll_rda:
    ldaa LSRg               *; Read the Line Status Register
    anda #UART_LSR_DR       *; Check if Data Ready (DR) flag is set
    beq _poll_rda           *; If no data is available, keep polling
    rts

*; Handle Received Data Available   
_hdl_rda:
    ldaa RBTHR           *; Read received character
    jsr _buf_last_byte      *; Buffer the last recieved byte

    cmpa #$00               *; Check for NULL terminator 
    beq _mark_rx_done          *; If NULL terminator mark RX as done

*;   Store the data at the next position in the SRAM
    jsr _buf_curr_p_to_x
	staa BUFFER_S_ADR,x   *; Store the recieved data in the current position of the buffer

	ldx #C_START_ADR     *; Load the start of the constants memory space into the X register 
    inc BUFFER_C_P_OFF,x       *; Move to the next position in SRAM

    dec BUFFER_C_C_OFF,x       *; Decrement the buffer current capacity 

*;   Check if buffer is full
    ldaa BUFFER_C_C_OFF,x      
    cmpa #$00 
    beq _hdl_buf_full   

    bra _r_hdl_rda

_mark_rx_done:
    ldx #C_START_ADR
    ldaa #$01            
    staa RX_DONE_OFF,x        *; Setting the flag for recieve done to true

*;! Here to indicate future idea for diodes indication for exit states of the program
*;  ldaa #$04                *; Set /OUT1 low and /OUT2 high to indicate end of RX
*;  staa MCR                 *; Store in MCR

*;   TODO: Create a routine that cleans up the values of variables (set to default values)  
*;   Set the value of the current position of the buffer in the SRAM to default (the start address - $0000)
    ldx #C_START_ADR         
    ldaa #BUFFER_S_ADR
    staa BUFFER_C_P_OFF,x   

    clra                    *; Clear ACCA

_r_hdl_rda:
    rts    

*; TODO: Implement the _hdl_buf_full subroutine
*; Handle buffer full
*;! Just for testing 
_hdl_buf_full:
    bra _mark_rx_done
*;! Here to indicate future idea for diodes indication for exit states of the program
*; ldaa #$01                 *; Set /DTR low to indicate that the buffer is full 
*; staa MCR

*;    bra _hdl_buf_full

*; Error validation for IRF for communication error
_val_rx_error:
    ldaa IIR         *; Read Interrupt Identification Register
    cmpa #UART_FLAG_ERR       *; Check for UART error
    bne _r_val_rx_error       *; If no error return 

    jsr _hdl_rx_error          *; Handle RX communication error 

_r_val_rx_error:
    rts

*; TODO  better logic for handling RX error
*;? TODO  couter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*; Handle RX communication error 
_hdl_rx_error:
    ldaa LSRg        *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    rts

*; Transmit loop
_tx_loop:
    jsr _poll_thre         *; Wait until the transmitter holding register is empty
    
    jsr _hdl_thre             *; Handle Transmitter Holding Register Empty

    jsr _val_tx_error          *; Check for communication error

*;   Check if transmitting is done
    ldx #C_START_ADR
    ldaa TX_DONE_OFF,x
    cmpa #01                    
    beq _r_tx_loop           *; If done return from subroutine

    bra _tx_loop              *; If not done continue with the loop

_r_tx_loop rts               *; Return from subroutine _tx_loop

*; Poll for THRE before transmitting
_poll_thre:
    ldaa LSRg               *; Read the Line Status Register
    anda #UART_LSR_THRE     *; Check if THRE flag is set
    beq _poll_thre          *; If THRE is not set, keep polling
    rts

*; Handle Transmitter Holding Register Empty
_hdl_thre:
    jsr _buf_curr_p_to_x
    ldaa BUFFER_S_ADR,x   *; Load the current data in the buffer into ACCA
    
    jsr _buf_last_byte      *; Buffer the last transmitted byte

    cmpa #$00               *; Check for NULL terminator
    beq _mark_tx_done          *; If NULL terminator mark TX as done

    staa RBTHR              *; Store the data into the Transmit Holding Register

    ldx #C_START_ADR
    inc BUFFER_C_P_OFF,x       *; Move to the next position in buffer

*;   Check is the whole buffer is read
    ldaa BUFFER_C_P_OFF,x
    cmpa #BUFFER_SIZE_MAX    
    beq _mark_tx_done          *; If the buffer is read mark TX as done
    rts

_mark_tx_done ldx #C_START_ADR
    ldaa #01                
    staa TX_DONE_OFF,x        *; Set the transmit done flag

*;! Here to indicate future idea for diodes indication for exit states of the program
*;  ldaa #$0C                *; Set /OUT1 high and /OUT2 high to indicate end of TX 
*;  staa MCR

    ldx #C_START_ADR
    clr BUFFER_C_P_OFF,x       *; Buffer Position = 0   

_clr_buf_loop:
    jsr _buf_curr_p_to_x
	clr BUFFER_S_ADR,x    *; Clear data at the current position of the buffer

    ldx #C_START_ADR
    ldaa BUFFER_C_P_OFF,x
    cmpa #BUFFER_SIZE_MAX     *; Check if the counter is at the end of the buffer
    beq _r_hdl_thre          *; Return to _main_loop

    inc BUFFER_C_P_OFF,x       *; Move to the next position of the buffer

    bra _clr_buf_loop

_r_hdl_thre:
    rts

*; Error validation for IRF for communication error
_val_tx_error:
    ldaa IIR        *; Read Interrupt Identification Register
    cmpa #UART_FLAG_ERR       *; Check for UART error
    bne _r_val_tx_error          *; If no error return 

    jsr _hdl_tx_error         *; Handle TX communication error 

_r_val_tx_error:
    rts

*; TODO  better logic for handling TX error
*;? TODO  couter to reset the chip (with MR for ex.) 
*;?       if the validation fails too many times
*;  Handle TX communication error 
_hdl_tx_error:
    ldaa LSRg       *; Read Line Status Register
    clra                    *; Clear accumulator (error handling can be improved)
    rts
