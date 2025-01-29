*; Define UART registers
RBTHR           equ $2000   *; UART Receive Buffer/Transmit Holding Register
IER             equ $2001   *; Interrupt Enable Register
IIR             equ $2002   *; Interrupt Identification Register
LCR             equ $2003   *; Line Control Register
MCR             equ $2004   *; Modem Control Register  
LSRg            equ $2005   *; Line Status Register

*; Define UART Line Status flags
UART_FLAG_RDA    equ $04    *; Received Data Available (RDA) flag IIR
UART_FLAG_THRE   equ $02    *; Transmitter Holding Register Empty (THRE) IIR

SP_ADR           equ $1FFF  *; Define the SP address

    org $0F00               *; Start address of the program in the EPROM

*; Initialize 
_init_uart:
    ldaa #$83               *; Set DLAB to access divisor registers
    staa LCR                *; Write to Line Control Register

    ldaa #$0D               *; Set low byte of baud rate divisor (9600 baud)
    staa RBTHR              *; Write to Divisor Latch Low Byte
    ldaa #$00               *; Set high byte of baud rate divisor
    staa IER                *; Write to Divisor Latch High Byte

    ldaa #$03               *; Clear DLAB, set 8-bit data, no parity, 1 stop bit
    staa LCR                *; Write to Line Control Register

    ldaa #$07               *; Enable RDA and THRE interrupt flags
    staa IER                *; Write to Interrupt Enable Register

*; Initialize SP
    lds #SP_ADR             *; Set stack pointer to top of SRAM ($1F00)

*; Main loop
_main_loop:
*;  Setting /OUT1 not active and /OUT2 not active 
    ldaa #$0C   
    staa MCR

*; Poll until the RDA flag is raised
_poll_rda:
    ldaa IIR                *; 
    cmpa #UART_FLAG_RDA     *; 
    bne _poll_rda           *; If RDA is not set, continue polling
    
    ldaa RBTHR              *; Load the received data into ACCA
    psha                    *; Push the data onto the stack

*;  Setting /OUT1 active and /OUT2 not active 
    ldaa #$08
    staa MCR

*; Poll until the THRE flag is raised
_poll_thre:
    ldaa IIR                *;
    cmpa #UART_FLAG_THRE    *;
    beq _poll_thre          *; If THRE is not set, continue polling

    pula                    *; Pull the data from the stack into ACCA
    staa RBTHR              *; Write the data to Transmit Holding Register (THR)

*;  Setting /OUT1 active and /OUT2 active 
    ldaa #$00
    staa MCR
    
    bra _main_loop          *; Repeat the process

    end
