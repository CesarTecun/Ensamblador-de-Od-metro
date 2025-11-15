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
