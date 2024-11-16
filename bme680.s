PORTB = $6000
PORTA = $6001
DDRB  = $6002
DDRA  = $6003
PCR   = $600c
IFR   = $600d
IER   = $600e

E  = %10000000
RW = %01000000
RS = %00100000

SCL  = %00010000
MOSI = %00001000
MISO = %00000100
CS   = %00000010

READ_BYTE  = $0000   ; used as return value of read_byte
WRITE_BYTE = $0001   ; used as argument value of write_byte

; calibration parameters
T1_MSB          = $0002
T1_LSB          = $0003
T2_MSB          = $0004
T2_LSB          = $0005
T3              = $0006

TEMP_LSB        = $0008
TEMP_MSB        = $0009

; here shall be arguments and return value for 32bit functions
ADD32_A         = $000e ; 4 bytes
ADD32_B         = $0012 ; 4 bytes
ADD32_RES       = $0016 ; 4 bytes

SUB32_A         = $001a ; 4 bytes
SUB32_B         = $001e ; 4 bytes
SUB32_RES       = $0022 ; 4 bytes

MUL32_A         = $0026 ; 4 bytes
MUL32_B         = $002f ; 4 bytes
MUL32_RES       = $0033 ; 4 bytes

SHL32_A         = $0038 ; 4 bytes
SHL32_B         = $003c ; 1 byte
SHL32_RES       = $003d ; 4 bytes

SHR32_A         = $0041 ; 4 bytes
SHR32_B         = $0045 ; 1 byte
SHR32_RES       = $0046 ; 4 bytes

OR32_A          = $004a ; 4 bytes
OR32_B          = $004e ; 4 bytes
OR32_RES        = $0052 ; 4 bytes

; get_temp local variables
VAR1            = $0056 ; 4 bytes
VAR2            = $005a ; 4 bytes
CALC_TEMP_LSB   = $005e ; 1 byte
CALC_TEMP_MSB   = $005f ; 1 byte

; print_number variables
REMAINDER       = $2000 ; 2 bytes
QUOTIENT        = $2002 ; 2 bytes
DIGIT_STRING    = $2004 ; null terminated string to hold digits in correct order
                        ; up to 6 bytes since 2 bytes can represent up to 65535
NUMBER         = $200a ; 2 bytes

        .org $8000

entry_point:
        jsr main
halt:
        jmp halt

main:
        ; Configure output pins

        ; the most significant 3 bits are
        ; still used for the LCD screen.
        ; the next 4 are SCL, MOSI, MISO, and CS in this order
        lda #%11111010
        sta DDRA

        lda #%11111111
        sta DDRB

        ; Turn off sensor by setting CS high
        lda #CS
        sta PORTA

        jsr configure_lcd

        ; read calibration data
        lda #$ea
        jsr read_byte
        lda READ_BYTE
        sta T1_MSB

        lda #$e9
        jsr read_byte
        lda READ_BYTE
        sta T1_LSB

        lda #$8b
        jsr read_byte
        lda READ_BYTE
        sta T2_MSB

        lda #$8a
        jsr read_byte
        lda READ_BYTE
        sta T2_LSB

        lda #$8c
        jsr read_byte
        lda READ_BYTE
        sta T3

        ; set spi_mem_page to 1
        lda #$10
        sta WRITE_BYTE
        lda #$73
        jsr write_byte

        ; set oversampling to x1 for temperature
        lda #$20
        sta WRITE_BYTE
        lda #$74
        jsr write_byte

read_temp_loop:
        ; set mode to forced mode so that 
        ; sensor does a measurement
        ; (osrs_t is still set to 2 and mode set to 1)
        lda #$21
        sta WRITE_BYTE
        lda #$74
        jsr write_byte

        ; send cursor home
        lda #%00000010
        jsr lcd_instruction

        ; note that this could be read in a single read 
        ; from the sensor but our subroutine doesn't 
        ; implement that...

        ; read temp_lsb
        lda #$23
        jsr read_byte
        lda READ_BYTE
        sta TEMP_LSB

        ; read temp_msb
        lda #$22
        jsr read_byte
        lda READ_BYTE
        sta TEMP_MSB

        jsr get_temp

        lda CALC_TEMP_LSB
        sta NUMBER
        lda CALC_TEMP_MSB
        sta NUMBER + 1

        jsr print_number

        jmp read_temp_loop

        rts


