[BITS 16]
[ORG 0x100]

section .text

start:
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov ax, 0003h        ; Set 80x25 text mode
    int 10h

    call show_menu       ; Display the main menu

main_loop:
    call clear_screen
    call draw_level_label
    call draw_score
    call draw_maze

get_input:
    mov ah, 0
    int 16h               ; Get key input
    cmp al, 27            ; ESC key pressed?; Compare key with ESC (ASCII 27)

    je NEAR exit_game

    ; Save old position
    mov al, [player_x]
    mov [old_x], al
    mov al, [player_y]
    mov [old_y], al

    cmp ah, 72            ; Up arrow
    je move_up
    cmp ah, 80            ; Down arrow
    je move_down
    cmp ah, 75            ; Left arrow
    je move_left
    cmp ah, 77            ; Right arrow
    je move_right
    jmp get_input

move_up:
    dec byte [player_y]
    jmp check_move
move_down:
    inc byte [player_y]
    jmp check_move
move_left:
    dec byte [player_x]
    jmp check_move
move_right:
    inc byte [player_x]

check_move:
    ; Calculate index in maze array
    mov al, [player_y]
    mov ah, 20           ; 20 columns per row
    mul ah
    add al, [player_x]
    adc ah, 0
    mov bx, ax

    mov si, [maze_ptr]
    add si, bx
    mov al, [si]         ; Get character at new position

    cmp al, '#'          ; Is it a wall?
    je restore_pos
    cmp al, 'E'          ; Is it an exit?
    je next_level
    cmp al, '.'          ; Is it a coin?
    jne update_position

    ; Pick up coin
    inc word [score]
    mov byte [si], ' '   ; Remove coin from maze

update_position:
    jmp main_loop

restore_pos:
    mov al, [old_x]
    mov [player_x], al
    mov al, [old_y]
    mov [player_y], al
    jmp main_loop

next_level:
    inc byte [current_level]
    cmp byte [current_level], total_levels
    jae win_game
    call load_level
    jmp main_loop

win_game:
    call clear_screen
    mov dx, win_msg
    call print_string
    call update_high_score
    call wait_key
    jmp show_menu

exit_game:
    mov ax, 4C00h
    int 21h

; -------------------------------
load_level:
    mov al, [current_level]
    movzx si, al
    shl si, 1
    mov bx, [maze_table + si] ; Get maze pointer
    mov [maze_ptr], bx
    mov si, [level_name_table + si] ; Get level name pointer
    mov [level_msg_ptr], si
    mov byte [player_x], 1
    mov byte [player_y], 1
    ret

draw_maze:
    mov cx, 10            ; 10 rows
    mov dx, 0             ; Current row
    mov si, [maze_ptr]

.next_row:
    push cx
    mov cx, 20            ; 20 columns
    mov bx, 0             ; Current column

.next_char:
    ; Check if this is player position
    mov al, bl
    cmp al, [player_x]
    jne .not_player
    mov al, dl
    cmp al, [player_y]
    jne .not_player

    ; Show player
    mov ah, 0Eh
    mov al, 'P'
    int 10h
    jmp .next_position

.not_player:
    mov al, [si]          ; Show maze character
    mov ah, 0Eh
    int 10h

.next_position:
    inc si
    inc bx
    loop .next_char

    ; New line
    mov ah, 0Eh
    mov al, 13
    int 10h
    mov al, 10
    int 10h

    inc dl
    pop cx
    loop .next_row
    ret

draw_level_label:
    mov dx, [level_msg_ptr]
    call print_string
    ret

draw_score:
    mov dx, score_msg
    call print_string

    mov ax, [score]
    mov bl, 10
    div bl                ; AL = tens, AH = ones

    cmp al, 0
    je .display_ones
    add al, '0'
    mov ah, 0Eh
    int 10h

.display_ones:
    mov al, ah
    add al, '0'
    mov ah, 0Eh
    int 10h

    ; New line
    mov al, 13
    int 10h
    mov al, 10
    int 10h
    ret

clear_screen:
    mov ax, 0600h
    mov bh, 07h
    mov cx, 0
    mov dx, 184Fh
    int 10h

    mov ah, 2
    mov bh, 0
    mov dx, 0
    int 10h
    ret

print_string:
    mov ah, 09h
    int 21h
    ret

wait_key:
    mov ah, 0
    int 16h
    ret

