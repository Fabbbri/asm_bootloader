BITS 64
DEFAULT REL

section .text
global alarm_cancel
global alarm_check
global alarm_configure
global alarm_is_editing
global alarm_handle_key
global alarm_print_editor
global alarm_is_triggered
global alarm_print_alert
global alarm_print_status

extern console_print
extern console_set_attribute
extern time_get_hms

COLOR_NORMAL equ 0x07
COLOR_ERROR equ 0x0C
COLOR_ALERT equ 0x4F
COLOR_PROMPT equ 0x0B
COLOR_SUCCESS equ 0x0A

; Editor no bloqueante: el bucle principal entrega una tecla por iteracion.
; alarm_configure inicia la captura y retorna inmediatamente.
alarm_configure:
    mov byte [editing], 1
    mov byte [input_count], 0
    mov qword [editor_message], 0
    mov word [input_display], '_'
    mov word [input_display + 2], '_'
    mov word [input_display + 6], '_'
    mov word [input_display + 8], '_'
    ret

; Salida: AL = 1 durante la captura.
alarm_is_editing:
    movzx eax, byte [editing]
    ret

; Entrada: AX = Unicode, DX = scan code UEFI. No espera teclas.
alarm_handle_key:
    cmp dx, 0x17
    je .cancel
    cmp ax, 27
    je .cancel
    test ax, ax
    jz .done
    cmp ax, '0'
    jb .invalid_key
    cmp ax, '9'
    ja .invalid_key

    movzx ecx, byte [input_count]
    lea r8, [input_buffer]
    mov [r8 + rcx], al
    mov edx, ecx
    cmp ecx, 2
    jb .store_display
    inc edx
.store_display:
    lea r8, [input_display]
    mov [r8 + rdx*2], ax
    inc byte [input_count]
    cmp byte [input_count], 4
    jne .done

    sub rsp, 40
    call validate_and_store
    add rsp, 40
    test al, al
    jz .invalid
    lea rax, [configured_msg]
    jmp .finish
.cancel:
    lea rax, [cancel_msg]
    jmp .finish
.invalid_key:
    lea rax, [invalid_key_msg]
    jmp .finish
.invalid:
    lea rax, [invalid_msg]
.finish:
    mov [editor_message], rax
    mov byte [editing], 0
.done:
    ret

; Entrada: RCX = EFI_SYSTEM_TABLE*. Redibuja la captura sin detener el reloj.
alarm_print_editor:
    push rbx
    sub rsp, 32
    mov rbx, rcx
    cmp byte [editing], 0
    je .message
    lea rdx, [prompt]
    call console_print
    mov rcx, rbx
    lea rdx, [input_display]
    call console_print
    jmp .done
.message:
    mov rdx, [editor_message]
    test rdx, rdx
    jz .done
    call console_print
.done:
    add rsp, 32
    pop rbx
    ret

; Cancela la alarma configurada.
alarm_cancel:
    mov byte [alarm_active], 0
    mov byte [alarm_triggered], 0
    ret

; Compara hora actual contra la alarma configurada.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
alarm_check:
    cmp byte [alarm_active], 0
    je .done
    cmp byte [alarm_triggered], 0
    jne .done

    push rbx
    sub rsp, 48

    mov rbx, rcx
    call time_get_hms

    cmp al, [alarm_hour]
    jne .finish
    cmp dl, [alarm_minute]
    jne .finish

    mov byte [alarm_triggered], 1

.finish:
    add rsp, 48
    pop rbx
.done:
    ret

; Indica si la alarma ya se disparo.
; Salida:
;   AL = 1 si esta disparada, 0 si no.
alarm_is_triggered:
    movzx eax, byte [alarm_triggered]
    ret

; Imprime el estado de la alarma.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
alarm_print_status:
    push rbx
    sub rsp, 32

    mov rbx, rcx

    cmp byte [alarm_active], 0
    je .inactive

    lea rdi, [alarm_line + alarm_value_offset]
    movzx eax, byte [alarm_hour]
    call write_two_digits
    add rdi, 2
    movzx eax, byte [alarm_minute]
    call write_two_digits

    mov rcx, rbx
    lea rdx, [alarm_line]
    call console_print
    jmp .done

