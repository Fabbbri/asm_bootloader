BITS 64
DEFAULT REL

section .text
global efi_main

extern console_print
extern console_wait_for_key
extern time_print_current

; EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
; UEFI x86_64 usa la ABI de Microsoft:
;   RCX = ImageHandle
;   RDX = SystemTable
efi_main:
    push rbx
    sub rsp, 32

    mov rbx, rdx

    mov rcx, rbx
    lea rdx, [welcome_message]
    call console_print

    mov rcx, rbx
    call time_print_current

    mov rcx, rbx
    lea rdx, [exit_message]
    call console_print

    mov rcx, rbx
    call console_wait_for_key

    xor eax, eax
    add rsp, 32
    pop rbx
    ret

section .data
; UEFI espera strings CHAR16: UTF-16LE terminado en cero.
welcome_message:
    dw __utf16__("CE4303 - Bootloader UEFI iniciado correctamente.")
    dw 13, 10
    dw __utf16__("Hola desde BOOTX64.EFI")
    dw 13, 10
    dw 0

exit_message:
    dw __utf16__("Presiona una tecla para salir.")
    dw 13, 10
    dw 0
