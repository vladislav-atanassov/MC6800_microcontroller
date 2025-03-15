*; Define UART registers
RBTHR           equ $2000   *; UART Receive Buffer/Transmit Holding Register
IER             equ $2001   *; Interrupt Enable Register
IIR             equ $2002   *; Interrupt Identification Register
LCR             equ $2003   *; Line Control Register
LSRg            equ $2005   *; Line Status Register

*; Define UART Line Status Register (LSRg) flags
UART_LSR_DR    equ $01      *; Data Ready (DR) flag in LSRg
UART_LSR_THRE  equ $20      *; Transmitter Holding Register Empty (THRE) flag in LSRg

SP_ADR          equ $1FFF   *; Define the SP address
    
    org $EC00               *; Start address of the program in the EPROM

    lds #SP_ADR

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

_main_loop:
    jsr _poll_dr

    ldaa RBTHR              *; Read the received character into ACCA
    psha

    jsr _poll_thre

    pula
    staa RBTHR              *; Write the character back to the UART (echo)

    bra _main_loop

*; Poll for received data
_poll_dr:
    ldaa LSRg               *; Read the Line Status Register
    anda #UART_LSR_DR       *; Check if Data Ready (DR) flag is set

    ldab #$FF
    jsr _delay              *; Delay 

    beq _poll_dr            *; If no data is available, keep polling
    rts

*; Poll for THRE before transmitting
_poll_thre:
    ldaa LSRg               *; Read the Line Status Register
    anda #UART_LSR_THRE     *; Check if THRE flag is set

    ldab #$FF
    jsr _delay              *; Delay
    
    beq _poll_thre          *; If THRE is not set, keep polling
    rts

*; Delay calculated with: value in ACCB * 8(the number of cycles) * (10 * 10e-6) (one cycle of the MCU)
*; Max delay: $FF * 8 * 10e-5 = 2 * 10e-2 seconds
_delay:
    decb
    cmpb #$00
    bne _delay  
    rts

    end