;*************************************************************************
; File:  snake.asm
; Autor: Philipp Kutsch
;
; The map is stored in an bitmap
; 80 x 25 each element is 1 byte wide
; Byte 0000 0000
;      nswo character
; nswo direction of tile
; character to draw
;
; On each tick the map is drawn to the video memory.
; Probably it would be easier to store only the direction
; on the second page of the video memory and the character
; directly on the first page. That way you could save
; the mapping of the CharacterIds.
;
; Generating the random numbers also needs some love.
;*************************************************************************

; Constants
VIDEO_MODE              equ 0x03    ; Mode 13h 80x25 text mode
SCREEN_WIDTH            equ 80      ; Screen width in characters
SCREEN_HEIGTH           equ 25      ; Screen heigth in characters
VIDEO_MEM               equ 0xb800  ; Video memory
MAP_MEM                 equ 0xc7a0  ; Map memory on second (invisible) page of video memory
MAP_MEM_LENGTH          equ SCREEN_WIDTH * SCREEN_HEIGTH   ; Map memory length

CHAR_BACKGROUND_ID      equ 0x00    ; Character id is directly mapped to the character below.
CHAR_BODY_ID            equ 0x01    ; Because we only have 4 bits per character,
CHAR_HEAD_ID            equ 0x02    ; the id of the character is stored in memory.
CHAR_CHERRY_ID          equ 0x03    ;
CHAR_WALL_HORIZONTAL_ID equ 0x04    ;
CHAR_WALL_VERTICAL_ID   equ 0x05    ;

CHAR_BODY               equ '*'     ; Actual characters drawn to the screen
CHAR_HEAD               equ 0xe9    ;
CHAR_CHERRY             equ 0xeb    ;
CHAR_WALL_HORIZONTAL    equ 0xcd    ;
CHAR_WALL_VERTICAL      equ 0xba    ;

COLOR_DEFAULT            equ 0x07    ; Character colors
COLOR_SNAKE_HEAD        equ 0x0a    ; https://wiki.osdev.org/Text_UI
COLOR_SNAKE_BODY        equ 0x02    ;
COLOR_CHERRY            equ 0x04    ;

DIRECTION_NORTH         equ 0b1000  ; Directional bitflags
DIRECTION_SOUTH         equ 0b0100  ;
DIRECTION_WEST          equ 0b0010  ;
DIRECTION_EAST          equ 0b0001  ;

SCANCODE_UP             equ 0x48    ; Keyboard scancodes
SCANCODE_DOWN           equ 0x50    ;
SCANCODE_LEFT           equ 0x4b    ;
SCANCODE_RIGHT          equ 0x4d    ;

TAIL_GROW_AMOUNT        equ 10      ; How much the snake grows when a cherry is eaten.

; Vars
headByteIndex:  dw 0                ; MAP_MEM + [headByteIndex] is the head memory location
tailByteIndex:  dw 0                ; MAP_MEM + [tailByteIndex] is the tail memory location
addElements:    db 0                ; Tail counter variable

