; =============================================================================
; Alarma basada en el RTC del BIOS
;
; Captura HH:MM, compara contra el RTC y controla la notificacion.
; =============================================================================

BITS 16

KEY_BACKSPACE equ 0x08

ALARM_INPUT_LENGTH equ 5
ALARM_ALERT_ROW     equ 14
ALARM_ALERT_COLUMN  equ 22
TEXT_SCREEN_CELLS   equ 80 * 25
TEXT_VIDEO_SEGMENT  equ 0xB800

ALARM_COLOR_RED   equ 0x4F
ALARM_COLOR_GREEN equ 0x2F
ALARM_COLOR_NORMAL equ 0x07

; Captura HH:MM. ESC conserva la alarma anterior y Q solicita salir.
; Salida: AL=0 si se cancelo, AL=1 si se configuro, AL=2 si se solicito salir.
alarm_configure:

.restart:
    mov byte [alarm_reference_second], 0xFF
    call console_clear
    mov si, alarm_configuration_header
    call console_print
    call time_print_current_line
    mov si, alarm_configuration_instructions
    call console_print

    call alarm_redraw_notification

    mov byte [alarm_input_count], 0
    mov di, alarm_input_buffer

.read_key:
    call alarm_read_key_live

    cmp al, KEY_ESCAPE
    je .cancel
    cmp al, 'q'
    je .request_exit
    cmp al, 'Q'
    je .request_exit
    cmp al, KEY_BACKSPACE
    je .backspace

    ; El buffer usa cinco posiciones: HH:MM.
    cmp byte [alarm_input_count], 2
    je .expect_colon

    call alarm_is_digit
    test al, al
    jz .invalid_key
    mov al, [alarm_typed_character]
    jmp .store_character

.expect_colon:
    cmp al, ':'
    jne .invalid_key

.store_character:
    mov [di], al
    inc di
    inc byte [alarm_input_count]
    call console_print_char

    cmp byte [alarm_input_count], ALARM_INPUT_LENGTH
    jne .read_key

    call alarm_validate_and_store
    test al, al
    jnz .configured

    mov si, alarm_invalid_time_message
    call console_print
    mov si, alarm_retry_message
    call console_print
    call alarm_read_key_live
    cmp al, 'q'
    je .request_exit
    cmp al, 'Q'
    je .request_exit
    cmp al, KEY_ESCAPE
    je .cancel
    jmp .restart

.backspace:
    cmp byte [alarm_input_count], 0
    je .read_key

    dec byte [alarm_input_count]
    dec di
    mov al, KEY_BACKSPACE
    call console_print_char
    mov al, ' '
    call console_print_char
    mov al, KEY_BACKSPACE
    call console_print_char
    jmp .read_key

.invalid_key:
    ; BEL informa el error sin abandonar la captura.
    mov al, 0x07
    call console_print_char
    jmp .read_key

.configured:
    mov al, 1
    ret

.cancel:
    xor al, al
    ret

.request_exit:
    mov al, 2
    ret

; Espera cooperativa usada tanto en la captura como en el mensaje de error.
; Mantiene el tiempo y la alarma anterior sin dibujar la pantalla principal.
; Salida: AL = tecla. R se consume aqui y reinicia sin alterar la captura.
alarm_read_key_live:
.poll:
    call alarm_check
    call alarm_update_notification
    call stopwatch_update
    call time_update_alarm_reference
    call console_read_key
    test al, al
    jz .idle
    cmp al, 'r'
    je .reset_stopwatch
    cmp al, 'R'
    je .reset_stopwatch
    ret
.reset_stopwatch:
    call stopwatch_reset
    jmp .poll
.idle:
    hlt
    jmp .poll

; Salida: AL=1 si el caracter es decimal; AL=0 si no lo es.
alarm_is_digit:
    mov [alarm_typed_character], al
    cmp al, '0'
    jb .not_digit
    cmp al, '9'
    ja .not_digit
    mov al, 1
    ret

.not_digit:
    xor al, al
    ret

