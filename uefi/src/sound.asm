BITS 64
DEFAULT REL

section .text
global sound_beep

; Genera un beep corto con el altavoz PC.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
sound_beep:
    push rbx
    sub rsp, 32

    mov rbx, rcx

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

    ; BootServices->Stall(180000): duracion del beep.
    mov rax, [rbx + 96]
    mov ecx, 180000
    call [rax + 248]

    ; Apaga el speaker.
    in al, 0x61
    and al, 0xFC
    out 0x61, al

    add rsp, 32
    pop rbx
    ret
