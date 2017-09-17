

rjmp RESET

.nolist
.include "m16adef.inc"
.include "lcd_dog_asm_driver_m16A.inc"
.list

RESET:
	ldi r16, High(RAMEND)		;stack pointer setup
	out SPH, r16
	ldi r16, Low(RAMEND)
	out SPL, r16

	ldi r16, $00				;setup port
	out DDRA, r16				;PORTA as inputs
	ldi r16, $FF				;initialize PORTB
	out DDRB, r16				;as outputs (LCD Display)

	ldi r16, $00				;PORT-D as inputs
	out PORTD, r16				;
	ldi r16, $FF				;initialize pull-ups...
	out PORTD, r16				;of PORT-D

	rcall init_lcd_dog			;initialize the LCD display (1x)
	rcall clr_dsp_buffs			;clear buff values (1x)
	rcall default_buff			;set up buffer for display
	rcall update_lcd_dog		;display buffers onto lcd

SETUP_ADC:
	ldi r16, $84				;enable ADC and ck/16 by setting ADEN, ADPS2:0
	out ADCSRA, r16				
	ldi r16, $C4				;2.56 Vref, ADC4 single ended
	out ADMUX, r16				;input right justified data

MAIN:
	rcall adc_read				;read voltage values
	rcall mpy16u				;16 bit multiplication (r9:r8) by (r19:r18)
	rcall div32u				;32-bit / 32-bit division
	rcall bin2bcd16				;converts hex to bcd
	rcall unpack_bcd_to_ascii 	;unpacks bcd
	rcall update_lcd_dog		;outputs
	rjmp MAIN					;repeat

;********************************************************************
;NAME:      clr_dsp_buffs
;FUNCTION:  Initializes dsp_buffers 1, 2, and 3 with blanks (0x20)
;ASSUMES:   Three CONTIGUOUS 16-byte dram based buffers named
;           dsp_buff_1, dsp_buff_2, dsp_buff_3.
;RETURNS:   nothing.
;MODIFIES:  r25,r26, Z-ptr
;CALLS:     none
;CALLED BY: main application and diagnostics
;********************************************************************
clr_dsp_buffs:
     ldi R25, 48               ; load total length of both buffer.
     ldi R26, ' '              ; load blank/space into R26.
     ldi ZH, high (dsp_buff_1) ; Load ZH and ZL as a pointer to 1st
     ldi ZL, low (dsp_buff_1)  ; byte of buffer for line 1.
   
    ;set DDRAM address to 1st position of first line.
store_bytes:
     st  Z+, R26       ; store ' ' into 1st/next buffer byte and
                       ; auto inc ptr to next location.
     dec  R25          ; 
     brne store_bytes  ; cont until r25=0, all bytes written.
     ret

;********************************************************************
;NAME:			default_buff
;FUNCTION:		initializes all three lines in buff
;ASSUMES:		BYTE has been allocated in SRAM
;RETURNS:		nothing
;MODIFIES:		SRAM
;CALLS:			load_msg
;CALLED BY:		reset
;********************************************************************

default_buff:
		ldi ZH, HIGH(line1_message<<1)
		ldi ZL, LOW(line1_message<<1)
		rcall load_msg
		ldi ZH, HIGH(line2_message<<1)
		ldi ZL, LOW(line2_message<<1)
		rcall load_msg
		ldi ZH, HIGH(line3_message<<1)
		ldi ZL, LOW(line3_message<<1)
		rcall load_msg
		ret										

line1_message: .db 1, "    .    VDC    ", 0		;string 1
line2_message: .db 1, "----------------", 0		;string 2
line3_message: .db 1, "AutoRun     VM1a", 0		;string 3

