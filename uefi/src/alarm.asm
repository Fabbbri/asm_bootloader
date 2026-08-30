BITS 64
DEFAULT REL

section .text
global alarm_cancel
global alarm_check
global alarm_configure
global alarm_is_triggered
global alarm_print_alert
global alarm_print_status

extern console_clear
extern console_print
extern console_print_char
extern console_read_key_blocking
extern console_set_attribute
extern sound_beep
extern time_get_hms

COLOR_NORMAL equ 0x07
COLOR_ERROR equ 0x0C
COLOR_ALERT equ 0x4F
COLOR_PROMPT equ 0x0B
COLOR_SUCCESS equ 0x0A

; Configura la alarma leyendo HH:MM desde teclado.
; Entrada:
;   RCX = EFI_SYSTEM_TABLE*
alarm_configure:
    push rbx
    push rsi
    sub rsp, 48

    mov rbx, rcx

    mov rcx, rbx
    call console_clear

    mov rcx, rbx
    mov edx, COLOR_PROMPT
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [prompt]
    call console_print

    lea rsi, [input_buffer]
    mov ecx, 5

.read_loop:
    push rcx
    mov rcx, rbx
    call console_read_key_blocking
    pop rcx

    mov [rsi], al
    inc rsi

    push rcx
    mov rcx, rbx
    mov dx, ax
    call console_print_char
    pop rcx

    loop .read_loop

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    call validate_and_store
    cmp al, 0
    je .invalid

    mov rcx, rbx
    mov edx, COLOR_SUCCESS
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [configured_msg]
    call console_print
    jmp .wait_done

.invalid:
    mov rcx, rbx
    mov edx, COLOR_ERROR
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [invalid_msg]
    call console_print

.wait_done:
    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [continue_msg]
    call console_print

    mov rcx, rbx
    call console_read_key_blocking

    add rsp, 48
    pop rsi
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
    sub rsp, 40

    mov rbx, rcx
    call time_get_hms

    cmp al, [alarm_hour]
    jne .finish
    cmp dl, [alarm_minute]
    jne .finish

    mov byte [alarm_triggered], 1
    mov rcx, rbx
    call sound_beep

.finish:
    add rsp, 40
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
    cmp byte [input_buffer + 2], ':'
    jne .bad
    mov al, [input_buffer + 3]
    call is_digit
    cmp al, 0
    je .bad
    mov al, [input_buffer + 4]
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
    mov [alarm_hour], al

    movzx eax, byte [input_buffer + 3]
    sub eax, '0'
    imul eax, 10
    movzx edx, byte [input_buffer + 4]
    sub edx, '0'
    add eax, edx
    cmp eax, 59
    ja .bad
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
    dw __utf16__("Ingrese hora en formato HH:MM: ")
    dw 0

configured_msg:
    dw 13, 10
    dw __utf16__("Alarma configurada correctamente.")
    dw 13, 10
    dw 0

invalid_msg:
    dw 13, 10
    dw __utf16__("Formato invalido. Use HH:MM, por ejemplo 07:30.")
    dw 13, 10
    dw 0

continue_msg:
    dw __utf16__("Presiona una tecla para volver.")
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

input_buffer times 5 db 0
alarm_hour db 0
alarm_minute db 0
alarm_active db 0
alarm_triggered db 0
