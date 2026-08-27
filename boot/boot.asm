BITS 16
ORG 0x7C00

start:
    ; Inicializa un entorno conocido antes de utilizar datos o la pila.
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    cld

    ; El BIOS entrega la unidad de arranque en DL. Se conserva para cuando el
    ; Stage 1 tenga que cargar el Stage 2 desde disco.
    mov [boot_drive], dl

    ; El modo de texto 03h también limpia la pantalla.
    mov ax, 0x0003
    int 0x10

    mov si, welcome_message
    call print_string

halt:
    cli
    hlt
    jmp halt

; Imprime la cadena terminada en cero apuntada por DS:SI.
print_string:
    lodsb
    test al, al
    jz .done

    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    jmp print_string

.done:
    ret

boot_drive db 0
welcome_message db 'CE4303 - Reloj/Cronometro', 0x0D, 0x0A
                db 'Boot loader iniciado correctamente.', 0x0D, 0x0A, 0

; Un sector de arranque tiene 512 bytes y finaliza con la firma 0xAA55.
times 510 - ($ - $$) db 0
dw 0xAA55
