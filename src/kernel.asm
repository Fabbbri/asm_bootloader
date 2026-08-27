BITS 16
ORG 0x0000

start:
    ; Stage 1 entra mediante un salto lejano a 0x1000:0x0000.
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; La aplicacion utiliza una pila separada del sector de arranque.
    mov ax, 0x7000
    mov ss, ax
    mov sp, 0xFFFE
    sti
    cld

    mov si, stage2_message
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

stage2_message db 'Stage 2 cargado correctamente.', 0x0D, 0x0A, 0
