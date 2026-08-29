BITS 64
DEFAULT REL

section .text
global console_print
global console_wait_for_key
global console_clear
global console_read_key

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

; Lee una tecla sin bloquear.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
; Salida:
;   AX = caracter Unicode, o 0 si no hay tecla disponible.
console_read_key:
    push rbx
    sub rsp, 64

    mov rbx, rcx

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
