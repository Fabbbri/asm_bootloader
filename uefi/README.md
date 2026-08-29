# Bootloader UEFI

Este directorio contiene el arranque UEFI de la tarea.

En UEFI no se genera un sector de arranque legacy de 512 bytes. Se genera una
aplicacion EFI llamada `BOOTX64.EFI` y se coloca en una imagen FAT en esta ruta:

```text
EFI/BOOT/BOOTX64.EFI
```

## Objetivo de esta parte

Implementar la alternativa UEFI del proyecto:

1. Arrancar desde firmware UEFI.
2. Mostrar una bienvenida inicial.
3. Entrar a una aplicacion interactiva de reloj/cronometro/alarma.
4. Obtener la hora actual desde el firmware.
5. Probar primero en QEMU con OVMF.
6. Copiar luego el `BOOTX64.EFI` a una USB FAT32 para probar en hardware real.

## Modularidad

El codigo se separa en modulos para que sea mas facil de explicar, probar y
modificar durante la defensa. Cada modulo se ensambla como objeto `win64` y
luego el `Makefile` los enlaza en una sola aplicacion UEFI `BOOTX64.EFI`.

La division actual/planeada es:

| Archivo | Responsabilidad |
| ------- | --------------- |
| `boot/boot.asm` | Implementado. Punto de entrada UEFI (`efi_main`) y flujo principal. |
| `src/console.asm` | Implementado. Rutinas de salida de texto, limpieza de pantalla y lectura de tecla. |
| `src/time.asm` | Implementado. Lectura de hora real mediante servicios UEFI y conversion a texto. |
| `src/keyboard.asm` | Planeado. Lectura de teclas y mapeo de comandos del usuario. |
| `src/clock.asm` | Implementado inicial. Modo reloj: mostrar y actualizar la hora actual. |
| `src/stopwatch.asm` | Planeado. Modo cronometro: iniciar, pausar, reanudar y reiniciar. |
| `src/alarm.asm` | Planeado. Configuracion, comparacion y cancelacion de alarma. |
| `src/ui.asm` | Planeado. Pantalla principal, etiquetas, estado actual y mensajes al usuario. |

## Servicios UEFI usados

En Legacy BIOS se utilizan interrupciones como `INT 10h`, `INT 16h` e `INT 1Ah`.
En UEFI puro no se llaman esas interrupciones directamente. UEFI ejecuta una
aplicacion de 64 bits en formato PE32+ y expone tablas de funciones del firmware:
`EFI_SYSTEM_TABLE`, `BootServices` y `RuntimeServices`.

Para la defensa, esta es la equivalencia que se debe explicar:

| Necesidad | Legacy BIOS | UEFI |
| --------- | ----------- | ---- |
| Mostrar texto | `INT 10h` | `SystemTable->ConOut->OutputString` |
| Leer teclado | `INT 16h` | `SystemTable->ConIn->ReadKeyStroke` y `BootServices->WaitForEvent` |
| Obtener hora RTC | `INT 1Ah`, funcion `02h` | `RuntimeServices->GetTime` |
| Esperar eventos | No aplica igual | `BootServices->WaitForEvent` |

### Lista de llamadas usadas o planeadas

1. `ConOut->OutputString`
   - Estado: usado actualmente.
   - Modulo: `src/console.asm`.
   - Uso: imprimir mensajes en pantalla.
   - Equivalente conceptual en BIOS legacy: `INT 10h`.

2. `RuntimeServices->GetTime`
   - Estado: usado actualmente.
   - Modulo: `src/time.asm`.
   - Uso: obtener hora actual del sistema desde el firmware UEFI.
   - Equivalente conceptual en BIOS legacy: `INT 1Ah`, funcion `02h`.

3. `BootServices->WaitForEvent`
   - Estado: usado actualmente para esperar una tecla antes de salir.
   - Modulo: `src/console.asm`.
   - Uso planeado: esperar eventos de teclado y controlar actualizaciones.
   - Equivalente conceptual aproximado: espera de entrada/eventos del BIOS.

4. `ConIn->ReadKeyStroke`
   - Estado: usado actualmente para consumir la tecla de salida; luego se usara
     para comandos interactivos.
   - Modulo actual: `src/console.asm`. Luego puede moverse a `src/keyboard.asm`.
   - Uso: leer comandos del usuario (`M`, `S`, `R`, `A`, `C`, `Q`).
   - Equivalente conceptual en BIOS legacy: `INT 16h`.

5. `ConOut->ClearScreen`
   - Estado: usado actualmente.
   - Modulo: `src/console.asm`.
   - Uso: limpiar pantalla para dibujar la interfaz.
   - Equivalente conceptual en BIOS legacy: `INT 10h`, modo texto/limpieza.

6. `ConOut->SetAttribute`
   - Estado: planeado.
   - Uso: cambiar colores para resaltar alarma o estados.
   - Equivalente conceptual en BIOS legacy: atributos de video con `INT 10h`.

7. `BootServices->Stall`
   - Estado: usado actualmente.
   - Modulo: `src/clock.asm`.
   - Uso: esperar aproximadamente un segundo entre actualizaciones del reloj.
   - Equivalente conceptual: retardo controlado por firmware.

## Nota sobre interrupciones y RTC

El enunciado pide obtener la hora desde el RTC mediante interrupciones BIOS.
Eso aplica directamente a la version Legacy del proyecto, donde se puede usar
`INT 1Ah`.

Esta version UEFI no corre en modo real de 16 bits ni usa BIOS legacy; por eso
usa `RuntimeServices->GetTime`, que es la forma UEFI de obtener la hora real del
firmware. Para efectos de documentacion, se considera el equivalente UEFI del
acceso al RTC.

## Compilar

```bash
make
```

## Inspeccionar

```bash
make inspect
```

## Simular con QEMU

```bash
make run
```

El `Makefile` usa `-rtc base=localtime` para que el RTC virtual de QEMU use la
hora local de la PC. Sin esa opcion, QEMU puede entregar la hora en UTC y el
reloj mostrado no coincide con la hora del sistema.

Si no hay ventana grafica disponible, tambien se puede correr en la terminal:

```bash
make run-term
```

## Pasar a hardware

Cuando ya funcione en QEMU, se copia `build/esp/EFI/BOOT/BOOTX64.EFI` a una USB
formateada en FAT32 con la misma estructura de carpetas:

```text
USB/
└── EFI/
    └── BOOT/
        └── BOOTX64.EFI
```