; Game
SnakeGame:
  mov ax, VIDEO_MODE  ; Setup video mode
  int 0x10            ;

  mov ah, 0x01        ; Set cursor mode
  mov cx, 0x2607      ; invisble cursor
  int 0x10            ;

  mov ax, VIDEO_MEM   ;
  mov es, ax          ;

  mov bx, MAP_MEM                       ; Clear map memory
  clear_mem_loop:                       ; Equivalent c function:
    mov byte [bx], 0x00                 ; char* map_mem = (char*) MAP_MEM;
    inc bx                              ; for(int i = 0; i < MAP_MEM + MAP_MEM_LENGTH; i++) {
    cmp bx, MAP_MEM + MAP_MEM_LENGTH    ;   map_mem[i] = 0x00;
    jb clear_mem_loop                   ; }

  mov word [MAP_MEM + 12 * SCREEN_WIDTH + 38], 0x1111         ; Add initial snake
  mov word [MAP_MEM + 12 * SCREEN_WIDTH + 40], 0x1211         ; We add three body elements and
  mov word [headByteIndex], 12 * SCREEN_WIDTH + 41            ; one head.
  mov word [tailByteIndex], 12 * SCREEN_WIDTH + 38            ;

  mov byte [MAP_MEM + 20 * SCREEN_WIDTH + 41], CHAR_CHERRY_ID ; Add the first cherry

  xor bx, bx                                                  ; Add map bounds horizontal
  draw_map_bounds_loop:                                       ; Equivalent c function:
    mov byte [MAP_MEM + bx], CHAR_WALL_HORIZONTAL_ID          ; char* map_mem = (char*) MAP_MEM;
    mov byte [MAP_MEM + 1920 + bx], CHAR_WALL_HORIZONTAL_ID   ; for(int i = 0; i < SCREEN_WIDTH; i++) {
    inc bx                                                    ;   map_mem[i] = CHAR_WALL_HORIZONTAL_ID;
    cmp bx, SCREEN_WIDTH                                      ;   map_mem[i + 1920] = CHAR_WALL_HORIZONTAL_ID;
    jb draw_map_bounds_loop                                   ; }

  mov bx, SCREEN_WIDTH                                        ; Add map bounds vertical
  draw_map_bounds_loop1:                                      ; Equivalent c function:
    mov byte [MAP_MEM + bx], CHAR_WALL_VERTICAL_ID            ; char* map_mem = (char*) MAP_MEM;
    mov byte [MAP_MEM + 79 + bx], CHAR_WALL_VERTICAL_ID       ; for(int i = SCREEN_WIDTH; i < SCREEN_WIDTH * 24; i += SCREEN_WIDTH) {
    add bx, SCREEN_WIDTH                                      ;   map_mem[i] = CHAR_WALL_VERTICAL_ID;
    cmp bx, SCREEN_WIDTH * 24                                 ;   map_mem[i + 79] = CHAR_WALL_VERTICAL_ID;
    jb draw_map_bounds_loop1                                  ; }

  ; Main game loop
  main_loop:
    call DrawMap                    ; draw memory map to video memory

    mov ah, 0x86                    ; Sleeping
    mov cx, 0x01                    ; dx lower cx upper microseconds sleep time
    int 0x15                        ;

    mov bx, [headByteIndex]         ; Update snake head
    mov byte cl, [MAP_MEM + bx]     ; Read byte value from game memory map
    shr cl, 4                       ; Shift bits so we only have the directional bits left


    mov ah, 0x01                    ; Read keyboard scan code
    int 0x16                        ; ah 0x01 = get the state of the keyboard buffer
    cbw                             ; zero out ah first byte
    int 0x16                        ; call interrupt again to clear the buffer?

    cmp ah, SCANCODE_UP             ; Set the new head direction based on the keyboard input
      je move_north                 ; Equivalent c function:
    cmp ah, SCANCODE_DOWN           ; switch(ah) {
      je move_south                 ;   case SCANCODE_UP : cl = DIRECTION_NORTH; break;
    cmp ah, SCANCODE_LEFT           ;   case SCANCODE_DOWN : cl = DIRECTION_SOUTH; break;
      je move_west                  ;   case SCANCODE_LEFT : cl = DIRECTION_WEST; break;
    cmp ah, SCANCODE_RIGHT          ;   case SCANCODE_RIGHT : cl = DIRECTION_EAST; break;
      je move_east                  ; }
    jmp endif                       ;

    move_north:                     ;
      mov cl, DIRECTION_NORTH       ;
      jmp endif                     ;
    move_south:                     ;
      mov cl, DIRECTION_SOUTH       ;
      jmp endif                     ;
    move_west:                      ;
      mov cl, DIRECTION_WEST        ;
      jmp endif                     ;
    move_east:                      ;
      mov cl, DIRECTION_EAST        ;

    endif:                          ;

    push cx                         ; Overwrite old head position
    shl cl, 4                       ; update direction to the new direction
    add cl, CHAR_BODY_ID            ;
    mov byte [MAP_MEM + bx], cl     ;
    pop cx                          ;

    mov ax, [headByteIndex]         ; Calculate new head position
    call UpdatePositionalByteIndex  ; ax contains the updated byte index

    ; Collision handling
    push cx                         ; Read data at the new head position
    mov bx, ax                      ;
    mov byte cl, [MAP_MEM + bx]     ;
    AND cl, 0x0F                    ; isolate character bits

    cmp cl, CHAR_CHERRY_ID          ; Check if a cherry is on the new head position
    je collect_cherry               ; Collect cherry
    jmp default_collision_check     ; Continue default check

    collect_cherry:
      mov byte [addElements], TAIL_GROW_AMOUNT  ; Set tail counter to default grow amount

      pusha                                     ; Spawn a new cherry
      generate_random_position:                 ; TODO improve to a proper pseudo random number generator
        mov ah, 0x02                            ; Read RTC Time
        int 0x1a                                ; Real Time Clock Services
        mov ax, dx                              ; CX:DX = number of clock ticks since midnight
        xor dx, dx                              ; Clear dx
        mov bx, MAP_MEM_LENGTH                  ; Limit random number to map size
        div bx                                  ; Divide ax by bx
        mov bx, dx                              ;
        mov dx, [MAP_MEM + bx]                  ;
        cmp dx, 0x00                            ; Check if the random position is free
        jne generate_random_position            ; Generate a new number

      mov byte [MAP_MEM + bx], CHAR_CHERRY_ID   ; Write cherry to memory map
      popa                                      ;

      jmp collision_check_end                   ; Skip default collision check

    default_collision_check:                    ; Check if the new head position is a wall
      cmp cl, 0x00                              ; or the snake body
      jne game_over                             ;

    collision_check_end:                        ;
    pop cx                                      ;

    mov [headByteIndex], ax                     ; Construct and write head data to the new memory position
    shl cl, 4                                   ; Shift directional bits left
    add cl, CHAR_HEAD_ID                        ; Add character id
    mov bx, [headByteIndex]                     ; Read headByteIndex
    mov byte [MAP_MEM + bx], cl                 ; Write target byte to headByteIndex in memory

    ; Tail
    cmp byte [addElements], 0x00                ; Skip tail update if the user has collected a cherry.
    ja skip_tail                                ; In this tick the tailByteIndex is therefore
    jmp tail_update                             ; not updated and the snake grows by one element.

    skip_tail:                                  ; Decrement grow counter
      dec byte [addElements]                    ;
      jmp main_loop                             ;

    tail_update:                                ; Update tail
    mov bx, [tailByteIndex]                     ; Load byte at tailByteIndex
    mov byte cl, [MAP_MEM + bx]                 ;
    shr cl, 4                                   ; Shift so we only have the directon flags

    mov byte [MAP_MEM + bx], 0x00               ; Remove old tail

    mov ax, [tailByteIndex]                     ; Calculate new tail position
    call UpdatePositionalByteIndex              ;
    mov [tailByteIndex], ax                     ;

    jmp main_loop                               ; Loop

    game_over:                                  ; Game Over
      mov ah, 0x00                              ; Await key press
      int 0x16                                  ;
      jmp SnakeGame                             ; Restart game
  ret