;*******************************************************************
;NAME:      load_msg
;FUNCTION:  Loads a predefined string msg into a specified diplay
;           buffer.
;ASSUMES:   Z = offset of message to be loaded. Msg format is 
;           defined below.
;RETURNS:   nothing.
;MODIFIES:  r16, Y, Z
;CALLS:     nothing
;CALLED BY:  
;********************************************************************
; Message structure:
;   label:  .db <buff num>, <text string/message>, <end of string>
;
; Message examples (also see Messages at the end of this file/module):
;   msg_1: .db 1,"First Message ", 0   ; loads msg into buff 1, eom=0
;   msg_2: .db 1,"Another message ", 0 ; loads msg into buff 1, eom=0
;
; Notes: 
;   a) The 1st number indicates which buffer to load (either 1, 2, or 3).
;   b) The last number (zero) is an 'end of string' indicator.
;   c) Y = ptr to disp_buffer
;      Z = ptr to message (passed to subroutine)
;********************************************************************
load_msg:
     ldi YH, high (dsp_buff_1) ; Load YH and YL as a pointer to 1st
     ldi YL, low (dsp_buff_1)  ; byte of dsp_buff_1 (Note - assuming 
                               ; (dsp_buff_1 for now).
     lpm R16, Z+               ; get dsply buff number (1st byte of msg).
     cpi r16, 1                ; if equal to '1', ptr already setup.
     breq get_msg_byte         ; jump and start message load.
     adiw YH:YL, 16            ; else set ptr to dsp buff 2.
     cpi r16, 2                ; if equal to '2', ptr now setup.
     breq get_msg_byte         ; jump and start message load.
     adiw YH:YL, 16            ; else set ptr to dsp buff 2.
        
get_msg_byte:
     lpm R16, Z+               ; get next byte of msg and see if '0'.        
     cpi R16, 0                ; if equal to '0', end of message reached.
     breq msg_loaded           ; jump and stop message loading operation.
     st Y+, R16                ; else, store next byte of msg in buffer.
     rjmp get_msg_byte         ; jump back and continue...
msg_loaded:
     ret

;********************************************************************
;NAME:			adc_read
;FUNCTION:		reads in voltage values using ADC
;ASSUMES:		ADC is set up
;RETURNS:		r9:r8 (10-bit resolution right justified)
;MODIFIES:		R9:R8
;CALLS:			nothing
;CALLED BY:		main
;********************************************************************

adc_read:
	sbi ADCSRA, ADSC			;start conversion
POLLING:						;wait until end of conversion
	sbis ADCSRA, ADIF			;end of conversion yet?
	rjmp POLLING				;repeat until end of conversion 
	sbi ADCSRA, ADIF			;write 1 to clear flag
	in r8, ADCL					;read low byte
	in r9, ADCH					;read high byte
	ret							;return 

	
;***************************************************************************
;*
;* "mpy16u" - 16x16 Bit Unsigned Multiplication
;*
;* This subroutine multiplies the two 16-bit register variables 
;* mp16uH:mp16uL and mc16uH:mc16uL.
;* The result is placed in m16u3:m16u2:m16u1:m16u0.
;*  
;* Number of words	:14 + return
;* Number of cycles	:153 + return
;* Low registers used	:None
;* High registers used  :7 (mp16uL,mp16uH,mc16uL/m16u0,mc16uH/m16u1,m16u2,
;*                          m16u3,mcnt16u)	
;*
;***************************************************************************

;***** Subroutine Register Variables
mpy16u:
.def	mc16uL	=r8			;multiplicand low byte
.def	mc16uH	=r9			;multiplicand high byte
.def	mp16uL	=r18		;multiplier low byte
.def	mp16uH	=r19		;multiplier high byte
.def	m16u0	=r18		;result byte 0 (LSB)
.def	m16u1	=r19		;result byte 1
.def	m16u2	=r20		;result byte 2
.def	m16u3	=r21		;result byte 3 (MSB)
.def	mcnt16u	=r22		;loop counter

;***** Code
	ldi r18, 50 			;conversion factor low byte (0050)
	ldi r19, $00			;conversion factor high bye (0050)

	clr	m16u3				;clear 2 highest bytes of result
	clr	m16u2
	ldi	mcnt16u,16			;init loop counter
	lsr	mp16uH
	ror	mp16uL

m16u_1:	brcc	noad8		;if bit 0 of multiplier set
	add	m16u2,mc16uL		;add multiplicand Low to byte 2 of res
	adc	m16u3,mc16uH		;add multiplicand high to byte 3 of res
noad8:	ror	m16u3			;shift right result byte 3
	ror	m16u2				;rotate right result byte 2
	ror	m16u1				;rotate result byte 1 and multiplier High
	ror	m16u0				;rotate result byte 0 and multiplier Low
	dec	mcnt16u				;decrement loop counter
	brne	m16u_1			;if not done, loop more
	ret


;***************************************************************************
;*
;* "div32u" - 32/32 Bit Unsigned Division
;*
;* Ken Short
;*
;* This subroutine divides the two 32-bit numbers 
;* "dd32u3:dd32u2:dd32u1:dd32u0" (dividend) and "dv32u3:dv32u2:dv32u3:dv32u2"
;* (divisor). 
;* The result is placed in "dres32u3:dres32u2:dres32u3:dres32u2" and the
;* remainder in "drem32u3:drem32u2:drem32u3:drem32u2".
;*  
;* Number of words	:
;* Number of cycles	:655/751 (Min/Max) ATmega16
;* #Low registers used	:2 (drem16uL,drem16uH)
;* #High registers used  :5 (dres16uL/dd16uL,dres16uH/dd16uH,dv16uL,dv16uH,
;*			    dcnt16u)
;* A $0000 divisor returns $FFFF
;*
;***************************************************************************

