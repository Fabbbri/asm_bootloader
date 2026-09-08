; =============================================================================
; Sonido mediante PIT y PC speaker
;
; La alarma inicia y detiene el tono sin bloquear el ciclo principal.
; =============================================================================

BITS 16

PIT_CONTROL_PORT equ 0x43
PIT_CHANNEL2_PORT equ 0x42
PC_SPEAKER_PORT equ 0x61

PIT_CHANNEL2_SQUARE_WAVE equ 0xB6
SOUND_FREQUENCY_DIVISOR equ 1193

; Configura el PIT canal 2 a aproximadamente 1 kHz y habilita el PC speaker.
; Preserva: AX.
sound_start:
    push ax

    mov al, PIT_CHANNEL2_SQUARE_WAVE
    out PIT_CONTROL_PORT, al

    mov ax, SOUND_FREQUENCY_DIVISOR
    ; El divisor de 16 bits se envia en dos escrituras: byte bajo y byte alto.
    out PIT_CHANNEL2_PORT, al
    mov al, ah
    out PIT_CHANNEL2_PORT, al

    in al, PC_SPEAKER_PORT
    ; Los bits 0 y 1 conectan la salida del canal 2 al altavoz.
    or al, 0x03
    out PC_SPEAKER_PORT, al

    pop ax
    ret

; Deshabilita las lineas gate/data del PC speaker.
; Preserva: AX.
sound_stop:
    push ax

    in al, PC_SPEAKER_PORT
    and al, 0xFC
    out PC_SPEAKER_PORT, al

    pop ax
    ret
