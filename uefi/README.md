# Reloj/Cronómetro con alarma — UEFI x86-64

Implementación en ensamblador NASM para la Tarea 1 de CE4303. El firmware carga
una aplicación PE32+ llamada `EFI/BOOT/BOOTX64.EFI`. Esta muestra la bienvenida,
espera la confirmación del usuario y ejecuta el reloj, cronómetro y alarma.
No se utiliza un sector de arranque BIOS de 512 bytes.

## Compilar y ejecutar en Linux

Herramientas necesarias: `make`, `nasm`, GNU `ld` con soporte `i386pep`, `mtools`
(`mformat`, `mmd`, `mcopy`, `mdir`), `file`, `dd`, `qemu-system-x86_64` y OVMF.
En Ubuntu/Debian se pueden instalar con:

```bash
sudo apt install build-essential nasm binutils mtools file qemu-system-x86 ovmf
```

Desde este directorio (`uefi/`):

```bash
make                 # Ensamblar, enlazar y generar la imagen FAT32
make inspect         # Inspeccionar el ejecutable EFI y su ubicación en la imagen
make run             # Ejecutar en QEMU con OVMF
make run-term        # Ejecutar con pantalla curses en una terminal compatible
make clean           # Eliminar los archivos generados en build/
```

Desde la raíz del repositorio se usa, por ejemplo, `make -C uefi run`.
El Makefile genera `build/esp/EFI/BOOT/BOOTX64.EFI` y `build/uefi.img` de 64 MiB.
La imagen se presenta a QEMU como almacenamiento USB. OVMF se busca en
`/usr/share/OVMF/OVMF_CODE_4M.fd`; se puede cambiar la ruta:

```bash
make run OVMF_CODE=/ruta/OVMF_CODE_4M.fd
```

QEMU usa `-rtc base=localtime` para inicializar el RTC virtual con la hora local
del equipo anfitrión. En hardware real se muestra la hora entregada por el
firmware, sin realizar una conversión adicional de zona horaria.

## Funcionamiento y controles

En la bienvenida, una tecla confirma la entrada al modo interactivo; `Q` permite
salir directamente. Los comandos aceptan mayúsculas y minúsculas.

| Tecla | Acción en la pantalla principal |
| --- | --- |
| `M` | Alternar entre reloj y cronómetro. |
| `S` | Iniciar, pausar o reanudar; solo en modo cronómetro. |
| `R` | Reiniciar a cero y dejar pausado el cronómetro desde cualquiera de los modos. |
| `A` | Abrir la pantalla separada de configuración de alarma. |
| `C` | Cancelar la alarma configurada y su notificación. |
| `Q` | Finalizar y retornar al firmware sin pedir una segunda tecla. |

El reloj muestra `HH:MM:SS` y se redibuja aproximadamente cada segundo.
El cronómetro muestra `HH:MM:SS.cc` (centésimas) y refresca el contador cada
50 ms nominales, reposicionando el cursor para evitar limpiar toda la pantalla
en cada actualización. Sigue contando al cambiar al reloj o configurar la
alarma. Pausar conserva las fracciones de segundo.

### Configuración de alarma

Se escriben cuatro dígitos `HHMM`; los dos puntos aparecen automáticamente.
Por ejemplo, `0730` configura `07:30`. La hora debe estar entre `00` y `23`,
y los minutos entre `00` y `59`. El cuarto dígito completa la entrada, sin Enter.
Solo se reemplaza la alarma anterior cuando ambos campos son válidos:
introducir `1260` muestra un error y conserva la configuración anterior.

La captura tiene su propia pantalla y no bloquea el cronómetro ni la comprobación
de la alarma anterior. Si esta se dispara durante la captura, la alerta también
se muestra allí. Al completar o cancelar la captura se vuelve a la pantalla
principal sin pedir una tecla adicional.

