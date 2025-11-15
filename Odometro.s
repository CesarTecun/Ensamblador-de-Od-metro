.syntax unified
    .thumb

    .global main
    .type   main, %function

/* ========== Registros base ========== */
@ --- Direcciones base del hardware del RP2040 (SIO, IO_BANK0, PADS) ---
@ Sirven para configurar GPIO, leer entradas y escribir salidas.

.equ SIO_BASE,              0xD0000000
.equ SIO_GPIO_IN,           (SIO_BASE + 0x004)
.equ SIO_GPIO_OUT_SET,      (SIO_BASE + 0x014)
.equ SIO_GPIO_OUT_CLR,      (SIO_BASE + 0x018)
.equ SIO_GPIO_OE_SET,       (SIO_BASE + 0x024)

.equ IO_BANK0_BASE,         0x40014000
.equ PADS_BANK0_BASE,       0x4001C000

/* GPIOx_CTRL offsets (RP2040) */
.equ GPIO4_CTRL,            (IO_BANK0_BASE + 0x024)
.equ GPIO5_CTRL,            (IO_BANK0_BASE + 0x02C)
.equ GPIO7_CTRL,            (IO_BANK0_BASE + 0x03C)
.equ GPIO8_CTRL,            (IO_BANK0_BASE + 0x044)
.equ GPIO9_CTRL,            (IO_BANK0_BASE + 0x04C)
.equ GPIO10_CTRL,           (IO_BANK0_BASE + 0x054)
.equ GPIO11_CTRL,           (IO_BANK0_BASE + 0x05C)
.equ GPIO12_CTRL,           (IO_BANK0_BASE + 0x064)
.equ GPIO13_CTRL,           (IO_BANK0_BASE + 0x06C)
.equ GPIO14_CTRL,           (IO_BANK0_BASE + 0x074)   @ Hall en GP14
.equ STEP_PULSO, 3      @ cuanto suma cada imán (1, 2, 3, etc)


@ === RESET: GPIO2_CTRL y PADS de GP2 ===
.equ GPIO2_CTRL,            (IO_BANK0_BASE + 0x014)
.equ PADS_GPIO2,            (PADS_BANK0_BASE + 0x0C)

/* PADS para GP14 (cada pad son 4 bytes)
   GPIO0: +0x04, GPIO1: +0x08, ..., GPIO13: +0x38, GPIO14: +0x3C */
.equ PADS_GPIO14,           (PADS_BANK0_BASE + 0x3C)

/* Pines del display */
.equ DIG_D1,    5   @ decenas (NPN D1)
.equ DIG_D2,    4   @ unidades (NPN D2)

/* ========== Macros ========== */

/* Máscara de todos los segmentos (a..g en GP13..7) */
.macro LOAD_ALL_SEGS_MASK reg
    ldr \reg, =((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7))
.endm

/* Máscara de todos los pines de salida (segmentos + D1 + D2) */
.macro LOAD_ALL_OE_MASK reg
    ldr \reg, =((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7)|(1<<5)|(1<<4))
.endm

/* ========== Datos ========== */
    .data
    .align 2
valor:      .word 0      @ valor mostrado (0..99) - debug/consulta
hall_prev:  .word 0      @ último estado del Hall (0/1)
pulsos:     .word 0      @ contador de pulsos 0..99

/* ========== LUT de segmentos ========== */
@ --- Tabla con la máscara de segmentos para cada dígito 0..9 ---
@ Cada valor enciende solo los segmentos correctos del display 7 segmentos.

    .text
    .align 2
SEG_LUT:
    /* 0 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8))
    /* 1 */ .word ((1<<12)|(1<<11))
    /* 2 */ .word ((1<<13)|(1<<12)|(1<<10)|(1<<9)|(1<<7))
    /* 3 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<7))
    /* 4 */ .word ((1<<12)|(1<<11)|(1<<8)|(1<<7))
    /* 5 */ .word ((1<<13)|(1<<11)|(1<<10)|(1<<8)|(1<<7))
    /* 6 */ .word ((1<<13)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7))
    /* 7 */ .word ((1<<13)|(1<<12)|(1<<11))
    /* 8 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<9)|(1<<8)|(1<<7))
    /* 9 */ .word ((1<<13)|(1<<12)|(1<<11)|(1<<10)|(1<<8)|(1<<7))

/* ========== delay pequeño por bucles ========== */
@ --- Pequeño delay por software ---
@ Se usa para dar tiempo a que cada dígito del display sea visible.

