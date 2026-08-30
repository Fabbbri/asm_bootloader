BITS 64
DEFAULT REL

section .text
global clock_run

extern console_clear
extern console_print
extern console_read_key
extern time_print_current
extern stopwatch_print
extern stopwatch_reset
extern stopwatch_tick
extern stopwatch_toggle

; Ejecuta el modo reloj con actualizacion periodica.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
clock_run:
    push rbx
    sub rsp, 48

    mov rbx, rcx

.loop:
    mov rcx, rbx
    call console_clear

    mov rcx, rbx
    lea rdx, [title]
    call console_print

    cmp byte [current_mode], 0
    jne .draw_stopwatch

    mov rcx, rbx
    lea rdx, [mode_clock]
    call console_print

    mov rcx, rbx
    call time_print_current
    jmp .draw_help

.draw_stopwatch:
    mov rcx, rbx
    lea rdx, [mode_stopwatch]
    call console_print

    mov rcx, rbx
    call stopwatch_print

.draw_help:
    mov rcx, rbx
    lea rdx, [help]
    call console_print

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
    call stopwatch_toggle
    jmp .wait_next_second

.reset_stopwatch:
    call stopwatch_reset
    jmp .wait_next_second

.exit:
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
    dw __utf16__("M: cambiar modo | S: iniciar/pausar | R: reiniciar | Q: salir")
    dw 13, 10
    dw 0

current_mode db 0
