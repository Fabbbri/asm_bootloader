
## Estado actual

El proyecto utiliza dos etapas en modo real de 16 bits:

- `boot/boot.asm`: sector de arranque que el BIOS carga en `0x7C00`.
- `src/kernel.asm`: aplicacion que Stage 1 carga en `0x1000:0x0000`.

Stage 1 muestra una bienvenida, lee Stage 2 con `INT 13h` y le transfiere el
control. Stage 2 solicita confirmacion antes de iniciar y presenta una interfaz
para alternar entre reloj y cronometro, ademas de configurar una alarma.

Controles generales:

- `Enter`: aceptar la confirmacion inicial.
- `M`: cambiar entre reloj y cronometro.
- `Q` o `Esc`: finalizar el programa.

Controles disponibles unicamente en modo reloj:

- `A`: configurar una alarma en formato `HH:MM`.
- `C`: cancelar la alarma configurada o detener una alarma disparada.

Controles disponibles unicamente en modo cronometro:

- `Espacio`: iniciar, pausar o reanudar el cronometro.
- `R`: reiniciar el cronometro y dejarlo detenido.

El modo reloj obtiene `HH:MM:SS` desde el RTC mediante `INT 1Ah`, funcion `02h`,
y actualiza la pantalla cada segundo. El cronometro utiliza el contador de ticks
del BIOS mediante `INT 1Ah`, funcion `00h`, por lo que mantiene un conteo
independiente del RTC incluso cuando se muestra el modo reloj.
Mientras el modo reloj esta visible, el cronometro puede seguir contando en
segundo plano, pero sus teclas de control se ignoran hasta regresar a su modo.

La alarma acepta horas entre `00:00` y `23:59`, permite corregir la entrada con
`Backspace` y cancelar la captura con `Esc`. La pantalla de configuracion muestra
una lectura actual del RTC como referencia. La hora ingresada se conserva en BCD y se
compara directamente con las horas y minutos entregados por `INT 1Ah/AH=02h`.
Cuando coincide, toda la pantalla alterna entre rojo y verde sin ocultar el
texto, y el altavoz PC suena de forma intermitente hasta presionar `C`. La alarma sigue comprobando el RTC y
puede dispararse mientras se visualiza el cronometro, pero su configuracion y
cancelacion solo estan disponibles desde la pantalla de reloj.

## Modularidad

La organizacion de `src/` replica las responsabilidades de la version UEFI,
limitandose a las funciones implementadas actualmente en Legacy:

| Archivo | Responsabilidad |
|---|---|
| `src/kernel.asm` | Punto de entrada de Stage 2, inicializacion, confirmacion y finalizacion. |
| `src/clock.asm` | Ciclo interactivo, cambio de modo, despacho de teclas e interfaz principal. |
| `src/console.asm` | Texto, limpieza de pantalla y teclado mediante `INT 10h` e `INT 16h`. |
| `src/time.asm` | Lectura y presentacion de la hora RTC mediante `INT 1Ah/AH=02h`. |
| `src/stopwatch.asm` | Estados, conteo y presentacion del cronometro mediante `INT 1Ah/AH=00h`. |
| `src/alarm.asm` | Captura `HH:MM`, validacion, comparacion RTC, cancelacion y aviso visual. |
| `src/sound.asm` | Configuracion del PIT canal 2 y control no bloqueante del PC speaker. |

UEFI ensambla cada modulo como objeto `win64` y los enlaza. Legacy, en cambio,
necesita conservar un binario plano de 16 bits, por lo que `kernel.asm` integra
los modulos con `%include`; el resultado sigue siendo un solo `kernel.bin`.

## Interrupciones BIOS utilizadas

| Interrupcion | Funcion | Uso en el codigo | Proposito |
|---|---|---|---|
| `INT 10h` | `AH=00h` — establecer modo de video | `mov ax, 0x0003`<br>`int 0x10` | Activa el modo de texto 80x25, limpia la pantalla y reinicia el cursor. Se usa al iniciar Stage 1 y al redibujar la interfaz. |
| `INT 10h` | `AH=0Eh` — salida teletipo | `mov ah, 0x0E`<br>`mov al, caracter`<br>`int 0x10` | Imprime el caracter almacenado en `AL` y avanza el cursor. Se utiliza para mostrar todos los mensajes y valores de tiempo. |
| `INT 10h` | `AH=02h` — posicionar cursor | `mov ah, 0x02`<br>`mov dh, fila`<br>`mov dl, columna`<br>`int 0x10` | Coloca el cursor en una posicion especifica. Permite actualizar `HH:MM:SS` sin redibujar toda la pantalla. |
| `INT 10h` | `AH=13h` — escribir cadena con atributo | `mov ax, 0x1300`<br>`int 0x10` | Dibuja el aviso de alarma sobre la pantalla coloreada. |
| `INT 13h` | `AH=00h` — reiniciar unidad | `xor ah, ah`<br>`mov dl, [boot_drive]`<br>`int 0x13` | Reinicia el estado de la unidad desde la que arranco el BIOS antes de intentar leer Stage 2. |
| `INT 13h` | `AH=02h` — leer sectores | `mov ah, 0x02`<br>`mov al, KERNEL_SECTORS`<br>`mov cl, 0x02`<br>`int 0x13` | Lee Stage 2 desde el disco y lo copia a `ES:BX`. `DL` identifica la unidad y `CF` indica si ocurrio un error. |
| `INT 16h` | `AH=00h` — leer tecla | `xor ah, ah`<br>`int 0x16` | Espera una tecla y la retira del buffer. Devuelve el codigo ASCII en `AL`; se usa en la confirmacion inicial y para consumir teclas detectadas. |
| `INT 16h` | `AH=01h` — consultar teclado | `mov ah, 0x01`<br>`int 0x16`<br>`jz .idle` | Comprueba sin bloquear si hay una tecla disponible. Esto permite que el reloj siga actualizandose mientras no hay entrada. |
| `INT 1Ah` | `AH=00h` — leer ticks del BIOS | `xor ah, ah`<br>`int 0x1A` | Devuelve en `CX:DX` los ticks transcurridos desde medianoche. Se usa como base de tiempo independiente para iniciar, pausar y reanudar el cronometro. |
| `INT 1Ah` | `AH=02h` — leer hora del RTC | `mov ah, 0x02`<br>`int 0x1A`<br>`jc .read_error` | Obtiene la hora del reloj de tiempo real: `CH` contiene horas, `CL` minutos y `DH` segundos en BCD. Se usa para mostrar la hora y compararla con la alarma. |

La notificacion sonora configura el PIT canal 2 mediante los puertos `0x43` y
`0x42`, y activa o desactiva el altavoz PC mediante el puerto `0x61`. El aviso
visual sigue siendo suficiente en equipos que no incorporan altavoz interno.
El cambio visual recorre los bytes de atributo de la memoria de video `0xB800`
para conservar todos los caracteres mientras cambia el color de las 2000 celdas.

## Compilacion y ejecucion

```bash
make
make inspect
make run
make clean
```

`make run` ejecuta QEMU sobre una copia temporal de la imagen y la elimina al
cerrar el emulador. De esta forma `build/disk.img` permanece disponible para
inspecciones o compilaciones posteriores.

QEMU conecta el PC speaker al sistema de audio mediante PipeWire. Si el equipo
utiliza PulseAudio directamente, se puede ejecutar:

```bash
make run AUDIO_DRIVER=pa
```
