/*
 * avm6.asm
 *
 *  Created: 11/14/2014 10:31:51 AM
 *   Author: Brandon Conklin and Suphasith Usdonvudhikai
 */ 
 ;A captured-voltage voltmeter that will us an audio-output system to read
 ;off voltage digits to the user.
 ;
 ;Voltage values will also be displayed on LCD screen.
 ;
 ;Voltmeter has range of 0V-4.096V, due to REF198
 ;1mV accuracy
 ;ADC system is MAX144
 ;
 ;MAX 144, LCD, and audio-output all utilize SPI data transfer
 ;
 ;MAX144 outputs 12-bit data. High 8 read in first, followed by low 4
 ;
 ;New audio-output hardware is utilized using provided include file that 
 ;contains all needed software and subroutines to properly run
 ;
 ;Capture-mode will hold voltage (capture it) until system returns down to 0V
 ;thanks to a pull-down resistor. After returning to 0V, system is ready again 
 ;to capture voltages.
 ;
 ;Now introducing, MULTI-MODE!
 ;User will be able to choose from 4 modes: RUN, HOLD, AUDIO CAPTURE, and CAP/STORE
 ;PBSWs and INT0 will be utilized
 ;Cycling Left (LF) or Right (RT) and pressing GO to select mode
 ;Pressing any PBSW will return to mode select screen
 ;
 ;For CAP/STORE MODE, Pressing UP will enter review section where the user can
 ;cycle through old voltage values as they are display to them on the LCD  


 
 .CSEG
 .org 0
 rjmp RESET						;avoid running through .include subs
 .org $02
 rjmp toggle_isr					;GO(PBSW5) was pressed

.nolist
.include "m16adef.inc"
.include "lcd_dog_asm_driver_m16A.inc"
.include "audio_playback_WTV20SD_beta.inc"
.list

 .DSEG
old_voltage_val: .byte 16		//save 16 bytes; one for each digit, x8 values
cap_store_val: .byte 1			//save 1 byte as a reference for cap/store
								//$FF=enabled, $00=disabled
see_stored_val: .byte 1			//save 1 byte as reference to see stored values
								//$FF=yes, $00=no
 .CSEG
RESET:
	ldi r16, High(RAMEND)		;stack pointer setup
	out SPH, r16
	ldi r16, Low(RAMEND)
	out SPL, r16

	ldi r16, $FF				;initialize as outputs...
	out DDRB, r16				;PORT-B (LCD Display)
	ldi r16, $F7
	out DDRA, r16				;PORT-A (Audio), except PA3(BUSY)
	//sbi PORTA, 3				;pull-up for busy
	ldi r16, $00				;Initialize as Input...
	out DDRD, r16				;Port-D
	ldi r16, $FF				;initialize pull-ups...
	out PORTD, r16				;of PORT-D
	sbi DDRC, 0					;initiliaze buzzer
	sbi PORTC, 0				;turn it off


	sbi PORTB, 0				;turnoff MAX144

	rcall init_lcd_dog			;initialize the LCD display (1x)
	rcall clr_dsp_buffs			;clear buff values (1x)
	//rcall default_buff			;set up buffer for display
	rcall update_lcd_dog		;display buffers onto lcd

