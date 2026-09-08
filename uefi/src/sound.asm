BITS 64
DEFAULT REL

section .text
global sound_start
global sound_stop

; Activa el altavoz sin esperar. El bucle principal decide cuando apagarlo.
sound_start:
    ; Programa el PIT (Programmable Interval Timer), canal 2.
    ; 0xB6 selecciona canal 2, envio de byte bajo/alto y onda cuadrada.
    mov al, 0xB6
    out 0x43, al                ; Puerto 0x43: registro de control del PIT.

    ; El PIT usa una base aproximada de 1 193 182 Hz.
    ; Divisor 1193 produce un tono cercano a 1000 Hz (1 kHz).
    mov ax, 1193
    out 0x42, al                ; Puerto 0x42: envia primero el byte bajo del divisor.
    mov al, ah
    out 0x42, al                ; Envia despues el byte alto del divisor.

    ; Activa speaker gate/data en puerto 0x61.
    in al, 0x61                 ; Lee el estado actual para conservar sus otros bits.
    or al, 0x03                 ; Activa bits 0 y 1: habilita la salida del PIT al altavoz.
    out 0x61, al                ; Puerto 0x61: control del speaker de PC.

    ret

sound_stop:
    ; Apaga el speaker.
    in al, 0x61                 ; Lee el valor actual del puerto de control.
    and al, 0xFC                ; Borra bits 0 y 1, pero conserva todos los demas.
    out 0x61, al                ; Desconecta el PIT del altavoz y detiene el tono.

    ret
