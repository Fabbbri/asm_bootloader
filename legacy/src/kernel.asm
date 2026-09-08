; =============================================================================
; Stage 2 - Punto de entrada Legacy BIOS
;
; Stage 1 carga este binario en 0x1000:0x0000. Aqui se preparan los segmentos,
; la pila y el flujo de entrada/salida de la aplicacion.
; =============================================================================

BITS 16
ORG 0x0000

MODE_CLOCK     equ 0
MODE_STOPWATCH equ 1

KEY_ENTER  equ 0x0D
KEY_ESCAPE equ 0x1B

start:
    ; DS y ES deben apuntar al segmento donde Stage 1 cargo el binario.
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

    ; La aplicacion no inicia hasta recibir ENTER.
    mov si, confirmation_message
    call console_print

wait_confirmation:
    call console_read_key_blocking

    cmp al, KEY_ENTER
    je start_application
    cmp al, KEY_ESCAPE
    je exit_application
    cmp al, 'q'
    je exit_application
    cmp al, 'Q'
    je exit_application
    jmp wait_confirmation

start_application:
    call clock_run

exit_application:
    call console_clear
    mov si, exit_message
    call console_print

halt:
    cli
    hlt
    jmp halt

confirmation_message db 'Stage 2 cargado correctamente.', 0x0D, 0x0A
                     db 0x0D, 0x0A
                     db 'Presione ENTER para iniciar.', 0x0D, 0x0A
                     db 'Presione ESC para finalizar.', 0x0D, 0x0A, 0

exit_message db 'Programa finalizado.', 0x0D, 0x0A, 0

; NASM concatena estos modulos para producir un unico binario plano.
%include "console.asm"
%include "time.asm"
%include "stopwatch.asm"
%include "sound.asm"
%include "alarm.asm"
%include "clock.asm"