delay_soft:
    push {r4, r5}
    ldr  r4, =800          @ ajusta este valor si quieres más/menos brillo
1:
    movs r5, #255
2:
    subs r5, r5, #1
    bne 2b
    subs r4, r4, #1
    bne 1b
    pop  {r4, r5}
    bx   lr

/* ========== seg_mask_for_digit ========== */
/* Entrada: r4 = dígito 0..9
   Salida:  r0 = máscara GPIO de segmentos */
   @ --- Obtiene la máscara de segmentos para un dígito ---
@ Entrada: r4 = número (0..9)
@ Salida: r0 = bits que deben encenderse.

seg_mask_for_digit:
    push {r1}
    lsls r4, r4, #2         @ offset = dígito * 4 bytes
    ldr  r1, =SEG_LUT
    ldr  r0, [r1, r4]
    pop  {r1}
    bx   lr                 @ return

/* ========== main() ========== */
main:
    /* ---- Configurar GPIO como SIO (FUNCSEL = 5) ---- */
    @ --- Configurar pines como función SIO para controlar GPIO manualmente ---
    
    movs r0, #5

    ldr r1, =GPIO13_CTRL    @ segmento a
    str r0, [r1]
    ldr r1, =GPIO12_CTRL    @ b
    str r0, [r1]
    ldr r1, =GPIO11_CTRL    @ c
    str r0, [r1]
    ldr r1, =GPIO10_CTRL    @ d
    str r0, [r1]
    ldr r1, =GPIO9_CTRL     @ e
    str r0, [r1]
    ldr r1, =GPIO8_CTRL     @ f
    str r0, [r1]
    ldr r1, =GPIO7_CTRL     @ g
    str r0, [r1]

    ldr r1, =GPIO5_CTRL     @ D1
    str r0, [r1]
    ldr r1, =GPIO4_CTRL     @ D2
    str r0, [r1]

    /* Hall en GP14 como SIO (entrada) */
    @ --- Configuramos el sensor Hall (GP14) como entrada con pull-up ---
@ El Hall baja a 0 cuando detecta un campo magnético.

    ldr r1, =GPIO14_CTRL
    str r0, [r1]

    /* === RESET: botón en GP2 como SIO (entrada) === */
    ldr r1, =GPIO2_CTRL
    str r0, [r1]

    /* Activar pull-up interno en GP14 (igual que antes)
       PADS bits (RP2040) en este código:
       - bit 2 = PDE (pull-down enable)
       - bit 3 = PUE (pull-up enable)
    */
    ldr r1, =PADS_GPIO14
    ldr r0, [r1]

    @ --- limpiar PDE (bit 2) ---
    movs r2, #4        @ r2 = 0b00000100
    mvns r2, r2        @ r2 = ~0b00000100
    ands r0, r2        @ r0 = r0 & ~4  -> PDE = 0

    @ --- activar PUE (bit 3) ---
    movs r2, #8        @ r2 = 0b00001000
    orrs r0, r2        @ r0 = r0 | 8   -> PUE = 1

    str r0, [r1]

    /* === RESET: pull-up interno en GP2 (mismo patrón que GP14) === */
    ldr r1, =PADS_GPIO2
    ldr r0, [r1]

    @ limpiar PDE (bit 2)
    movs r2, #4
    mvns r2, r2
    ands r0, r2

    @ activar PUE (bit 3)
    movs r2, #8
    orrs r0, r2

    str r0, [r1]

    /* ---- Habilitar como salidas todos los segmentos + D1 + D2 ---- */
    LOAD_ALL_OE_MASK r0
    ldr r1, =SIO_GPIO_OE_SET
    str r0, [r1]

    /* init pulsos = 0 */
    ldr  r0, =pulsos
    movs r1, #0
    str  r1, [r0]

    /* init hall_prev = estado actual del Hall (0/1) */
@ --- Guardamos el estado inicial del Hall para detectar cambios (flancos) --- 
  
    ldr  r0, =SIO_GPIO_IN
    ldr  r1, [r0]
    ldr  r2, =(1<<14)
    ands r1, r1, r2
    lsrs r1, r1, #14        @ r1 = 0/1
    ldr  r0, =hall_prev
    str  r1, [r0]

@ ===== BUCLE PRINCIPAL =====
@ Lee el Hall, detecta flancos, incrementa el contador y refresca el display.

