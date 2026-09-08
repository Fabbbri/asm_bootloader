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
global console_set_cursor

; Servicio UEFI: SimpleTextOutputProtocol->SetCursorPosition.
; RCX = EFI_SYSTEM_TABLE*, EDX = columna, R8D = fila (desde cero).
console_set_cursor:
    sub rsp, 40                 ; 32 bytes de shadow space + alineacion de stack.
    mov rax, [rcx + 64]         ; SystemTable->ConOut (consola de salida).
    mov rcx, rax                ; Parametro 1: el propio ConOut.
    ; ConOut + 56 = SetCursorPosition(ConOut, columna, fila).
    call [rax + 56]
    add rsp, 40
    ret

; Imprime una cadena CHAR16 terminada en cero.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
;   RDX = CHAR16*
console_print:
    sub rsp, 40

    mov rax, [rcx + 64]         ; SystemTable->ConOut.
    mov rcx, rax                ; Parametro 1: ConOut; RDX aun contiene CHAR16*.
    ; ConOut + 8 = OutputString(ConOut, cadena).
    call [rax + 8]

    add rsp, 40
    ret

; Limpia la pantalla.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
console_clear:
    sub rsp, 40

    mov rax, [rcx + 64]         ; SystemTable->ConOut.
    mov rcx, rax                ; Parametro 1: ConOut.
    ; ConOut + 48 = ClearScreen(ConOut).
    call [rax + 48]

    add rsp, 40
    ret

; Cambia color de texto/fondo.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
;   EDX = atributo UEFI
console_set_attribute:
    sub rsp, 40

    mov rax, [rcx + 64]         ; SystemTable->ConOut.
    mov rcx, rax                ; Parametro 1: ConOut; EDX aun contiene el atributo.
    ; ConOut + 40 = SetAttribute(ConOut, atributo).
    call [rax + 40]

    add rsp, 40
    ret

; Espera una tecla y la consume.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
console_wait_for_key:
    push rbx
    sub rsp, 64

    mov rbx, rcx                ; Conserva SystemTable durante las llamadas.

    ; BootServices->WaitForEvent(1, &ConIn->WaitForKey, &index)
    mov rax, [rbx + 48]         ; SystemTable->ConIn (consola de entrada).
    mov rax, [rax + 16]         ; ConIn->WaitForKey: evento de teclado.
    mov [rsp + 32], rax         ; Guarda el EFI_EVENT para pasarlo por direccion.

    mov rax, [rbx + 96]         ; SystemTable->BootServices.
    mov rcx, 1                  ; Numero de eventos que se van a esperar.
    lea rdx, [rsp + 32]         ; &ConIn->WaitForKey.
    lea r8, [rsp + 40]          ; &index: recibira el indice del evento activado.
    ; BootServices + 96 = WaitForEvent(numero, eventos, index).
    call [rax + 96]

    ; ConIn->ReadKeyStroke(ConIn, &key)
    mov rax, [rbx + 48]         ; SystemTable->ConIn.
    mov rcx, rax                ; Parametro 1: ConIn.
    lea rdx, [rsp + 48]         ; Parametro 2: &EFI_INPUT_KEY donde se guarda la tecla.
    ; ConIn + 8 = ReadKeyStroke(ConIn, &key).
    call [rax + 8]

    add rsp, 64
    pop rbx
    ret

; Espera una tecla y devuelve su caracter Unicode.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
; Salida:
;   AX = caracter Unicode
;   DX = scan code UEFI
console_read_key_blocking:
    push rbx
    sub rsp, 64

    mov rbx, rcx                ; Conserva SystemTable durante las llamadas.

    ; BootServices->WaitForEvent(1, &ConIn->WaitForKey, &index)
    mov rax, [rbx + 48]         ; SystemTable->ConIn.
    mov rax, [rax + 16]         ; ConIn->WaitForKey.
    mov [rsp + 32], rax         ; EFI_EVENT temporal en el stack.

    mov rax, [rbx + 96]         ; SystemTable->BootServices.
    mov rcx, 1
    lea rdx, [rsp + 32]
    lea r8, [rsp + 40]
    call [rax + 96]             ; BootServices->WaitForEvent(1, &evento, &index).

    ; ConIn->ReadKeyStroke(ConIn, &key)
    mov rax, [rbx + 48]         ; SystemTable->ConIn.
    mov rcx, rax
    lea rdx, [rsp + 48]
    call [rax + 8]              ; ConIn->ReadKeyStroke(ConIn, &key).

    movzx edx, word [rsp + 48]  ; EFI_INPUT_KEY.ScanCode -> DX.
    movzx eax, word [rsp + 50]  ; EFI_INPUT_KEY.UnicodeChar -> AX.

    add rsp, 64
    pop rbx
    ret

; Lee una tecla sin bloquear.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
; Salida:
;   AX = caracter Unicode, o 0 si no hay tecla disponible.
;   DX = scan code UEFI, o 0 si no hay tecla disponible.
console_read_key:
    push rbx
    sub rsp, 64

    mov rbx, rcx                ; Conserva SystemTable durante las llamadas.

    ; Evita bloquear el loop del reloj cuando no hay tecla disponible.
    mov rax, [rbx + 48]         ; SystemTable->ConIn.
    mov rcx, [rax + 16]         ; Parametro: ConIn->WaitForKey.
    mov rax, [rbx + 96]         ; SystemTable->BootServices.
    ; BootServices + 120 = CheckEvent(evento): no espera; consulta su estado.
    call [rax + 120]

    test rax, rax
    jnz .no_key

    mov rax, [rbx + 48]         ; SystemTable->ConIn.
    mov rcx, rax
    lea rdx, [rsp + 48]
    call [rax + 8]              ; ConIn->ReadKeyStroke(ConIn, &key).

    test rax, rax
    jnz .no_key

    movzx edx, word [rsp + 48]  ; key.ScanCode.
    movzx eax, word [rsp + 50]  ; key.UnicodeChar.
    jmp .done

.no_key:
    xor eax, eax
    xor edx, edx

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

    mov [rsp + 48], dx          ; Primer CHAR16: el caracter recibido.
    mov word [rsp + 50], 0      ; Segundo CHAR16: terminador nulo.

    mov rax, [rcx + 64]         ; SystemTable->ConOut.
    mov rcx, rax                ; Parametro 1: ConOut.
    lea rdx, [rsp + 48]         ; Parametro 2: la cadena temporal [caracter, 0].
    call [rax + 8]              ; ConOut->OutputString(ConOut, cadena).

    add rsp, 56
    ret
