; =============================================================================
; Controlador de reloj/cronometro
;
; Mantiene el ciclo interactivo, selecciona el modo visible y coordina consola,
; RTC y cronometro.
; =============================================================================

BITS 16

; Ejecuta la interfaz hasta que Q o ESC soliciten regresar al kernel.
clock_run:
    mov byte [current_mode], MODE_CLOCK
    call clock_draw_interface

.main_loop:
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
    call console_read_key
    test al, al
    jz .idle

    cmp al, 'm'
    je .toggle_mode
    cmp al, 'M'
    je .toggle_mode

    ; ESPACIO y R solo tienen efecto cuando el cronometro esta visible.
    cmp byte [current_mode], MODE_STOPWATCH
    jne .check_exit
    cmp al, ' '
    je .toggle_stopwatch
    cmp al, 'r'
    je .reset_stopwatch
    cmp al, 'R'
    je .reset_stopwatch

.check_exit:
    cmp al, 'q'
    je .exit
    cmp al, 'Q'
    je .exit
    cmp al, KEY_ESCAPE
    je .exit
    jmp .main_loop

.idle:
    ; El timer BIOS despierta periodicamente la CPU para actualizar el tiempo.
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
    call stopwatch_print
    jmp .main_loop

.exit:
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
                       db '[M] Cambiar modo', 0x0D, 0x0A
                       db '[Q/ESC] Finalizar', 0x0D, 0x0A, 0

stopwatch_controls_message db 0x0D, 0x0A
                           db '[M] Cambiar modo', 0x0D, 0x0A
                           db '[ESPACIO] Iniciar/Pausar/Reanudar', 0x0D, 0x0A
                           db '[R] Reiniciar cronometro', 0x0D, 0x0A
                           db '[Q/ESC] Finalizar', 0x0D, 0x0A, 0
