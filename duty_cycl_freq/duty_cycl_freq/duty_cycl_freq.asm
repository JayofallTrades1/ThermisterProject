/*
 * duty_cycle_freq.asm
 *
 *  Created: 10/3/2014 8:41:50 AM
 *   Author: Brandon Conklin and Suphasith Usdonvudhikai
 */ 
 ;This program is a modification of the previous program 
 ;which generates a PWM signal to produce
 ;a square wave with variable duty cycle. PWM 
 ;(Pulse Width Modulation) uses digital signals 
 ;'0' & '1' to control analog devices. This is done 
 ;by manipulating the duty cycle of a square-wave.
 ;
 ;Modification consists of using previously unused upper 
 ;nibble BCD to vary the frequency of the waveform.
 ;
 ;Time high=%of duty cycle
 ;
 ;Represented on an LED
 ;
 ;74HC74 Dual D-Type FF also used to produce 
 ;square wave with half frequency
 ;
 ;74HC74 D-FF configured as a T-FF
 ;
 ;INPUTS=2x 4-bit DIP switches (High and low Nibble)
 ;		 PBSW LOAD switch
 ;		 Internal ATMega16A pull-up resistors
 ;		 ATMega16A PORT-D (PD0-7)
 ;				   PC0 (PBSW)
 ;OUTPUTS=2x LED (active-high_ to represent PWM 
 ;		  74HC74 D-FF (as a T-FF)
 ;		  7-seg to represent duty cycle %
 ;        ATMega16A PORT-B (PB0-7)
 ;		            PA0 (LED & D-FF)

 .nolist
 .include "m16def.inc"
 .list

setup:
		ldi r16, LOW(RAMEND)		;load SPL with low byte of
		out SPL, r16				;RAMEND Address
		ldi r16, HIGH(RAMEND)		;load SPH with high byte of
		out SPH, r16				;RAMEND Address
		ldi r16, $FF				;Initialize as outputs... 
		out DDRB, r16				;PORT-B
		out DDRA, r16				;PORT-A
		ldi r16, $00				;initialize as inputs...
		out DDRD, r16				;PORT-D
		out DDRC, r16				;PORT-C
		ldi r16, $FF				;initialize pullups of...
		out PORTD, r16				;PORT-D
		out PORTC, r16				;PORT-C
		ldi r16, $40				;initialize
		out PORTB, r16				;7-seg to '0'
		cbi PORTA, 0				;make sure wave low and LED off

wait:
		sbic PINC, 0				;read the switch value of LOAD PBSW
		rjmp wait					;loop until set '0' (pressed)
main:
		sbis PINC, 0				;read the switch value of LOAD PBSW
		rjmp main					;loop until open '1' (released)
		ldi r19, $0A				;set loop counter for later
		in r18, PIND				;read switches of PORT-D (low nibble)
		mov r21, r18				;copy BCD for low nibble masking
		andi r18, $0F				;mask upper nibble of PORT-D
		andi r21, $F0				;mask lower nibble of PORT-D
		cpi r21, $00				;check if frequency BCD is '0'
		breq freq_0					;if freq='0' jump
		swap r21					;swap upper nibble to lower for z-pointer later on
		rcall frequency				;jump to subroutine to modify frequency
		mov r20, r18				;copy of BCD nibble
		cpi r18, $0A				;check for BCD nibble >9
		brge PWM_9					;if BCD nibble >9, jump to special PWM
		cpi r18, $00				;check if the nibble is 0
		breq PWM_0					;if it is then we jump to program
		rcall bcd7_seg				;jump to table-lookup
		rcall PWM					;jump to subroutine that produces PWM (1KHz)
		rjmp main					;restart main looping
		
PWM_0:
		ldi r16, $06				;load r16 to be ready for output
		out PORTB, r16				;display a "E' on the 7 seg
		cbi PORTA, 0				;output 0 volts
		sbic PINC, 0				;check if button was pressed
		rjmp PWM_0					;if it is not then we repeat and display a 'E'
		rjmp main					;if pressed we go to main

PWM_9:
		ldi r16, $06				;load r16 to be ready for output
		out PORTB, r16				;display 'E' on the 7-seg
		sbi PORTA, 0				;turn on 5 volts
		sbic PINC, 0				;check if button was pressed
		rjmp PWM_9					;if it is not then we repeat and display a 'E'
		rjmp main					;if pressed we go to main

freq_0:
		ldi r18, 0					;make the low nibble '0' so PA0 is '0'
		mov r20, r18				;copy for reload at end of delay
		inc r23						;inc so that if still '0', wont go all the way around
		rcall PWM					;jump to PWM
		rjmp main					;return to main

//SUBROUTINES BELOW

;PWM - self-contained subroutine for the outputting of the PWM
;	frequency at given by the previous subroutine
;	Uses nested looping delay of an inner and
;	an outer loop to accomplish different frequencies.
;
;inputs: inner and outer looping counter (r16 and r17)
;		 low nibble BCD value (r18)
;		 copy of low nibble BCD value to reset (r20)
;		 PC0 to check if PBSW pressed again
;		 $0A loop count value to generate the loop 10x (100%) (r19)
;outputs: PA0 high when r18>0
;		  PA0 low when r18<=0

PWM:
		cpi r18, $01				;compare to see if r18 (nibble) is '0'
		brlt less
		sbi PORTA, 0				;set logic-1 to PA0, high
		rjmp delay_1ms
	less:
		cbi PORTA, 0				;clear logic-0 to PA0, low
		//start of looping portion
	delay_1ms:
		mov r17, r23				;outer delay countdown value
	outer_loop:
		mov r16, r23				;inner delay countdown value
	inner_loop:
		dec r16						;decrement the inner delay countdown 
		brne inner_loop				;repeat until '0'=r16
	check_outer_cnt:
		dec r17						;dec outer loop delay countdown
		brne outer_loop				;repeat until '0'=r17
		//end of looping portion
		dec r18						;subtract 1 from BCD count
		dec r19						;subtract one from loop count
		brne PWM					;if r19!=0, keep looping
		ldi r19, $0A				;reset loop count
		mov r18, r20				;reset nibble count
		sbic PINC, 0				;see if switch has been pressed again
		rjmp PWM					;loop back to output again if PBSW not pressed
		ret							;return to main code

;bcd7_seg - Self-contained subroutine that uses table lookups to 
;		find and display decimal percentage of duty cycle being 
;		generated, onto the 7-seg.
;Copy of table provided by Scott a couple labs back
;
;inputs: Z-pointer
;			-ZH is high Z
;			-ZL is low Z
;		 r16 is a place holder for adc
;		 r18 is low nibble BCD count for the duty cycle
;outputs: result of Z point are loaded into r22
;		  displayed out to PORT-B

bcd7_seg:
		ldi ZH, high (table * 2)	;set Z to point to start of table
		ldi ZL, low (table * 2)		;
		ldi r16, $00				;clear for add w/ carry
		add ZL, r18					;add low byte
		adc ZH, r16					;add in the CY
		lpm r22, Z					;load bit pattern from table into r18
display:
		out PORTB, r22				;output pattern for 7-seg
		ret							;return to main

;table of 7-seg bit patterns to display digits 0-8
table: .db $40,$79,$24,$30,$19,$12,$03,$78,$0,$10
		   ;0    1   2   3   4   5   6   7  8   9

;frequency - Self-contained subroutine that uses table lookups to 
;		find and record the frequeny values for the PWM.
;
;inputs: Z-pointer
;			-ZH is high Z
;			-ZL is low Z
;		 r16 is a place holder for adc
;		 r21 is swapped (was high) low nibble BCD count for the frequency
;outputs: result of Z point are loaded into r23
;		  sent back for later use in delay loop

frequency:
		ldi ZH, high (freq * 2)		;set Z to point to start of freq_table
		ldi ZL, low (freq * 2)		;
		ldi r16, $00				;clear for adc
		add ZL, r21					;add low byte
		adc ZH, r16					;add in C
		lpm r23, Z					;load bit into r23
		ret

;table of frequencies
freq: .db $00,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$03,$02,$01
		  ;LOW--------------------------------------------------------HIGH