update_high_score:
    mov ax, [score]
    cmp ax, [high_score]
    jbe .done
    mov [high_score], ax
.done:
    ret

show_menu:
    call clear_screen
    mov dx, menu_title
    call print_string
    mov dx, menu_1
    call print_string
    mov dx, menu_2
    call print_string
    mov dx, menu_3
    call print_string
    mov dx, menu_esc
    call print_string

menu_wait:
    mov ah, 0
    int 16h
    cmp al, '1'
    je start_game
    cmp al, '2'
    je view_high_score
    cmp al, '3'
    je show_instructions
    cmp al, 27
    je exit_game
    jmp menu_wait

start_game:
    mov word [score], 0
    mov byte [current_level], 0
    call load_level
    jmp main_loop

view_high_score:
    call clear_screen
    mov dx, high_score_msg
    call print_string

    mov ax, [high_score]
    mov bl, 10
    div bl

    cmp al, 0
    je .hs_ones
    add al, '0'
    mov ah, 0Eh
    int 10h

.hs_ones:
    mov al, ah
    add al, '0'
    mov ah, 0Eh
    int 10h

    call wait_key
    jmp show_menu

show_instructions:
    call clear_screen
    mov dx, inst_msg
    call print_string
    call wait_key
    jmp show_menu

section .data

menu_title db 13,10,'--- Maze Game ---',13,10,'$'
menu_1     db '1. Start Game',13,10,'$'
menu_2     db '2. View High Score',13,10,'$'
menu_3     db '3. Instructions',13,10,'$'
menu_esc   db 'Press ESC to Exit',13,10,'$'

inst_msg   db 13,10,'MAZE GAME INSTRUCTIONS:',13,10,13,10
           db 'OBJECTIVE:',13,10
           db 'Navigate through the maze to reach the exit (E) ',13,10
           db 'while collecting as many coins as possible.',13,10,13,10
           db 'CONTROLS:',13,10
           db 'Use arrow keys to move your player (P)',13,10,13,10
           db 'SCORING SYSTEM:',13,10
           db '- Each coin (.) collected increases your score by 1 point',13,10
           db '- Your current score is displayed below the level name',13,10
           db '- If you collect more than 10 coins, you get a bonus message',13,10,13,10
           db 'GAME ELEMENTS:',13,10
           db 'P = Player (you)',13,10
           db '. = Coin (worth 1 point)',13,10
           db '# = Wall (cannot pass through)',13,10
           db 'E = Exit (go to next level)',13,10,13,10
           db 'TIPS:',13,10
           db '- Try to collect all coins before exiting',13,10
           db '- Higher levels have more complex mazes',13,10
           db '- Your score carries over between levels',13,10,13,10
           db 'Press any key to return to menu',13,10,'$'

high_score_msg db 'High Score: $'
win_msg   db 13, 10, 'You Win! All levels completed!', 13, 10, '$'
score_msg db 'Score: $'

level1_msg db 'Level 1 - Easy', 13, 10, '$'
level2_msg db 'Level 2 - Medium', 13, 10, '$'
level3_msg db 'Level 3 - Hard', 13, 10, '$'

level_msg_ptr dw 0
player_x  db 1
player_y  db 1
old_x     db 0
old_y     db 0
score     dw 0
high_score dw 0
current_level db 0
total_levels  equ 3
maze_ptr dw 0

maze1:
    db '####################'
    db '#P.......        E#'
    db '#.############## ##'
    db '#.......           #'
    db '############## ### #'
    db '#.................#'
    db '#.#################'
    db '#..........        #'
    db '################## #'
    db '####################'

maze2:
    db '####################'
    db '#P#......        E##'
    db '#.# ############# ##'
    db '#.#..........    ###'
    db '# ##############   #'
    db '#................. #'
    db '####### ########## #'
    db '#................. #'
    db '# ##################'
    db '####################'

maze3:
    db '####################'
    db '#P..  #####....... #'
    db '###.###.###.###### #'
    db '#...  #   #....... #'
    db '#####.#####.###### #'
    db '#...       #...### #'
    db '#.#.###.#.####.### #'
    db '#.#...#.#.....#... #'
    db '#.###.#######.######'
    db '#.......E..........#'

maze_table:
    dw maze1
    dw maze2
    dw maze3

level_name_table:
    dw level1_msg
    dw level2_msg
    dw level3_msg