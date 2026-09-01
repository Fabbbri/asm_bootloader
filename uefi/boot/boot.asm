BITS 64
DEFAULT REL

section .text
global efi_main

extern console_print
extern console_wait_for_key
extern console_clear
extern console_set_attribute
extern clock_run

COLOR_NORMAL equ 0x07
COLOR_TITLE equ 0x0E
COLOR_ACCENT equ 0x0B
COLOR_CONFIRM equ 0x0A

; EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
; UEFI x86_64 usa la ABI de Microsoft:
;   RCX = ImageHandle
;   RDX = SystemTable
efi_main:
    push rbx
    sub rsp, 32

    mov rbx, rdx

    mov rcx, rbx
    call console_clear

    mov rcx, rbx
    mov edx, COLOR_ACCENT
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [task_title]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [boot_details]
    call console_print

    mov rcx, rbx
    mov edx, COLOR_CONFIRM
    call console_set_attribute

    mov rcx, rbx
    lea rdx, [confirm_message]
    call console_print

    mov rcx, rbx
    call console_wait_for_key

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    mov rcx, rbx
    call clock_run

    mov rcx, rbx
    lea rdx, [exit_message]
    call console_print

    mov rcx, rbx
    call console_wait_for_key

    mov rcx, rbx
    mov edx, COLOR_NORMAL
    call console_set_attribute

    xor eax, eax
    add rsp, 32
    pop rbx
    ret

section .data
; UEFI espera strings CHAR16: UTF-16LE terminado en cero.
task_title:
    dw __utf16__("Tarea 1 - Reloj/Cronometro con Alarma")
    dw 13, 10
    dw __utf16__("Bootloader UEFI x86-64")
    dw 13, 10
    dw 13, 10
    dw 0

boot_details:
    dw __utf16__("Curso: CE4303 - Principios de Sistemas Operativos")
    dw 13, 10
    dw __utf16__("Firmware: UEFI")
    dw 13, 10
    dw __utf16__("Archivo de arranque: EFI/BOOT/BOOTX64.EFI")
    dw 13, 10
    dw 13, 10
    dw 0

confirm_message:
    dw __utf16__("Presiona cualquier tecla para entrar al modo interactivo.")
    dw 13, 10
    dw 0

exit_message:
    dw __utf16__("Programa finalizado. Presiona una tecla para salir.")
    dw 13, 10
    dw 0