loop:
    /* --- Leer Hall en GP14 (0/1) --- */
    ldr  r0, =SIO_GPIO_IN
    ldr  r1, [r0]
    ldr  r2, =(1<<14)
    ands r1, r1, r2
    lsrs r1, r1, #14        @ r1 = estado actual 0/1

    /* --- Cargar estado previo --- */
    ldr  r0, =hall_prev
    ldr  r3, [r0]           @ r3 = hall_prev

    /* Si igual, no hay flanco -> saltar */
    cmp  r1, r3
    beq  no_edge

    /* Hubo cambio: ver si fue 1 -> 0 (flanco de bajada) */
    cmp  r3, #1
    bne  not_1_to_0
    cmp  r1, #0
    bne  not_1_to_0

    /* ===== Aquí hay flanco 1 -> 0: sumar pulso ===== */
@ --- Detectar flanco descendente (1→0) del Hall ---
@ Esto significa que un imán pasó frente al sensor.  
    
    ldr  r2, =pulsos
    ldr  r4, [r2]       @ r4 = pulsos
    adds r4, r4, #STEP_PULSO   @ pulsos += STEP_PULSO
    cmp  r4, #100
    blt  store_pulses
    movs r4, #0         @ si llega a 100, reinicia a 0
store_pulses:
    str  r4, [r2]

not_1_to_0:
    /* Actualizar hall_prev = estado actual */
    ldr  r0, =hall_prev
    str  r1, [r0]

no_edge:
    /* === RESET: leer botón en GP2 (activo en 0) === */
@ --- Botón RESET: si r5=0, reinicia contador a 0 ---
@ Botón a GND, pull-up interno → presionado = 0, suelto = 1.

    ldr  r0, =SIO_GPIO_IN
    ldr  r1, [r0]
    ldr  r2, =(1<<2)        @ bit de GP2
    ands r1, r1, r2
    lsrs r1, r1, #2         @ r1 = 0 (presionado) / 1 (suelto)
    cmp  r1, #0
    bne  skip_reset
    @ si está presionado, poner pulsos = 0
    ldr  r0, =pulsos
    movs r2, #0
    str  r2, [r0]
skip_reset:

    /* --- Cargar pulsos (0..99) en r2 --- */
 @ --- Incrementar contador de pulsos (mod 100) ---

    ldr  r2, =pulsos
    ldr  r2, [r2]

    /* Guardar también en 'valor' por si quieres leerlo desde debug/consola */
    ldr  r0, =valor
    str  r2, [r0]

    /* --- Obtener decenas/unidades de r2 --- */
@ --- Convertir el número total (0..99) en decenas (r3) y unidades (r2) ---
@ Se hace restando 10 repetidamente porque no usamos división hardware.    

    movs r3, #0             @ decenas = 0
dec_loop:
    cmp  r2, #9
    bls  dec_done
    subs r2, r2, #10
    adds r3, r3, #1
    b    dec_loop
dec_done:
    @ r3 = decenas (0..9)
    @ r2 = unidades (0..9)

    /* ===== Mostrar decenas en D1 ===== */
    /* Apagar todo */
    ldr r5, =SIO_GPIO_OUT_CLR
    LOAD_ALL_SEGS_MASK r4
    str  r4, [r5]                         @ apaga segmentos
    ldr  r4, =((1<<DIG_D1)|(1<<DIG_D2))
    str  r4, [r5]                         @ apaga D1 y D2

    /* Segments para decenas (r3) */
    mov  r4, r3
    bl   seg_mask_for_digit               @ r0 = máscara segmentos
    ldr  r1, =SIO_GPIO_OUT_SET
    str  r0, [r1]                         @ enciende segmentos de la decena

    /* Enciende D1 */
@ --- Mostrar dígito de decenas en el display D1 ---
    ldr  r0, =(1<<DIG_D1)
    str  r0, [r1]

    /* Retardo para que se vea */
    bl   delay_soft

    /* ===== Mostrar unidades en D2 ===== */
    /* Apagar todo */
    ldr r5, =SIO_GPIO_OUT_CLR
    LOAD_ALL_SEGS_MASK r4
    str  r4, [r5]
    ldr  r4, =((1<<DIG_D1)|(1<<DIG_D2))
    str  r4, [r5]

    /* Segments para unidades (r2) */
    mov  r4, r2
    bl   seg_mask_for_digit               @ r0 = máscara segmentos
    ldr  r1, =SIO_GPIO_OUT_SET
    str  r0, [r1]                         @ enciende segmentos de la unidad

    /* Enciende D2 */
@ --- Mostrar dígito de unidades en el display D2 ---
    ldr  r0, =(1<<DIG_D2)
    str  r0, [r1]

    /* Retardo para que se vea */
    bl   delay_soft

    b    loop