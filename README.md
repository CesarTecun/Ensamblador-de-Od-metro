# Ensamblador-de-Odometro

Autores:
- Edras Fernando Tatuaca Alvarado – 7690-22-11542
- Cesar Alberto Tecún Leiva – 7690-22-11766

## Descripción del proyecto

Este proyecto implementa un odómetro de rueda utilizando una Raspberry Pi Pico (RP2040) programada completamente en ensamblador ARM.  
El sistema utiliza un sensor Hall A3144 con cuatro imanes en la rueda para detectar giros, calcula la distancia recorrida y la muestra en dos displays de siete segmentos mediante multiplexación por software.

El código fue desarrollado para cumplir con las especificaciones del curso de Arquitectura de Computadoras II, con el objetivo de comprender el funcionamiento del microcontrolador a bajo nivel y su interacción directa con los periféricos.

## Componentes principales

- Raspberry Pi Pico o Pico W
- Sensor Hall A3144
- 4 imanes de neodimio
- 2 displays de 7 segmentos (cátodo común)
- 2 transistores NPN (2N2222)
- Resistencias de 220–330 Ω para los segmentos
- Resistencias de 470–1k Ω para las bases de los transistores
- Botón Reset
- Switch RUN
- Power bank o alimentación por USB

## Mapeo de pines GPIO

| Función | GPIO | Notas |
|----------|------|-------|
| Segmento a | GP13 | Resistencia 220–330 Ω |
| Segmento b | GP12 | Resistencia 220–330 Ω |
| Segmento c | GP11 | Resistencia 220–330 Ω |
| Segmento d | GP10 | Resistencia 220–330 Ω |
| Segmento e | GP9  | Resistencia 220–330 Ω |
| Segmento f | GP8  | Resistencia 220–330 Ω |
| Segmento g | GP7  | Resistencia 220–330 Ω |
| Dígito D1 (decenas) | GP5 | Base NPN hacia cátodo común |
| Dígito D2 (unidades) | GP4 | Base NPN hacia cátodo común |
| Sensor Hall | GP14 | Entrada con pull-up interno |
| Botón Reset | GP2 | A GND, con pull-up interno |
| Switch RUN | RUN | Centro al pin RUN, extremo a GND |

## Instalación de dependencias

En Ubuntu o Debian:

```bash
sudo apt update
sudo apt install -y build-essential cmake ninja-build git gcc-arm-none-eabi gdb-multiarch openocd python3
```

## Clonar y configurar el SDK

```bash
mkdir -p ~/pico && cd ~/pico
git clone -b master https://github.com/raspberrypi/pico-sdk
cd pico-sdk
git submodule update --init
cd ..
echo 'export PICO_SDK_PATH="$HOME/pico/pico-sdk"' >> ~/.bashrc
source ~/.bashrc
```

## Compilar el proyecto

Dentro del directorio del proyecto `odometro_asm`:

```bash
cd ~/pico/odometro_asm
rm -rf build && mkdir build && cd build
cmake -G Ninja -DPICO_SDK_PATH=$PICO_SDK_PATH -DPICO_BOARD=pico_w ..
ninja
```

Esto generará el archivo `odometro_asm.uf2` en la carpeta `build`.

## Cargar el archivo .uf2 a la Raspberry Pi Pico

1. Conectar la Pico al computador mientras se mantiene presionado el botón BOOTSEL.
2. Esperar a que se monte como una unidad USB llamada `RPI-RP2`.
3. Copiar el archivo compilado:

```bash
cp odometro_asm.uf2 /media/$USER/RPI-RP2/
sync
```

4. La Pico se reiniciará automáticamente y ejecutará el programa.

## Créditos

Proyecto académico desarrollado como parte del curso Arquitectura de Computadoras II  
Universidad Mariano Gálvez de Guatemala – 2025
Ing. Henry Sontay

## Documentación del código ensamblador
    .syntax unified              @ Usar sintaxis unificada ARM/Thumb
    .thumb                       @ El RP2040 ejecuta código en modo Thumb

    .global main                 @ Hacemos visible la etiqueta main al linker
    .type   main, %function      @ Indicamos que 'main' es una función