div32u:
;***** Subroutine Register Variables
.def	drem32u0=r12    ;remainder
.def	drem32u1=r13
.def	drem32u2=r14
.def	drem32u3=r15

.def	dres32u0=r18    ;result (quotient)
.def	dres32u1=r19
.def	dres32u2=r20
.def	dres32u3=r21

.def	dd32u0	=r18    ;dividend
.def	dd32u1	=r19
.def	dd32u2	=r20
.def	dd32u3	=r21

.def	dv32u0	=r22    ;divisor
.def	dv32u1	=r23
.def	dv32u2	=r24
.def	dv32u3	=r25

.def	dcnt32u	=r17

ldi r22, 10
ldi r23, 0
ldi r24, 0
ldi r25, 0

;***** Code
	clr	drem32u0			;clear remainder Low byte
    clr drem32u1
    clr drem32u2
	sub	drem32u3,drem32u3	;clear remainder High byte and carry
	ldi	dcnt32u,33			;init loop counter
d32u_1:
	rol	dd32u0				;shift left dividend
	rol	dd32u1
	rol	dd32u2    
	rol	dd32u3
	dec	dcnt32u				;decrement counter
	brne	d32u_2			;if done
	ret						;return
d32u_2:
	rol	drem32u0			;shift dividend into remainder
    rol	drem32u1
    rol	drem32u2
	rol	drem32u3

	sub	drem32u0,dv32u0		;remainder = remainder - divisor
    sbc	drem32u1,dv32u1
    sbc	drem32u2,dv32u2
	sbc	drem32u3,dv32u3	
	brcc	d32u_3			;branch if reult is pos or zero

	add	drem32u0,dv32u0 	;if result negative restore remainder
	adc	drem32u1,dv32u1
	adc	drem32u2,dv32u2
	adc	drem32u3,dv32u3
	clc						;clear carry to be shifted into result
	rjmp	d32u_1			;else
d32u_3:	sec					;set carry to be shifted into result
	rjmp	d32u_1

;***************************************************************************
;*
;* "bin2BCD16" - 16-bit Binary to BCD conversion
;*
;* This subroutine converts a 16-bit number (fbinH:fbinL) to a 5-digit
;* packed BCD number represented by 3 bytes (tBCD2:tBCD1:tBCD0).
;* MSD of the 5-digit number is placed in the lowermost nibble of tBCD2.
;*
;* Number of words	:25
;* Number of cycles	:751/768 (Min/Max)
;* Low registers used	:3 (tBCD0,tBCD1,tBCD2)
;* High registers used  :4(fbinL,fbinH,cnt16a,tmp16a)	
;* Pointers used	:Z
;*
;***************************************************************************

