; =============================================================================
; Consola BIOS: video y teclado
;
; Centraliza los servicios de INT 10h para texto e INT 16h para entrada de teclado.
; =============================================================================

BITS 16

; Activa el modo de texto 03h (80x25), limpia la pantalla y reinicia el cursor.
; Modifica: AX y el estado de video.
console_clear:
    mov ax, 0x0003
    int 0x10
    ret

; Imprime una cadena terminada en cero mediante INT 10h/AH=0Eh.
; Entrada:  DS:SI apunta al primer caracter de la cadena.
; Salida:   SI queda apuntando despues del byte terminador.
; Modifica: AX, BX y SI.
console_print:
    lodsb
    test al, al
    jz .done

    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    jmp console_print

.done:
    ret

; Imprime un caracter mediante INT 10h/AH=0Eh.
; Entrada:  AL contiene el caracter ASCII.
; Preserva: BX.
console_print_char:
    push bx
    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    pop bx
    ret

; Espera una tecla, la consume y devuelve su codigo ASCII.
; Salida: AL = caracter ASCII; AH = scan code BIOS.
console_read_key_blocking:
    xor ah, ah
    int 0x16
    ret

; Consulta y consume una tecla sin bloquear el ciclo principal.
; Salida: AL = caracter ASCII, o cero cuando no hay tecla disponible.
console_read_key:
    mov ah, 0x01
    int 0x16
    jz .no_key

    xor ah, ah
    int 0x16
    ret

.no_key:
    xor ax, ax
    ret