/* ========== Registros base ========== */
/* Direcciones base del bloque SIO (Single-Cycle I/O) y IO_BANK0, PADS */
/* SIO: permite escribir/leer GPIO de forma rápida (OUT, IN, OE, etc.). */
/* IO_BANK0: controla función de cada GPIO (FUNCSEL). */
/* PADS: controla resistencias internas (pull-up, pull-down, etc.). */

.equ SIO_BASE,              0xD0000000
.equ SIO_GPIO_IN,           (SIO_BASE + 0x004)   @ Registro de lectura de todos los GPIO
.equ SIO_GPIO_OUT_SET,      (SIO_BASE + 0x014)   @ Escribir 1 en un bit = pone a 1 ese GPIO
.equ SIO_GPIO_OUT_CLR,      (SIO_BASE + 0x018)   @ Escribir 1 en un bit = pone a 0 ese GPIO
.equ SIO_GPIO_OE_SET,       (SIO_BASE + 0x024)   @ Habilita dirección de salida (Output Enable)

.equ IO_BANK0_BASE,         0x40014000
.equ PADS_BANK0_BASE,       0x4001C000

/* GPIOx_CTRL offsets (RP2040) - Configuración de función de pin */
/* Cada GPIOx_CTRL selecciona la función del pin (FUNCSEL). */
/* FUNCSEL = 5 => Función SIO (GPIO controlado por SIO). */

.equ GPIO4_CTRL,            (IO_BANK0_BASE + 0x024)
.equ GPIO5_CTRL,            (IO_BANK0_BASE + 0x02C)
.equ GPIO7_CTRL,            (IO_BANK0_BASE + 0x03C)
.equ GPIO8_CTRL,            (IO_BANK0_BASE + 0x044)
.equ GPIO9_CTRL,            (IO_BANK0_BASE + 0x04C)
.equ GPIO10_CTRL,           (IO_BANK0_BASE + 0x054)
.equ GPIO11_CTRL,           (IO_BANK0_BASE + 0x05C)
.equ GPIO12_CTRL,           (IO_BANK0_BASE + 0x064)
.equ GPIO13_CTRL,           (IO_BANK0_BASE + 0x06C)
.equ GPIO14_CTRL,           (IO_BANK0_BASE + 0x074)   @ Sensor Hall en GP14

/* Paso por imán detectado (ajustable según número de imanes) */
/* Cada flanco detectado suma 3 "unidades" al contador (ej: 3 cm por pulso). */
.equ STEP_PULSO, 3

/* Configuración del pin RESET (GP2) */
.equ GPIO2_CTRL,            (IO_BANK0_BASE + 0x014)
.equ PADS_GPIO2,            (PADS_BANK0_BASE + 0x0C)

/* PADS para GP14 (control de resistencias pull-up/down) */
.equ PADS_GPIO14,           (PADS_BANK0_BASE + 0x3C)

/* Pines del display */
/* DIG_D1 y DIG_D2 controlan qué dígito está activo (decenas/unidades). */
.equ DIG_D1,    5   @ decenas (NPN D1, pin GP5)
.equ DIG_D2,    4   @ unidades (NPN D2, pin GP4)

/* ========== Macros ========== */
/* Estas macros cargan máscaras de bits ya preparadas en un registro. */

/* Máscara de todos los segmentos (a..g en GP13..7) */
/* a = GP13, b = 12, c = 11, d = 10, e = 9, f = 8, g = 7. */
.macro LOAD_ALL_SEGS_MASK reg
    ldr \reg, =((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7))
.endm

/* Máscara de todos los pines de salida (segmentos + D1 + D2) */
/* Incluye segmentos (GP13..7) y dígitos (GP5, GP4). */
.macro LOAD_ALL_OE_MASK reg
    ldr \reg, =((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7)|(1<<5)|(1<<4))
.endm