main:	
	set							;turn on t-flag to prevent loop
	ldi r16, $00				;disable interrupt request...
	out GICR, r16				;at INT0
	cli							;disable global interrupt to prevent INT0
	ldi ZH, HIGH(line5_message<<1)
	ldi ZL, LOW(line5_message<<1)
	rcall load_msg
	ldi ZH, HIGH(line2_message<<1)
	ldi ZL, LOW(line2_message<<1)
	rcall load_msg
	ldi r16, $00				;load disable
	sts cap_store_val, r16		;disable cap/store
	
	capture_once:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8					;compare to all PBSWs high
	brne capture_once			;wait for all to be high
	ldi ZH, HIGH(line6_message<<1)
	ldi ZL, LOW(line6_message<<1)
	rcall load_msg
	rcall update_lcd_dog		;output to display
	capture_loop:
	sbis PIND, 6				;skip if RT not pressed
	rjmp run_once				;enter run screen 
	sbis PIND, 7				;skip if GO not pressed
	rcall capture_mode			;enter capture mode
	brtc main					;upon returning, start over
	rjmp capture_loop			;wait for user input...
	
	run_once:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne run_once			;wait for all to be high
	ldi ZH, HIGH(line7_message<<1)
	ldi ZL, LOW(line7_message<<1)
	rcall load_msg
	rcall update_lcd_dog		;output to display
	run_loop:
	sbis PIND, 6				;skip if RT not pressed
	rjmp hold_once				;enter hold screen
	sbis PIND, 7				;skip if GO not pressed
	rcall run_mode				;enter run mode
	sbis PIND, 5				;skip if LF not pressed
	rjmp capture_once			;enter capture screen
	brtc main					;upon reutnr, start over
	rjmp run_loop				;wait for user input...
	
	hold_once:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne hold_once			;wait for all to be high
	ldi ZH, HIGH(line8_message<<1)
	ldi ZL, LOW(line8_message<<1)
	rcall load_msg
	rcall update_lcd_dog		;output to display
	hold_loop:
	sbis PIND, 6				;skip if RT not pressed
	rjmp store_once				;enter store screen
	sbis PIND, 7				;skip if GO not pressed
	rcall hold_mode				;enter hold mode
	sbis PIND, 5				;skip if LF not pressed
	rjmp run_once				;enter run screen
	brtc main					;return to main
	rjmp hold_loop				;wait for user input

	store_once:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne store_once			;wait for all to be high
	ldi ZH, HIGH(line10_message<<1)
	ldi ZL, LOW(line10_message<<1)
	rcall load_msg
	rcall update_lcd_dog		;output to display
	store_loop:
	sbis PIND, 7				;skip if GO not pressed
	rcall store_mode			;enter store mode
	sbis PIND, 5				;skip if LF not pressed
	rjmp hold_once				;enter hold screen
	;************************************************
	brtc hold_loop				;unable to reach main on its own
	;OUT-OF-REACH ERROR			;jump to hold_loop to then make
								;the jump from there
	;************************************************
	rjmp store_loop				;wait for user input
	

;********************************************************************
;capture_mode- is a self-containted, independent subroutine in which 
;the voltmeter will read an incoming voltage value, display it on the
;LCD, and keep it displayed there until a new voltage is read, after
;it has returned to 0V.
;
;Is the main code of "evm1c"
;
;Utilizes multiple nested subroutines. 
;
;Won't return to main program until user tells it to through use of
;polling the INT0 interrupt flag and using t-flag handshaking
capture_mode:
	clt
	rcall default_buff			;set up buffer for display
		rcall update_lcd_dog		;display buffers onto lcd
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne capture_mode			;wait for all to be high
	sei
	ldi r16, $FF				;}
	out GIFR, r16				;}clr into flag to avoid pending interrupts
	ldi r16, $03				;INT0 will interrupt...
	out MCUCR, r16				;on the rising edges
	ldi r16, 1 << INT0			;enable interrupt request...
	out GICR, r16				;at INT0

capturing:
	rcall read_voltage			;uses SPI protocol to read in voltages
	rcall bin2BCD16				;convert
	rcall unpack_bcd_to_ascii	;convert to ascii

display:
	ldi r17, $00				;high byte of audio output
	ldi r16, $FF				;setup portB 
	out DDRB, r16				;as outputs
	//cbi PORTB, 4				;CLR PB4 to enable LCD Connection 
	//ldi ZH, HIGH(line4_message<<1)
	//ldi ZL, LOW(line4_message<<1)
	//rcall load_msg
	rcall update_lcd_dog		;output to display
	mov r16, r3					;1s digit of voltage
	rcall send_audio_r17r16
	ldi r16, $0A				;'point'
	rcall send_audio_r17r16
	mov r16, r2					;tenth's digit
	rcall send_audio_r17r16
	mov r16, r1					;hundredth's digit
	rcall send_audio_r17r16
	mov r16, r0					;thousand's digit
	rcall send_audio_r17r16
	brts end_capture			;if t-flag set from INT, end mode
	rjmp capturing				;repeat
	end_capture:
	clt							;clr t-flag
	ret

