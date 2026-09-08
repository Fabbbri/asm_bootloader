BITS 64
DEFAULT REL

section .text
global clock_run

extern console_clear
extern console_print
extern console_read_key
extern console_set_attribute
extern console_set_cursor
extern time_print_current
extern alarm_cancel
extern alarm_check
extern alarm_configure
extern alarm_is_editing
extern alarm_handle_key
extern alarm_print_editor
extern alarm_is_triggered
extern alarm_print_alert
extern alarm_print_status
extern stopwatch_print
extern stopwatch_reset
extern stopwatch_update
extern timer_start
extern timer_stop
extern timer_ticks
extern stopwatch_toggle
extern sound_start
extern sound_stop

COLOR_NORMAL equ 0x07
COLOR_TITLE equ 0x0B
COLOR_MODE equ 0x0E
COLOR_HELP equ 0x0A
COLOR_ALERT_RED equ 0x4F
COLOR_ALERT_GREEN equ 0x2F

; Ejecuta el modo reloj con actualizacion periodica.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
clock_run:
    push rbx
    sub rsp, 48                 ; Shadow space (32 bytes) + variable local/alineacion.

    mov rbx, rcx                ; Conserva SystemTable para reutilizarla en todo el bucle.
    call timer_start            ; Inicia el temporizador UEFI que incrementa timer_ticks.
    test rax, rax               ; EFI_SUCCESS es 0; cualquier otro valor representa error.
    jnz .timer_error
    mov qword [last_second], -1 ; Fuerza el primer redibujado de la pantalla.

.loop:
    mov rcx, [timer_ticks]      ; Pasa los ticks actuales al modulo de cronometro.
    call stopwatch_update       ; Actualiza el tiempo acumulado si el cronometro esta activo.
    mov rax, [timer_ticks]
    xor edx, edx
    mov ecx, 100                ; El timer genera 100 ticks por segundo.
    div rcx                     ; RAX = segundos completos; RDX = ticks restantes.
    cmp rax, [last_second]      ; Comprueba si comenzo un segundo nuevo.
    je .refresh_stopwatch
    mov [last_second], rax
    jmp .redraw

.refresh_stopwatch:
    ; Refrescar solo el contador cada 50 ms, sin limpiar toda la pantalla.
    cmp byte [current_mode], 1
    jne .read_key
    call alarm_is_editing
    test al, al
    jnz .read_key
    mov rax, [timer_ticks]
    xor edx, edx
    mov ecx, 5                  ; 100 / 5 = 20 refrescos por segundo (uno cada 50 ms).
    div rcx
    cmp rax, [last_frame]
    je .read_key
    mov [last_frame], rax
    mov rcx, rbx
    xor edx, edx
    mov r8d, 3                  ; Fila del contador, bajo titulo/modo/linea vacia.
    call console_set_cursor
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute
    mov rcx, rbx
    call stopwatch_print
    jmp .read_key

.redraw:
    mov rcx, rbx
    call alarm_check             ; Compara la hora actual con la alarma configurada.

    mov rcx, rbx
    call alarm_is_triggered      ; AL != 0 si la alarma esta sonando.
    cmp al, 0
    je .normal_screen

    mov rax, [last_second]
    and eax, 1                   ; Alterna 0/1: segundos pares/impares para el parpadeo.
    mov [alert_blink], al
    cmp byte [alert_blink], 0
    je .alert_green

    call sound_start             ; En segundos impares: activa el sonido y fondo rojo.
    mov rcx, rbx
    mov edx, COLOR_ALERT_RED
    call console_set_attribute
    jmp .clear_screen

.alert_green:
    call sound_stop              ; En segundos pares: pausa el sonido y muestra fondo verde.
    mov rcx, rbx
    mov edx, COLOR_ALERT_GREEN
    call console_set_attribute
    jmp .clear_screen

.normal_screen:
    call sound_stop              ; Sin alarma activa, garantiza que no quede sonido reproduciendose.
    mov byte [alert_blink], 0
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

.clear_screen:
    mov rcx, rbx
    call console_clear           ; Redibujo completo: elimina el contenido anterior.

    ; La captura de alarma tiene su propia pantalla, pero comparte el bucle de tiempo.
    call alarm_is_editing
    test al, al
    jnz .draw_alarm_editor

    mov rcx, rbx
    mov edx, COLOR_TITLE
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [title]
    call console_print

    cmp byte [current_mode], 0
    jne .draw_stopwatch

    mov rcx, rbx
    mov edx, COLOR_MODE
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [mode_clock]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    call time_print_current      ; El modulo time obtiene e imprime la hora real de UEFI.
    jmp .draw_help

.draw_stopwatch:
    mov rcx, rbx
    mov edx, COLOR_MODE
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [mode_stopwatch]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    call stopwatch_print         ; Imprime el estado actual del cronometro.