.inactive:
    mov rcx, rbx
    lea rdx, [alarm_inactive_line]
    call console_print

.done:
    add rsp, 32
    pop rbx
    ret

; Imprime alerta visual si la alarma ya se disparo.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
alarm_print_alert:
    cmp byte [alarm_triggered], 0
    je .done

    push rbx
    sub rsp, 32

    mov rbx, rcx

    mov rcx, rbx
    mov edx, COLOR_ALERT
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [alert_msg]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    add rsp, 32
    pop rbx

.done:
    ret

validate_and_store:
    mov al, [input_buffer + 0]
    call is_digit
    cmp al, 0
    je .bad
    mov al, [input_buffer + 1]
    call is_digit
    cmp al, 0
    je .bad
    mov al, [input_buffer + 2]
    call is_digit
    cmp al, 0
    je .bad
    mov al, [input_buffer + 3]
    call is_digit
    cmp al, 0
    je .bad

    movzx eax, byte [input_buffer + 0]
    sub eax, '0'
    imul eax, 10
    movzx edx, byte [input_buffer + 1]
    sub edx, '0'
    add eax, edx
    cmp eax, 23
    ja .bad
    mov r9b, al

    movzx eax, byte [input_buffer + 2]
    sub eax, '0'
    imul eax, 10
    movzx edx, byte [input_buffer + 3]
    sub edx, '0'
    add eax, edx
    cmp eax, 59
    ja .bad
    mov [alarm_hour], r9b
    mov [alarm_minute], al

    mov byte [alarm_active], 1
    mov byte [alarm_triggered], 0
    mov al, 1
    ret

.bad:
    mov al, 0
    ret

is_digit:
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    mov al, 1
    ret
.bad:
    mov al, 0
    ret

write_two_digits:
    xor edx, edx
    mov r8d, 10
    div r8d

    add al, '0'
    mov [rdi], ax
    add rdi, 2

    mov eax, edx
    add al, '0'
    mov [rdi], ax
    add rdi, 2
    ret

section .data
prompt:
    dw __utf16__("Configurar alarma")
    dw 13, 10
    dw __utf16__("Ingrese hora en formato HHMM.")
    dw 13, 10
    dw __utf16__("Rangos validos: HH 00-23, MM 00-59.")
    dw 13, 10
    dw __utf16__("Ejemplo: 0730 para 07:30. ESC cancela.")
    dw 13, 10
    dw __utf16__("Hora: ")
    dw 0

configured_msg:
    dw 13, 10
    dw __utf16__("Alarma configurada correctamente.")
    dw 13, 10
    dw 0

invalid_msg:
    dw 13, 10
    dw __utf16__("Formato invalido. Use HH 00-23 y MM 00-59.")
    dw 13, 10
    dw 0

invalid_key_msg:
    dw 13, 10
    dw __utf16__("Entrada invalida. Solo se permiten numeros del 0 al 9.")
    dw 13, 10
    dw 0

cancel_msg:
    dw 13, 10
    dw __utf16__("Configuracion de alarma cancelada.")
    dw 13, 10
    dw 0

alarm_line:
    dw __utf16__("Alarma: ")
alarm_value_offset equ $ - alarm_line
    dw __utf16__("00:00")
    dw 13, 10
    dw 0

alarm_inactive_line:
    dw __utf16__("Alarma: sin configurar")
    dw 13, 10
    dw 0

alert_msg:
    dw 13, 10
    dw __utf16__("ALARMA ACTIVA - HORA CONFIGURADA ALCANZADA")
    dw 13, 10
    dw 0

input_buffer times 4 db 0
input_count db 0
editing db 0
editor_message dq 0
input_display:
    dw __utf16__("__:__"), 13, 10, 0
alarm_hour db 0
alarm_minute db 0
alarm_active db 0
alarm_triggered db 0