; ====================== get_temp =======================
; converts temp read from sensor (in TEMP_LSB and TEMP_MSB)
; to celsius
get_temp:
        ; get temp_adc in the API's 32-bit format
        ; where it is defined as:
        ; temp_msb << 12 | temp_lsb << 4 | temp_xlsb >> 4
        ; (due to x1 oversampling we ignore temp_xlsb)
        lda TEMP_MSB
        sta SHL32_A

        lda #0
        sta SHL32_A + 1
        sta SHL32_A + 2
        sta SHL32_A + 3

        lda #12
        sta SHL32_B

        jsr shl32

        lda SHL32_RES
        sta OR32_A
        lda SHL32_RES + 1
        sta OR32_A + 1
        lda SHL32_RES + 2
        lda OR32_A + 2
        lda SHL32_RES + 3
        lda OR32_A + 3

        lda TEMP_LSB
        sta SHL32_A

        lda #0
        sta SHL32_A + 1
        sta SHL32_A + 2
        sta SHL32_A + 3

        lda #4
        sta SHL32_B

        jsr shl32

        lda SHL32_RES
        sta OR32_B
        lda SHL32_RES + 1
        sta OR32_B + 1
        lda SHL32_RES + 2
        sta OR32_B + 2
        lda SHL32_RES + 3
        sta OR32_B + 3

        jsr or32

        ; temp_adc >> 3
        lda OR32_RES
        sta SHR32_A
        lda OR32_RES + 1
        sta SHR32_A + 1
        lda OR32_RES + 2
        sta SHR32_A + 2
        lda OR32_RES + 3
        sta SHR32_A + 3

        lda #3
        sta SHR32_B

        jsr shr32

        ; par_t1 << 1
        lda T1_LSB
        sta SHL32_A
        lda T1_MSB
        sta SHL32_A + 1
        lda #0
        sta SHL32_A + 2
        sta SHL32_A + 3

        lda #1
        sta SHL32_B

        jsr shl32

        ; var1 = (temp_adc >> 3) - (par_t1 << 1)
        lda SHR32_RES
        sta SUB32_A
        lda SHR32_RES + 1
        sta SUB32_A + 1
        lda SHR32_RES + 2
        sta SUB32_A + 2
        lda SHR32_RES + 3
        sta SUB32_A + 3

        lda SHL32_RES
        sta SUB32_B
        lda SHL32_RES + 1
        sta SUB32_B + 1
        lda SHL32_RES + 2
        sta SUB32_B + 2
        lda SHL32_RES + 3
        sta SUB32_B + 3
        
        jsr sub32

        lda SUB32_RES
        sta VAR1
        lda SUB32_RES + 1
        sta VAR1 + 1
        lda SUB32_RES + 2
        sta VAR1 + 2
        lda SUB32_RES + 3
        sta VAR1 + 3

        ; var2 = (var1 * par_t2) >> 11;
        lda VAR1
        sta MUL32_A
        lda VAR1 + 1
        sta MUL32_A + 1
        lda VAR1 + 2
        sta MUL32_A + 2
        lda VAR1 + 3
        sta MUL32_A + 3

        lda T2_LSB
        sta MUL32_B
        lda T2_MSB
        sta MUL32_B + 1
        lda #0
        sta MUL32_B + 2
        sta MUL32_B + 3

        jsr mul32

        lda MUL32_RES
        sta SHR32_A
        lda MUL32_RES + 1
        sta SHR32_A + 1
        lda MUL32_RES + 2
        sta SHR32_A + 2
        lda MUL32_RES + 3
        sta SHR32_A + 3

        lda #11
        sta SHR32_B

        jsr shr32

        lda SHR32_RES
        sta VAR2
        lda SHR32_RES + 1
        sta VAR2 + 1
        lda SHR32_RES + 2
        sta VAR2 + 2
        lda SHR32_RES + 3
        sta VAR2 + 3

        ; var3 = ((var1 >> 1) * (var1 >> 1)) >> 12

        lda VAR1
        sta SHR32_A
        lda VAR1 + 1
        sta SHR32_A + 1
        lda VAR1 + 2
        sta SHR32_A + 2
        lda VAR1 + 3
        sta SHR32_A + 3

        jsr shr32

        lda SHR32_RES
        sta MUL32_A
        sta MUL32_B
        lda SHR32_RES + 1
        sta MUL32_A + 1
        sta MUL32_B + 1
        lda SHR32_RES + 2
        sta MUL32_A + 2
        sta MUL32_B + 2
        lda SHR32_RES + 3
        sta MUL32_A + 3
        sta MUL32_B + 3

        jsr mul32

        lda MUL32_RES
        sta SHR32_A
        lda MUL32_RES + 1
        sta SHR32_A + 1
        lda MUL32_RES + 2
        sta SHR32_A + 2
        lda MUL32_RES + 3
        sta SHR32_A + 3
        
        lda #12
        sta SHR32_B
        jsr shr32

        ; var3 = (var3 * (par_t3 << 4)) >> 14

        lda SHR32_RES
        sta MUL32_A
        lda SHR32_RES + 1
        sta MUL32_A + 1
        lda SHR32_RES + 2
        sta MUL32_A + 2
        lda SHR32_RES + 3
        sta MUL32_A + 3

        lda T3
        sta SHL32_A
        lda #0
        sta SHL32_A + 1
        sta SHL32_A + 2
        sta SHL32_A + 3

        lda #4
        sta SHL32_B
        jsr shl32

        lda SHL32_RES
        sta MUL32_B
        lda SHL32_RES + 1
        sta MUL32_B + 1
        lda SHL32_RES + 2
        sta MUL32_B + 2
        lda SHL32_RES + 3
        sta MUL32_B + 3

        jsr mul32

        lda MUL32_RES
        sta SHR32_A
        lda MUL32_RES + 1
        sta SHR32_A + 1
        lda MUL32_RES + 2
        sta SHR32_A + 2
        lda MUL32_RES + 3
        sta SHR32_A + 3

        lda #14
        sta SHR32_B

        jsr shr32

        ; t_fine = var2 + var3

        lda SHR32_RES
        sta ADD32_B
        lda SHR32_RES + 1
        sta ADD32_B + 1
        lda SHR32_RES + 2
        sta ADD32_B + 2
        lda SHR32_RES + 3
        sta ADD32_B + 3

        lda VAR2
        sta ADD32_A
        lda VAR2 + 1
        sta ADD32_A + 1
        lda VAR2 + 2
        sta ADD32_A + 2
        lda VAR2 + 3
        sta ADD32_A + 3

        jsr add32

        ; calc_temp = (int16_t) ((t_fine * 5) + 128) >> 8)

        lda ADD32_RES
        sta MUL32_A
        lda ADD32_RES + 1
        sta MUL32_A + 1
        lda ADD32_RES + 2
        sta MUL32_A + 2
        lda ADD32_RES + 3
        sta MUL32_A + 3

        lda #5
        sta MUL32_B
        lda #0
        sta MUL32_B + 1
        sta MUL32_B + 2
        sta MUL32_B + 3

        jsr mul32

        lda MUL32_RES
        sta ADD32_A
        lda MUL32_RES + 1
        sta ADD32_A + 1
        lda MUL32_RES + 2
        sta ADD32_A + 2
        lda MUL32_RES + 3
        sta ADD32_A + 3

        lda #128
        sta ADD32_B
        lda #0
        sta ADD32_B + 1
        sta ADD32_B + 2
        sta ADD32_B + 3

        jsr add32

        lda ADD32_RES
        sta SHR32_A
        lda ADD32_RES + 1
        sta SHR32_A + 1
        lda ADD32_RES + 2
        sta SHR32_A + 2
        lda ADD32_RES + 3
        sta SHR32_A + 3

        lda #8
        sta SHR32_B

        jsr shr32

        lda SHR32_RES
        sta CALC_TEMP_LSB

        lda SHR32_RES + 1
        sta CALC_TEMP_MSB

        rts
