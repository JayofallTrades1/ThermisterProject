/*
 * incr_decr: is a program that turns on all LEDs in the 7-segment display if a button is pressed. 
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
		
.NOLIST
.include "m16def.inc"
.LIST
							
 setup: 
										;configure I/O ports
	ldi r16, $ff						;Outputs are at PORTB (7 Segment display) and PA0
	out DDRB, r16						;Set up PORTB as outputs
	out DDRA, r16						;set up PORTA as outputs
	ldi r16, $00						;input is at PINC 0, 6, 7 (Push Button Switch)
	out DDRC, r16						;Set up all of PORTC as inputs
	ldi r16, $ff						;turn on all internal resistors 
	out PORTC, r16						;eliminates floating inputs 
	ldi r22, $01						;over flow 

reset:
	ldi r18, $00						;initial counter 
	sbi PORTA, 0						;turns off annunciator
	rjmp bcd_7seg						;display a "0"

wait_for_1:
	in r16, PINC						;loads the inputs at PINC into register
	cpi r16, $FF						;compares all of PORTC to ensure logic 1s
	brne wait_for_1						;if it isnt then we repeat

										;delay for 10us
delay1:		ldi r16, 10					;intiazlize outer loop (1us)
again1:		ldi r17, 190				;initialize inner loop (1us)
here1:		nop							;waste clock cycle (2us)
			nop									
 			dec r17						;r17 decrements until (z = 0) (1us)
			brne here1					;keep repeating until (z = 0) (1/2 us)
			dec r16						;outer loop decrements 
			brne again1					;keep repeating until (z = 0) (1/2 us)

check_for_1:
	in r16, PINC						;checks if the PBSW is released
	cpi r16, $FF						;compares all of PORTC again to verify logic 1's
	brne wait_for_1						;repeat until it is logic 1's

wait_for_0:
	in r16, PINC						;input from PINC into r16
	com r16								;complement r16 since PORTC is mostly logic 1
	andi r16, $C1						;and operation to mask all bits but PC0, PC6, PC7
	breq wait_for_0						;repeat until button is pressed

										;delay for 10us
delay2:		ldi r16, 10					;intiazlize outer loop (1us)
again2:		ldi r17, 190				;initialize inner loop (1us)
here2:		nop							;waste clock cycle (2us)
			nop									
 			dec r17						;r17 decrements until (z = 0) (1us)
			brne here2					;keep repeating until (z = 0) (1/2 us)
			dec r16						;outer loop decrements 
			brne again2					;keep repeating until (z = 0) (1/2 us)
		
check_for_0:
	in r16, PINC						;input from PINC into r16
	com r16								;complement r16 since PORTC is mostly logic 1
	andi r16, $C1						;and operation to mask all bits but PC0, PC6, PC7
	breq wait_for_1						;if button wasnt pressed then we start all over
	mov r20, r16						;if button was pressed we save the value into r20	

main_loop:
	cpi r20, $01						;check if PBSW1 was pressed						
	breq PBSW1							;if it is then go to PBSW1 program		
	cpi r20, $40						;check if PBSW2 was pressed
	breq PBSW2							;if it is then go to PBSW2 program
	cpi r20, $80						;check if PBSW3 was pressed
	breq PBSW3							;if it is then go to PBSW3 program

PBSW1: 
	inc r18								;if PBSW1 is pressed increment counter
	cpi r18, $0A						;check if counter is less than 10
	brlo bcd_7seg						;if it is then go to segment
	ldi r18, $00						;if greater than 10 we roll over to 0
	ldi r16, $ff						;setup register to turn off LEDs
	out PORTB, r16						;turn off all LEDs
	cbi PORTA, 0						;turn on annunciator 
	rjmp reset							;go back

PBSW2:	
	dec	r18								;decrement counter
	cpi r18, $ff						;check if counter is less than 0
	breq reset							;if lower then we go to reset and display "0"
	rjmp bcd_7seg						;if not then go to bcd_7seg
	
	
PBSW3:
	rjmp reset							;warm reset

bcd_7seg:
	ldi ZH, high(table * 2)				;set z to point to start of table
	ldi ZL, low(table * 2)				;
	ldi r16, $00						;clear for later use
	add ZL, r18							;add low byte
	adc ZH, r16							;add in CY
	lpm r21, Z							;load bit pattern from table into r18

display:
	out PORTB, r21						;output pattern into 7-segment display
	rjmp wait_for_1						;go back 

table: .db $40,$79,$24,$30,$19,$12,$03,$78,$0,$10
		  ; 0	1	2	3	4	5	6	7	8	9


