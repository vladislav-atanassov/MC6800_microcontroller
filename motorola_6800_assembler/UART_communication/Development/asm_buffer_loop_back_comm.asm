*; Define UART registers
RBTHR           equ $2000  *; UART Transmit Holding Register
IER             equ $2001  *; Interrupt Enable Register
IIR             equ $2002  *; Interrupt Identification Register
LCR             equ $2003  *; Line Control Register
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
BUFFER_SIZE_MAX equ $0F     *; Define buffer max size 
END_OF_MSG_CHAR equ 'z'     *; End of message character  
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

    org $EE00               *; Start address of the program in the EPROM

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
    ldx #CONSTS_S_ADR    
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
    ldx #CONSTS_S_ADR
    staa BUF_L_BYTE_OFF,x   *; Store the last byte into the constants buffer at index BUF_L_BYTE_OFF
    rts

*; Loading the the current position of the buffer into the X register
_buf_curr_p_to_x:
    ldx #CONSTS_S_ADR       *; Load the start of the constants memory space into the X register 
	ldab BUFFER_C_P_OFF,x   *; Load the offset into accumulator B
	stab CALC_ADR_ACC       *; Store the offset  
	ldx CALC_ADR_IDXR       *; Load the offet into the X register
    rts

*; Recieve loop 
_rx_loop:
    jsr _poll_dr            *; Wait for data to be recieved

    jsr _hdl_dr            *; Handle Recieved Data Available

    ldx #CONSTS_S_ADR
    ldaa RX_DONE_OFF,x       
    cmpa #01                *; Check if recieving is done
    beq _r_rx_loop          *; If done return from subroutine
	
    bra _rx_loop            *; If not done continue with the loop

_r_rx_loop:
    rts                     *; Return from subroutine _rx_loop

*; Poll for received data
_poll_dr:
    ldaa LSRg               *; Read the Line Status Register
    anda #LSR_FLAG_DR       *; Check if Data Ready (DR) flag is set
    beq _poll_dr            *; If no data is available, keep polling
    rts

*; Handle Data Ready   
_hdl_dr:
    ldaa RBTHR              *; Read received character
    jsr _buf_last_byte      *; Buffer the last recieved byte

*;  Store the data at the next position in the SRAM
    jsr _buf_curr_p_to_x    *; Loading the the current position of the buffer into the X register
	staa BUFFER_S_ADR,x     *; Store the recieved data in the current position of the buffer

	ldx #CONSTS_S_ADR       *; Load the start of the constants memory space into the X register 
    inc BUFFER_C_P_OFF,x    *; Move to the next position in SRAM

    dec BUFFER_C_C_OFF,x    *; Decrement the buffer current capacity 

    ldaa BUF_L_BYTE_OFF,x   *; Load the last received byte into ACCA
    cmpa #END_OF_MSG_CHAR   *; Check if "end of message char" is received 
    beq _mark_rx_done       *; If "end of message char" mark RX as done

*;  Check if buffer is full
    ldaa BUFFER_C_C_OFF,x      
    cmpa #$00 
    beq _hdl_buf_full   

    bra _r_hdl_dr

_mark_rx_done:
    ldx #CONSTS_S_ADR
    ldaa #$01            
    staa RX_DONE_OFF,x      *; Setting the flag for recieve done to true

    ldx #CONSTS_S_ADR         
    clr BUFFER_C_P_OFF,x    *; BUFFER_C_P_OFF = 0

_r_hdl_dr:
    rts    

*; TODO: Implement better _hdl_buf_full subroutine
*; Handle buffer full
_hdl_buf_full:
    bra _mark_rx_done

*; Transmit loop
_tx_loop:
    jsr _poll_thre          *; Wait until the transmitter holding register is empty
    
    jsr _hdl_thre           *; Handle Transmitter Holding Register Empty

*;  Check if transmitting is done
    ldx #CONSTS_S_ADR
    ldaa TX_DONE_OFF,x
    cmpa #01                    
    beq _r_tx_loop          *; If done return from subroutine

    bra _tx_loop            *; If not done continue with the loop

_r_tx_loop:
    rts                     *; Return from subroutine _tx_loop

*; Poll for THRE before transmitting
_poll_thre:
    ldaa LSRg               *; Read the Line Status Register
    anda #LSR_FLAG_THRE     *; Check if THRE flag is set
    beq _poll_thre          *; If THRE is not set, keep polling
    rts

*; Handle Transmitter Holding Register Empty
_hdl_thre:
    jsr _buf_curr_p_to_x
    ldaa BUFFER_S_ADR,x     *; Load the current data in the buffer into ACCA
    
    jsr _buf_last_byte      *; Buffer the last transmitted byte

    staa RBTHR              *; Store the data into the Transmit Holding Register

    ldx #CONSTS_S_ADR
    inc BUFFER_C_P_OFF,x    *; Move to the next position in buffer

    ldaa BUF_L_BYTE_OFF,x   *; Load the last transmitted byte into ACCA
    cmpa #END_OF_MSG_CHAR   *; Check if "end of message char" is received 
    beq _mark_tx_done       *; If "end of message char" mark TX as done

*;  Check is the whole buffer is read
    ldaa BUFFER_C_P_OFF,x
    cmpa #BUFFER_SIZE_MAX    
    beq _mark_tx_done       *; If the buffer is read mark TX as done
    rts

_mark_tx_done:
    ldx #CONSTS_S_ADR
    ldaa #01                
    staa TX_DONE_OFF,x      *; Set the transmit done flag

    ldx #CONSTS_S_ADR
    clr BUFFER_C_P_OFF,x    *; Buffer Position = 0   

_clr_buf_loop:
    jsr _buf_curr_p_to_x
	clr BUFFER_S_ADR,x      *; Clear data at the current position of the buffer

    ldx #CONSTS_S_ADR
    ldaa BUFFER_C_P_OFF,x
    cmpa #BUFFER_SIZE_MAX   *; Check if the counter is at the end of the buffer
    beq _r_hdl_thre         *; Return to _main_loop

    inc BUFFER_C_P_OFF,x    *; Move to the next position of the buffer

    bra _clr_buf_loop

_r_hdl_thre:
    rts
