BITS 64
DEFAULT REL

section .text
global time_print_current
global time_get_hms

extern console_print

; Obtiene hora, minuto y segundo actuales.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
; Salida:
;   AL = hora, DL = minuto, R8B = segundo
time_get_hms:
    sub rsp, 72

    mov rax, [rcx + 88]
    lea rcx, [rsp + 48]
    xor edx, edx
    call [rax + 24]

    movzx eax, byte [rsp + 52]
    movzx edx, byte [rsp + 53]
    movzx r8d, byte [rsp + 54]

    add rsp, 72
    ret

; Lee la hora actual del firmware UEFI y la imprime como HH:MM:SS.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
time_print_current:
    push rbx
    sub rsp, 80

    mov rbx, rcx

    call time_get_hms
    mov [rsp + 32], al
    mov [rsp + 33], dl
    mov [rsp + 34], r8b

    lea rdi, [time_line + time_value_offset]
    movzx eax, byte [rsp + 32]
    call write_two_digits
    add rdi, 2
    movzx eax, byte [rsp + 33]
    call write_two_digits
    add rdi, 2
    movzx eax, byte [rsp + 34]
    call write_two_digits

    mov rcx, rbx
    lea rdx, [time_line]
    call console_print

    add rsp, 80
    pop rbx
    ret

; Entrada:
;   EAX = numero entre 0 y 99
;   RDI = posicion del buffer CHAR16
; Salida:
;   RDI avanza dos caracteres UTF-16.
write_two_digits:
    xor edx, edx
    mov r8d, 10
    div r8d

    add al, '0'
    mov [rdi], ax
    add rdi, 2

    mov eax, edx
    add al, '0'
    mov [rdi], ax
    add rdi, 2
    ret

section .data
time_line:
    dw __utf16__("Hora actual: ")
time_value_offset equ $ - time_line
    dw __utf16__("00:00:00")
    dw 13, 10
    dw 0