| Tecla durante la captura | Acción |
| --- | --- |
| `0`–`9` | Introducir los dígitos de la hora. |
| `Esc` | Cancelar la captura y conservar la alarma anterior. |
| `R` | Reiniciar el cronómetro sin borrar los dígitos ingresados. |
| `Q` | Finalizar el programa. |

Actualmente `C` dentro de la captura se trata como entrada inválida: sale del
editor pero conserva la alarma. Para cancelarla desde allí, se vuelve primero
a la pantalla principal y se pulsa `C`. Otras entradas de texto no válidas
muestran un error; no hay edición con retroceso. `Esc` se reconoce por su scan
code UEFI `0x17`, además del carácter 27 si el firmware lo entrega así.

Cuando coinciden la hora y el minuto del sistema con la alarma, esta queda
disparada hasta cancelarla o sustituirla por una configuración válida. La
pantalla alterna colores rojo y verde y el altavoz alterna sonido y silencio
según la fase del temporizador. La presencia de un altavoz PC depende del equipo;
la notificación visual también está implementada.

## Interrupciones BIOS y servicios UEFI utilizados

En esta versión no se ejecutan instrucciones BIOS `INT 10h`, `INT 16h` o
`INT 1Ah`. Sus funciones se realizan mediante llamadas a protocolos y servicios
del firmware UEFI. Técnicamente son **llamadas a funciones, no interrupciones
BIOS**, aunque cubren necesidades equivalentes dentro de la aplicación.

`efi_main` recibe `EFI_SYSTEM_TABLE*` en `RDX`. Desde esa tabla se accede a
`ConIn`, `ConOut`, `RuntimeServices` y `BootServices`.

| Servicio o método usado | Módulo que lo llama | Uso concreto |
| --- | --- | --- |
| `ConOut->OutputString` | `src/console.asm` | Imprimir bienvenida, hora, cronómetro, instrucciones y mensajes con cadenas CHAR16. |
| `ConOut->ClearScreen` | `src/console.asm` | Limpiar la pantalla en los redibujados completos. |
| `ConOut->SetAttribute` | `src/console.asm` | Elegir colores de texto/fondo y mostrar la alerta visual. |
| `ConOut->SetCursorPosition` | `src/console.asm` | Reposicionar el cursor para actualizar el cronómetro cada 50 ms. |
| `ConIn->ReadKeyStroke` | `src/console.asm` | Leer el carácter Unicode y, cuando se necesita, el scan code de una tecla. |
| `BootServices->WaitForEvent` | `src/console.asm` | Esperar el evento `ConIn->WaitForKey` en la confirmación inicial. |
| `BootServices->CheckEvent` | `src/console.asm` | Consultar `ConIn->WaitForKey` sin bloquear el bucle interactivo. |
| `RuntimeServices->GetTime` | `src/time.asm` | Obtener la hora para el reloj y para comparar la alarma. |
| `BootServices->CreateEvent` | `src/timer.asm` | Crear el evento temporizado con callback. |
| `BootServices->SetTimer` | `src/timer.asm` | Programar notificaciones periódicas cada 10 ms nominales. |
| `BootServices->CloseEvent` | `src/timer.asm` | Cerrar el evento al salir; también limpiar si falla su programación. |
| `BootServices->Stall` | `src/clock.asm` | Esperar 10 ms entre consultas sin entrada; no se usa para medir el cronómetro. |

`WaitForKey` es un evento del protocolo de entrada, no una función. El retorno
de `efi_main` devuelve el control al firmware; no es una llamada a `ResetSystem`
ni apaga físicamente el equipo. La aplicación conserva los Boot Services durante
su ejecución: no llama a `ExitBootServices`.

### Sonido: acceso directo a hardware

`src/sound.asm` utiliza instrucciones `IN` y `OUT`, no un servicio UEFI de audio:

| Puerto | Uso |
| --- | --- |
| `0x43` | Configurar el PIT, canal 2, en modo de onda cuadrada. |
| `0x42` | Escribir el divisor 1193 para un tono aproximado de 1 kHz. |
| `0x61` | Activar o desactivar los bits de control del altavoz PC. |

