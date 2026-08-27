# Reloj/Cronometro booteable

Proyecto en ensamblador x86 de 16 bits para el curso CE4303 - Principios de
Sistemas Operativos.

Actualmente, el proyecto contiene un Stage 1 basico para Legacy BIOS. Este
sector de arranque inicializa los segmentos y la pila, muestra un mensaje de
bienvenida y se detiene de forma segura.

## Requisitos

- NASM
- QEMU (`qemu-system-i386`)
- `xxd`

## Uso

```bash
make          # Compila y genera build/disk.img
make inspect  # Verifica el tamano y la firma del sector
make run      # Inicia la imagen en QEMU
make clean    # Elimina los archivos generados
```

El comando `make run` limpia para QEMU las variables de bibliotecas y GTK que
inyectan algunas terminales iniciadas desde aplicaciones Snap. Esto evita que
QEMU mezcle las bibliotecas de Snap con las del sistema.
