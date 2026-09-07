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
    sub rsp, 48                 ; Shadow space + espacio para el quinto argumento y un error temporal.
    mov rbx, [rcx + 96]         ; SystemTable->BootServices.
    mov qword [timer_ticks], 0  ; El contador comienza en cero al entrar al modo interactivo.

    ; BootServices->CreateEvent(tipo, prioridad, callback, contexto, &evento).
    mov ecx, 0x80000200         ; EVT_TIMER | EVT_NOTIFY_SIGNAL: timer que llama un callback.
    mov edx, 16                 ; TPL_NOTIFY: prioridad con la que UEFI ejecuta el callback.
    lea r8, [timer_notify]      ; Direccion de la funcion ejecutada cada vez que venza el timer.
    xor r9d, r9d                ; Contexto = NULL; este callback no necesita datos extra.
    lea rax, [timer_event]      ; Direccion donde UEFI guardara el identificador creado.
    mov [rsp + 32], rax         ; Quinto argumento: &timer_event va en el stack.
    call [rbx + 80]             ; BootServices + 80 = CreateEvent(...).
    test rax, rax               ; EFI_SUCCESS = 0; un valor distinto de cero indica error.
    jnz .done

    ; BootServices->SetTimer(evento, TimerPeriodic, intervalo_en_100_ns).
    mov rcx, [timer_event]
    mov edx, 1                  ; TimerPeriodic: se repite hasta cerrar el evento.
    mov r8d, 100000             ; 100 000 x 100 ns = 10 ms = 100 ticks por segundo.
    call [rbx + 88]             ; BootServices + 88 = SetTimer(...).
    test rax, rax
    jz .done

    ; Si SetTimer falla, el evento ya creado debe cerrarse para no dejar recursos UEFI abiertos.
    mov [rsp + 40], rax         ; Conserva el EFI_STATUS de error mientras se llama CloseEvent.
    mov rcx, [timer_event]
    call [rbx + 112]            ; BootServices + 112 = CloseEvent(timer_event).
    mov qword [timer_event], 0
    mov rax, [rsp + 40]         ; Devuelve a clock.asm el error original de SetTimer.
.done:
    add rsp, 48                 ; Libera el espacio reservado al inicio.
    pop rbx                     ; Restaura RBX, registro que esta funcion debe preservar.
    ret

; RCX = EFI_SYSTEM_TABLE*. Cerrar cancela el temporizador antes del retorno EFI.
timer_stop:
    sub rsp, 40
    mov rax, [rcx + 96]         ; SystemTable->BootServices.
    mov rcx, [timer_event]      ; Evento que se creo en timer_start.
    test rcx, rcx                ; Evita cerrar un evento inexistente (valor 0).
    jz .done
    call [rax + 112]            ; BootServices->CloseEvent(evento); tambien cancela el timer.
    mov qword [timer_event], 0  ; Marca que ya no hay recurso UEFI que cerrar.
.done:
    add rsp, 40
    ret

; Callback de UEFI: se invoca automaticamente cada 10 ms.
; Los parametros Event y Context llegan en RCX/RDX, pero no se necesitan aqui.
timer_notify:
    inc qword [timer_ticks]     ; Un tick = 10 ms de tiempo transcurrido.
    ret

section .data
align 8
timer_ticks dq 0                 ; Contador global consultado por clock.asm y stopwatch.asm.
timer_event dq 0                 ; EFI_EVENT creado por CreateEvent; 0 significa "no creado".
