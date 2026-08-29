BITS 64
DEFAULT REL

section .text
global clock_run

extern console_clear
extern console_print
extern console_read_key
extern time_print_current

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

    mov rcx, rbx
    call time_print_current

    mov rcx, rbx
    lea rdx, [help]
    call console_print

    mov rcx, rbx
    call console_read_key
    cmp ax, 'q'
    je .exit
    cmp ax, 'Q'
    je .exit

    ; BootServices->Stall(1000000): espera 1 segundo.
    mov rax, [rbx + 96]
    mov ecx, 1000000
    call [rax + 248]
    jmp .loop

.exit:
    add rsp, 48
    pop rbx
    ret

section .data
title:
    dw __utf16__("CE4303 - Reloj UEFI")
    dw 13, 10
    dw __utf16__("Modo actual: Reloj")
    dw 13, 10
    dw 13, 10
    dw 0

help:
    dw 13, 10
    dw __utf16__("Q: salir")
    dw 13, 10
    dw 0
