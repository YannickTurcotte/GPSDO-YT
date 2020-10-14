;****************************************************************************************************
;****************************************************************************************************
;****************************************************************************************************
;interrupt atmega328jmp RESET ; Reset
jmp reset
jmp Latch ; IRQ0
jmp pushbutton ; IRQ1
jmp reset ; PCINT0
jmp reset ; PCINT1
jmp reset ; PCINT2
jmp watchdog_overflow ; Watchdog Timeout
jmp reset ; Timer2 CompareA
jmp reset ; Timer2 CompareB
jmp reset ; Timer2 Overflow
jmp reset ; Timer1 Capture
jmp reset ; Timer1 CompareA
jmp reset ; Timer1 CompareB
jmp reset ; Timer1 Overflow
jmp reset ; Timer0 CompareA
jmp reset ; Timer0 CompareB
jmp TIM0_OVF ; Timer0 Overflow
jmp reset ; SPI Transfer Complete
jmp reset ; USART RX Complete
jmp reset ; USART UDR Empty
jmp reset ; USART TX Complete
jmp reset ; ADC Conversion Complete
jmp reset ; EEPROM Ready
jmp reset ; Analog Comparator
jmp reset ; 2-wire Serial
jmp reset ; SPM Ready