.draw_help:
    mov rcx, rbx
    call alarm_print_status      ; Muestra si existe una alarma programada.

    mov rcx, rbx
    call alarm_print_alert       ; Muestra el mensaje de alarma si fue activada.

    mov rcx, rbx
    mov edx, COLOR_HELP
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [help]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    call alarm_print_editor
    jmp .read_key

.draw_alarm_editor:
    mov rcx, rbx
    mov edx, COLOR_TITLE
    call console_set_attribute

    mov rcx, rbx
    call alarm_print_editor

    ; Una alarma previa sigue notificandose incluso durante la captura.
    mov rcx, rbx
    call alarm_print_alert

.read_key:
    mov rcx, [timer_ticks]
    call stopwatch_update
    call alarm_is_editing
    mov [rsp + 32], al           ; Guarda si se edita alarma antes de llamar a otra funcion.
    mov rcx, rbx
    call console_read_key        ; No bloquea: AX=Unicode y DX=scan code, o ambos 0.
    mov cx, ax
    or cx, dx                    ; Si ambos son cero, aun no hay entrada disponible.
    jz .wait_input
    cmp ax, 'q'
    je .exit
    cmp ax, 'Q'
    je .exit
    ; Reinicio global: tambien funciona mientras se configura la alarma.
    cmp ax, 'r'
    je .reset_stopwatch
    cmp ax, 'R'
    je .reset_stopwatch
    cmp byte [rsp + 32], 0       ; Si se edita alarma, las teclas se envian a ese modulo.
    jne .edit_alarm
    cmp ax, 'm'
    je .switch_mode
    cmp ax, 'M'
    je .switch_mode
    cmp ax, 's'
    je .toggle_stopwatch
    cmp ax, 'S'
    je .toggle_stopwatch
    cmp ax, 'a'
    je .configure_alarm
    cmp ax, 'A'
    je .configure_alarm
    cmp ax, 'c'
    je .cancel_alarm
    cmp ax, 'C'
    je .cancel_alarm
    jmp .wait_input

.wait_input:
    ; Espera corta: el tiempo transcurrido proviene del timer, no de Stall.
    mov rax, [rbx + 96]          ; SystemTable->BootServices.
    mov ecx, 10000               ; 10 000 microsegundos = 10 ms.
    call [rax + 248]             ; BootServices->Stall(10000): reduce el uso de CPU.
    jmp .loop

.switch_mode:
    xor byte [current_mode], 1   ; Alterna: 0 (reloj) <-> 1 (cronometro).
    jmp .redraw

.toggle_stopwatch:
    cmp byte [current_mode], 1
    jne .wait_input              ; S solo opera si el modo actual es cronometro.
    call stopwatch_toggle
    jmp .redraw

.reset_stopwatch:
    call stopwatch_reset
    jmp .redraw

.edit_alarm:
    call alarm_handle_key        ; Delega la tecla al editor de alarma.
    jmp .redraw

.configure_alarm:
    mov rcx, rbx
    call alarm_configure         ; Entra al modo de captura de hora para la alarma.
    jmp .redraw

.cancel_alarm:
    call alarm_cancel            ; Desactiva la alarma configurada.
    jmp .redraw

.exit:
    call sound_stop              ; Limpieza: nunca salir dejando una alerta sonora activa.
    mov rcx, rbx
    call timer_stop              ; Cancela/libera el temporizador UEFI.
    jmp .finish

.timer_error:
    mov rcx, rbx
    lea rdx, [timer_error]
    call console_print           ; Informa que no se pudo iniciar el servicio de timer.

.finish:
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    add rsp, 48                  ; Libera el espacio reservado al inicio.
    pop rbx                      ; Restaura el registro preservado.
    ret                          ; Regresa a boot.asm.

section .data
title:
    dw __utf16__("CE4303 - Reloj/Cronometro UEFI")
    dw 13, 10
    dw 0

mode_clock:
    dw __utf16__("Modo actual: Reloj")
    dw 13, 10
    dw 13, 10
    dw 0

mode_stopwatch:
    dw __utf16__("Modo actual: Cronometro")
    dw 13, 10
    dw 13, 10
    dw 0

help:
    dw 13, 10
    dw __utf16__("M: modo | S: iniciar/pausar | R: reiniciar")
    dw 13, 10
    dw __utf16__("A: configurar alarma | C: cancelar alarma | Q: salir")
    dw 13, 10
    dw 0

current_mode db 0                ; 0 = reloj; 1 = cronometro.
alert_blink db 0                 ; 0 = alerta verde/sin alerta; 1 = alerta roja con sonido.

align 8
last_second dq -1                ; Ultimo segundo que disparo un redibujado completo.
last_frame dq -1                 ; Ultimo frame que refresco solo el cronometro.
timer_error:
    dw __utf16__("Error: no se pudo iniciar el temporizador UEFI."), 13, 10, 0