; Valida 00-23/00-59 y almacena ambos campos en BCD.
; Salida: AL=1 si la hora es valida; AL=0 en caso contrario.
alarm_validate_and_store:
    push bx
    push dx

    mov al, [alarm_input_buffer]
    sub al, '0'
    mov bl, 10
    mul bl
    mov dl, [alarm_input_buffer + 1]
    sub dl, '0'
    add al, dl
    cmp al, 23
    ja .invalid

    mov al, [alarm_input_buffer + 3]
    sub al, '0'
    mul bl
    mov dl, [alarm_input_buffer + 4]
    sub dl, '0'
    add al, dl
    cmp al, 59
    ja .invalid

    ; El mismo formato BCD del RTC permite comparar sin conversion posterior.
    mov al, [alarm_input_buffer]
    sub al, '0'
    shl al, 4
    mov dl, [alarm_input_buffer + 1]
    sub dl, '0'
    or al, dl
    mov [alarm_hour_bcd], al

    mov al, [alarm_input_buffer + 3]
    sub al, '0'
    shl al, 4
    mov dl, [alarm_input_buffer + 4]
    sub dl, '0'
    or al, dl
    mov [alarm_minute_bcd], al

    mov byte [alarm_active], 1
    mov byte [alarm_triggered], 0
    mov byte [alarm_alert_phase], 0
    mov byte [alarm_last_alert_second], 0xFF
    call sound_stop

    mov al, 1
    jmp .done

.invalid:
    xor al, al

.done:
    pop dx
    pop bx
    ret

; Compara la hora/minuto del RTC con la alarma configurada.
; La alarma queda disparada hasta que el usuario presione C.
alarm_check:
    push ax
    push cx
    push dx

    cmp byte [alarm_active], 0
    je .done
    cmp byte [alarm_triggered], 0
    jne .done

    mov ah, 0x02
    int 0x1A
    jc .done

    cmp ch, [alarm_hour_bcd]
    jne .done
    cmp cl, [alarm_minute_bcd]
    jne .done

    mov byte [alarm_triggered], 1
    mov byte [alarm_alert_phase], 0
    mov byte [alarm_last_alert_second], 0xFF

.done:
    pop dx
    pop cx
    pop ax
    ret

; Alterna color y sonido una vez por segundo sin bloquear el teclado.
alarm_update_notification:
    push ax
    push cx
    push dx

    cmp byte [alarm_triggered], 0
    je .done

    mov ah, 0x02
    int 0x1A
    jc .rtc_error

    cmp dh, [alarm_last_alert_second]
    je .done
    mov [alarm_last_alert_second], dh

    xor byte [alarm_alert_phase], 1
    cmp byte [alarm_alert_phase], 0
    je .silent_phase

    call sound_start
    call alarm_draw_alert
    jmp .done

.silent_phase:
    call sound_stop
    call alarm_draw_alert
    jmp .done

.rtc_error:
    call sound_stop

.done:
    pop dx
    pop cx
    pop ax
    ret

; Imprime el estado de la alarma en la fila reservada del modo reloj.
alarm_print_status:
    push ax
    push bx
    push dx
    push si

    mov ah, 0x02
    xor bh, bh
    mov dh, 4
    xor dl, dl
    int 0x10

    cmp byte [alarm_active], 0
    je .inactive

    call alarm_update_status_text
    mov si, alarm_active_text
    jmp .print

.inactive:
    mov si, alarm_inactive_text

.print:
    call console_print
    pop si
    pop dx
    pop bx
    pop ax
    ret

; Vuelve a dibujar el aviso cuando la interfaz se reconstruye durante una alarma.
alarm_redraw_notification:
    cmp byte [alarm_triggered], 0
    je .done
    call alarm_draw_alert
.done:
    ret

; Desactiva y borra por completo la alarma configurada.
alarm_cancel:
    mov byte [alarm_active], 0
    mov byte [alarm_triggered], 0
    mov byte [alarm_alert_phase], 0
    mov byte [alarm_last_alert_second], 0xFF
    call sound_stop
    call alarm_clear_alert
    ret

; Garantiza que el altavoz quede apagado antes de finalizar la aplicacion.
alarm_shutdown:
    call sound_stop
    ret