/*********************************************************************/
;run_mode: Self-contained subroutine which is a modifiction of "evm1a"
;Will simply read and display, continuously, incoming voltages that are 
;read.
;
;Utilizes multiple nested subroutines.
;
;Won't return to main program until user tells it to through use of
;polling the INT0 interrupt flag and using t-flag handshaking
run_mode:
	clt
	rcall default_buff			;set up buffer for display
		rcall update_lcd_dog		;display buffers onto lcd

	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne run_mode				;wait for all to be high
	sei
	ldi r16, $FF				;}
	out GIFR, r16				;}clr into flag to avoid pending interrupts
	ldi r16, $03				;INT0 will interrupt...
	out MCUCR, r16				;on the rising edges
	ldi r16, 1 << INT0			;enable interrupt request...
	out GICR, r16				;at INT0

running:
	rcall read_voltage_run			;uses SPI protocol to read in voltages
	rcall bin2BCD16				;convert
	rcall unpack_bcd_to_ascii	;convert to ascii

display_run:
	ldi r16, $FF				;setup portB 
	out DDRB, r16				;as outputs
	//cbi PORTB, 4				;CLR PB4 to enable LCD Connection 
	rcall update_lcd_dog		;output to 
	brts end_run
	rjmp running				;repeat
	end_run:
	clt
	ret							;back to menu select


/*********************************************************************/
;hold_mode: Self-contained subroutine which is a modifiction of "evm1b"
;Will simply continue to display whatever value was previosuly read,
;either from the capture or run mode.
;
;Utilizes multiple nested subroutines.
;
;Won't return to main program until user tells it to through use of
;polling the INT0 interrupt flag and using t-flag handshaking
hold_mode:
	clt
	rcall default_buff			;set up buffer for display
		rcall update_lcd_dog		;display buffers onto lcd
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne hold_mode			;wait for all to be high
	sei
	ldi r16, $FF				;}
	out GIFR, r16				;}clr into flag to avoid pending interrupts
	ldi r16, $03				;INT0 will interrupt...
	out MCUCR, r16				;on the rising edges
	ldi r16, 1 << INT0			;enable interrupt request...
	out GICR, r16				;at INT0

	ldi r16, $FF				;}PORT-B outputs for LCD
	out DDRB, r16				;}

	//cbi PORTB, 4					;clear PB4 to enable LCD connection
	rcall unpack_bcd_to_ascii	;reload previous voltage value to buffers
	ldi ZH, High(line9_message<<1)
	ldi ZL, Low(line9_message<<1)
	rcall load_msg
	rcall update_lcd_dog		;HOLD previous voltage

holding:
	brts end_hold				;end when user wants to
	rjmp holding				;wait for user input
	end_hold:
	clt							;clear t-flag
	ret							;back to menu select


;********************************************************************
;store_mode- is a self-containted, independent subroutine in which 
;the voltmeter will read an incoming voltage value, display it on the
;LCD, and keep it displayed there until a new voltage is read, after
;it has returned to 0V. 
;
;It will also save the value to a memory location (up to 8 voltages)
;
;
;Utilizes multiple nested subroutines. 
;
;Won't return to main program until user tells it to through use of
;polling the INT0 interrupt flag and using t-flag handshaking
;
;If user had pressed UP, however, instead on t-flag handshaking, 
;system will enter the review storage section of the mode.
;
;Review section is exited by detection of a new voltage value on Port-D

