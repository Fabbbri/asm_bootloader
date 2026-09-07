BITS 64
DEFAULT REL

section .text
global stopwatch_print
global stopwatch_reset
global stopwatch_update
global stopwatch_toggle

extern console_print

; Imprime el tiempo acumulado del cronometro.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
stopwatch_print:
    push rbx
    sub rsp, 48                 ; Shadow space + espacio para guardar las centesimas.

    mov rbx, rcx                ; Conserva SystemTable para imprimir al final.

    mov rax, [elapsed_ticks]    ; Cada tick equivale a 10 ms.
    xor edx, edx
    mov ecx, 100                ; 100 ticks = 1 segundo.
    div rcx                     ; RAX = segundos completos; RDX = centesimas (0..99).
    mov [rsp + 32], edx         ; Conserva las centesimas mientras se calculan H:M:S.
    xor edx, edx
    mov ecx, 3600               ; 3600 segundos = 1 hora.
    div rcx                     ; RAX = horas; RDX = segundos restantes.
    mov r8d, eax                ; R8D guarda las horas.

    mov rax, rdx                ; Trabaja con los segundos que no formaron una hora completa.
    xor edx, edx
    mov ecx, 60                 ; 60 segundos = 1 minuto.
    div rcx                     ; RAX = minutos; RDX = segundos restantes.
    mov r9d, eax                ; R9D guarda minutos.
    mov r10d, edx               ; R10D guarda segundos.

    ; La cadena comienza como "Cronometro: 00:00:00.00".
    ; R11 apunta al primer 0 que sera reemplazado.
    lea r11, [stopwatch_line + stopwatch_value_offset]
    mov eax, r8d
    call write_two_digits       ; Escribe HH.
    add r11, 2                  ; Salta ':' (un caracter UTF-16 ocupa 2 bytes).
    mov eax, r9d
    call write_two_digits       ; Escribe MM.
    add r11, 2                  ; Salta el segundo ':'.
    mov eax, r10d
    call write_two_digits       ; Escribe SS.
    add r11, 2                  ; Salta el punto '.'.
    mov eax, [rsp + 32]
    call write_two_digits       ; Escribe CC (centesimas).

    mov rcx, rbx
    lea rdx, [stopwatch_line]
    call console_print          ; Muestra: "Cronometro: HH:MM:SS.CC".

    cmp byte [is_running], 0
    je .paused

    mov rcx, rbx
    lea rdx, [running_line]
    call console_print          ; Muestra "Estado: corriendo".
    jmp .done

.paused:
    mov rcx, rbx
    lea rdx, [paused_line]
    call console_print          ; Muestra "Estado: pausado".

.done:
    add rsp, 48
    pop rbx
    ret

; RCX = contador de ticks de 10 ms. Acumula tambien el tiempo de redibujado.
; Se llama antes de procesar teclas; las pausas conservan las fracciones.
stopwatch_update:
    mov rax, rcx                ; RCX es timer_ticks: cantidad total de ticks hasta ahora.
    sub rax, [last_tick]        ; Calcula cuantos ticks nuevos ocurrieron desde la ultima revision.
    mov [last_tick], rcx        ; Actualiza la referencia incluso estando pausado.
    cmp byte [is_running], 0
    je .done                    ; Pausado: no acumula los ticks nuevos.
    add [elapsed_ticks], rax    ; Corriendo: suma los ticks nuevos al tiempo del cronometro.
.done:
    ret

; Alterna entre iniciado y pausado.
stopwatch_toggle:
    xor byte [is_running], 1    ; Alterna 0 (pausado) <-> 1 (corriendo).
    ret

; Reinicia el cronometro y lo deja pausado.
stopwatch_reset:
    mov qword [elapsed_ticks], 0 ; Borra todo el tiempo acumulado.
    mov byte [is_running], 0     ; Despues de reiniciar queda pausado.
    ret

; Entrada:
;   EAX = numero entre 0 y 99
;   R11 = posicion del buffer CHAR16
; Salida:
;   R11 avanza dos caracteres UTF-16.
write_two_digits:
    xor edx, edx
    mov ecx, 10
    div ecx                     ; EAX / 10: EAX=decena y EDX=unidad.

    add al, '0'                 ; Convierte el numero de decenas a caracter, por ejemplo 0 -> '0'.
    mov [r11], ax               ; Guarda ese caracter como CHAR16.
    add r11, 2

    mov eax, edx
    add al, '0'                 ; Convierte el numero de unidades a caracter.
    mov [r11], ax               ; Guarda el segundo caracter como CHAR16.
    add r11, 2
    ret

section .data
stopwatch_line:
    dw __utf16__("Cronometro: ")
stopwatch_value_offset equ $ - stopwatch_line ; Inicio del espacio "00:00:00.00" dentro del texto.
    dw __utf16__("00:00:00.00")
    dw 13, 10
    dw 0

running_line:
    dw __utf16__("Estado: corriendo")
    dw 13, 10
    dw 0

paused_line:
    dw __utf16__("Estado: pausado")
    dw 13, 10
    dw 0

elapsed_ticks dq 0              ; Tiempo acumulado; 1 unidad = 10 ms.
last_tick dq 0                  ; Ultimo timer_ticks procesado; evita contar dos veces el mismo tiempo.
is_running db 0                 ; 0 = pausado; 1 = corriendo.
