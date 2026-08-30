BITS 64
DEFAULT REL

section .text
global clock_run

extern console_clear
extern console_print
extern console_read_key
extern console_set_attribute
extern time_print_current
extern alarm_cancel
extern alarm_check
extern alarm_configure
extern alarm_is_triggered
extern alarm_print_alert
extern alarm_print_status
extern stopwatch_print
extern stopwatch_reset
extern stopwatch_tick
extern stopwatch_toggle

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

.loop:
    mov rcx, rbx
    call alarm_check

    mov rcx, rbx
    call alarm_is_triggered
    cmp al, 0
    je .normal_screen

    xor byte [alert_blink], 1
    cmp byte [alert_blink], 0
    je .alert_green

    mov rcx, rbx
    mov edx, COLOR_ALERT_RED
    call console_set_attribute
    jmp .clear_screen

.alert_green:
    mov rcx, rbx
    mov edx, COLOR_ALERT_GREEN
    call console_set_attribute
    jmp .clear_screen

.normal_screen:
    mov byte [alert_blink], 0
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

.clear_screen:
    mov rcx, rbx
    call console_clear

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
    call console_read_key
    cmp ax, 'q'
    je .exit
    cmp ax, 'Q'
    je .exit
    cmp ax, 'm'
    je .switch_mode
    cmp ax, 'M'
    je .switch_mode
    cmp ax, 's'
    je .toggle_stopwatch
    cmp ax, 'S'
    je .toggle_stopwatch
    cmp ax, 'r'
    je .reset_stopwatch
    cmp ax, 'R'
    je .reset_stopwatch
    cmp ax, 'a'
    je .configure_alarm
    cmp ax, 'A'
    je .configure_alarm
    cmp ax, 'c'
    je .cancel_alarm
    cmp ax, 'C'
    je .cancel_alarm

.wait_next_second:
    ; BootServices->Stall(1000000): espera 1 segundo.
    mov rax, [rbx + 96]
    mov ecx, 1000000
    call [rax + 248]

    call stopwatch_tick
    jmp .loop

.switch_mode:
    xor byte [current_mode], 1
    jmp .wait_next_second

.toggle_stopwatch:
    cmp byte [current_mode], 1
    jne .wait_next_second
    call stopwatch_toggle
    jmp .wait_next_second

.reset_stopwatch:
    cmp byte [current_mode], 1
    jne .wait_next_second
    call stopwatch_reset
    jmp .wait_next_second

.configure_alarm:
    mov rcx, rbx
    call alarm_configure
    jmp .loop

.cancel_alarm:
    call alarm_cancel
    jmp .wait_next_second

.exit:
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
