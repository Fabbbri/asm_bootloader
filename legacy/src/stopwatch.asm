; =============================================================================
; Cronometro independiente
;
; Mantiene el conteo, sus estados y su presentacion usando los ticks de 
; INT 1Ah/AH=00h como base temporal.
; =============================================================================

BITS 16

STOPWATCH_STOPPED equ 0
STOPWATCH_RUNNING equ 1
STOPWATCH_PAUSED  equ 2

; El contador BIOS avanza aproximadamente 18.2 veces por segundo. Se escala
; por 10 para conservar la fraccion: 182 unidades equivalen a un segundo.
BIOS_TICK_SCALE       equ 10
BIOS_TICKS_PER_SECOND equ 182
BIOS_TICKS_DAY_HIGH   equ 0x0018
BIOS_TICKS_DAY_LOW    equ 0x00B0

; Alterna entre iniciado y pausado. Al iniciar o reanudar captura el tick actual
; para que el tiempo en pausa no se sume al conteo.
stopwatch_toggle:
    cmp byte [stopwatch_state], STOPWATCH_RUNNING
    je .pause

    call stopwatch_capture_tick
    mov byte [stopwatch_state], STOPWATCH_RUNNING
    ret

.pause:
    mov byte [stopwatch_state], STOPWATCH_PAUSED
    ret

; Reinicia el cronometro y lo deja detenido.
stopwatch_reset:
    mov byte [stopwatch_state], STOPWATCH_STOPPED
    mov word [stopwatch_tick_fraction], 0
    mov byte [stopwatch_hours], 0
    mov byte [stopwatch_minutes], 0
    mov byte [stopwatch_seconds], 0
    ret

; Actualiza el cronometro a partir de los ticks BIOS en CX:DX.
; Salida: AL=1 si cambio el segundo mostrado; AL=0 en caso contrario.
; Preserva: BX, CX, DX, SI y DI.
stopwatch_update:
    push bx
    push cx
    push dx
    push si
    push di

    cmp byte [stopwatch_state], STOPWATCH_RUNNING
    jne .unchanged

    xor ah, ah
    int 0x1A

    test al, al
    jnz .midnight_rollover

    ; Delta normal de 32 bits: tick_actual - tick_anterior.
    mov ax, dx
    mov bx, cx
    sub ax, [stopwatch_last_tick_low]
    sbb bx, [stopwatch_last_tick_high]
    jmp .delta_ready

.midnight_rollover:
    ; Delta = (ticks_por_dia - tick_anterior) + tick_actual.
    mov ax, BIOS_TICKS_DAY_LOW
    mov bx, BIOS_TICKS_DAY_HIGH
    sub ax, [stopwatch_last_tick_low]
    sbb bx, [stopwatch_last_tick_high]
    add ax, dx
    adc bx, cx

.delta_ready:
    mov [stopwatch_last_tick_low], dx
    mov [stopwatch_last_tick_high], cx

    mov si, ax
    or si, bx
    jz .unchanged

    ; Multiplica el delta BX:AX por 10 usando 10x = 8x + 2x.
    shl ax, 1
    rcl bx, 1
    mov si, ax
    mov di, bx
    shl ax, 1
    rcl bx, 1
    shl ax, 1
    rcl bx, 1
    add ax, si
    adc bx, di

    ; Agrega la fraccion pendiente y convierte a segundos completos.
    add ax, [stopwatch_tick_fraction]
    adc bx, 0
    mov dx, bx
    mov bx, BIOS_TICKS_PER_SECOND
    div bx
    mov [stopwatch_tick_fraction], dx

    test ax, ax
    jz .unchanged

    call stopwatch_add_seconds
    mov al, 1
    jmp .done

.unchanged:
    xor al, al

.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

; Imprime el valor y el estado actual del cronometro.
stopwatch_print:
    call stopwatch_print_time
    call stopwatch_print_status
    ret

; Guarda el tick BIOS actual como referencia para iniciar o reanudar.
stopwatch_capture_tick:
    push ax
    push cx
    push dx

    xor ah, ah
    int 0x1A
    mov [stopwatch_last_tick_low], dx
    mov [stopwatch_last_tick_high], cx

    pop dx
    pop cx
    pop ax
    ret

; Suma los segundos de AX y normaliza segundos, minutos y horas.
; Las horas vuelven a cero despues de 99:59:59.
stopwatch_add_seconds:
    xor bx, bx
    mov bl, [stopwatch_seconds]
    add ax, bx
    xor dx, dx
    mov bx, 60
    div bx
    mov [stopwatch_seconds], dl

    xor bx, bx
    mov bl, [stopwatch_minutes]
    add ax, bx
    xor dx, dx
    mov bx, 60
    div bx
    mov [stopwatch_minutes], dl

    xor bx, bx
    mov bl, [stopwatch_hours]
    add ax, bx
    xor dx, dx
    mov bx, 100
    div bx
    mov [stopwatch_hours], dl
    ret

; Escribe HH:MM:SS en la fila reservada para el cronometro.
stopwatch_print_time:
    push ax
    push bx
    push dx

    mov ah, 0x02
    xor bh, bh
    mov dh, 3
    mov dl, 12
    int 0x10

    mov al, [stopwatch_hours]
    call stopwatch_print_two_digits
    mov al, ':'
    call console_print_char
    mov al, [stopwatch_minutes]
    call stopwatch_print_two_digits
    mov al, ':'
    call console_print_char
    mov al, [stopwatch_seconds]
    call stopwatch_print_two_digits

    pop dx
    pop bx
    pop ax
    ret

; Muestra DETENIDO, CORRIENDO o PAUSADO segun el estado actual.
stopwatch_print_status:
    push ax
    push bx
    push dx
    push si

    mov ah, 0x02
    xor bh, bh
    mov dh, 4
    mov dl, 8
    int 0x10

    cmp byte [stopwatch_state], STOPWATCH_RUNNING
    je .running
    cmp byte [stopwatch_state], STOPWATCH_PAUSED
    je .paused

    mov si, stopwatch_stopped_text
    jmp .print

.running:
    mov si, stopwatch_running_text
    jmp .print

.paused:
    mov si, stopwatch_paused_text

.print:
    call console_print
    pop si
    pop dx
    pop bx
    pop ax
    ret

; Convierte el numero binario de AL (0-99) en dos caracteres decimales.
stopwatch_print_two_digits:
    push ax
    push bx

    xor ah, ah
    mov bl, 10
    div bl
    mov bh, ah

    add al, '0'
    call console_print_char
    mov al, bh
    add al, '0'
    call console_print_char

    pop bx
    pop ax
    ret

stopwatch_state db STOPWATCH_STOPPED
stopwatch_last_tick_low dw 0
stopwatch_last_tick_high dw 0
stopwatch_tick_fraction dw 0
stopwatch_hours db 0
stopwatch_minutes db 0
stopwatch_seconds db 0

stopwatch_stopped_text db 'DETENIDO ', 0
stopwatch_running_text db 'CORRIENDO', 0
stopwatch_paused_text db 'PAUSADO  ', 0
