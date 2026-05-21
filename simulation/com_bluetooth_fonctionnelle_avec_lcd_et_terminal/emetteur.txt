TITLE "Emetteur Intelligent - Sanderson"
    LIST P=18F2550
    #include <P18F2550.INC>
    
    CONFIG FOSC = INTOSCIO_EC, WDT = OFF, MCLRE = OFF, LVP = OFF

    CBLOCK 0x000
        temp, d1, d2, d3
        char_rx, last_char
        ptr_count
    ENDC

#define MSG_BASE 0x100

    ORG 0x0000
    GOTO start

    ORG 0x0020
start:
    MOVLW 0x60
    MOVWF OSCCON
    CLRF TRISB
    
    CALL reset_buffer
    
    CALL delay_50ms
    CALL lcd_init
    CALL init_uart

main_loop:
    BTFSS PIR1, RCIF
    BRA main_loop
    
    MOVF RCREG, W
    MOVWF char_rx

    XORLW '&'
    BNZ check_send
    MOVF last_char, W
    XORLW '&'
    BNZ update_last
    CALL clear_lcd_and_reset
    BRA main_loop

check_send:
    MOVF char_rx, W
    XORLW '-'
    BNZ store_and_display
    MOVF last_char, W
    XORLW '-'
    BNZ update_last
    CALL send_buffer    
    BRA main_loop

store_and_display:
    MOVF char_rx, W
    CALL lcd_write_char
    
    MOVF ptr_count, W
    SUBLW .15
    BTFSS STATUS, C
    CALL lcd_scroll_left

    MOVF char_rx, W
    MOVWF POSTINC0      
    INCF ptr_count, 1
    BRA update_last

update_last:
    MOVF char_rx, W
    MOVWF last_char
    BRA main_loop

lcd_scroll_left:
    MOVLW 0x18
    CALL lcd_cmd
    RETURN

clear_lcd_and_reset:
    MOVLW 0x01
    CALL lcd_cmd
    CALL reset_buffer
    RETURN

send_buffer:
    MOVF ptr_count, W
    BZ end_send
    LFSR FSR1, MSG_BASE
send_next:
    MOVF POSTINC1, W
    CALL send_char
    DECFSZ ptr_count, 1
    BRA send_next
    MOVLW 0x00          ; Envoi du NULL pour notifier le PIC 2
    CALL send_char
end_send:
    CALL clear_lcd_and_reset
    RETURN

reset_buffer:
    CLRF ptr_count
    LFSR FSR0, MSG_BASE 
    CLRF last_char
    RETURN

init_uart:
    BSF TRISC, 7
    BCF TRISC, 6
    MOVLW .25
    MOVWF SPBRG
    BSF RCSTA, SPEN
    BSF RCSTA, CREN
    BSF TXSTA, TXEN
    BSF TXSTA, BRGH
    RETURN

send_char:
    BTFSS PIR1, TXIF
    BRA send_char
    MOVWF TXREG
    RETURN

lcd_init:
    MOVLW 0x03
    MOVWF LATB
    CALL pulse_e
    CALL delay_5ms
    MOVLW 0x02
    MOVWF LATB
    CALL pulse_e
    MOVLW 0x28
    CALL lcd_cmd
    MOVLW 0x0C
    CALL lcd_cmd
    MOVLW 0x01
    CALL lcd_cmd
    RETURN

lcd_cmd:
    MOVWF temp
    SWAPF temp, W
    ANDLW 0x0F
    MOVWF LATB
    CALL pulse_e
    MOVF temp, W
    ANDLW 0x0F
    MOVWF LATB
    CALL pulse_e
    CALL delay_5ms
    RETURN

lcd_write_char:
    MOVWF temp
    SWAPF temp, W
    ANDLW 0x0F
    IORLW 0x10
    MOVWF LATB
    CALL pulse_e
    MOVF temp, W
    ANDLW 0x0F
    IORLW 0x10
    MOVWF LATB
    CALL pulse_e
    MOVF temp, W
    RETURN

pulse_e:
    BSF LATB, 5
    NOP
    BCF LATB, 5
    CALL delay_5ms
    RETURN

delay_5ms:
    MOVLW .203
    MOVWF d1
    MOVLW .7
    MOVWF d2
d5_L_e: 
    DECFSZ d1, 1
    BRA d5_L_e
    DECFSZ d2, 1
    BRA d5_L_e
    RETURN

delay_50ms:
    MOVLW .10
    MOVWF d3
d50_L_e: 
    CALL delay_5ms
    DECFSZ d3, 1
    BRA d50_L_e
    RETURN

    END