store_mode:
	clt
	ldi r16, $FF				;load and save...
	sts cap_store_val, r16		;to enable cap/store	

	rcall default_buff			;set up buffer for display
		rcall update_lcd_dog		;display buffers onto lcd
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne store_mode				;wait for all to be high


count:
	ldi r20, $00				;set voltage value count to 0
	rcall default_buff			;set up buffer for display
		rcall update_lcd_dog		;display buffers onto lcd
cap:
	sei
	ldi r16, $FF				;}
	out GIFR, r16				;}clr into flag to avoid pending interrupts
	ldi r16, $03				;INT0 will interrupt...
	out MCUCR, r16				;on the rising edges
	ldi r16, 1 << INT0			;enable interrupt request...
	out GICR, r16				;at INT0
	ldi r16, $00				;load and save
	sts see_stored_val, r16		;to disable see values
	inc r20						;each value of r20=voltage value cap/stored
	push r20					;save voltage count
	rcall read_voltage			;uses SPI protocol to read in voltages
	rcall bin2BCD16				;convert
	rcall unpack_bcd_to_ascii	;convert to ascii
	pop r20						;retrieve voltage count
storing_1:
	cpi r20, $01				;voltage 1?
	brne storing_2				;no
	sts old_voltage_val, r14		;save one's of v1
	sts old_voltage_val+1, r13	;save tenth's of v1
	//sts old_voltage_val+2, r1	;save hundreth's of v1
	//sts old_voltage_val+3, r0	;save thousandth's of v1
	rjmp disp					;jump to display
storing_2:
	cpi r20, $02				;voltage 2?
	brne storing_3				;no
	sts old_voltage_val+2, r14	;save one's of v2
	sts old_voltage_val+3, r13	;save tenth's of v2
	//sts old_voltage_val+6, r1	;save hundreth's of v2
	//sts old_voltage_val+7, r0	;save thousandth's of v2
	rjmp disp
storing_3:
	cpi r20, $03				;voltage 3?
	brne storing_4				;no
	sts old_voltage_val+4, r14	;save one's of v3
	sts old_voltage_val+5, r13	;save tenth's of v3
	//sts old_voltage_val+10, r1	;save hundreth's of v3
	//sts old_voltage_val+11, r0	;save thousandth's of v3
	rjmp disp					;jump to display
storing_4:
	cpi r20, $04				;voltage 4?
	brne storing_5				;no
	sts old_voltage_val+6, r14	;save one's of v4
	sts old_voltage_val+7, r13	;save tenth's of v4
	//sts old_voltage_val+14, r1	;save hundreth's of v4
	//sts old_voltage_val+15, r0	;save thousandth's of v4
	rjmp disp					;jump to display
storing_5:
	cpi r20, $05				;voltage 5?
	brne storing_6				;no
	sts old_voltage_val+8, r14	;save one's of v5
	sts old_voltage_val+9, r13	;save tenth's of v5
//	sts old_voltage_val+18, r1	;save hundreth's of v5
//	sts old_voltage_val+19, r0	;save thousandth's of v5
	rjmp disp					;jump to display
storing_6:
	cpi r20, $06				;voltage 6?
	brne storing_7				;no
	sts old_voltage_val+10, r14	;save one's of v6
	sts old_voltage_val+11, r13	;save tenth's of v6
	//sts old_voltage_val+22, r1	;save hundreth's of v6
	//sts old_voltage_val+23, r0	;save thousandth's of v6
	rjmp disp					;jump to display
storing_7:
	cpi r20, $07				;voltage 7?
	brne storing_8				;no
	sts old_voltage_val+12, r14	;save one's of v7
	sts old_voltage_val+13, r13	;save tenth's of v7
	//sts old_voltage_val+26, r1	;save hundreth's of v7
	//sts old_voltage_val+27, r0	;save thousandth's of v7
	rjmp disp					;jump to display
storing_8:
	cpi r20, $08				;voltage 8?
	brne disp					;no (ERROR)
	sts old_voltage_val+14, r14	;save one's of v8
	sts old_voltage_val+15, r13	;save tenth's of v8
	//sts old_voltage_val+30, r1	;save hundreth's of v8
	//sts old_voltage_val+31, r0	;save thousandth's of v8