;---------------------------------------------------
; The function reads, interprets and writes
; the content of the MemoryMap into the video memory
; IN : nothing
; OUT : nothing
DrawMap:
  xor bx, bx                                    ; bx = memory map index
  xor ax, ax                                    ; ax = video memory index
  draw_map_loop:                                ; Iterate over all memory map bytes
    mov byte cl, [MAP_MEM + bx]                           ; Read byte from memory
    AND cl, 0x0F                                ; Isolate character bits

    mov dl, COLOR_DEFAULT                        ; Equivalent c function:
    cmp cl, CHAR_BACKGROUND_ID                  ; switch(cl) {
    je draw_background                          ; case CHAR_BACKGROUND_ID :
    cmp cl, CHAR_HEAD_ID                        ;   cl = 0x00;
    je draw_head                                ;   break;
    cmp cl, CHAR_BODY_ID                        ; case CHAR_HEAD_ID :
    je draw_body                                ;   cl = CHAR_HEAD;
    cmp cl, CHAR_CHERRY_ID                      ;   dl = COLOR_SNAKE_HEAD;
    je draw_cherry                              ;   break;
    cmp cl, CHAR_WALL_HORIZONTAL_ID             ; case CHAR_BODY_ID :
    je draw_wall_horizontal                     ;   cl = CHAR_BODY;
    cmp cl, CHAR_WALL_VERTICAL_ID               ;   dl = COLOR_SNAKE_BODY;
    je draw_wall_vertical                       ;   break;
    jmp draw_char                               ; case CHAR_CHERRY_ID :
                                                ;   cl = CHAR_CHERRY;
    draw_background:                            ;   dl = COLOR_CHERRY;
      mov cl, 0x00                              ;   break;
      jmp draw_char                             ; case CHAR_WALL_HORIZONTAL_ID :
                                                ;   cl = CHAR_WALL_HORIZONTAL;
    draw_head:                                  ;   break;
      mov cl, CHAR_HEAD                         ; case CHAR_WALL_VERTICAL_ID :
      mov dl, COLOR_SNAKE_HEAD                  ;   cl = CHAR_WALL_VERTICAL;
      jmp draw_char                             ;   break;
                                                ; }
    draw_body:                                  ;
      mov cl, CHAR_BODY                         ;
      mov dl, COLOR_SNAKE_BODY                  ;
      jmp draw_char                             ;

    draw_cherry:                                ;
      mov cl, CHAR_CHERRY                       ;
      mov dl, COLOR_CHERRY                      ;
      jmp draw_char                             ;

    draw_wall_horizontal:                       ;
      mov cl, CHAR_WALL_HORIZONTAL              ;
      jmp draw_char                             ;

    draw_wall_vertical:                         ;
      mov cl, CHAR_WALL_VERTICAL                ;

    draw_char:                                  ; Draw character to video memory
      push bx                                   ; cl = Ascii character
      mov bx, ax                                ; dl = Color
      mov byte [es:bx], cl                      ; Write character byte
      mov byte [es:bx + 1], dl                  ; Write color byte
      pop bx                                    ; Restore bx value

    inc bx                                      ; Increment memory map index
    add ax, 2                                   ; Increment video memory index
    cmp bx, MAP_MEM_LENGTH                      ;
    jb draw_map_loop                            ;

  mov word [es:0], 0x07C9                       ; Draw corner characters
  mov word [es:158], 0x07BB                     ; Because corners have no collision we draw
  mov word [es:160 * 24], 0x07C8                ; them directly to video memory to save space.
  mov word [es:160 * 24 + 158], 0x07BC          ;
  ret

