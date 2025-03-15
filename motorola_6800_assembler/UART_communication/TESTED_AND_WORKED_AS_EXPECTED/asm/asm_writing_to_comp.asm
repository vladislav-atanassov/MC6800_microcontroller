*; Define UART registers
RBTHR           equ $2000   *; UART Receive Buffer/Transmit Holding Register
IER             equ $2001   *; Interrupt Enable Register
IIR             equ $2002   *; Interrupt Identification Register
LCR             equ $2003   *; Line Control Register
MCR             equ $2004   *; Modem Control Register  
LSRg            equ $2005   *; Line Status Register

*; Define UART Line Status flags
UART_FLAG_RLS   equ $06     *; Reciever Line Status (RLS) flag IIR
UART_FLAG_RDA   equ $04     *; Received Data Available (RDA) flag IIR
UART_FLAG_THRE  equ $02     *; Transmitter Holding Register Empty (THRE) flag IIR

SP_ADR           equ $1FFF  *; Define the SP address

    org $0000               *; Start address of the program in the EPROM

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

    ldab #'0'               *; Store '0' to transmit it to the computer

_tx_continue:
    stab RBTHR
    incb
    cmpb #'9'
    bne _poll_thre

    ldab #'0'
    bra _poll_thre

*; Poll until the THRE flag is raised
_poll_thre:
    ldaa IIR                *; 
    cmpa #UART_FLAG_THRE    *; 
    beq _tx_continue

    bne _poll_thre           *; If THRE is not set and no errors, continue polling

    end
    
*;!
*;* TESTED AND WORKED AS EXPECTED