#!/bin/bash
mkdir -p bin
mkdir -p img
nasm src/main.asm -i src/ -o bin/main.bin
nasm src/main.asm -i src/ -o img/bootSectorSnake.img -dIMAGE
