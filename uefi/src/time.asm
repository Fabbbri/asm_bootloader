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
    sub rsp, 72                 ; Shadow space + buffer EFI_TIME temporal, con stack alineado.

    mov rax, [rcx + 88]         ; SystemTable->RuntimeServices.
    lea rcx, [rsp + 48]         ; Parametro 1: &EFI_TIME, donde UEFI escribira fecha y hora.
    xor edx, edx                ; Parametro 2: NULL; no se solicitan capacidades del reloj.
    call [rax + 24]             ; RuntimeServices + 24 = GetTime(&time, NULL).

    ; Dentro de EFI_TIME: hora esta en offset 4, minuto en 5 y segundo en 6.
    movzx eax, byte [rsp + 52]  ; time.Hour   -> AL/EAX.
    movzx edx, byte [rsp + 53]  ; time.Minute -> DL/EDX.
    movzx r8d, byte [rsp + 54]  ; time.Second -> R8B/R8D.

    add rsp, 72                 ; Libera el buffer EFI_TIME temporal.
    ret

; Lee la hora actual del firmware UEFI y la imprime como HH:MM:SS.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
time_print_current:
    push rbx
    push rdi                ; RDI es no volatil en la ABI UEFI x64.
    sub rsp, 88             ; Mantener RSP alineado a 16 antes de cada call.

    mov rbx, rcx                ; Conserva SystemTable para imprimir despues de consultar la hora.

    call time_get_hms           ; Obtiene hora/minuto/segundo desde RuntimeServices->GetTime.
    mov [rsp + 32], al          ; Guarda hora, porque write_two_digits reutiliza EAX.
    mov [rsp + 33], dl          ; Guarda minuto.
    mov [rsp + 34], r8b         ; Guarda segundo.

    ; time_line empieza como "Hora actual: 00:00:00".
    ; El offset apunta al primer 0 para reemplazarlo por los valores reales.
    lea rdi, [time_line + time_value_offset]
    movzx eax, byte [rsp + 32]
    call write_two_digits       ; Escribe HH.
    add rdi, 2                  ; Salta el caracter ':' (un CHAR16 ocupa 2 bytes).
    movzx eax, byte [rsp + 33]
    call write_two_digits       ; Escribe MM.
    add rdi, 2                  ; Salta el segundo ':'.
    movzx eax, byte [rsp + 34]
    call write_two_digits       ; Escribe SS.

    mov rcx, rbx
    lea rdx, [time_line]
    call console_print          ; Imprime: "Hora actual: HH:MM:SS".

    add rsp, 88
    pop rdi
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
    div r8d                     ; EAX / 10: EAX=cifra de decenas, EDX=cifra de unidades.

    add al, '0'                 ; Convierte, por ejemplo, 1 en el caracter ASCII/UTF-16 '1'.
    mov [rdi], ax               ; Escribe la decena como CHAR16.
    add rdi, 2

    mov eax, edx
    add al, '0'                 ; Convierte la unidad a caracter.
    mov [rdi], ax               ; Escribe la unidad como CHAR16.
    add rdi, 2
    ret

section .data
time_line:
    dw __utf16__("Hora actual: ")
time_value_offset equ $ - time_line ; Posicion donde comienza el texto "00:00:00".
    dw __utf16__("00:00:00")
    dw 13, 10
    dw 0