disp:
	push r20					;save voltage count
	ldi r17, $00				;high byte of audio output
	ldi r16, $FF				;setup portB 
	out DDRB, r16				;as outputs
	//cbi PORTB, 4				;CLR PB4 to enable LCD Connection 
	//ldi ZH, HIGH(line4_message<<1)
	//ldi ZL, LOW(line4_message<<1)
	//rcall load_msg
	rcall update_lcd_dog		;output to display
	mov r16, r3					;1s digit of voltage
	rcall send_audio_r17r16
	ldi r16, $0A				;'point'
	rcall send_audio_r17r16
	mov r16, r2					;tenth's digit
	rcall send_audio_r17r16
	mov r16, r1					;hundredth's digit
	rcall send_audio_r17r16
	mov r16, r0					;thousand's digit
	rcall send_audio_r17r16
	
	pop r20						;retrieve voltage count
	brts end_cap				;if t-flag set from INT, end mode
	//user want to see values?
	lds r16, see_stored_val		;$FF=yes, $00=no
	cpi r16, $FF				;check...
	breq see_stored				;YES
	//otherwise, no
	check_cap:
	cpi r20, $08				;check voltage count
	breq count_return			;go to reset count
	rjmp cap					;repeat
	
	//breq count is out of reach so this will enable it to reach
	count_return:
	jmp count
	
	end_cap:
	clt							;clr t-flag
	ret

see_stored:
	ldi r16, $00				;disable interrupt request...
	out GICR, r16				;at INT0
	cli							;disable global interrupt to prevent INT0
	ldi ZH, HIGH(line11_message<<1)
	ldi ZL, LOW(line11_message<<1)
	rcall load_msg
stored_1:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_1				;wait for all to be high
	lds r14, old_voltage_val		;load one's of v1
	lds r13, old_voltage_val+1	;load tenth's of v1

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $01
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_1_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 3				;skip if UP not pressed
	rjmp stored_2				;enter stored_2 screen 
	rjmp stored_1_loop			;wait for user input...
stored_2:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_2				;wait for all to be high
	lds r14, old_voltage_val+2	;load one's of v2
	lds r13, old_voltage_val+3	;load tenth's of v2

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $02
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_2_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 3				;skip if UP not pressed
	rjmp stored_3				;enter stored_3 screen 
	sbis PIND, 4				;skip if DOWN not pressed
	rjmp stored_1
	rjmp stored_2_loop			;wait for user input...
stored_3:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_3				;wait for all to be high
	lds r14, old_voltage_val+4	;load one's of v3
	lds r13, old_voltage_val+5	;load tenth's of v3

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $03
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_3_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 3				;skip if UP not pressed
	rjmp stored_4				;enter stored_4 screen 
	sbis PIND, 4				;skip if DOWN not pressed
	rjmp stored_2
	rjmp stored_3_loop			;wait for user input...
stored_4:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_4				;wait for all to be high
	lds r14, old_voltage_val+6	;load one's of v4
	lds r13, old_voltage_val+7	;load tenth's of v4

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $04
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_4_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 3				;skip if UP not pressed
	rjmp stored_5				;enter stored_5 screen 
	sbis PIND, 4				;skip if DOWN not pressed
	rjmp stored_3
	rjmp stored_4_loop			;wait for user input...
stored_5:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_5				;wait for all to be high
	lds r14, old_voltage_val+8	;load one's of v5
	lds r13, old_voltage_val+9	;load tenth's of v5

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $05
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_5_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 3				;skip if UP not pressed
	rjmp stored_6				;enter stored_6 screen 
	sbis PIND, 4				;skip if DOWN not pressed
	rjmp stored_4
	rjmp stored_5_loop			;wait for user input...