;---------------------------------------------------
; The function moves the memory index in the specified direction
; IN : cl = positional flag byte ax = byte index to update
; OUT : ax = updated index
UpdatePositionalByteIndex:                      ; Equivalent c function:
  cmp cl, DIRECTION_NORTH                       ; switch(cl) {
  je pos_dir_north                              ; case DIRECTION_NORTH :
  cmp cl, DIRECTION_SOUTH                       ;   ax -= SCREEN_WIDTH;
  je pos_dir_south                              ;   break;
  cmp cl, DIRECTION_WEST                        ; case DIRECTION_SOUTH :
  je pos_dir_west                               ;   ax += SCREEN_WIDTH;
  cmp cl, DIRECTION_EAST                        ;   break;
  je pos_dir_east                               ; case DIRECTION_WEST :
  jmp pos_end                                   ;   ax--;
                                                ;   break;
  pos_dir_north:                                ; case DIRECTION_EAST :
    sub word ax, SCREEN_WIDTH                   ;   ax++;
    jmp pos_end                                 ;   break;
  pos_dir_south:                                ; }
    add word ax, SCREEN_WIDTH                   ;
    jmp pos_end                                 ;
  pos_dir_west:                                 ;
    dec word ax                                 ;
    jmp pos_end                                 ;
  pos_dir_east:                                 ;
    inc word ax                                 ;
    jmp pos_end                                 ;

  pos_end:                                      ;
    ret                                         ;