; ====================== get_temp =======================


; ====================== add32 =======================
add32:
        clc

        lda ADD32_A
        adc ADD32_B
        sta ADD32_RES

        lda ADD32_A + 1
        adc ADD32_B + 1
        sta ADD32_RES + 1

        lda ADD32_A + 2
        adc ADD32_B + 2
        sta ADD32_RES + 2

        lda ADD32_A + 3
        adc ADD32_B + 3
        sta ADD32_RES + 3

        rts
; ====================== add32 =======================


; ====================== sub32 =======================
sub32:
        sec

        lda SUB32_A
        sbc SUB32_B
        sta SUB32_RES

        lda SUB32_A + 1
        sbc SUB32_B + 1
        sta SUB32_RES + 1

        lda SUB32_A + 2
        sbc SUB32_B + 2
        sta SUB32_RES + 2

        lda SUB32_A + 3
        sbc SUB32_B + 3
        sta SUB32_RES + 3

        rts
; ====================== sub32 =======================


; ====================== mul32 =======================
; note that it destroys MUL32_A and MUL32_B
; modulo 2^32 because i'm guessing we don't really need
; the 64-bit result for the temperature computation
mul32:
        lda #0
        sta MUL32_RES
        sta MUL32_RES + 1
        sta MUL32_RES + 2
        sta MUL32_RES + 3
        ldx #32
