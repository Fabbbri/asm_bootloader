# Entorno de desarrollo — Bootloader ASM x86 (Tarea 1, CE4303)

Instrucciones para instalar todo lo necesario en **Ubuntu Linux** para desarrollar y probar un bootloader en ensamblador x86 (modo real), usando **NASM** como ensamblador y **QEMU** como entorno de emulación principal.

## Requisitos

- Ubuntu (o derivado de Debian) con `apt`
- Acceso `sudo`

## Instalación

### 1. Actualizar índices de paquetes

```bash
sudo apt update
```

### 2. Herramientas base: ensamblador y build tools

```bash
sudo apt install nasm build-essential
```

- **nasm** — ensamblador x86 (sintaxis Intel).
- **build-essential** — incluye `make`, `gcc`, `ld`, `binutils`.

### 3. Emulador QEMU

```bash
sudo apt install qemu-system-x86
```

Permite arrancar la imagen del bootloader sin necesidad de hardware real ni USB en cada prueba.

### 4. Debugging a bajo nivel

```bash
sudo apt install gdb
```

Se usa junto con QEMU (`qemu-system-x86_64 -s -S`) para hacer step-by-step del código en modo real.

### 5. Inspección de binarios

```bash
sudo apt install xxd
```

Para revisar en hexadecimal la imagen de 512 bytes y confirmar la firma de arranque `0xAA55`.

### 6. Utilidades de sistema de archivos (opcional, útil para stage2)

```bash
sudo apt install mtools dosfstools
```

Si se necesita manejar un sistema de archivos FAT simple para cargar código/datos adicionales desde disco.

## Todo en un solo comando

```bash
sudo apt update && sudo apt install -y nasm build-essential qemu-system-x86 gdb xxd mtools dosfstools
```

## Verificación de instalación

```bash
nasm -v
qemu-system-x86_64 --version
gdb --version
```

Salida esperada (versiones pueden variar):

```
NASM version 2.16.01
QEMU emulator version 8.2.2
GNU gdb (Ubuntu) 15.1-...
```

