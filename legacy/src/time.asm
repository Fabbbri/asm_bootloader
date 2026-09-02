; =============================================================================
; Hora real mediante RTC
;
; Obtiene HH:MM:SS mediante el servicio RTC del BIOS y actualiza solamente el 
; campo de hora de la interfaz.
; =============================================================================

BITS 16

; Fuerza una escritura inmediata de la hora y luego realiza la lectura RTC.
time_force_refresh:
    mov byte [last_rtc_second], 0xFF
    call time_update
    ret

; Lee la hora real con INT 1Ah/AH=02h. El BIOS devuelve valores BCD empaquetados:
; CH=hora, CL=minutos y DH=segundos. Solo escribe en pantalla cuando cambia el
; segundo; si CF=1, muestra --:--:-- una unica vez.
;
; Preserva: AX, BX, CX, DX y SI.
time_update:
    push ax
    push bx
    push cx
    push dx
    push si

    mov ah, 0x02
    int 0x1A
    jc .read_error

    cmp dh, [last_rtc_second]
    je .done

    mov [rtc_hour], ch
    mov [rtc_minute], cl
    mov [rtc_second], dh
    mov [last_rtc_second], dh

    call time_set_cursor
    mov al, [rtc_hour]
    call time_print_bcd
    mov al, ':'
    call console_print_char
    mov al, [rtc_minute]
    call time_print_bcd
    mov al, ':'
    call console_print_char
    mov al, [rtc_second]
    call time_print_bcd
    jmp .done

.read_error:
    cmp byte [last_rtc_second], 0xFE
    je .done

    mov byte [last_rtc_second], 0xFE
    call time_set_cursor
    mov si, rtc_error_value
    call console_print

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Posiciona el cursor al inicio del campo HH:MM:SS del modo reloj.
time_set_cursor:
    mov ah, 0x02
    xor bh, bh
    mov dh, 3
    mov dl, 13
    int 0x10
    ret

; Convierte el BCD empaquetado de AL en dos caracteres decimales.
; Ejemplo: AL=0x23 imprime "23". Preserva AX y BX.
time_print_bcd:
    push ax
    push bx

    mov bl, al
    shr al, 4
    and al, 0x0F
    add al, '0'
    call console_print_char

    mov al, bl
    and al, 0x0F
    add al, '0'
    call console_print_char

    pop bx
    pop ax
    ret

last_rtc_second db 0xFF
rtc_hour db 0
rtc_minute db 0
rtc_second db 0
rtc_error_value db '--:--:--', 0
