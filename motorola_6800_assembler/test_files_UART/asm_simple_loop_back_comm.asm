*; Define UART registers
RBTHR           equ $2000   *; UART Receive Buffer/Transmit Holding Register
IER             equ $2001   *; Interrupt Enable Register
IIR             equ $2002   *; Interrupt Identification Register
LCR             equ $2003   *; Line Control Register
LSRg            equ $2005   *; Line Status Register

*; Define UART Line Status Register (LSRg) flags
UART_LSR_DR    equ $01      *; Data Ready (DR) flag in LSRg
UART_LSR_THRE  equ $20      *; Transmitter Holding Register Empty (THRE) flag in LSRg

    org $0F00               *; Start address of the program in the EPROM

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

*; Poll for received data
_poll_rda:
    ldaa LSRg               *; Read the Line Status Register
    anda #UART_LSR_DR       *; Check if Data Ready (DR) flag is set
    beq _poll_rda           *; If no data is available, keep polling

    ldab RBTHR              *; Read the received character into ACCB

*; Poll for THRE before transmitting
_poll_thre:
    ldaa LSRg               *; Read the Line Status Register
    anda #UART_LSR_THRE     *; Check if THRE flag is set
    beq _poll_thre          *; If THRE is not set, keep polling

    stab RBTHR              *; Write the character back to the UART (echo)

    bra _poll_rda           *; Repeat the loop
    
    end

*;!
*;* TESTED AND WORKED AS EXPECTED