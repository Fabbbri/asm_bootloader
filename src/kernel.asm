; =============================================================================
; Stage 2 - Aplicacion de reloj y cronometro para Legacy BIOS
;
; Stage 1 carga este binario en 0x1000:0x0000 y transfiere el control con un
; salto lejano. Todo el codigo se ejecuta en x86 Real Mode de 16 bits y utiliza
; servicios del BIOS; no existe un sistema operativo debajo de la aplicacion.
; =============================================================================

BITS 16
ORG 0x0000

; -----------------------------------------------------------------------------
; Constantes de estado y teclado
; -----------------------------------------------------------------------------

MODE_CLOCK     equ 0
MODE_STOPWATCH equ 1

KEY_ENTER equ 0x0D
KEY_ESCAPE equ 0x1B

; -----------------------------------------------------------------------------
; Punto de entrada e inicializacion del entorno
; -----------------------------------------------------------------------------

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

    ; Se conserva en pantalla la bienvenida de Stage 1 hasta que el usuario
    ; acepte entrar a la aplicacion.
    mov si, confirmation_message
    call print_string

; -----------------------------------------------------------------------------
; Confirmacion inicial
;
; INT 16h/AH=00h bloquea hasta recibir una tecla. Solo ENTER permite iniciar;
; ESC y Q terminan la aplicacion. Las demas teclas se ignoran.
; -----------------------------------------------------------------------------

wait_confirmation:
    xor ah, ah
    int 0x16

    cmp al, KEY_ENTER
    je start_application
    cmp al, KEY_ESCAPE
    je exit_application
    cmp al, 'q'
    je exit_application
    cmp al, 'Q'
    je exit_application
    jmp wait_confirmation

; Inicializa el estado visible de la aplicacion en modo reloj.
start_application:
    mov byte [current_mode], MODE_CLOCK
    call draw_interface

; -----------------------------------------------------------------------------
; Ciclo principal y despacho de teclado
;
; En cada iteracion se actualiza el reloj, se consulta el teclado sin bloquear
; y se procesa una tecla si esta disponible. Cuando no hay trabajo, HLT reduce
; el uso de CPU hasta que una interrupcion de hardware la despierte.
; -----------------------------------------------------------------------------

main_loop:
    call update_clock

    ; AH=01h consulta el teclado sin bloquear ni retirar la tecla del buffer.
    mov ah, 0x01
    int 0x16
    jz .idle

    ; Hay una tecla disponible: AH=00h la retira del buffer y la devuelve.
    xor ah, ah
    int 0x16

    cmp al, 'm'
    je toggle_mode
    cmp al, 'M'
    je toggle_mode
    cmp al, 'q'
    je exit_application
    cmp al, 'Q'
    je exit_application
    cmp al, KEY_ESCAPE
    je exit_application
    jmp main_loop

.idle:
    ; El timer del BIOS despierta periodicamente la CPU para volver a consultar.
    hlt
    jmp main_loop

; Alterna MODE_CLOCK <-> MODE_STOPWATCH y reconstruye la interfaz.
toggle_mode:
    xor byte [current_mode], 1
    call draw_interface
    jmp main_loop

; Muestra el mensaje final y cae intencionalmente en halt.
exit_application:
    call clear_screen
    mov si, exit_message
    call print_string

; Estado terminal: interrupciones desactivadas y CPU detenida.
halt:
    cli
    hlt
    jmp halt

; -----------------------------------------------------------------------------
; Construccion de la interfaz
;
; Entrada:  current_mode selecciona la pantalla que debe mostrarse.
; Salida:   pantalla completa dibujada y, en modo reloj, hora actualizada.
; Modifica: AX, BX y SI a traves de las rutinas de video.
; -----------------------------------------------------------------------------

draw_interface:
    call clear_screen

    mov si, application_title
    call print_string

    cmp byte [current_mode], MODE_CLOCK
    jne .stopwatch

    mov si, clock_screen
    jmp .print_mode

.stopwatch:
    mov si, stopwatch_screen

.print_mode:
    call print_string
    mov si, controls_message
    call print_string

    ; Fuerza una lectura inmediata al entrar o regresar al modo reloj.
    mov byte [last_rtc_second], 0xFF
    call update_clock
    ret

; -----------------------------------------------------------------------------
; Servicio de reloj RTC
; -----------------------------------------------------------------------------