mul32_loop:
        lsr MUL32_B + 3
        ror MUL32_B + 2
        ror MUL32_B + 1
        ror MUL32_B
        bcc mul32_skip
        clc
        lda MUL32_A
        adc MUL32_RES
        sta MUL32_RES
        lda MUL32_A + 1
        adc MUL32_RES + 1
        sta MUL32_RES + 1
        lda MUL32_A + 2
        adc MUL32_RES + 2
        sta MUL32_RES + 2
        lda MUL32_A + 3
        adc MUL32_RES + 3
        sta MUL32_RES + 3
mul32_skip:
        asl MUL32_A
        rol MUL32_A + 1
        rol MUL32_A + 2
        rol MUL32_A + 3
        dex
        bne mul32_loop
        rts
; ====================== mul32 =======================


; ====================== shl32 =======================
shl32:
        lda SHL32_A
        sta SHL32_RES
        lda SHL32_A + 1
        sta SHL32_RES + 1
        lda SHL32_A + 2
        sta SHL32_RES + 2
        lda SHL32_A + 3
        sta SHL32_RES + 3

        lda SHL32_B
        tax
shl32_loop:
        beq shl32_exit

        clc
        lda SHL32_RES
        rol
        sta SHL32_RES
        lda SHL32_RES + 1
        rol
        sta SHL32_RES + 1
        lda SHL32_RES + 2
        rol
        sta SHL32_RES + 2
        lda SHL32_RES + 3
        rol
        sta SHL32_RES + 3

        sec
        txa
        sbc #1
        tax
        jmp shl32_loop

shl32_exit:
        rts
; ====================== shl32 =======================

; ====================== shr32 =======================
shr32:
        lda SHR32_A
        sta SHR32_RES
        lda SHR32_A + 1
        sta SHR32_RES + 1
        lda SHR32_A + 2
        sta SHR32_RES + 2
        lda SHR32_A + 3
        sta SHR32_RES + 3

        lda SHR32_B
        tax
shr32_loop:
        beq shr32_exit

        clc
        lda SHR32_RES + 3
        ror
        sta SHR32_RES + 3
        lda SHR32_RES + 2
        ror
        sta SHR32_RES + 2
        lda SHR32_RES + 1
        ror
        sta SHR32_RES + 1
        lda SHR32_RES
        ror
        sta SHR32_RES

        sec
        txa
        sbc #1
        tax

        jmp shr32_loop
shr32_exit:
        rts
; ====================== shr32 =======================

; ====================== or32 =======================
or32:
        lda OR32_A
        ora OR32_B
        sta OR32_RES
        lda OR32_A + 1
        ora OR32_B + 1
        sta OR32_RES + 1
        lda OR32_A + 2
        ora OR32_B + 2
        sta OR32_RES + 2
        lda OR32_A + 3
        ora OR32_B + 3
        sta OR32_RES + 3

        rts
; ====================== or32 =======================


; ====================== read_byte =======================
; read byte at address in A and return byte in READ_BYTE variable
read_byte:
        ; send address in 7-bit width with the eight bit set
        ; to 1 a as a read bit from datasheet SPI section
        ora #$80
        jsr send_byte

        lda #8
        tay

        lda #0
        sta READ_BYTE
        clc

receive_bit:
        rol READ_BYTE
        lda #0
        sta PORTA
        lda #SCL
        sta PORTA

        lda PORTA
        and #MISO
        beq byte_loop_check
        sec

byte_loop_check:
        dey
        bne receive_bit

        ; shift that last bit in
        rol READ_BYTE

        ; turn sensor off
        lda #CS
        sta PORTA

        rts

; ====================== read_byte =======================

