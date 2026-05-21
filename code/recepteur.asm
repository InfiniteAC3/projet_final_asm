TITLE "Recepteur Commutation Forcee - Sanderson"
    LIST P=18F2550
    #include <P18F2550.INC>
    
    CONFIG FOSC = INTOSCIO_EC, WDT = OFF, MCLRE = OFF, LVP = OFF

    CBLOCK 0x000
        offset, char_count, temp, d1, d2, d3
    ENDC

#define MSG_RAM_START 0x100

    ORG 0x0000
    GOTO start

; --- ROUTINES DE BASE ---

delay_5ms:
    MOVLW .203
    MOVWF d1
    MOVLW .7
    MOVWF d2
d5_L: 
    DECFSZ d1, 1
    BRA d5_L
    DECFSZ d2, 1
    BRA d5_L
    RETURN

delay_25ms:
    MOVLW .5
    MOVWF d3
d25_L: 
    CALL delay_5ms
    DECFSZ d3, 1
    BRA d25_L
    RETURN

pulse_e:
    BSF LATB, 5
    NOP
    BCF LATB, 5
    CALL delay_5ms
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
    RETURN

; --- INITIALISATIONS ---

start:
    MOVLW 0x60
    MOVWF OSCCON
    CLRF TRISB
    
    ; Init LCD
    CALL delay_5ms
    MOVLW 0x03
    MOVWF LATB
    CALL pulse_e
    MOVLW 0x02
    MOVWF LATB
    CALL pulse_e
    MOVLW 0x28
    CALL lcd_cmd
    MOVLW 0x0C
    CALL lcd_cmd
    
    ; Init UART
    BSF TRISC, 7
    BCF TRISC, 6
    MOVLW .25
    MOVWF SPBRG
    MOVLW 0x90
    MOVWF RCSTA
    MOVLW 0x24
    MOVWF TXSTA

; --- BOUCLE DE RECEPTION ---

prepare_new_msg:
    MOVLW 0x01          
    CALL lcd_cmd
    BCF RCSTA, CREN     
    MOVF RCREG, W       
    MOVF RCREG, W
    BSF RCSTA, CREN
    LFSR FSR0, MSG_RAM_START 

wait_char:
    BTFSS PIR1, RCIF
    BRA wait_char
    
    MOVF RCREG, W
    MOVWF POSTINC0
    XORLW 0x00          
    BNZ wait_char

; --- BOUCLE DE SCROLL AVEC DETECTION D'INTERRUPTION ---

main_scroll:
    CLRF offset
scroll_step:
    MOVLW 0x80
    CALL lcd_cmd
    
    LFSR FSR0, MSG_RAM_START
    MOVF offset, W
    ADDWF FSR0L, 1
    
    MOVLW .16
    MOVWF char_count
display_window:
    BTFSC PIR1, RCIF
    BRA prepare_new_msg
    
    MOVF INDF0, W       ; Analyse le caractère SANS déplacer le pointeur
    BZ restart_scroll
    
    MOVF POSTINC0, W    ; Charge dans W et incrémente proprement pour l'affichage
    CALL lcd_write_char
    DECFSZ char_count, 1
    BRA display_window
    
    CALL delay_25ms
    INCF offset, 1
    BRA scroll_step

restart_scroll:
    BRA main_scroll

    END