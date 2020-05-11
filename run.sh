#!/bin/bash
qemu-system-i386 -drive file=img/bootSectorSnake.img,format=raw,index=0,media=disk