; ====================== write_byte =======================
; write byte at address A with value of WRITE_BYTE
write_byte:
        ; send address in 7-bit width with the eight bit set
        ; to 0 a as a write bit from datasheet SPI section
        and #$7f
        jsr send_byte

        lda WRITE_BYTE
        jsr send_byte

        ; turn sensor off
        lda CS
        sta PORTA

        rts
; ====================== write_byte =======================

; ====================== send_byte =======================
; send byte in A out MOSI line
send_byte:
        tax
        lda #8
        tay
        clc

send_byte_loop:
        txa
        rol
        tax
        bcs send_byte_write_one

        lda #0
        sta PORTA
        lda #SCL
        sta PORTA
        jmp send_byte_loop_check

send_byte_write_one:
        lda #MOSI
        sta PORTA
        lda #(SCL | MOSI)
        sta PORTA

send_byte_loop_check:
        dey
        bne send_byte_loop

        rts
; ====================== send_byte =======================


; ====================== print_number =======================
; print 2 byte number to LCD screen in decimal base
print_number:
        ; disable interrupts to not modify NUMBER in the middle of 
        ; where we need it
        sei     
        lda NUMBER
        sta QUOTIENT
        lda NUMBER + 1
        sta QUOTIENT + 1
        cli

        lda #0
        sta DIGIT_STRING

get_digit:
        lda #0
        sta REMAINDER
        sta REMAINDER + 1
        clc

        ldx #16

divide_loop:
        rol QUOTIENT
        rol QUOTIENT + 1
        rol REMAINDER
        rol REMAINDER + 1

        sec                 
        lda REMAINDER
        sbc #10             
        tay                 
        lda REMAINDER + 1
        sbc #0              ; in case we borrowed

        bcc ignore_result   
        sty REMAINDER      
        sta REMAINDER + 1

ignore_result:
        dex
        bne divide_loop

        rol QUOTIENT
        rol QUOTIENT + 1

        lda REMAINDER
        clc
        adc #"0"
        jsr push_char

        lda QUOTIENT
        ora QUOTIENT + 1
        bne get_digit

        jsr print_string

        rts
; ====================== print_number =======================


; ====================== push_char =======================
; push character in register A to the beginning of the DIGIT_STRING
push_char:
        ldy #0

push_char_loop:
        pha                     

        lda DIGIT_STRING, y     
        tax                     

        pla     
        sta DIGIT_STRING, y    

        iny                   
        txa                  

        bne push_char_loop

        sta DIGIT_STRING, y
        rts
; ====================== push_char =======================


; ====================== print_string =======================
; prints null terminated string DIGIT_STRING
print_string:
        ldx #0

print_string_loop:
        lda DIGIT_STRING, x

        beq print_string_done

        jsr print_char
        inx
        jmp print_string_loop

print_string_done:
        rts
; ====================== print_string =======================


; ====================== configure_lcd =======================
configure_lcd:

        ; Clear display
        lda #%00000001
        jsr lcd_instruction

        ; Function set
        lda #%00111000
        jsr lcd_instruction

        ; Display on/off control
        lda #%00001110
        jsr lcd_instruction

        ; Entry mode set
        lda #%00000110
        jsr lcd_instruction

        rts
; ====================== configure_lcd =======================


; ====================== lcd_wait =======================
lcd_wait:
        ; push accumulator to save for call to lcd_instruction
        pha

        ; set port b as input to read busy flag
        lda #%00000000
        sta DDRB

lcd_wait_loop:
        ; send read busy flag instruction to lcd
        lda #RW
        sta PORTA
        lda #(RW | E)
        sta PORTA

        lda PORTB
        and #%10000000
        bne lcd_wait_loop

        lda #RW
        sta PORTA

        ; set port b as output again
        lda #%11111111
        sta DDRB

        pla

        rts
; ====================== lcd_wait =======================


; ====================== lcd_instrucction =======================
lcd_instruction:
        jsr lcd_wait

        sta PORTB
        lda #0
        sta PORTA
        lda #E
        sta PORTA
        lda #0
        sta PORTA
        rts
; ====================== lcd_instrucction =======================


; ====================== print_char =======================
print_char:
        jsr lcd_wait

        sta PORTB
        lda #RS
        sta PORTA
        lda #(RS | E)
        sta PORTA
        lda #RS
        sta PORTA
        rts
; ====================== print_char =======================

nmi:
irq:
        rti

        .org $fffa
        .word nmi
        .word entry_point
        .word irq 

