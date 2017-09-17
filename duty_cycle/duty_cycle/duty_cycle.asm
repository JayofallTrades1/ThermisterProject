/*
 * frequency_meter.asm
 *
 *  Created: 10/16/2014 6:54:57 PM
 *   Author: Brandon Conklin and Suphasith Usdonvudhikai
 */ 
 ;This program will take an incoming pulse waveform, and output
 ;the frequency value on an LCD display. Frequency is caluclated
 ;by counting the number of rising edges of the waveform, in a 1
 ;second period.
 ;
 ;Instantaneous transfer of date from waveform to LCD display (no PBSW)
 ;SYNC Pulse output to oscilloscope to calibrate 1 second wait period
 ;
 ;LCD display only accepts ASCII. Hex values must be converted
 ;
 ;INPUT=PORTA(PA7)(Pulse Waveform)(pull-up not required)
 ;OUTPUT=PORTB(PB0,3-5,7)(LCD DISPLAY)
 ;		 PORTA(PA6)(SYNC PULSE)

 rjmp setup							;avoid running through .include subs

.nolist
.include "m16def.inc"
.include "lcd_dog_asm_driver_m16A.inc"
.list

setup:
		ldi r16, LOW(RAMEND)		;initialize SPL
		out SPL, r16				;with LOW RAMEND 
		ldi r16, HIGH(RAMEND)		;initialize SPH
		out SPH, r16				;with HIGH RAMEND (stack pointer now ready)
		ldi r16, $FF				;initialize PORT-B...
		out DDRB, r16				;as output
		ldi r16, $7F				;initialize PORT-A
		out DDRA, r16				;as output (PA6) & input (PA7)
		rcall init_lcd_dog			;initialize the LCD display (1x)
		rcall clr_dsp_buffs			;clear buff values (1x)
		cbi PORTA, 6				;clear (low) the SYNC pulse
main:
		sbi PORTA, 6				;set and
		cbi PORTA, 6				;clear SYNC pulse (start)
		rcall freq_meas_1secgate	;measure incoming pulse (PA7)
		sbi PORTA, 6				;set and
		cbi PORTA, 6				;clear SYNC pulse (stop)
	init_load:
		ldi r16, $46				;load ASCII 'F'
		sts dsp_buff_1, r16			;store in SRAM
		ldi r16, $72				;load ASCII 'r'
		sts dsp_buff_1+1, r16		;store in SRAM
		ldi r16, 'e'				;load ASCII 'e'
		sts dsp_buff_1+2, r16		;store in SRAM
		ldi r16, 'q'				;load ASCII 'q'
		sts dsp_buff_1+3, r16		;store in SRAM
		ldi r16, '='				;load ASCII '='
		sts dsp_buff_1+4, r16		;store in SRAM
		ldi r16, 'H'				;load ASCII 'H'
		sts dsp_buff_1+9, r16		;store in SRAM
		ldi r16, 'z'				;load ASCII 'z'
		sts dsp_buff_1+10, r16		;store in SRAM
	unpack:
		ldi r16, $0F				;load and
		mov r10, r16				;save masking value
		mov r1, r9					;copy high hex values 
		swap r1						;swap hex values
		and r1, r10					;keep highest value
		mov r27, r1					;copy for table
		rcall ASCII_table			;jump to table lookup
		sts dsp_buff_1+5, r22		;store HIGHEST HEX value
		mov r2, r9					;copy high hex values
		and r2, r10					;keep 2nd highest hex
		mov r27, r2					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+6, r22		;store 2ND HIGHEST HEX VALUE
		mov r3, r8					;copy low hex values
		swap r3						;swap hex values
		and r3, r10					;keep 3rd highest value
		mov r27, r3					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+7, r22		;store 3RD HIGHEST HEX VALUE
		mov r4, r8					;copy low hex values
		and r4, r10					;keep lowest hex value
		mov r27, r4					;copy for table
		rcall ASCII_table			;jmp to table lookup
		sts dsp_buff_1+8, r22		;store LOWEST HEX VALUE
	display:
		rcall update_lcd_dog		;load dsp_buff_1 to LCD display
		rjmp main					;start all over again



;freq_meas_1secgate - self-contained subroutine in which 
;a 1 sec loop is generated, during which all rising edges
;(positive) of an incoming waveform on PA7 are added up.
;
;INPUTS=PORTA(PA7)(waveform)
;registers used=r19,r18,r9,r8,r16,r17,r25
;r19:r18=loop counter
;r9:r8=edge counter
;r16=PA7 value
;r25=seeded PA7 value
;r17=tweak delay value
;
;when comparing old vs new PA7 values: 
;Z=1 means no change
;C=1 means negative edge
;looking for both not set

freq_meas_1secgate:
		ldi r16, $00				;load to
		mov r9, r16					;set edge counter 
		mov r8, r16					;to zero(0)
		ldi r19, $A0				;set loop counter }CALIBRATION
		ldi r18, $00				;for 1s loop      }REQUIRED!
		in r16, PINA				;read in PINA (PA7)
		andi r16, $80				;keep only PA7
		mov r25, r16				;seed value
	sec_loop:
		in r16, PINA				;read in PINA (PA7)
		andi r16, $80				;keep only PA7
		cp r16, r25					;compare new vs old PA7
		breq loop_check				;Z=1(no change) 
		brcs new_seed				;C=1(neg. change)
		mov r25, r16				;save new PA7 value
		inc r8						;inc low byte of edge counter
		brne loop_check				;jmp until low byte rollover
		inc r9						;inc high byte of edge counter
	loop_check:
		dec r18						;dec low byte of loop counter
		brne no_rollover			;jmp until low byte rollover
		dec r19						;dec high bytw of loop counter
	no_rollover:
		cpi r19, $00				;if loop counter =00xx
		breq end					;end subroutine
	keep:
		ldi r17, $01				;tweaking loop for in lab
	tweak:
		dec r17						;
		brne tweak					;
		rjmp sec_loop				;start over

	new_seed:
		mov r25, r16				;save new PA7 value
		rjmp loop_check				;return to loop

	end:
		ret							;return to main program
		

;************************
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

ASCII_table:
		ldi ZH, high (table * 2)	;set Z to point to start of table
		ldi ZL, low (table * 2)		;
		ldi r16, $00				;clear for add w/ carry
		add ZL, r27					;add low byte
		adc ZH, r16					;add in the CY
		lpm r22, Z					;load bit pattern from table into r22
		ret

table: .db $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$41,$42,$43,$44,$45,$46
		   ;0,  1,  2,  3,  4,  5,  6,  7,  8

