/*
 * frequency_meter.asm
 *
 *  Created: 10/16/2014 6:54:57 PM
 *   Author: Suphasith Usdonvudhikai and Brandon Conklin
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

 rjmp RESET
.nolist 
.include "m16def.inc"
.include "lcd_dog_asm_driver_m16A.inc"
.nolist 

RESET: 
	ldi r16, LOW(RAMEND)			;initialize stack pointer
	out SPL, r16					;
	ldi r16, HIGH(RAMEND)			;
	out SPH, r16					;

	ldi r16, $FF					;initialize PORTB
	out PORTB, r16					;as outputs (LCD Display)

	ldi r16, $7F					;initialize PORTA
	out DDRA, r16					;as output (PA6) & input (PA7)

	rcall init_lcd_dog				;initialize LCD display with SPI protocol
	rcall clr_dsp_buffs				;clear the display buffers. 

	cbi PORTA, 6					;turn off sync pulse

MAIN:
	initialize:
		rcall default_buff				;send "FREQ=" to buffer
		rcall update_lcd_dog			;send to LCD
	main_loop:
		sbi PORTA, 6					;gate pulse
		cbi PORTA, 6					;
		rcall freq_meas_1secgate		;measure frequency
		sbi PORTA, 6					;gate pulse
		cbi PORTA, 6					;
		rcall unpack_ascii				;convert hex to ascii
		rcall update_lcd_dog			;update LCD
		rjmp main_loop					;repeat 



;********************************************************************
;NAME:			default_buff
;FUNCTION:		initializes first line in buffer with "FREQ="
;ASSUMES:		BYTE has been allocated in SRAM
;RETURNS:		nothing
;MODIFIES:		SRAM
;CALLS:			nothing
;CALLED BY:		MAIN
;********************************************************************

default_buff:
		ldi r16, 'F'				;load ASCII 'F'
		sts dsp_buff_1, r16			;store in SRAM
		ldi r16, 'R'				;load ASCII 'r'
		sts dsp_buff_1+1, r16		;store in SRAM
		ldi r16, 'E'				;load ASCII 'e'
		sts dsp_buff_1+2, r16		;store in SRAM
		ldi r16, 'Q'				;load ASCII 'q'
		sts dsp_buff_1+3, r16		;store in SRAM
		ldi r16, '='				;load ASCII '='
		sts dsp_buff_1+4, r16		;store in SRAM
		ldi r16, 'H'				;load ASCII 'H'
		sts dsp_buff_1+9, r16		;store in SRAM
		ldi r16, 'z'				;load ASCII 'z'
		sts dsp_buff_1+10, r16		;store in SRAM
		ret							;return 


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

;**************************************************************************
;NAME:		freq_measure
;FUNCTION:	counts the total number of rising edges in a 1 second loop
;ASSUMES:	PORTS are initlize for inputs PA7(square wave)
;RETURNS:	r9:r8 are returned (edge counter)
;MODIFIES:	r9:r8, r19:r18(16-bit loop counter), r16(8-bit sample in-line)
;CALLS:		none
;CALLED BY:	MAIN
;**************************************************************************

freq_meas_1secgate:	
	initialize_count:
		ldi r19, $A0		;outerloop counter
		ldi r18, $00		;(r19:r18)
		ldi r21, $00
		mov r9, r21			;edge counter
		mov r8, r21			;(r19:r18)
		in r16, PINA		;read in contents
		andi r16, $80		;mask all bits besides PA0
		mov r25, r16		;seed value into r25
	loop:
		in r16, PINA		;read inputs
		andi r16, $80		;mask all bits
		cp r16, r25			;compare 
		breq loop_check		;Z=1 no change
		brcs new_seed		;C=1 negative pulse
		mov r25, r16		;new seed
		inc r8				;inc low byte of edge counter
		brne loop_check		;jmp until low byte rollover
		inc r9				;inc high byte of edge counter
	loop_check:
		dec r18				;dec low byte of loop counter
		brne no_rollover	;jmp until low byte rollover
		dec r19				;dec high bytw of loop counter
	no_rollover:
		cpi r19, $00		;if loop counter =00xx
		breq exit			;end subroutine
	tweak:
		ldi r17, $01		;tweak delay
	delay:
		dec r17				;
		brne delay			;repeat 
		rjmp loop			;return to loop
	new_seed:
		mov r25, r16		;new seed
		rjmp loop_check		;go to loop check
	exit:
		ret
	
unpack:
	ldi r16, $0F			;load and
	mov r10, r16			;save masking value
	mov r4, r15				;copy BCD4 
	and r4, r10				;keep highest value
	mov r27, r4				;copy for table
	rcall ASCII_table		;jump to table lookup
	sts dsp_buff_1+5, r22	;store BCD4
	mov r3, r14				;copy BCD2&3
	swap r3					;SWAP BCD2&3
	and r3, r10				;save BCD3
	mov r27, r3				;copy for table
	rcall ASCII_table		;jmp to table lookup
	sts dsp_buff_1+6, r22	;store BCD3
	mov r2, r14				;copy BCD2&3
	and r2, r10				;keep BCD2
	mov r27, r2				;copy for table
	rcall ASCII_table		;jmp to table lookup
	sts dsp_buff_1+7, r22	;store BCD2
	mov r1, r13				;copy BCD1&0
	swap r1					;swap BCD1&0
	and r1, r10				;save BCD1
	mov r27, r1				;copy for table
	rcall ASCII_table		;jmp to table lookup
	sts dsp_buff_1+8, r22	;store BCD1
	mov r0, r13				;copy BCD1&0
	and r0, r10				;save BCD0
	mov r27, r0				;copy for table
	rcall ASCII_table		;jmp to table lookup
	sts dsp_buff_1+8, r22	;store BCD0

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


		