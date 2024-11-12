; CS2 address bus is 0010              - added the last 0 to make a nible
; 0010 0000 0000 0000 - HEX ($2000)    - start of UART space 
; 0010 0000 0000 0111 - HEX ($2007)    - end of UART space  

; Register addressing
; $2000   Receiver Buffer (read), Transmitter Holding Register (write)      
; $2001   Interrupt Enable Register
; $2002   Interrupt Identification (read only)
; $2003   Line Control
; $2004   MODEM Control
; $2005   Line Status
; $2006   MODEM Status
; $2007   N/A
; DLAB 1  $2000   Divisor Latch (least significant byte)
; DLAB 1  $2001   Divisor Latch (most significant byte)

; Configuring the register of the UART

; $07 in Interrupt Enable Register - $2001

; $83 in Line control register
; - bit 0, 1      - determines the word lenght ot be 8 bit (set to 1, 1)
; - bit 2         - determines the number of stop bits to be one (set to 0)
; - bit 3, 4, 5   - determines the usage of parity bits (all set to 0)
; - bit 6         - transmits a continuous low signal for an indefinite period (used for resynchronization or error indication)
; - bit 7         - allows acces to the divisor latch to set the baud rate

; $0D in Divisor Latch(LS), $00 in Divisor Latch(MS) - used to work with 9600 baud rate / 2MHz clock

; $03 in Lne Control register - finished using the divisor latch and setTing it low

; Assembler code to configure the registers for UART

org $E000   ; EPROM selected

ldaa $07    ; Configuring Interrupt Enable Register (IER) for RDA, THRE, and LSR   
staa $2001 

ldaa $83    ; Configuring Line control register
staa $2003

ldaa $0D    ; Configuring divisor latch for 9600 Baud rate
staa $2000
ldaa $00
staa $2001

ldaa $03    ; Setting DLAB to 0
staa $2003

ldaa $20                ; Setting /OUT1 to high and /OUT2 to low 
staa MCR

HANDLE_UART_INTR:   
    ldaa $2002      ; Storing the information from the Interrupt Identification in ACCA    

    ; bit 0 is not checked for because we have only one device
    cmpa #$04                       ; Checking for Received Data Available
    beq HANDLE_DATA_RB        
    cmpa #$06                       ; Checking for Receiver Line Status
    beq HANDLE_UART_ERR  
    cmpa #$02                       ; Checking for TX holding Register Empty
    beq HANDLE_TX_EMPTY             
    rts

HANDLE_DATA_RB:           
    ldaa $2000                  ; Reading the Receiver Data Register  
    rts

HANDLE_UART_ERR:     
    ldaa $2005                  ; Reading the Line Status Register
    rts

HANDLE_TX_EMPTY:                
    ldaa "DATA"                 ; Load address of the data to be transmitted (buffer or in RAM)
    staa $2000                  ; Store the byte in the THR (clears the THRE interrupt)
    rts                         