stored_6:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_6				;wait for all to be high
	lds r14, old_voltage_val+10	;load one's of v6
	lds r13, old_voltage_val+11	;load tenth's of v6

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $06
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_6_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 3				;skip if UP not pressed
	rjmp stored_7				;enter stored_7 screen 
	sbis PIND, 4				;skip if DOWN not pressed
	rjmp stored_5
	rjmp stored_6_loop			;wait for user input...
stored_7:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_7				;wait for all to be high
	lds r14, old_voltage_val+12	;load one's of v7
	lds r13, old_voltage_val+13	;load tenth's of v7

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $07
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_7_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 3				;skip if UP not pressed
	rjmp stored_8				;enter stored_8 screen 
	sbis PIND, 4				;skip if DOWN not pressed
	rjmp stored_6
	rjmp stored_7_loop			;wait for user input...
stored_8:
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne stored_8				;wait for all to be high
	lds r14, old_voltage_val+14	;load one's of v8
	lds r13, old_voltage_val+15	;load tenth's of v8

	rcall unpack_bcd_to_ascii	;convert to ascii
	ldi r16, $08
	sts dsp_buff_3+12, r16
	push r20
	rcall update_lcd_dog		;output to display
	pop r20
	stored_8_loop:
	sbis PIND, 7				;skip if GO not pressed
	rjmp check_cap				;leave see_stored
	sbis PIND, 4				;skip if DOWN not pressed
	rjmp stored_7
	rjmp stored_8_loop			;wait for user input...



	
;*******************************************************
; delay_10mS - Nested loop delay for creating
;              a debounce delay of 10 mS
;
; inputs = none
; outputs = none
; alters r17:r16 (inner and outer loop counts)
;******************************************************

; Debouncing delay equate counts
.equ outer_cnt = 0xf1  ; outer loop counter load value
.equ inner_cnt = 0x0d  ; inner loop counter load value

delay_10mS:
    ldi  r16,outer_cnt   ;init outer loop counter value
dloop1:
	ldi  r17,inner_cnt   ;init inner loop counter value
dloop2:
	dec  r17             ; decr inner count and if
	brne dloop2          ; 0, fall thru.
    dec r16              ; decr outer count, and if
	brne dloop1          ; 0, fall thru.
    ret                  ; ************** 



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
;NAME:      read_voltge_run
;FUNCTION:  reads a 12-bit voltage value from MAX144
;			specifically for the run_mode
;ASSUMES:   nothing
;RETURNS:   R19:R18
;MODIFIES:  R19,R18,R16
;CALLS:     nothing
;CALLED BY: main application 
;********************************************************************
read_voltage_run: 
	ldi r16, (1<<7)|(1<<0)
	out DDRB, r16
	ldi r16, (1<<SPE)|(1<<MSTR)|(1<<SPR1)	;enable SPI, Master, and  fck/64
	out SPCR, r16

	cbi PORTB, 0				;CLR PB0 to turn on CS for MAX144
	ldi r16, $FF				;garbage value 
	out SPDR, r16				;load garbage value to start transmission

high_byte_run:
	sbis SPSR, SPIF				;poll until first byte is read
	rjmp high_byte_run				;
	in r19, SPDR				;load high byte
	andi r19, $0F				;mask bit

start_run:
	ldi r16, $FF				;garbage value
	out SPDR, r16				;start second transmission
	
low_byte_run:
	sbis SPSR,SPIF				;poll until low byte is read
	rjmp low_byte_run				;
	in r18, SPDR				;load low_byte
	sbi PORTB, 0				;turn off MAX144
	ret	 




;********************************************************************
;NAME:      read_voltge
;FUNCTION:  reads a 12-bit voltage value from MAX144
;			specifically for capture_mode
;ASSUMES:   nothing
;RETURNS:   R19:R18
;MODIFIES:  R19,R18,R16
;CALLS:     nothing
;CALLED BY: main application 
;********************************************************************
read_voltage: 
	ldi r16, (1<<7)|(1<<0)
	out DDRB, r16 
	ldi r16, (1<<SPE)|(1<<MSTR)|(1<<SPR1)	;enable SPI, Master, and  fck/64
	out SPCR, r16

	//cbi PORTB, 0				;CLR PB0 to turn on CS for MAX144

