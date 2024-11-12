MCR .equ $2004  ; MODEM Control Register     

    .org $0C00  ; Address to store the program in the EPROM

    ldaa #$04   ; Setting /OUT1 to low and /OUT2 to high 
    staa MCR

loop nop        ; "while(true)" loop to prevent reading other memory after the instructions
    bra loop                

    .end

;!
;* TESTED AND WORKED AS EXPECTED
