;? Suggesting that instead of pushing the constants and flags into the stack and indexing from the top of the stack,
;? an address space can be reserved just for them and index from the start of it. 
;? That way we reduce the complexity of the code significantly but still getting the benefit of maitainability in the future 
;? in the context of that if the address space for the constants and flags needs to be moved it can be easily done 
;? with just changing the staring address of the memory block that holds them.

;? CONSTS_START_ADR could be defined directly after the buffer 
CONSTS_START_ADR    .equ $100   ; Define the start of the constants memory space   
BUFFER_SIZE_MAX     .equ $ff    ; Define buffer max size   
BUFFER_C_C_OFF      .equ $00    ; Define offset from SP for buffer current capacity

; How the addressing will happen with this approach
    ldx CONSTS_START_ADR        ; Load the start address of the memory block for consts and flags into the index register 
    ldaa BUFFER_C_C_OFF,x       ; Load the desired const or flag with its offset 