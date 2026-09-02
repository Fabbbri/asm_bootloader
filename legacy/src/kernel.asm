; =============================================================================
; Stage 2 - Punto de entrada Legacy BIOS
;
; Stage 1 carga este binario en 0x1000:0x0000. Este archivo conserva solamente
; la inicializacion, confirmacion y finalizacion; las responsabilidades de la
; aplicacion se separan igual que en uefi/src.
;
; Los modulos se incorporan con %include porque Legacy genera un binario plano
; de 16 bits, sin el enlazador PE32+ utilizado por UEFI.
; =============================================================================

BITS 16
ORG 0x0000

MODE_CLOCK     equ 0
MODE_STOPWATCH equ 1

KEY_ENTER  equ 0x0D
KEY_ESCAPE equ 0x1B

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

    ; Conserva la bienvenida de Stage 1 hasta que el usuario confirme.
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

; La ruta de inclusion se configura en el Makefile mediante "-I src/".
%include "console.asm"
%include "time.asm"
%include "stopwatch.asm"
%include "clock.asm"