/* ========== Variables de datos ========== */
.data
.align 2
valor:      .word 0      @ Valor actual mostrado (debug/consulta)
hall_prev:  .word 0      @ Último estado del Hall (0/1) para detectar flanco
pulsos:     .word 0      @ Contador de pulsos, rango 0..99

/* ========== Tabla de segmentos (LUT) ========== */
/* SEG_LUT: tabla de búsqueda (Look-Up Table) para cada dígito 0–9. */
/* Cada entrada es una máscara de bits que enciende los segmentos necesarios. */

.text
.align 2
SEG_LUT:
    /* 0 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8))              @ a,b,c,d,e,f
    /* 1 */ .word ((1<<12)|(1<<11))                                            @ b,c
    /* 2 */ .word ((1<<13)|(1<<12)|(1<<10)|(1<<9)|(1<<7))                      @ a,b,d,e,g
    /* 3 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<7))                     @ a,b,c,d,g
    /* 4 */ .word ((1<<12)|(1<<11)|(1<<8)|(1<<7))                              @ b,c,f,g
    /* 5 */ .word ((1<<13)|(1<<11)|(1<<10)|(1<<8)|(1<<7))                      @ a,c,d,f,g
    /* 6 */ .word ((1<<13)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7))               @ a,c,d,e,f,g
    /* 7 */ .word ((1<<13)|(1<<12)|(1<<11))                                    @ a,b,c
    /* 8 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7))       @ a,b,c,d,e,f,g
    /* 9 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<8)|(1<<7))              @ a,b,c,d,f,g

/* ========== delay_soft ========== */
/* Pequeño retardo por software. */
/* Se usa para:
   - Controlar el tiempo que cada dígito está encendido (multiplexado).
   - Ajustar el brillo aparente del display.
*/
delay_soft:
    push {r4, r5}         @ Guardar r4 y r5 en la pila (se usan como contadores)
    ldr  r4, =800         @ Bucle externo: número de repeticiones (ajusta brillo/duración)
1:
    movs r5, #255         @ Bucle interno: cuenta regresiva desde 255
2:
    subs r5, r5, #1       @ r5 = r5 - 1
    bne 2b                @ Mientras r5 != 0, seguir en el bucle interno
    subs r4, r4, #1       @ r4 = r4 - 1
    bne 1b                @ Mientras r4 != 0, repetir el bucle externo
    pop  {r4, r5}         @ Restaurar r4 y r5
    bx   lr               @ Volver a la función que llamó a delay_soft

/* ========== seg_mask_for_digit ========== */
/* Entrada: r4 = dígito (0–9) */
/* Salida:  r0 = máscara de segmentos correspondiente a ese dígito. */
seg_mask_for_digit:
    push {r1}             @ Guardamos r1 (se usará como puntero base)
    lsls r4, r4, #2       @ offset = dígito * 4 bytes (cada entrada es un .word)
    ldr  r1, =SEG_LUT     @ r1 apunta al inicio de la tabla SEG_LUT
    ldr  r0, [r1, r4]     @ r0 = *(SEG_LUT + offset)
    pop  {r1}             @ Restauramos r1
    bx   lr               @ return; r0 queda con la máscara