`sound_start` y `sound_stop` retornan sin esperas. El bucle principal decide
cuándo activar o desactivar el tono y apaga el altavoz antes de salir.

## Temporización y convención de llamadas

El evento se crea con `EVT_TIMER | EVT_NOTIFY_SIGNAL`, callback a `TPL_NOTIFY`
(valor 16), y `TimerPeriodic`. `SetTimer` recibe 100000 unidades de 100 ns,
equivalentes a 10 ms. El callback solo incrementa un contador alineado de 64 bits;
no imprime, no lee teclas ni espera.

`stopwatch_update` acumula las diferencias entre lecturas del contador mientras
está corriendo. Así se contabilizan también los ticks transcurridos durante un
redibujado o la captura de una alarma. La resolución nominal es de 10 ms; la
precisión depende de la entrega de notificaciones del firmware. Mostrar
centésimas no garantiza exactitud física de una centésima en todos los equipos.

Las llamadas UEFI x64 siguen la ABI de Microsoft: los primeros cuatro argumentos
van en `RCX`, `RDX`, `R8` y `R9`; se reservan 32 bytes de shadow space y se alinea
la pila a 16 bytes antes de llamar. `time_print_current` y `alarm_print_status`
guardan/restauran `RDI`, además de preservar `RBX`.

## Módulos actuales

| Archivo | Responsabilidad |
| --- | --- |
| `boot/boot.asm` | Entrada EFI, bienvenida, confirmación y retorno al firmware. |
| `src/console.asm` | Texto, colores, limpieza, cursor y lectura de teclado. |
| `src/time.asm` | Lectura mediante `GetTime` y formato de la hora. |
| `src/timer.asm` | Creación, programación, callback y cierre del temporizador. |
| `src/clock.asm` | Bucle principal, modos, pantallas y distribución de comandos. |
| `src/stopwatch.asm` | Acumulado, centésimas, pausa, reanudación y reinicio. |
| `src/alarm.asm` | Captura no bloqueante, validación, comparación y estado de alarma. |
| `src/sound.asm` | Activación y apagado del altavoz PC. |

Cada módulo se ensambla como objeto `win64` y se enlazan todos en una aplicación
EFI. La entrada de teclado y la interfaz ya están en estos módulos; no se
requieren archivos separados `keyboard.asm` o `ui.asm`.

## Ejecución en hardware real y estado de revisión

Copiar `build/esp/EFI/BOOT/BOOTX64.EFI` a una USB FAT32 respetando la estructura:

```text
USB/
└── EFI/
    └── BOOT/
        └── BOOTX64.EFI
```

Seleccionar el arranque UEFI de esa USB desde el menú del equipo. El Makefile no
firma el ejecutable: con Secure Boot activo, el firmware debe confiar en su firma
para ejecutarlo; para probar esta compilación sin firma se requiere Secure Boot
desactivado. La prueba debe hacerse en un equipo compatible con UEFI x86-64.

La compilación y la ubicación del ejecutable en la imagen se han verificado.
Se han realizado pruebas en QEMU/OVMF de los controles, cronómetro, alarma y
captura separada, incluido el cruce de medianoche. Eso no sustituye la prueba en
hardware real requerida por la tarea, que permanece pendiente de documentar.

Pendiente de robustez: `time_get_hms` todavía no comprueba el estado devuelto
por `GetTime`. Si el firmware devuelve un error, no se debe asumir que la hora
leída sea válida. En cambio, los errores de creación/programación del timer se
comprueban y provocan un mensaje y retorno al firmware.

## Referencias UEFI

- [Tabla del sistema UEFI](https://uefi.org/specs/UEFI/2.10/04_EFI_System_Table.html).
- [Eventos, temporizadores y Boot Services](https://uefi.org/specs/UEFI/2.10_A/07_Services_Boot_Services.html).
- [Runtime Services, incluido GetTime](https://uefi.org/specs/UEFI/2.10/08_Services_Runtime_Services.html).
