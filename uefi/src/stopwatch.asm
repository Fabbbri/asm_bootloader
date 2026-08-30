BITS 64
DEFAULT REL

section .text
global stopwatch_print
global stopwatch_reset
global stopwatch_tick
global stopwatch_toggle

extern console_print

; Imprime el tiempo acumulado del cronometro.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
stopwatch_print:
    push rbx
    sub rsp, 32

    mov rbx, rcx

    mov rax, [elapsed_seconds]
    xor edx, edx
    mov ecx, 3600
    div rcx
    mov r8d, eax

    mov rax, rdx
    xor edx, edx
    mov ecx, 60
    div rcx
    mov r9d, eax
    mov r10d, edx

    lea r11, [stopwatch_line + stopwatch_value_offset]
    mov eax, r8d
    call write_two_digits
    add r11, 2
    mov eax, r9d
    call write_two_digits
    add r11, 2
    mov eax, r10d
    call write_two_digits

    mov rcx, rbx
    lea rdx, [stopwatch_line]
    call console_print

    cmp byte [is_running], 0
    je .paused

    mov rcx, rbx
    lea rdx, [running_line]
    call console_print
    jmp .done

.paused:
    mov rcx, rbx
    lea rdx, [paused_line]
    call console_print

.done:
    add rsp, 32
    pop rbx
    ret

; Si el cronometro esta corriendo, suma un segundo.
stopwatch_tick:
    cmp byte [is_running], 0
    je .done
    inc qword [elapsed_seconds]
.done:
    ret

; Alterna entre iniciado y pausado.
stopwatch_toggle:
    xor byte [is_running], 1
    ret

; Reinicia el cronometro y lo deja pausado.
stopwatch_reset:
    mov qword [elapsed_seconds], 0
    mov byte [is_running], 0
    ret

; Entrada:
;   EAX = numero entre 0 y 99
;   R11 = posicion del buffer CHAR16
; Salida:
;   R11 avanza dos caracteres UTF-16.
write_two_digits:
    xor edx, edx
    mov ecx, 10
    div ecx

    add al, '0'
    mov [r11], ax
    add r11, 2

    mov eax, edx
    add al, '0'
    mov [r11], ax
    add r11, 2
    ret

section .data
stopwatch_line:
    dw __utf16__("Cronometro: ")
stopwatch_value_offset equ $ - stopwatch_line
    dw __utf16__("00:00:00")
    dw 13, 10
    dw 0

running_line:
    dw __utf16__("Estado: corriendo")
    dw 13, 10
    dw 0

paused_line:
    dw __utf16__("Estado: pausado")
    dw 13, 10
    dw 0

elapsed_seconds dq 0
is_running db 0
