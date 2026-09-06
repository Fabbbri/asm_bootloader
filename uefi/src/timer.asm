BITS 64
DEFAULT REL

section .text
global timer_start
global timer_stop
global timer_ticks

; Temporizador periodico de 10 ms independiente de los redibujados.
; RCX = EFI_SYSTEM_TABLE*. RAX = EFI_STATUS.
; El callback solo incrementa un contador: no imprime ni espera eventos.
timer_start:
    push rbx
    sub rsp, 48
    mov rbx, [rcx + 96]
    mov qword [timer_ticks], 0
    mov ecx, 0x80000200       ; EVT_TIMER | EVT_NOTIFY_SIGNAL
    mov edx, 16               ; TPL_NOTIFY
    lea r8, [timer_notify]
    xor r9d, r9d
    lea rax, [timer_event]
    mov [rsp + 32], rax       ; quinto argumento de CreateEvent
    call [rbx + 80]
    test rax, rax
    jnz .done
    mov rcx, [timer_event]
    mov edx, 1               ; TimerPeriodic
    mov r8d, 100000          ; 10 ms en unidades de 100 ns
    call [rbx + 88]
    test rax, rax
    jz .done
    mov [rsp + 40], rax
    mov rcx, [timer_event]
    call [rbx + 112]         ; CloseEvent si SetTimer falla
    mov qword [timer_event], 0
    mov rax, [rsp + 40]
.done:
    add rsp, 48
    pop rbx
    ret

; RCX = EFI_SYSTEM_TABLE*. Cerrar cancela el temporizador antes del retorno EFI.
timer_stop:
    sub rsp, 40
    mov rax, [rcx + 96]
    mov rcx, [timer_event]
    test rcx, rcx
    jz .done
    call [rax + 112]
    mov qword [timer_event], 0
.done:
    add rsp, 40
    ret

timer_notify:
    inc qword [timer_ticks]
    ret

section .data
align 8
timer_ticks dq 0
timer_event dq 0