/* ========== main() ========== */
/* Punto de entrada principal del programa:
   - Configura pines.
   - Inicializa variables.
   - Entra en el bucle principal de lectura y display.
*/
main:

    /* Configurar GPIO como función SIO (FUNCSEL = 5) */
    movs r0, #5           @ r0 = 5 => función SIO para GPIOx_CTRL

    /* ---- Configuración de pines de segmentos (salida) ---- */
    ldr r1, =GPIO13_CTRL  @ segmento 'a'
    str r0, [r1]          @ FUNCSEL = 5 (SIO)
    ldr r1, =GPIO12_CTRL  @ 'b'
    str r0, [r1]
    ldr r1, =GPIO11_CTRL  @ 'c'
    str r0, [r1]
    ldr r1, =GPIO10_CTRL  @ 'd'
    str r0, [r1]
    ldr r1, =GPIO9_CTRL   @ 'e'
    str r0, [r1]
    ldr r1, =GPIO8_CTRL   @ 'f'
    str r0, [r1]
    ldr r1, =GPIO7_CTRL   @ 'g'
    str r0, [r1]

    /* ---- Configuración de los pines de dígitos (salida) ---- */
    ldr r1, =GPIO5_CTRL   @ DIG_D1 (decenas)
    str r0, [r1]
    ldr r1, =GPIO4_CTRL   @ DIG_D2 (unidades)
    str r0, [r1]

    /* ---- Configurar sensor Hall (GP14) como SIO (entrada) ---- */
    ldr r1, =GPIO14_CTRL
    str r0, [r1]          @ FUNCSEL = 5, pero la dirección (IN/OUT) la controla OE

    /* ---- Configurar botón RESET (GP2) como SIO (entrada) ---- */
    ldr r1, =GPIO2_CTRL
    str r0, [r1]

    /* ---- Activar pull-up en GP14 (Hall) ---- */
    ldr r1, =PADS_GPIO14  @ r1 = dirección del registro PADS de GP14
    ldr r0, [r1]          @ r0 = valor actual del PADS
    movs r2, #4           @ bit PDE (pull-down enable)
    mvns r2, r2           @ r2 = ~4 => máscara con todos 1 excepto PDE
    ands r0, r2           @ limpia PDE (desactiva pull-down)
    movs r2, #8           @ bit PUE (pull-up enable)
    orrs r0, r2           @ activa PUE (habilita pull-up)
    str r0, [r1]          @ guarda nueva configuración

    /* ---- Activar pull-up en GP2 (RESET) ---- */
    ldr r1, =PADS_GPIO2
    ldr r0, [r1]
    movs r2, #4
    mvns r2, r2           @ desactiva pull-down
    ands r0, r2
    movs r2, #8
    orrs r0, r2           @ activa pull-up en el botón
    str r0, [r1]

    /* ---- Habilitar salida en todos los pines de segmentos y dígitos ---- */
    LOAD_ALL_OE_MASK r0   @ r0 = máscara de todos los GPIO de salida (segmentos + D1 + D2)
    ldr r1, =SIO_GPIO_OE_SET
    str r0, [r1]          @ Marca esos GPIO como salidas (output enable = 1)

    /* ---- Inicializar variables ---- */
    ldr  r0, =pulsos
    movs r1, #0
    str  r1, [r0]         @ pulsos = 0

    /* Guardar el estado inicial del Hall en hall_prev */
    ldr  r0, =SIO_GPIO_IN @ leer todos los GPIO
    ldr  r1, [r0]
    ldr  r2, =(1<<14)     @ máscara para GP14
    ands r1, r1, r2       @ aislamos el bit 14
    lsrs r1, r1, #14      @ r1 = 0 o 1
    ldr  r0, =hall_prev
    str  r1, [r0]

/* ===== BUCLE PRINCIPAL ===== */
/* Aquí se:
   - Lee el Hall y detecta flancos.
   - Actualiza el contador.
   - Lee el botón de reset.
   - Calcula decenas/unidades.
   - Multiplexa el display de 2 dígitos.
*/
loop:
    /* --- Leer estado del Hall (GP14) --- */
    ldr  r0, =SIO_GPIO_IN
    ldr  r1, [r0]         @ r1 = valor de todos los GPIO
    ldr  r2, =(1<<14)     @ máscara de GP14
    ands r1, r1, r2       @ quedarnos solo con bit 14
    lsrs r1, r1, #14      @ r1 = estado actual (0 o 1)

    /* --- Cargar estado previo del Hall --- */
    ldr  r0, =hall_prev
    ldr  r3, [r0]         @ r3 = hall_prev

    /* Si el estado actual == anterior, no hubo cambio de nivel */
    cmp  r1, r3
    beq  no_edge          @ si son iguales, saltar a no_edge

    /* Hubo cambio: vemos si fue un flanco de bajada 1 -> 0 */
    cmp  r3, #1
    bne  not_1_to_0       @ si antes no era 1, no es flanco 1->0
    cmp  r1, #0
    bne  not_1_to_0       @ si ahora no es 0, tampoco es flanco 1->0

    /* ---- Flanco 1->0 detectado: aumentar contador de pulsos ---- */
    ldr  r2, =pulsos
    ldr  r4, [r2]         @ r4 = pulsos actuales
    adds r4, r4, #STEP_PULSO  @ pulsos += STEP_PULSO (ej: +3)
    cmp  r4, #100
    blt  store_pulses     @ si < 100, guardamos directamente
    movs r4, #0           @ si llega a 100 o más, reiniciamos a 0