; Lee la hora real con INT 1Ah/AH=02h. El BIOS devuelve valores BCD empaquetados:
; CH=hora, CL=minutos y DH=segundos. Solo escribe en pantalla cuando cambia el
; segundo; si CF=1, muestra --:--:-- una unica vez.
;
; Entrada:  current_mode y last_rtc_second.
; Salida:   variables rtc_* y campo HH:MM:SS actualizados cuando corresponde.
; Preserva: AX, BX, CX, DX y SI.
update_clock:
    push ax
    push bx
    push cx
    push dx
    push si

    cmp byte [current_mode], MODE_CLOCK
    jne .done

    mov ah, 0x02
    int 0x1A
    jc .read_error

    cmp dh, [last_rtc_second]
    je .done

    mov [rtc_hour], ch
    mov [rtc_minute], cl
    mov [rtc_second], dh
    mov [last_rtc_second], dh

    call set_clock_cursor
    mov al, [rtc_hour]
    call print_bcd
    mov al, ':'
    call print_char
    mov al, [rtc_minute]
    call print_bcd
    mov al, ':'
    call print_char
    mov al, [rtc_second]
    call print_bcd
    jmp .done

.read_error:
    cmp byte [last_rtc_second], 0xFE
    je .done

    mov byte [last_rtc_second], 0xFE
    call set_clock_cursor
    mov si, rtc_error_value
    call print_string

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Posiciona el cursor al inicio del campo HH:MM:SS.
; Modifica: AH, BH, DH y DL.
set_clock_cursor:
    ; La hora comienza en la fila 3, columna 13 de la interfaz.
    mov ah, 0x02
    xor bh, bh
    mov dh, 3
    mov dl, 13
    int 0x10
    ret

; Convierte el BCD empaquetado de AL en dos caracteres decimales.
; Ejemplo: AL=0x23 imprime "23".
;
; Entrada:  AL contiene un byte BCD valido.
; Salida:   dos caracteres impresos mediante INT 10h.
; Preserva: AX y BX.
print_bcd:
    push ax
    push bx

    mov bl, al
    shr al, 4
    and al, 0x0F
    add al, '0'
    call print_char

    mov al, bl
    and al, 0x0F
    add al, '0'
    call print_char

    pop bx
    pop ax
    ret

; Imprime un caracter mediante INT 10h/AH=0Eh.
; Entrada:  AL contiene el caracter ASCII.
; Preserva: BX.
print_char:
    push bx
    mov ah, 0x0E
    xor bh, bh
    mov bl, 0x07
    int 0x10
    pop bx
    ret

; -----------------------------------------------------------------------------
; Servicios basicos de video
; -----------------------------------------------------------------------------

; Activa el modo de texto 03h (80x25), limpia la pantalla y reinicia el cursor.
; Modifica: AX y el estado de video.
clear_screen:
    mov ax, 0x0003
    int 0x10
    ret

; Imprime una cadena terminada en cero mediante INT 10h/AH=0Eh.
; Entrada:  DS:SI apunta al primer caracter de la cadena.
; Salida:   SI queda apuntando despues del byte terminador.
; Modifica: AX, BX y SI.
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

; -----------------------------------------------------------------------------
; Estado mutable de la aplicacion
;
; last_rtc_second usa dos sentinelas:
;   0xFF = forzar una nueva lectura y escritura de la hora.
;   0xFE = ya se mostro un error de lectura del RTC.
; -----------------------------------------------------------------------------

current_mode db MODE_CLOCK
last_rtc_second db 0xFF
rtc_hour db 0
rtc_minute db 0
rtc_second db 0

; -----------------------------------------------------------------------------
; Textos de la interfaz
;
; Las cadenas usan CR/LF (0x0D, 0x0A) para nuevas lineas y terminan en cero.
; -----------------------------------------------------------------------------

confirmation_message db 'Stage 2 cargado correctamente.', 0x0D, 0x0A
                     db 0x0D, 0x0A
                     db 'Presione ENTER para iniciar.', 0x0D, 0x0A
                     db 'Presione ESC para finalizar.', 0x0D, 0x0A, 0

application_title db '=== Reloj/Cronometro con Alarma ===', 0x0D, 0x0A
                  db 0x0D, 0x0A, 0

clock_screen db 'Modo: RELOJ', 0x0D, 0x0A
             db 'Hora actual: 00:00:00', 0x0D, 0x0A, 0

stopwatch_screen db 'Modo: CRONOMETRO', 0x0D, 0x0A
                 db 'Cronometro: 00:00:00', 0x0D, 0x0A, 0

controls_message db 0x0D, 0x0A
                 db '[M] Cambiar modo', 0x0D, 0x0A
                 db '[Q/ESC] Finalizar', 0x0D, 0x0A, 0

exit_message db 'Programa finalizado.', 0x0D, 0x0A, 0
rtc_error_value db '--:--:--', 0
