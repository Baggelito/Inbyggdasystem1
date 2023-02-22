
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

;Reset vektor, interuppt och timerfunktionet med både overflow och compare
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

;Vad som händer när man trycker på de olika knapparna. 
ISR_PCINT0:
    CLR R24
	STS PCICR, R24				; PCICR = 0 => inga avbrott.
	STS TIMSK0, R16				; Sätter på Timer 0 i 300 ms, sedan återaktiveras avbrott.
;Läser av om knappen är in trycket eller inte. Om inte så hoppar koden till nästa knapp och läser av
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
	CALL timer1_toggle			; Togglar lysdioden 1 så att den antingen blinkar eller helt av
	RETI
IS_BUTTON3_PRESSED:
	IN R24, PINB
	ANDI R24, (1 << BUTTON3)
	BREQ ISR_PCINT0_end
	CALL timer2_toggle			; Togglar lysdiod 2 så att den antingen blinkar eller helt av
ISR_PCINT0_end:
	RETI

; Gör så att led2 blinkar av och på när timer2 är igång i 200 ms
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

; Gör att led1 blinkar av och på när timer1 är igång i 100 ms
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

; Efter 300 ms återaktiveras PCI-avbrott och Timer 0 stängs av.
ISR_TIMER0_OVF:
	LDS R24, counter0
	INC R24
	CPI R24, TIMER0_MAX_COUNT
	BRLO ISR_TIMER0_OVF_end
	STS PCICR, R16				; PCICR = (1 << PCIE0) => PCIE0 = bit 0.
	CLR R24						; Nollställer counter0 så att den kan räkna om.
	STS TIMSK0, R24				; TIMSK0 = 0 => Timer 0 avstängd, då den gjort sitt jobb för denna gång.
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
	;Avbrottsvektor för knapparna
	STS PCICR, R16
	STS PCMSK0, R18

	;Sätter så att timer1 räknar upp till 256
	LDI R19, (1 << CS00) | (1 << CS02)
	OUT TCCR0B, R19 
	LDI R19, (1 << WGM12) | (1 << CS10) | (1 << CS12) ; WGM12 gör så att vi kan ställa in när den ska börja om
	STS TCCR1B, R19
	; OCR1A = 256 => Timer 1 räknar till 256 som de andra timerkretsarna.
	LDI R19, high(256)								  ; 256 = 0000 0001 0000 0000 => övre till OCR1AH, lägre till OCR1AL.
	STS OCR1AH, R19									  ; OCR1AH = 0000 0001.
	LDI R19, low(256) 
	STS OCR1AL, R19									  ; OCR1AL = 0000 0000
	;Sätter timer2 så att den räknar upp till 256
	LDI R19, (1 << CS22) | (1 << CS21) | (1 << CS20)
	STS TCCR2B, R19
	
main_loop:
	RJMP main_loop

system_reset:
   ;Släcker leds, stänga av timers och nollställ räknarna.
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

;Toggle funktion för timer1 både av och på
timer1_toggle:
	LDS R24, TIMSK1
	CPI R24, 0
	BREQ timer1_on
timer1_off:					;Släcker led1 och nollställer timer1
	CLR R24
	STS TIMSK1, R24
	IN R24, PORTB
	ANDI R24, ~(1 << LED1)
	OUT PORTB, R24
	RET
timer1_on:					;Sätter igång timer1 som tänder led1
	STS TIMSK1, R17			; (1 << OCIE1A) = (1 << LED2) = R17
	RET

;Toggle funktion för timer2 både av och på
timer2_toggle:
	LDS R24, TIMSK2
	CPI R24, 0
	BREQ timer2_on
timer2_off:					;Släcker led2 och nollställer timer2
	CLR R24
	STS TIMSK2, R24
	IN R24, PORTB
	ANDI R24, ~(1 << LED2)
	OUT PORTB, R24
	RET
timer2_on:					;Sätter igång timer1 som tänder led1
	STS TIMSK2, R16			; (1 << TOIE2) = (1 << LED1) = R16
	RET