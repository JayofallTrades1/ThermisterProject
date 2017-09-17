/*
 * evm1c.asm
 *
 *  Created: 11/6/2014 2:11:23 PM
 *   Author: Suphasith Usdonvudhikai and Brandon Conklin
 */ 
 ;This program is modification of "evm1a"
 ;
 ;This program will read incoming voltage values and display onto the
 ;LCD display.
 ;
 ;Voltmeter will use a range of 0-4V; target voltage range of 0.25-4V.
 ;Vref will be 4.096V from external REF198.
 ;This applies 1 mV accuracy.
 ;
 ;External ADC (MAX144) used as opposed to internal
 ;
 ;MAX144 and LCD both SPI
 ;Require controlling which is being used when
 ;
 ;MAX144 outputs 12-bit data. High 8 read in first, followed by low 8
 ;first 4 bits of high byte are "garbage"
 ;
 ;No multiplying or dividing subroutines needed like in previous lab
 ;due to MAX144 outputting full voltage level.
 ;
 ;SCK and oscillator frequency prescaled by 16.
 ;
 ;New SPI registers will be utilized
 ;
 ;"Capture" Mode will be utilied to save voltage value on screen; replaces
 ;"HOLD" Mode.
 ;
 ;Buzzer will also be utilized.


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

	ldi r16, $FF				;initialize PORTB
	out DDRB, r16				;as outputs (LCD Display)

	sbi PORTB, 0				;turnoff MAX144

	rcall init_lcd_dog			;initialize the LCD display (1x)
	rcall clr_dsp_buffs			;clear buff values (1x)
	rcall default_buff			;set up buffer for display
	rcall update_lcd_dog		;display buffers onto lcd

main:
	rcall read_voltage			;uses SPI protocol to read in voltages
	rcall bin2BCD16				;convert
	rcall unpack_bcd_to_ascii	;convert to ascii

display:
	ldi r16, $FF				;setup portB 
	out PORTB, r16				;as outputs
	cbi PORTB, 4				;CLR PB4 to enable LCD Connection 
	ldi ZH, HIGH(line4_message<<1)
	ldi ZL, LOW(line4_message<<1)
	rcall load_msg
	rcall update_lcd_dog		;output to display
	rjmp main					;repeat


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

start_high:
	ldi r16, $FF				;garbage value 
	out SPDR, r16				;load garbage value to start transmission

high_byte:
	sbis SPSR, SPIF				;poll until first byte is read
	rjmp high_byte				;
	in r19, SPDR				;load high byte
	andi r19, $0F				;mask bit

start_low:
	ldi r16, $FF				;garbage value
	out SPDR, r16				;start second transmission
	
low_byte:
	sbis SPSR,SPIF				;poll until low byte is read
	rjmp low_byte				;
	in r18, SPDR				;load low_byte
	sbi PORTB, 0				;turn off MAX144

compare_high:
	cpi r19, $00				;compare to 0
	brne start_high				;if not then system cannot capture

compare_low:
	cpi r18, $00				;compare to 0
	brne start_high				;if not then system cannot capture

/***********************Capture Mode******************************/
capture:
	ldi r16, $FF
	out SPDR, r16

high_byte1:
	sbis SPSR, SPIF
	rjmp high_byte1
	in r19, SPDR
	andi r19, $0F

	ldi r16, $FF
	out SPDR, r16

low_byte1:
	sbis SPSR, SPIF
	rjmp low_byte1
	in r18, SPDR

compare_high1:
	cpi r19, $00
	brne end

compare_low1:
	cpi r18, $00
	breq capture

end:
	sbi PORTB, 0				;turn off MAX144
	ldi r16, $FF
	out PORTB, r16
	cbi PORTB, 4
	ldi ZH, HIGH(line3_message<<1)
	ldi ZL, LOW(line3_message<<1)
	rcall load_msg
	rcall tone_5V
	rcall update_lcd_dog
	rcall delay
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
		ldi ZH, HIGH(line1_message<<1)
		ldi ZL, LOW(line1_message<<1)
		rcall load_msg
		ldi ZH, HIGH(line2_message<<1)
		ldi ZL, LOW(line2_message<<1)
		rcall load_msg
		ldi ZH, HIGH(line4_message<<1)
		ldi ZL, LOW(line4_message<<1)
		rcall load_msg
		ret										

line1_message: .db 1, "    .    VDC    ", 0	 ;string 1
line2_message: .db 2, "----------------", 0	 ;string 2
line3_message: .db 3, "CAPTURED   evm1c", 0  ;string 3
line4_message: .db 3, "WAITING    evm1c", 0  ;string 4


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
		and r0, r10					;save BCD0
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

;**************************************************************************
;NAME:		delay
;FUNCTION:	creates a variable delay
;ASSUMES:	nothing
;RETURNS:	nothing
;MODIFIES:	r16, r17
;CALLS:		nothing
;CALLED BY:	adc_read
;**************************************************************************
delay:
		ldi r16, $FF		;outer 10ms delay loop
delay1:
		ldi r17, $FF		;inner loop counter
here:
		dec r17				;decrement the inner loop
		nop					;delay
		brne here			;if r17 isnt zero, inner loop repeat
		dec r16				;decrement the outer loop
		nop					;delay
		brne delay1		;if r16 isnt zero, outer loop repeat
		nop					;delay
		nop					;delay
		ret

;*********************************************************************
;NAME:      tone_5V
;FUNCTION:  causes tone/beep on piezo element
;ASSUMES:   nothing
;RETURNS:   nothing
;MODIFIES:  SREG
;CALLS:     v_delay
;*********************************************************************
tone_5V:
      push  r23   ; save registers
      push  r22
      push  r16

   ;***************************************************
   ;SOUNDER TONE/DURATION - ADJUSTABLE VALUE
   ;(May be adjusted by user, as needed)
    ldi   r16, 12     ; CALIBRATION PARAMETER
   ;SOUNDER TONE/DURATION ADJUSTMENT
   ;***************************************************
      ldi  r22, 0x04  ; inner delay count.
      ldi  r23, 1     ; outer delay count.
tone_loop:
      push r22        ; save counts in r22 and r23
      push r23        ;
      cbi  PortC,0    ; turn on sounder
      rcall v_delay   ; delay
      sbi  PortC,0    ; turn off sounder
      pop r23         ; restore delay count
      pop r22         ; down registers
      dec r16         ; adjust loop ctr, and if not
      brne tone_loop  ; zero, then branch and repeat.

      pop  r16   ; restore registers
      pop  r22
      pop  r23
      ret
