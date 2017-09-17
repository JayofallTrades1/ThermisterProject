
.nolist
.include "m16adef.inc"
.include "lcd_dog__asm_driver_m16A.inc"
.list

.org $00
rjmp reset
.org $02
rjmp isr_PBSW
.org $0C
rjmp isr_timer 

reset:
	ldi r16, High(RAMEND)	//stack pointer setup
	out SPH, r16
	ldi r16, Low(RAMEND)
	out SPL, r16
	
	ldi r16, $FF				;initialize PORT-B...
	out DDRB, r16				;as output
		
	ldi r16, $00				;initialize PORT-D...
	out DDRD, r16				;as input
	ldi r16, $FF				;initialize pull-ups...
	out PORTD, r16				;of PORT-D

	ldi r16, $7F				;initialize PORT-A
	out DDRA, r16				;as output (PA6) & input (PA7)

	rcall init_lcd_dog			;initialize the LCD display (1x)
	rcall clr_dsp_buffs			;clear buff values (1x)

main:
	ldi r16, (1 << TOIE1)
	out TIMSK, r16
	sei 
	ldi r16, -15625
	out TCNT1, r16
	
init_load_1sec:
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
		ldi r16, 'F'				;load ASCII 'F'
		sts dsp_buff_2+4, r16		;store in SRAM
		ldi r16, 'M'				;load ASCII 'M'
		sts dsp_buff_2+5, r16		;store in SRAM
		ldi r16, '2'				;load ASCII '2'
		sts dsp_buff_2+6, r16		;store in SRAM
		ldi r16, 'G'				;load ASCII 'G'
		sts dsp_buff_3+1, r16		;store in SRAM
		ldi r16, 'A'				;load ASCII 'A'
		sts dsp_buff_3+2, r16		;store in SRAM
		ldi r16, 'T'				;load ASCII 'T'
		sts dsp_buff_3+3, r16		;store in SRAM
		ldi r16, 'E'				;load ASCII 'E'
		sts dsp_buff_3+4, r16		;store in SRAM
		ldi r16, '='				;load ASCII '='
		sts dsp_buff_3+5, r16		;store in SRAM
		ldi r16, '1'				;load ASCII '1'
		sts dsp_buff_3+6, r16		;store in SRAM
		ldi r16, 'S'				;load ASCII 'S'
		sts dsp_buff_3+7, r16		;store in SRAM
		ldi r16, 'E'				;load ASCII 'E'
		sts dsp_buff_3+8, r16		;store in SRAM
		ldi r16, 'C'				;load ASCII 'C'
		sts dsp_buff_3+9, r16		;store in SRAM
		ret

init_load_half:
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
		ldi r16, 'F'				;load ASCII 'F'
		sts dsp_buff_2+4, r16		;store in SRAM
		ldi r16, 'M'				;load ASCII 'M'
		sts dsp_buff_2+5, r16		;store in SRAM
		ldi r16, '3'				;load ASCII '3'
		sts dsp_buff_2+6, r16		;store in SRAM
		ldi r16, 'G'				;load ASCII 'G'
		sts dsp_buff_3, r16			;store in SRAM
		ldi r16, 'A'				;load ASCII 'A'
		sts dsp_buff_3+1, r16		;store in SRAM
		ldi r16, 'T'				;load ASCII 'T'
		sts dsp_buff_3+2, r16		;store in SRAM
		ldi r16, 'E'				;load ASCII 'E'
		sts dsp_buff_3+3, r16		;store in SRAM
		ldi r16, '='				;load ASCII '='
		sts dsp_buff_3+4, r16		;store in SRAM
		ldi r16, '1'				;load ASCII '1'
		sts dsp_buff_3+5, r16		;store in SRAM
		ldi r16, '/'				;load ASCII '/'
		sts dsp_buff_3+6, r16		;store in SRAM
		ldi r16, '2'				;load ASCII '2'
		sts dsp_buff_3+7, r16		;store in SRAM
		ldi r16, 'S'				;load ASCII 'S'
		sts dsp_buff_3+8, r16		;store in SRAM
		ldi r16, 'E'				;load ASCII 'E'
		sts dsp_buff_3+9, r16		;store in SRAM
		ldi r16, 'C'				;load ASCII 'C'
		sts dsp_buff_3+10, r16		;store in SRAM
		ret

