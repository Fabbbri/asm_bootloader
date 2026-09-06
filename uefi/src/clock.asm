BITS 64
DEFAULT REL

section .text
global clock_run

extern console_clear
extern console_print
extern console_read_key
extern console_set_attribute
extern console_set_cursor
extern time_print_current
extern alarm_cancel
extern alarm_check
extern alarm_configure
extern alarm_is_editing
extern alarm_handle_key
extern alarm_print_editor
extern alarm_is_triggered
extern alarm_print_alert
extern alarm_print_status
extern stopwatch_print
extern stopwatch_reset
extern stopwatch_update
extern timer_start
extern timer_stop
extern timer_ticks
extern stopwatch_toggle
extern sound_start
extern sound_stop

COLOR_NORMAL equ 0x07
COLOR_TITLE equ 0x0B
COLOR_MODE equ 0x0E
COLOR_HELP equ 0x0A
COLOR_ALERT_RED equ 0x4F
COLOR_ALERT_GREEN equ 0x2F

; Ejecuta el modo reloj con actualizacion periodica.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
clock_run:
    push rbx
    sub rsp, 48

    mov rbx, rcx
    call timer_start
    test rax, rax
    jnz .timer_error
    mov qword [last_second], -1

.loop:
    mov rcx, [timer_ticks]
    call stopwatch_update
    mov rax, [timer_ticks]
    xor edx, edx
    mov ecx, 100
    div rcx
    cmp rax, [last_second]
    je .refresh_stopwatch
    mov [last_second], rax
    jmp .redraw

.refresh_stopwatch:
    ; Refrescar solo el contador cada 50 ms, sin limpiar toda la pantalla.
    cmp byte [current_mode], 1
    jne .read_key
    call alarm_is_editing
    test al, al
    jnz .read_key
    mov rax, [timer_ticks]
    xor edx, edx
    mov ecx, 5
    div rcx
    cmp rax, [last_frame]
    je .read_key
    mov [last_frame], rax
    mov rcx, rbx
    xor edx, edx
    mov r8d, 3               ; fila del contador, bajo titulo/modo/linea vacia
    call console_set_cursor
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute
    mov rcx, rbx
    call stopwatch_print
    jmp .read_key

.redraw:
    mov rcx, rbx
    call alarm_check

    mov rcx, rbx
    call alarm_is_triggered
    cmp al, 0
    je .normal_screen

    mov rax, [last_second]
    and eax, 1
    mov [alert_blink], al
    cmp byte [alert_blink], 0
    je .alert_green

    call sound_start
    mov rcx, rbx
    mov edx, COLOR_ALERT_RED
    call console_set_attribute
    jmp .clear_screen

.alert_green:
    call sound_stop
    mov rcx, rbx
    mov edx, COLOR_ALERT_GREEN
    call console_set_attribute
    jmp .clear_screen

.normal_screen:
    call sound_stop
    mov byte [alert_blink], 0
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

.clear_screen:
    mov rcx, rbx
    call console_clear

    ; La captura tiene su propia pantalla, pero comparte el bucle de tiempo.
    call alarm_is_editing
    test al, al
    jnz .draw_alarm_editor

    mov rcx, rbx
    mov edx, COLOR_TITLE
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [title]
    call console_print

    cmp byte [current_mode], 0
    jne .draw_stopwatch

    mov rcx, rbx
    mov edx, COLOR_MODE
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [mode_clock]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    call time_print_current
    jmp .draw_help

.draw_stopwatch:
    mov rcx, rbx
    mov edx, COLOR_MODE
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [mode_stopwatch]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    call stopwatch_print

.draw_help:
    mov rcx, rbx
    call alarm_print_status

    mov rcx, rbx
    call alarm_print_alert

    mov rcx, rbx
    mov edx, COLOR_HELP
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [help]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    call alarm_print_editor
    jmp .read_key

.draw_alarm_editor:
    mov rcx, rbx
    mov edx, COLOR_TITLE
    call console_set_attribute

    mov rcx, rbx
    call alarm_print_editor

    ; Una alarma previa sigue notificandose incluso durante la captura.
    mov rcx, rbx
    call alarm_print_alert

.read_key:
    mov rcx, [timer_ticks]
    call stopwatch_update
    call alarm_is_editing
    mov [rsp + 32], al
    mov rcx, rbx
    call console_read_key
    mov cx, ax
    or cx, dx
    jz .wait_input
    cmp ax, 'q'
    je .exit
    cmp ax, 'Q'
    je .exit
    ; Reinicio global: tambien funciona mientras se configura la alarma.
    cmp ax, 'r'
    je .reset_stopwatch
    cmp ax, 'R'
    je .reset_stopwatch
    cmp byte [rsp + 32], 0
    jne .edit_alarm
    cmp ax, 'm'
    je .switch_mode
    cmp ax, 'M'
    je .switch_mode
    cmp ax, 's'
    je .toggle_stopwatch
    cmp ax, 'S'
    je .toggle_stopwatch
    cmp ax, 'a'
    je .configure_alarm
    cmp ax, 'A'
    je .configure_alarm
    cmp ax, 'c'
    je .cancel_alarm
    cmp ax, 'C'
    je .cancel_alarm
    jmp .wait_input

.wait_input:
    ; Espera corta: el tiempo transcurrido proviene del timer, no de Stall.
    mov rax, [rbx + 96]
    mov ecx, 10000
    call [rax + 248]
    jmp .loop

.switch_mode:
    xor byte [current_mode], 1
    jmp .redraw

.toggle_stopwatch:
    cmp byte [current_mode], 1
    jne .wait_input
    call stopwatch_toggle
    jmp .redraw

.reset_stopwatch:
    call stopwatch_reset
    jmp .redraw

.edit_alarm:
    call alarm_handle_key
    jmp .redraw

.configure_alarm:
    mov rcx, rbx
    call alarm_configure
    jmp .redraw

.cancel_alarm:
    call alarm_cancel
    jmp .redraw

.exit:
    call sound_stop
    mov rcx, rbx
    call timer_stop
    jmp .finish

.timer_error:
    mov rcx, rbx
    lea rdx, [timer_error]
    call console_print

.finish:
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    add rsp, 48
    pop rbx
    ret

section .data
title:
    dw __utf16__("CE4303 - Reloj/Cronometro UEFI")
    dw 13, 10
    dw 0

mode_clock:
    dw __utf16__("Modo actual: Reloj")
    dw 13, 10
    dw 13, 10
    dw 0

mode_stopwatch:
    dw __utf16__("Modo actual: Cronometro")
    dw 13, 10
    dw 13, 10
    dw 0

help:
    dw 13, 10
    dw __utf16__("M: modo | S: iniciar/pausar | R: reiniciar")
    dw 13, 10
    dw __utf16__("A: configurar alarma | C: cancelar alarma | Q: salir")
    dw 13, 10
    dw 0

current_mode db 0
alert_blink db 0

align 8
last_second dq -1
last_frame dq -1
timer_error:
    dw __utf16__("Error: no se pudo iniciar el temporizador UEFI."), 13, 10, 0