store_pulses:
    str  r4, [r2]         @ pulsos = r4

not_1_to_0:
    /* Actualizar hall_prev = estado actual */
    ldr  r0, =hall_prev
    str  r1, [r0]

no_edge:
    /* === RESET: leer botón en GP2 (activo en 0) === */
    ldr  r0, =SIO_GPIO_IN
    ldr  r1, [r0]
    ldr  r2, =(1<<2)      @ máscara para GP2
    ands r1, r1, r2
    lsrs r1, r1, #2       @ r1 = 0 (presionado) / 1 (suelto)
    cmp  r1, #0
    bne  skip_reset       @ si no está presionado, saltamos
    @ si está presionado, poner pulsos = 0
    ldr  r0, =pulsos
    movs r2, #0
    str  r2, [r0]
skip_reset:

    /* Cargar número de pulsos (0..99) para mostrarlo */
    ldr  r2, =pulsos
    ldr  r2, [r2]         @ r2 = valor 0..99
    ldr  r0, =valor
    str  r2, [r0]         @ guardamos en 'valor' solo para debug

    /* Obtener decenas/unidades usando restas sucesivas */
    movs r3, #0           @ r3 = decenas
dec_loop:
    cmp  r2, #9
    bls  dec_done         @ si r2 <= 9, ya es la unidad final
    subs r2, r2, #10      @ r2 -= 10
    adds r3, r3, #1       @ decenas += 1
    b    dec_loop
dec_done:
    @ Al final:
    @ r3 = decenas (0..9)
    @ r2 = unidades (0..9)

    /* ===== Mostrar decenas (D1) ===== */
    ldr r5, =SIO_GPIO_OUT_CLR
    LOAD_ALL_SEGS_MASK r4       @ r4 = máscara de todos los segmentos
    str  r4, [r5]               @ Apaga todos los segmentos
    ldr  r4, =((1<<DIG_D1)|(1<<DIG_D2))
    str  r4, [r5]               @ Apaga ambos dígitos (D1 y D2)

    mov  r4, r3                 @ r4 = decenas (dígito a mostrar en D1)
    bl   seg_mask_for_digit     @ r0 = máscara de segmentos para ese dígito
    ldr  r1, =SIO_GPIO_OUT_SET
    str  r0, [r1]               @ Enciende los segmentos necesarios
    ldr  r0, =(1<<DIG_D1)       @ Selecciona D1
    str  r0, [r1]               @ Enciende solo D1
    bl   delay_soft             @ Pequeño retardo para que el ojo lo vea

    /* ===== Mostrar unidades (D2) ===== */
    ldr r5, =SIO_GPIO_OUT_CLR
    LOAD_ALL_SEGS_MASK r4
    str  r4, [r5]               @ Apaga todos los segmentos
    ldr  r4, =((1<<DIG_D1)|(1<<DIG_D2))
    str  r4, [r5]               @ Apaga ambos dígitos

    mov  r4, r2                 @ r4 = unidades
    bl   seg_mask_for_digit     @ r0 = máscara de segmentos para unidades
    ldr  r1, =SIO_GPIO_OUT_SET
    str  r0, [r1]               @ Enciende segmentos requeridos
    ldr  r0, =(1<<DIG_D2)       @ Selecciona D2
    str  r0, [r1]               @ Enciende solo D2
    bl   delay_soft             @ Retardo para multiplexado

    b    loop                   @ Repetir bucle principal indefinidamente