;***** Subroutine Register Variables

.equ	AtBCD0	=13			;address of tBCD0
.equ	AtBCD2	=15			;address of tBCD1

.def	tBCD0	=r13		;BCD value digits 1 and 0
.def	tBCD1	=r14		;BCD value digits 3 and 2
.def	tBCD2	=r15		;BCD value digit 4
.def	fbinL	=r18		;binary value Low byte
.def	fbinH	=r19		;binary value High byte
.def	cnt16a	=r16		;loop counter
.def	tmp16a	=r17		;temporary value

;***** Code

bin2BCD16:
	ldi	cnt16a,16	;Init loop counter	
	clr	tBCD2		;clear result (3 bytes)
	clr	tBCD1		
	clr	tBCD0		
	clr	ZH		;clear ZH (not needed for AT90Sxx0x)
bBCDx_1:lsl	fbinL		;shift input value
	rol	fbinH		;through all bytes
	rol	tBCD0		;
	rol	tBCD1
	rol	tBCD2
	dec	cnt16a		;decrement loop counter
	brne	bBCDx_2		;if counter not zero
	ret			;   return

bBCDx_2:ldi	r30,AtBCD2+1	;Z points to result MSB + 1
bBCDx_3:
	ld	tmp16a,-Z	;get (Z) with pre-decrement
	subi	tmp16a,-$03	;add 0x03
	sbrc	tmp16a,3	;if bit 3 not clear
	st	Z,tmp16a	;	store back
	ld	tmp16a,Z	;get (Z)
	subi	tmp16a,-$30	;add 0x30
	sbrc	tmp16a,7	;if bit 7 not clear
	st	Z,tmp16a	;	store back
	cpi	ZL,AtBCD0	;done all three?
	brne	bBCDx_3		;loop again if not
	rjmp	bBCDx_1		


;**************************************************************************
;NAME:		unpack_bcd_to_ascii
;FUNCTION:	unpacks bcd numbers and converts to ascii
;ASSUMES:	r14:r13 are bcd values
;RETURNS:	values stored in buffers
;MODIFIES:	SRAM
;CALLS:		ASCII_table
;CALLED BY:	MAIN
;**************************************************************************

unpack_bcd_to_ascii:
		ldi r16, $0F				;load and
		mov r10, r16				;save masking value
		mov r3, r14					;copy BCD2&3
		swap r3						;SWAP BCD2&3
		and r3, r10					;save BCD3
		mov r27, r3					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+4, r22		;store BCD3
		mov r2, r14					;copy BCD2&3
		and r2, r10					;keep BCD2
		mov r27, r2					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+6, r22		;store BCD2
		mov r1, r13					;copy BCD1&0
		swap r1						;swap BCD1&0
		and r1, r10					;save BCD1
		mov r27, r1					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+7, r22		;store BCD1
		mov r0, r13					;copy BCD1&0
		add r0, r10					;save BCD0
		mov r27, r0					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+8, r22		;store BCD0
		ret							;return

;**************************************************************************
;ASCII_table- self-contained subroutine that takes a HEX value
;and points to its associated ASCII value
;modification of BCD lookup table
;
;inputs: Z-pointer
;			-ZH is high Z
;			-ZL is low Z
;		 r16 is a place holder for adc
;		 r27 is the HEX value to be converted
;outputs: result of Z point are loaded into r22
;		  returned to be stored in SRAM
;***************************************************************************

ASCII_table:
		ldi ZH, high (table * 2)	;set Z to point to start of table
		ldi ZL, low (table * 2)		;
		ldi r16, $00				;clear for add w/ carry
		add ZL, r27					;add low byte
		adc ZH, r16					;add in the CY
		lpm r22, Z					;load bit pattern from table into r22
		ret

table: .db $30,$31,$32,$33,$34,$35,$36,$37,$38,$39
		   ;0,  1,  2,  3,  4,  5,  6,  7,  8,	9


		