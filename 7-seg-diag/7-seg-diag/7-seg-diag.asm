/*
 * _7_seg_diag.asm: is a program that turns on all LEDs in the 7-segment display if a button is pressed. 
 *
 * Descripton:  This program also counts for the debouncing effect in the button. We must use a delay of 10us
 *				in order to determine if the button is still logic '0'
 *
 * inputs: PBSW in PINC0
 *
 * outputs: 7-segment display in PORTB
 *
 * resgister Assignment/Purposes:
 * r16 = GP/delay count(outer loop)
 * r17 = GP/delay count (inner loop)
 * 
 * stack depth: 2 Bytes

 *  Created: 9/26/2014 6:35:23 PM
 *   Author: Suphasith Usdonvudhikai & Brandon Conklin
 */ 
		
.nolist
.include "m16def.inc"
.list
				
 reset: 
										;configure I/O ports
	ldi r16, $ff						;Outputs are at PORTB (7 Segment display)
	out DDRB, r16						;Set up PORTB as outputs
	ldi r16, $00						;Input is at PINC0 (Push Button Switch)
	out DDRC, r16						;Set up all of PORTC as inputs
	ldi r16, $ff						;turn on all internal resistors 
	out PORTC, r16						;eliminates floating inputs

stack:
										;initial stack for return address (CALL and RET)
	ldi r16, HIGH(RAMEND)				;loads the high bye of ram address
	out SPH, r16						;high byte of stack pointer -> high byte of ram
	ldi r16, LOW(RAMEND)				;loads the low bye of ram address
	out SPL, r16						;low byte of stack pointer -> low byte of ram


wait_for_1:
	sbis PINC, 0						;checks if the intial input into pin logic 1 
	rjmp wait_for_1						;if it isnt then we repeat; ensures a logic 1 is at input
	call delay							;delay for 10us

check_for_1:
	sbis PINC, 0						;checks if the PBSW is released
	rjmp wait_for_1						;repeat until PBSW is released

check_for_0:
	sbic PINC, 0						;waits for the button to be pressed
	rjmp check_for_0					;skips this if button is pressed (logic '0')
	call delay							;time delay for switch debounce
	sbic PINC, 0						;checks if the button is still (logic '0')
	rjmp wait_for_1						;go back to intial settings

LED_ON:
	ldi r16, $00						;sets up all PORTB for outputs
	out DDRB, r16						;turns on all LEDs in PORTB
	rjmp wait_for_1						;repeat again until next button press



							/*SUBROUTINES*/

delay:		ldi r16, 10					;intiazlize outer loop (1us)
again:		ldi r17, 190				;initialize inner loop (1us)
here:		nop							;waste clock cycle (2us)
			nop										
 			dec r17						;r17 decrements until (z = 0) (1us)
			brne here					;keep repeating until (z = 0) (1/2 us)
			dec r16						;outer loop decrements 
			brne again					;keep repeating until (z = 0) (1/2 us)
			ret							;return back to program main 


