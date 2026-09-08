; =============================================================================
; Controlador de reloj/cronometro
;
; Coordina la interfaz, el teclado y las actualizaciones periodicas.
; =============================================================================

BITS 16

; Ejecuta la interfaz hasta que Q o ESC soliciten regresar al kernel.
clock_run:
    mov byte [current_mode], MODE_CLOCK
    call clock_draw_interface

.main_loop:
    ; La alarma y el cronometro avanzan aunque no sean el modo visible.
    call alarm_check
    call alarm_update_notification

    call stopwatch_update
    test al, al
    jz .update_clock

    cmp byte [current_mode], MODE_STOPWATCH
    jne .update_clock
    call stopwatch_print

.update_clock:
    cmp byte [current_mode], MODE_CLOCK
    jne .read_keyboard
    call time_update

.read_keyboard:
    ; La consulta no bloqueante permite seguir actualizando el tiempo.
    call console_read_key
    test al, al
    jz .idle

    ; R es global, incluso cuando se muestra el reloj.
    cmp al, 'r'
    je .reset_stopwatch
    cmp al, 'R'
    je .reset_stopwatch

    cmp al, 'm'
    je .toggle_mode
    cmp al, 'M'
    je .toggle_mode

    ; A y C pertenecen exclusivamente al modo reloj.
    cmp byte [current_mode], MODE_CLOCK
    jne .stopwatch_controls

    cmp al, 'a'
    je .configure_alarm
    cmp al, 'A'
    je .configure_alarm
    cmp al, 'c'
    je .cancel_alarm
    cmp al, 'C'
    je .cancel_alarm
    jmp .check_exit

.stopwatch_controls:
    ; ESPACIO pertenece exclusivamente al cronometro.
    cmp al, ' '
    je .toggle_stopwatch

.check_exit:
    cmp al, 'q'
    je .exit
    cmp al, 'Q'
    je .exit
    cmp al, KEY_ESCAPE
    je .exit
    jmp .main_loop

.idle:
    ; El timer BIOS despierta la CPU del HLT periodicamente.
    hlt
    jmp .main_loop

.toggle_mode:
    xor byte [current_mode], 1
    call clock_draw_interface
    jmp .main_loop

.toggle_stopwatch:
    call stopwatch_toggle
    call stopwatch_print
    jmp .main_loop

.reset_stopwatch:
    call stopwatch_reset
    cmp byte [current_mode], MODE_STOPWATCH
    jne .main_loop
    call stopwatch_print
    jmp .main_loop

.configure_alarm:
    call alarm_configure
    cmp al, 2
    je .exit
    call clock_draw_interface
    jmp .main_loop

.cancel_alarm:
    call alarm_cancel
    call clock_draw_interface
    jmp .main_loop

.exit:
    call alarm_shutdown
    ret

; Reconstruye la pantalla segun current_mode.
clock_draw_interface:
    call console_clear

    mov si, application_title
    call console_print

    cmp byte [current_mode], MODE_CLOCK
    jne .stopwatch

    mov si, clock_screen
    call console_print
    mov si, clock_controls_message
    call console_print
    call time_force_refresh
    call alarm_print_status
    call alarm_redraw_notification
    ret

.stopwatch:
    mov si, stopwatch_screen
    call console_print
    call stopwatch_print
    mov si, stopwatch_controls_message
    call console_print
    ret

current_mode db MODE_CLOCK

application_title db '=== Reloj/Cronometro con Alarma ===', 0x0D, 0x0A
                  db 0x0D, 0x0A, 0

clock_screen db 'Modo: RELOJ', 0x0D, 0x0A
             db 'Hora actual: 00:00:00', 0x0D, 0x0A, 0

stopwatch_screen db 'Modo: CRONOMETRO', 0x0D, 0x0A
                 db 'Cronometro: 00:00:00', 0x0D, 0x0A
                 db 'Estado: ', 0

clock_controls_message db 0x0D, 0x0A
                       db '[R] Reiniciar cronometro', 0x0D, 0x0A
                       db '[M] Cambiar modo', 0x0D, 0x0A
                       db '[A] Configurar alarma  [C] Cancelar alarma', 0x0D, 0x0A
                       db '[Q/ESC] Finalizar', 0x0D, 0x0A, 0

stopwatch_controls_message db 0x0D, 0x0A
                           db '[M] Cambiar modo', 0x0D, 0x0A
                           db '[ESPACIO] Iniciar/Pausar/Reanudar', 0x0D, 0x0A
                           db '[R] Reiniciar cronometro', 0x0D, 0x0A
                           db '[Q/ESC] Finalizar', 0x0D, 0x0A, 0
