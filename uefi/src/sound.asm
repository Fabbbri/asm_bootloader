BITS 64
DEFAULT REL

section .text
global sound_start
global sound_stop

; Activa el altavoz sin esperar. El bucle principal decide cuando apagarlo.
sound_start:
    ; PIT canal 2, square wave, divisor para una frecuencia aproximada de 1 kHz.
    mov al, 0xB6
    out 0x43, al

    mov ax, 1193
    out 0x42, al
    mov al, ah
    out 0x42, al

    ; Activa speaker gate/data en puerto 0x61.
    in al, 0x61
    or al, 0x03
    out 0x61, al

    ret

sound_stop:
    ; Apaga el speaker.
    in al, 0x61
    and al, 0xFC
    out 0x61, al

    ret