start_high:
cbi PORTB, 0				;CLR PB0 to turn on CS for MAX144

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
ldi ZH, HIGH(line3_message<<1)
ldi ZL, LOW(line3_message<<1)
rcall load_msg
rcall update_lcd_dog		;output to display
sbi PORTB, 0
rcall tone_5V		//ready to capture
capture:
rcall delay_40ms
rcall delay_40ms
rcall delay_40ms
rcall delay_40ms

cbi PORTB, 0 
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
	sbi PORTB, 0				;turn off MAX144
compare_high1:
	cpi r19, $00
	brne end

compare_low1:
	cpi r18, 100
	brlo capture

end:
	//sbi PORTB, 0				;turn off MAX144
	ldi r16, $FF
	out DDRB, r16
	ldi ZH, HIGH(line3_message<<1)
	ldi ZL, LOW(line3_message<<1)
	rcall load_msg
	rcall tone_5V				;captured
	rcall update_lcd_dog
	rcall delay
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
    ldi   r16, 255    ; CALIBRATION PARAMETER
   ;SOUNDER TONE/DURATION ADJUSTMENT
   ;***************************************************
      ldi  r22, 30  ; inner delay count.
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

;**************************************************************************
;toggle_isr: Will turn on the T-flag when any PBSW on PORT-D is pressed
;uses delay_10ms for switch debouncing
;registers used- r16, r17, r18, r19
;
;modifies-tflag
;**************************************************************************

toggle_isr:
	push r19
	push r18
	push r17
	push r16
	in r16, SREG
	push r16			;save all registers to be used
	in r18, PIND		;read which switch was pressed
	andi r18, $F8		;keep only PBSWs
	mov r19, r18		;save
	;*************************************************
	rcall delay_10ms	;delay to test switch bouncing
	;*************************************************
	in r18, PIND		;read again
	andi r18, $F8
	cp r18, r19			;switches same?
	brne bounce			;no, bounce occured
	//test UP
	lds r16, cap_store_val	;check if cap/store enabled
	cpi r16, $FF		;
	brne no_UP			;no
	com r18				;make 1's=0's, vice versa
	andi r18, $08		;isolate PD3(UP)
	cpi r18, $08		;if UP was pressed(0=1)
	breq set_store		;user doesn't want to leave, wants to 
						;see stored voltages
	no_UP:
	pop r16
	out SREG, r16
	set					;turn on t-flag
	rjmp end_isr
	bounce:
	pop r16
	out SREG, r16
	rjmp end_isr
	set_store:
	ldi r16, $FF		;load and store...
	sts see_stored_val, r16	;to see stored values
	pop r16
	out SREG, r16
	end_isr:
	//make sure all switches high before leaving
	rcall delay_10mS			;prevent switch bouncing
	in r16, PIND				;read PBSW
	andi r16, $F8				;keep PBSW
	cpi r16, $F8				;compare to all PBSWs high
	brne end_isr				;wait for all to be high
	//******************************************
	pop r16
	pop r17
	pop r18
	pop r19
	reti


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



/*********************************************************************/
line1_message: .db 1, "    .    VDC    ", 0	 ;string 1
line2_message: .db 2, "----------------", 0	 ;string 2
line3_message: .db 3, "CAPTURED        ", 0  ;string 3
line4_message: .db 3, "RUNNING         ", 0  ;string 4
line5_message: .db 1, "   Select Mode  ", 0
line6_message: .db 3, "  Capture Mode? ", 0
line7_message: .db 3, "    Run Mode?   ", 0
line8_message: .db 3, "    Hold Mode?  ", 0
line9_message: .db 3, "HOLDING         ", 0	
line10_message: .db 3, "Cap/Store Mode? ", 0
line11_message: .db 3, "    Voltage     ", 0



