;*************************************************************************
; File:  main.asm
; Autor: Philipp Kutsch, Skelleton code by Michael Graf
; http://www.lowlevel.eu/wiki/Eigener_Bootloader
;*************************************************************************

[BITS 16]           ; 16bit realmode code
;[CPU 186]           ; Target instruction set Intel 80186
[ORG 0x0000]        ; start Organisation at position

START:              ; Initalize segmentregisters and create Stack
  mov ax, 0x07C0    ; segmentlocation 0x07C0
  mov ds, ax        ; set DataSegment to 0x07C0
  mov es, ax        ; set ExtraSegment t0 0x07C0
                    ; create stack
  mov ss, ax        ; set StackSegment to 0x07C0
  mov sp, 0xFFFF    ; set StackPointer to 0xFFFF

  jmp WORD 07C0h:MAIN         ; jump into main to configure
                              ; CodeSegment and InstructionPointer

MAIN:
  call SnakeGame

%include "snake.asm"

; Bootsector padding
TIMES 510-($-$$) db 0x00           ;
dw 0xAA55                          ; Magic Number

%ifdef IMAGE                       ;
TIMES 1474048 DB 0x00              ; Empty Disk Image 1.44MB
%endif
