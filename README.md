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

## Estado actual

El proyecto utiliza dos etapas en modo real de 16 bits:

- `boot/boot.asm`: sector de arranque que el BIOS carga en `0x7C00`.
- `src/kernel.asm`: aplicacion que Stage 1 carga en `0x1000:0x0000`.

Stage 1 muestra una bienvenida, lee Stage 2 con `INT 13h` y le transfiere el
control. Stage 2 solicita confirmacion antes de iniciar y presenta una interfaz
basica para alternar entre los modos reloj y cronometro.

Controles disponibles:

- `Enter`: aceptar la confirmacion inicial.
- `M`: cambiar entre reloj y cronometro.
- `Q` o `Esc`: finalizar el programa.

El modo reloj obtiene `HH:MM:SS` desde el RTC mediante `INT 1Ah`, funcion `02h`,
y actualiza la pantalla cada segundo. El valor del cronometro sigue siendo
provisional y se agregara en un avance posterior.

## Interrupciones BIOS utilizadas

| Interrupcion | Funcion | Uso en el codigo | Proposito |
|---|---|---|---|
| `INT 10h` | `AH=00h` — establecer modo de video | `mov ax, 0x0003`<br>`int 0x10` | Activa el modo de texto 80x25, limpia la pantalla y reinicia el cursor. Se usa al iniciar Stage 1 y al redibujar la interfaz. |
| `INT 10h` | `AH=0Eh` — salida teletipo | `mov ah, 0x0E`<br>`mov al, caracter`<br>`int 0x10` | Imprime el caracter almacenado en `AL` y avanza el cursor. Se utiliza para mostrar todos los mensajes y valores de tiempo. |
| `INT 10h` | `AH=02h` — posicionar cursor | `mov ah, 0x02`<br>`mov dh, fila`<br>`mov dl, columna`<br>`int 0x10` | Coloca el cursor en una posicion especifica. Permite actualizar `HH:MM:SS` sin redibujar toda la pantalla. |
| `INT 13h` | `AH=00h` — reiniciar unidad | `xor ah, ah`<br>`mov dl, [boot_drive]`<br>`int 0x13` | Reinicia el estado de la unidad desde la que arranco el BIOS antes de intentar leer Stage 2. |
| `INT 13h` | `AH=02h` — leer sectores | `mov ah, 0x02`<br>`mov al, KERNEL_SECTORS`<br>`mov cl, 0x02`<br>`int 0x13` | Lee Stage 2 desde el disco y lo copia a `ES:BX`. `DL` identifica la unidad y `CF` indica si ocurrio un error. |
| `INT 16h` | `AH=00h` — leer tecla | `xor ah, ah`<br>`int 0x16` | Espera una tecla y la retira del buffer. Devuelve el codigo ASCII en `AL`; se usa en la confirmacion inicial y para consumir teclas detectadas. |
| `INT 16h` | `AH=01h` — consultar teclado | `mov ah, 0x01`<br>`int 0x16`<br>`jz .idle` | Comprueba sin bloquear si hay una tecla disponible. Esto permite que el reloj siga actualizandose mientras no hay entrada. |
| `INT 1Ah` | `AH=02h` — leer hora del RTC | `mov ah, 0x02`<br>`int 0x1A`<br>`jc .read_error` | Obtiene la hora del reloj de tiempo real: `CH` contiene horas, `CL` minutos y `DH` segundos en BCD. `CF` indica un error de lectura. |

## Compilacion y ejecucion

```bash
make
make inspect
make run
make clean
```
