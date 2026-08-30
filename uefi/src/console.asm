BITS 64
DEFAULT REL

section .text
global console_print
global console_wait_for_key
global console_clear
global console_read_key
global console_read_key_blocking
global console_print_char
global console_set_attribute

; Imprime una cadena CHAR16 terminada en cero.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
;   RDX = CHAR16*
console_print:
    sub rsp, 40

    mov rax, [rcx + 64]
    mov rcx, rax
    call [rax + 8]

    add rsp, 40
    ret

; Limpia la pantalla.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
console_clear:
    sub rsp, 40

    mov rax, [rcx + 64]
    mov rcx, rax
    call [rax + 48]

    add rsp, 40
    ret

; Cambia color de texto/fondo.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
;   EDX = atributo UEFI
console_set_attribute:
    sub rsp, 40

    mov rax, [rcx + 64]
    mov rcx, rax
    call [rax + 40]

    add rsp, 40
    ret

; Espera una tecla y la consume.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
console_wait_for_key:
    push rbx
    sub rsp, 64

    mov rbx, rcx

    ; BootServices->WaitForEvent(1, &ConIn->WaitForKey, &index)
    mov rax, [rbx + 48]
    mov rax, [rax + 16]
    mov [rsp + 32], rax

    mov rax, [rbx + 96]
    mov rcx, 1
    lea rdx, [rsp + 32]
    lea r8, [rsp + 40]
    call [rax + 96]

    ; ConIn->ReadKeyStroke(ConIn, &key)
    mov rax, [rbx + 48]
    mov rcx, rax
    lea rdx, [rsp + 48]
    call [rax + 8]

    add rsp, 64
    pop rbx
    ret

; Espera una tecla y devuelve su caracter Unicode.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
; Salida:
;   AX = caracter Unicode
console_read_key_blocking:
    push rbx
    sub rsp, 64

    mov rbx, rcx

    ; BootServices->WaitForEvent(1, &ConIn->WaitForKey, &index)
    mov rax, [rbx + 48]
    mov rax, [rax + 16]
    mov [rsp + 32], rax

    mov rax, [rbx + 96]
    mov rcx, 1
    lea rdx, [rsp + 32]
    lea r8, [rsp + 40]
    call [rax + 96]

    ; ConIn->ReadKeyStroke(ConIn, &key)
    mov rax, [rbx + 48]
    mov rcx, rax
    lea rdx, [rsp + 48]
    call [rax + 8]

    movzx eax, word [rsp + 50]

    add rsp, 64
    pop rbx
    ret

; Lee una tecla sin bloquear.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
; Salida:
;   AX = caracter Unicode, o 0 si no hay tecla disponible.
console_read_key:
    push rbx
    sub rsp, 64

    mov rbx, rcx

    ; Evita bloquear el loop del reloj cuando no hay tecla disponible.
    mov rax, [rbx + 48]
    mov rcx, [rax + 16]
    mov rax, [rbx + 96]
    call [rax + 120]

    test rax, rax
    jnz .no_key

    mov rax, [rbx + 48]
    mov rcx, rax
    lea rdx, [rsp + 48]
    call [rax + 8]

    test rax, rax
    jnz .no_key

    movzx eax, word [rsp + 50]
    jmp .done

.no_key:
    xor eax, eax

.done:
    add rsp, 64
    pop rbx
    ret

; Imprime un unico caracter CHAR16.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
;   DX = caracter Unicode
console_print_char:
    sub rsp, 56

    mov [rsp + 48], dx
    mov word [rsp + 50], 0

    mov rax, [rcx + 64]
    mov rcx, rax
    lea rdx, [rsp + 48]
    call [rax + 8]

    add rsp, 56
    ret
