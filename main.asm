
;Inkluderar dioder
.EQU LED1 = PORTB0				; PIN 8
.EQU LED2 = PORTB1				; PIN 9

;Inkulderar Knappar
.EQU BUTTON1 = PORTB3			; PIN 11
.EQU BUTTON2 = PORTB4			; PIN 12
.EQU BUTTON3 = PORTB5			; PIN 13

;Vilka timer kretsar vi har
.EQU TIMER0_MAX_COUNT = 6 
.EQU TIMER1_MAX_COUNT = 12
.EQU TIMER2_MAX_COUNT = 18

;Reset vektor, interuppt och timerfunktionet med b�de overflow och compare
.EQU RESET_vect = 0x00
.EQU PCINT0_vect = 0x06
.EQU TIMER2_OVF_vect = 0x12
.EQU TIMER1_COMPA_vect = 0x16
.EQU TIMER0_OVF_vect = 0x20

;Data segment
.DSEG
.ORG SRAM_START
counter0: .byte 1				;= static uint8_t counter0
counter1: .byte 1				;      -||-       counter1
counter2: .byte 1				;      -||-       counter2

;Code segemet
.CSEG

.ORG RESET_vect
	RJMP main

.ORG PCINT0_vect
	RJMP ISR_PCINT0

.ORG TIMER2_OVF_vect
	RJMP ISR_TIMER2_OVF

.ORG TIMER1_COMPA_vect
	RJMP ISR_TIMER1_COMPA

.ORG TIMER0_OVF_vect
	RJMP ISR_TIMER0_OVF

;Vad som h�nder n�r man trycker p� de olika knapparna. 
ISR_PCINT0:
    CLR R24
	STS PCICR, R24				; PCICR = 0 => inga avbrott.
	STS TIMSK0, R16				; S�tter p� Timer 0 i 300 ms, sedan �teraktiveras avbrott.
;L�ser av om knappen �r in trycket eller inte. Om inte s� hoppar koden till n�sta knapp och l�ser av
IS_BUTTON1_PRESSED:
	IN R24, PINB
	ANDI R24, (1 << BUTTON1)
	BREQ IS_BUTTON2_PRESSED
	CALL system_reset
	RETI
IS_BUTTON2_PRESSED:
	IN R24, PINB
	ANDI R24, (1 << BUTTON2)
	BREQ IS_BUTTON3_PRESSED
	CALL timer1_toggle			; Togglar lysdioden 1 s� att den antingen blinkar eller helt av
	RETI
IS_BUTTON3_PRESSED:
	IN R24, PINB
	ANDI R24, (1 << BUTTON3)
	BREQ ISR_PCINT0_end
	CALL timer2_toggle			; Togglar lysdiod 2 s� att den antingen blinkar eller helt av
ISR_PCINT0_end:
	RETI

; G�r s� att led2 blinkar av och p� n�r timer2 �r ig�ng i 200 ms
ISR_TIMER2_OVF:
	LDS R24, counter2
	INC R24
	CPI R24, TIMER2_MAX_COUNT
	BRLO ISR_TIMER2_OVF_end
	OUT PINB, R17				;Togglar LED2
	CLR R24						; counter2 = 0
ISR_TIMER2_OVF_end:
	STS counter2, R24
	RETI

; G�r att led1 blinkar av och p� n�r timer1 �r ig�ng i 100 ms
ISR_TIMER1_COMPA:
	LDS R24, counter1
	INC R24
	CPI R24, TIMER1_MAX_COUNT
	BRLO ISR_TIMER1_COMPA_end
	OUT PINB, R16				; Togglar LED1.
	CLR R24					    ; counter1 = 0
ISR_TIMER1_COMPA_end:
	STS counter1, R24
	RETI

; Efter 300 ms �teraktiveras PCI-avbrott och Timer 0 st�ngs av.
ISR_TIMER0_OVF:
	LDS R24, counter0
	INC R24
	CPI R24, TIMER0_MAX_COUNT
	BRLO ISR_TIMER0_OVF_end
	STS PCICR, R16				; PCICR = (1 << PCIE0) => PCIE0 = bit 0.
	CLR R24						; Nollst�ller counter0 s� att den kan r�kna om.
	STS TIMSK0, R24				; TIMSK0 = 0 => Timer 0 avst�ngd, d� den gjort sitt jobb f�r denna g�ng.
ISR_TIMER0_OVF_end:
	STS counter0, R24
	RETI

main:
	
setup:	
	;Vart man lagrar var leds och knappar defineras som in eller ut port
	LDI R16, (1 << LED1) | (1 << LED2)
	OUT DDRB, R16
	LDI R18, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
	OUT PINB, R18
	LDI R16, (1 << LED1)
	LDI R17, (1 << LED2)
	SEI
	;Avbrottsvektor f�r knapparna
	STS PCICR, R16
	STS PCMSK0, R18

	;S�tter s� att timer1 r�knar upp till 256
	LDI R19, (1 << CS00) | (1 << CS02)
	OUT TCCR0B, R19 
	LDI R19, (1 << WGM12) | (1 << CS10) | (1 << CS12) ; WGM12 g�r s� att vi kan st�lla in n�r den ska b�rja om
	STS TCCR1B, R19
	; OCR1A = 256 => Timer 1 r�knar till 256 som de andra timerkretsarna.
	LDI R19, high(256)								  ; 256 = 0000 0001 0000 0000 => �vre till OCR1AH, l�gre till OCR1AL.
	STS OCR1AH, R19									  ; OCR1AH = 0000 0001.
	LDI R19, low(256) 
	STS OCR1AL, R19									  ; OCR1AL = 0000 0000
	;S�tter timer2 s� att den r�knar upp till 256
	LDI R19, (1 << CS22) | (1 << CS21) | (1 << CS20)
	STS TCCR2B, R19
	
main_loop:
	RJMP main_loop

system_reset:
   ;Sl�cker leds, st�nga av timers och nollst�ll r�knarna.
   IN R24, PORTB
   ANDI R24, ~((1 << LED1) | (1 << LED2))
   OUT PORTB, R24

   CLR R24
   STS counter0, R24
   STS counter1, R24
   STS counter2, R24

   STS TIMSK1, R24
   STS TIMSK2, R24

   RET

;Toggle funktion f�r timer1 b�de av och p�
timer1_toggle:
	LDS R24, TIMSK1
	CPI R24, 0
	BREQ timer1_on
timer1_off:					;Sl�cker led1 och nollst�ller timer1
	CLR R24
	STS TIMSK1, R24
	IN R24, PORTB
	ANDI R24, ~(1 << LED1)
	OUT PORTB, R24
	RET
timer1_on:					;S�tter ig�ng timer1 som t�nder led1
	STS TIMSK1, R17			; (1 << OCIE1A) = (1 << LED2) = R17
	RET

;Toggle funktion f�r timer2 b�de av och p�
timer2_toggle:
	LDS R24, TIMSK2
	CPI R24, 0
	BREQ timer2_on
timer2_off:					;Sl�cker led2 och nollst�ller timer2
	CLR R24
	STS TIMSK2, R24
	IN R24, PORTB
	ANDI R24, ~(1 << LED2)
	OUT PORTB, R24
	RET
timer2_on:					;S�tter ig�ng timer1 som t�nder led1
	STS TIMSK2, R16			; (1 << TOIE2) = (1 << LED1) = R16
	RET