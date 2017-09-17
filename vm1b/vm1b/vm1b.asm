/*
 * evm1b.asm
 *
 *  Created: 11/5/2014 7:53:19 PM
 *   Author: Suphasith Udonvudhikai and Brandon Conklin 
 */ 
 ;This program is modification of "vm1b"
 ;
 ;This program will read incoming voltage values and display onto the
 ;LCD display.
 ;
 ;Voltmeter will use a range of 0-5V; target voltage range of 0.25-4V.
 ;Vref will be 4.8V from external REF198.
 ;
 ;External ADC (MAX144) used as opposed to internal
 ;
 ;MAX144 and LCD both SPI
 ;Require controlling which is being used when
 ;
 ;MAX144 outputs 12-bit data. High 8 read in first, followed by low 8
 ;
 ;No multiplying or dividing subroutines needed like in previous lab
 ;due to MAX144 outputting full voltage level.
 ;
 ;SCK and oscillator frequency prescaled by 16.
 ;
 ;New SPI registers will be utilized
 ;
 ;HOLD mode generated when GO PBSW is pressed
 ;switch debouncing


.org 00
rjmp RESET
.org $02
rjmp toggle_isr

.nolist
.include "m16adef.inc"
.include "lcd_dog_asm_driver_m16A.inc"
.list

RESET:
	ldi r16, High(RAMEND)		;stack pointer setup
	out SPH, r16
	ldi r16, Low(RAMEND)
	out SPL, r16

	ldi r16, $FF				;initialize PORTB
	out DDRB, r16				;as outputs (LCD Display)

	sbi PORTB, 0				;turnoff MAX144

	ldi r16, $00				;setup PortD
	out DDRD, r16				;as inputs
	ldi r16, $FF				;
	out PORTD, r16				;turn on pullups

	rcall init_lcd_dog			;initialize the LCD display (1x)
	rcall clr_dsp_buffs			;clear buff values (1x)
	rcall default_buff			;set up buffer for display
	rcall update_lcd_dog		;display buffers onto lcd

	sei							;set global interupt
	ldi r16, $03				;setup INT0 on rising edges
	out MCUCR, r16				;
	ldi r16, 1<<INT0			;
	out GICR, r16				;set external interupt
	set							;set t-flag					

MAIN:
	brts continue				;go to run mode
	rcall hold					;jump to hold

continue:
	rcall read_voltage			;read voltage values
	rcall bin2bcd16				;converts hex to bcd
	rcall default_buff			;set up buffer for display
	rcall unpack_bcd_to_ascii 	;unpacks bcd
	rcall update_lcd_dog		;outputs
	rjmp MAIN					;repeat

;*********************************************************************
;hold: is a self-contained subroutine in which the voltmeter
;is in HOLD MODE.
;
;Previously read voltage will still be displayed, new 3rd row display
;stay here until toggle T-flag.
;
;INPUTS=
;OUTPUTS=LCD Display(3rd row of LCD is changed)
;**********************************************************************

hold:
	ldi r16, $FF	
	out DDRB, r16
	cbi PORTB, 4					;clear PB4 to enable LCD connection
	ldi ZH, High(line4_message<<1)
	ldi ZL, Low(line4_message<<1)
	rcall load_msg
	rcall update_lcd_dog
	brtc hold
	ret

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
		ldi r16, $FF				;setup PORTB as outputs
		out DDRB, r16				;
		cbi PORTB, 4				;enable LCD Dog
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
line2_message: .db 2, "----------------", 0		;string 2
line3_message: .db 3, "AutoRun     VM1a", 0		;string 3
line4_message: .db 3, "HOLD        VM1b", 0		;string 4

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
;NAME:      read_voltge
;FUNCTION:  reads a 12-bit voltage value from MAX144
;ASSUMES:   nothing
;RETURNS:   R19:R18
;MODIFIES:  R19,R18,R16
;CALLS:     nothing
;CALLED BY: main application 
;********************************************************************
read_voltage: 
	ldi r16, (1<<7)|(1<<0)
	out DDRB, r17 
	ldi r16, (1<<SPE)|(1<<MSTR)|(1<<SPR1)	;enable SPI, Master, and  fck/64
	out SPCR, r16

	cbi PORTB, 0				;CLR PB0 to turn on CS for MAX144
	ldi r16, $FF				;garbage value 
	out SPDR, r16				;load garbage value to start transmission

high_byte:
	sbis SPSR, SPIF				;poll until first byte is read
	rjmp high_byte				;
	in r19, SPDR				;load high byte
	andi r19, $0F				;mask bit

start:
	ldi r16, $FF				;garbage value
	out SPDR, r16				;start second transmission
	
low_byte:
	sbis SPSR,SPIF				;poll until low byte is read
	rjmp low_byte				;
	in r18, SPDR				;load low_byte
	sbi PORTB, 0				;turn off MAX144
	ret	 

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
;ASSUMES:	r14:r3 are bcd values
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
		sts dsp_buff_1+3, r22		;store BCD3
		mov r2, r14					;copy BCD2&3
		and r2, r10					;keep BCD2
		mov r27, r2					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+5, r22		;store BCD2
		mov r1, r13					;copy BCD1&0
		swap r1						;swap BCD1&0
		and r1, r10					;save BCD1
		mov r27, r1					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+6, r22		;store BCD1
		mov r0, r13					;copy BCD1&0
		and r0, r10					;save BCD0
		mov r27, r0					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+7, r22		;store BCD0
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


;**************************************************************************
;NAME:		toggle_isr
;FUNCTION:	sets t flag after switch debounce if button was pressed
;ASSUMES:	interupts are enabled
;RETURNS:	t-flag
;MODIFIES:	SREG
;CALLS:		nothing
;CALLED BY:	External
;**************************************************************************

toggle_isr:
	push r16
	push r17
	in r16, SREG
	push r16


	delay:	ldi r16, 10			;intiazlize outer loop (1us)
	again:	ldi r17, 190		;initialize inner loop (1us)
	here:	nop					;waste clock cycle (2us)
			nop										
 			dec r17				;r17 decrements until (z = 0) (1us)
			brne here			;keep repeating until (z = 0) (1/2 us)
			dec r16				;outer loop decrements 
			brne again			;keep repeating until (z = 0) (1/2 us)

	in r16, PIND				;read in values for 
	andi r16, $80				;mask bits
	cpi r16, $80				;compare value to logic-1
	breq almost_done			;if !=, debounce occured. end    
	brts cleart					;if T=1, jump to clr
	brtc sett					;if T=0, jump to set

	cleart:
		pop r16
		out SREG, r16
		clt						;clear T-FLag (HOLD)
		rjmp done				;dont run through sett
	sett:
		pop r16
		out SREG, r16
		set						;set T-FLag(RUN)
		rjmp done				;dont run through almost_done
	almost_done:
		pop r16
		out SREG, r16
	done:
		pop r17
		pop r16
		reti