; Inserta la hora BCD configurada dentro de la cadena visible de estado.
alarm_update_status_text:
    push ax
    push bx

    mov al, [alarm_hour_bcd]
    mov bl, al
    shr al, 4
    and al, 0x0F
    add al, '0'
    mov [alarm_active_text + 8], al
    mov al, bl
    and al, 0x0F
    add al, '0'
    mov [alarm_active_text + 9], al

    mov al, [alarm_minute_bcd]
    mov bl, al
    shr al, 4
    and al, 0x0F
    add al, '0'
    mov [alarm_active_text + 11], al
    mov al, bl
    and al, 0x0F
    add al, '0'
    mov [alarm_active_text + 12], al

    pop bx
    pop ax
    ret

; Colorea toda la pantalla y escribe el mensaje de alerta.
alarm_draw_alert:
    push ax
    push bx
    push cx
    push dx
    push bp
    push es

    push ds
    pop es
    mov bp, alarm_alert_text
    mov cx, ALARM_ALERT_LENGTH
    mov dh, ALARM_ALERT_ROW
    mov dl, ALARM_ALERT_COLUMN
    xor bh, bh
    mov bl, ALARM_COLOR_RED
    cmp byte [alarm_alert_phase], 0
    jne .write
    mov bl, ALARM_COLOR_GREEN

.write:
    call alarm_apply_screen_color
    mov ax, 0x1300
    int 0x10

    pop es
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Cambia solo los bytes de atributo en la memoria de video 80x25.
; Entrada: BL = atributo de color que se aplicara a toda la pantalla.
alarm_apply_screen_color:
    push ax
    push cx
    push di
    push es

    mov ax, TEXT_VIDEO_SEGMENT
    mov es, ax
    mov di, 1
    mov cx, TEXT_SCREEN_CELLS

.next_cell:
    mov [es:di], bl
    add di, 2
    loop .next_cell

    pop es
    pop di
    pop cx
    pop ax
    ret

; Borra unicamente la linea donde se presenta el mensaje de alarma.
alarm_clear_alert:
    push ax
    push bx
    push cx
    push dx
    push bp
    push es

    push ds
    pop es
    mov bp, alarm_alert_clear_text
    mov cx, ALARM_ALERT_LENGTH
    mov dh, ALARM_ALERT_ROW
    mov dl, ALARM_ALERT_COLUMN
    xor bh, bh
    mov bl, ALARM_COLOR_NORMAL
    mov ax, 0x1300
    int 0x10

    pop es
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret

alarm_configuration_header db '=== Configurar alarma ===', 0x0D, 0x0A
                           db 0x0D, 0x0A, 0

alarm_configuration_instructions db 0x0D, 0x0A
                                 db 'Ingrese la hora en formato HH:MM.', 0x0D, 0x0A
                                 db 'Rangos: HH 00-23 y MM 00-59.', 0x0D, 0x0A
                                 db '[BACKSPACE] Corregir  [ESC] Cancelar  [Q] Salir', 0x0D, 0x0A
                                 db '[R] Reiniciar cronometro', 0x0D, 0x0A
                                 db 0x0D, 0x0A
                                 db 'Alarma: ', 0

alarm_invalid_time_message db 0x0D, 0x0A
                           db 'Hora invalida.', 0x0D, 0x0A, 0
alarm_retry_message db 'Presione ENTER para intentarlo de nuevo o ESC para cancelar.', 0x0D, 0x0A, 0

alarm_active_text db 'Alarma: 00:00 (C cancela)', 0x0D, 0x0A, 0
alarm_inactive_text db 'Alarma: no configurada       ', 0x0D, 0x0A, 0

alarm_alert_text db '*** ALARMA ACTIVA - PRESIONE C ***'
alarm_alert_end:
ALARM_ALERT_LENGTH equ alarm_alert_end - alarm_alert_text
alarm_alert_clear_text times ALARM_ALERT_LENGTH db ' '

alarm_input_buffer times ALARM_INPUT_LENGTH db 0
alarm_input_count db 0
alarm_typed_character db 0

; Hora configurada en el mismo BCD que devuelve INT 1Ah.
alarm_hour_bcd db 0
alarm_minute_bcd db 0

; Estado persistente consultado por el ciclo principal.
alarm_active db 0
alarm_triggered db 0
alarm_alert_phase db 0
alarm_last_alert_second db 0xFF
