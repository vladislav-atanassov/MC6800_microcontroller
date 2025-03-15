MCR equ $2004   *; MODEM Control Register     

    org $EF00   *; Address to store the program in the EPROM

    ldaa #$04   *; Loading a value that will set /OUT1 to low and /OUT2 to high
    staa $0101  *; Storing the value in an address in the SRAM

    ldab $0101  *; Loading the value
    stab MCR    *; Setting /OUT1 to low and /OUT2 to high 

loop:
    nop         *; "while(true)" loop to prevent reading other memory after the instructions
    bra loop                

*;!
*;* TESTED AND WORKED AS EXPECTED
          
