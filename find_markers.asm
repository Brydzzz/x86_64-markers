section .text
global find_markers


find_markers:
    push rbp
    mov rbp, rsp
    
    sub rsp, 32

    ; rdi - *bitmap
    ; rsi - *x_pos
    ; rdx - *y_pos

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r8, 0     ; counter of detected markers
    mov r9, 0     ; marker thickness counter
    mov r10, 0    ; local variable where current x coordiante is stored
    mov r11, 0    ; current marker corner x coordinate
    mov r12, 0    ; current marker corner y coordinate
    mov r13, 0    ; marker width
    mov r14, 0    ; local variable where current y coordiante is stored
    mov r15, 0    ; bytes per row
    mov QWORD[rbp-8], 0    ; image width
    mov QWORD[rbp-16], 0    ; image height
    mov QWORD[rbp-24], rdx ;copy of *y_pos
    mov QWORD[rbp-32], rdi ;copy of *bitmap

.analyze_bitmap:
    ;get image height from header
    mov cl, BYTE[rdi+23]
    shl rcx, 8
    mov cl, BYTE[rdi+22]
    mov QWORD[rbp-16], rcx  ; move image height to rbp-32

    
    ;get image width from header
    xor rcx, rcx    ; reset rcx
    mov cl, BYTE[rdi+19]
    shl rcx, 8
    mov cl, BYTE[rdi+18]
    mov QWORD[rbp-8], rcx  ; move image width to rbp-36

    ;calculate bytes per row - ((BitPerPixel * Width + 31) // 32) * 4
    imul rcx, 24    ; BitPerPixel * Width
    add rcx, 31     ; (BitPerPixel * Width + 31)
    
    xor rdx, rdx    ; clear dividend
    mov rax, rcx    ; store dividend in rax
    mov rcx, 32     ; divisor
    
    div rcx     ; (BitPerPixel * Width + 31) // 32
    shl rax, 2  ; (BitPerPixel * Width + 31) // 32) * 4
    mov r15, rax  ; move bytes per row to rbp-40

    ; get offset to pixel data
    xor rcx, rcx    ; clear rcx after div
    ; mov rdx, QWORD[rbp-24]   ; load address *y_pos back to rdx
    mov cl, BYTE[rdi+11]
    shl rcx, 8
    mov cl, BYTE[rdi+10]

    add rdi, rcx    ; add offset to address of bitmap

    xor rax, rax    ; rax - current x coordinate
    xor rdx, rbx    ; rbx - current y coordinate

.find_corner_in_row_loop:
    cmp rbx, QWORD[rbp-16]
    jge .exit   ; if y >= HEIGHT exit
    cmp rax, QWORD[rbp-8] 
    jge .next_row   ; if x >= WIDTH next_row
    mov r10, rax  ; store x
    call get_pixel
    test rax, rax
    jz .possible_corner ; if pixel is black - possible corner
    mov rax, r10 ; restore x
    inc rax
    jmp .find_corner_in_row_loop


.next_row:
    xor rax, rax    ; x=0
    inc rbx     ; y+=1
    cmp rbx, QWORD[rbp-16]
    jge .exit ; if y >= HEIGHT exit
    jmp .find_corner_in_row_loop

.possible_corner:
    mov rax, r10 ; restore x

.arm_one:
    mov r11, rax ; save corner's x for later
    mov r12, rbx ; save corner's y for later

    ;check pixel_below_corner
    test rbx, rbx
    jz .arm_one_row_0   ; if arm one is at x=0 don't check below pixels
    dec rbx     ; y-=1
    mov r10, rax  ; save current x
    call get_pixel  ; get color of pixel below corner
    test rax, rax
    jz .not_a_marker_1 ; if pixel below corner is black it's not a marker
    mov rax, r10 ; restore x
    inc rax ; x+=1

.arm_one_loop:
    cmp rax, QWORD[rbp-8]  ; if x>= WIDTH end of arm_one
    jge .end_of_arm_one_file_border
    mov r10, rax  ; save current x
    call get_pixel  ; get color of pixel in row below corner
    test rax, rax
    jz .not_a_marker_1
    mov rax, r10  ; restore x
    inc rbx     
    call get_pixel ; check pixel in corner row
    test rax, rax
    jnz .end_of_arm_one ; if pixel in corner row not black jump to end_of_arm_one
    mov rax, r10  ; restore x
    inc rax     ; x+=1
    dec rbx     ; y-=1 - move back to row below corner
    jmp .arm_one_loop


.arm_one_row_0:
    cmp rax, QWORD[rbp-8]  ; if x>= WIDTH end of arm_one
    jge .end_of_arm_one_file_border
    mov r10, rax  ; save current x
    call get_pixel
    test rax, rax
    jnz .end_of_arm_one     ; if pixel in corner row not black jump to end_of_arm_one
    mov rax, r10  ; restore x
    inc rax     ; x+=1
    jmp .arm_one_row_0

.not_a_marker_1:
    mov r9, 0 ; reset marker thickness
    mov rbx, r12 ; go back to row where incorrect corner was found
    mov rax, r10 ; restore x
    call get_pixel ; check pixel in corner row to determine whether to increase current_x by 1 or 2
    test rax, rax
    jz .increase_by_2
    mov rax, r10  ; restore x
    inc rax     ; x+=1
    jmp .find_corner_in_row_loop

    .increase_by_2:
        mov rax, r10  ; restore x
        add rax, 2  ; x+=1
        jmp .find_corner_in_row_loop

.end_of_arm_one:
    mov rax, r10  ; restore x
    mov rcx, rax
    sub rcx, r11  ; width = current_x - corner_x
    mov r13, rcx  ; store width
    test rcx, 1     ; check if width even
    jnz .not_a_marker_1
    dec rax     ; go to the last black pixel in arm
    mov r10, rax  ; save current x
    jmp .find_arm_one_top_row

.end_of_arm_one_file_border:
    mov rax, r10  ; restore x
    mov rcx, rax
    sub rcx, r11  ; width = current_x - corner_x
    inc rcx     ; width correction - width+=1
    mov r13, rcx  ; store width
    test rcx, 1     ; check if width even
    jnz .not_a_marker_1
    dec rax     ; go to the last black pixel in arm
    mov r10, rax  ; save current x
    jmp .find_arm_one_top_skip_right_check

.find_arm_one_top_row:
    mov rax, r10  ; restore x
    inc rbx     ; y+=1
    cmp rbx, QWORD[rbp-16]
    jge .not_a_marker_2
    inc rax     ; x+=1
    call get_pixel  ; check if right pixel white
    test rax, rax
    jz .not_a_marker_2
    mov rax, r10  ; restore x
    call get_pixel
    test rax, rax
    jnz .go_to_arm_two ; when arm one top was found go to arm two
    jmp .find_arm_one_top_row

.find_arm_one_top_skip_right_check:
    mov rax, r10  ; restore x
    inc rbx     ; y+=1
    cmp rbx, QWORD[rbp-16] 
    jge .not_a_marker_2 ; if y >= HEIGHT not_a_marker_2
    call get_pixel
    test rax, rax
    jnz .go_to_arm_two  ; when arm one top was found go to arm two
    jmp .find_arm_one_top_skip_right_check

.not_a_marker_2:
    mov r9, 0 ; reset marker thickness counter
    mov rax, r11 ; x = corner_x
    add rax, r13 ; x+=width
    inc rax
    mov rbx, r12 ; y = corner_y
    jmp .find_corner_in_row_loop

.go_to_arm_two:
    ; marker thickness calculations
    mov rcx, rbx    ; rcx = current_y
    sub rcx, r12  ; arm one thickness = current_y - corner_y
    mov r9, rcx   ; move thickness value to rbp-8

    mov rax, r10  ; restore x
    dec rax ; x-=1
    mov r10, rax  ; save current x

.check_arm_one_column:
    cmp rbx, r12  ; compare current_y and corner_y
    je .check_above_pixel   ; if current_y == corner_y jmp check_above_pixel
    dec rbx     ; y-=1
    call get_pixel
    test rax, rax
    jnz .not_a_marker_2
    mov rax, r10  ; restore x
    jmp .check_arm_one_column

.check_above_pixel:
    mov rax, r10  ; restore x
    add rbx, r9   ; go to row above arm one y+=arm_one_thickness
    call get_pixel
    test rax, rax
    jz .find_arm_two_top
    mov rax, r10  ; restore x
    cmp rax, r11  ; if current_x=corner_x its not a marker (cause there is no arm two - pixel above is not black)
    je .not_a_marker_2
    jmp .go_to_arm_two

.find_arm_two_top:
    mov rax, r10  ; restore x
    inc rbx     ; y+=1
    cmp rbx, QWORD[rbp-16]
    jge .marker_at_top_border   ; if y >=HEIGHT
    inc rax     ; x+=1
    call get_pixel
    test rax, rax
    jz .not_a_marker_2  ; if pixel to the right of arm two is black, it's not a marker
    mov rax, r10  ; restore x
    call get_pixel
    test rax, rax
    jnz .arm_two_top_found  ; now check arm two right border pixels
    mov rax, r10  ; restore x
    jmp .find_arm_two_top

.marker_at_top_border:
    ; calculate_height_and_ratio
    mov rcx, rbx    ; rcx = current_y
    sub rcx, r12  ; height=current_y - corner_y
	imul rcx, 2     ; height * 2
    cmp rcx, r13 
    jne .not_a_marker_2 ; if height*2!=width not_a_marker_2
    dec rbx     ; back to y=HEIGHT-1
    dec r9    ; marker thickness -=1, start of check if arms thickness is the same
    jmp .marker_at_top_border_top_loop

.marker_at_top_border_top_loop:
    test rax, rax
    jz .arm_two_right
    cmp rax, r11  ; if top_most_right_x == corner_x jmp to check arm two right_side
    je .arm_two_right
    dec r9    ; marker thickness -=1
    dec rax
    mov r10, rax  ; save current x
    mov r14, rbx  ; save current y
    jmp .check_arm_two_column_matb

.restore_y:
    mov rax, r10  ; restore x
    mov rbx, r14  ; restore y
    jmp .marker_at_top_border_top_loop

.check_arm_two_column_matb:     ; matb - marker at top border
    cmp rbx, r12 
    je .restore_y ; y==corner_y
    mov rax, r10 ; restore x
    call get_pixel
    test rax, rax
    jnz .not_a_marker_2     ; if pixels in column are not black it's not a marker
    dec rbx     ; y-=1
    jmp .check_arm_two_column_matb

.arm_two_top_found:
    ; calculate_height_and_ratio
    mov rcx, rbx ; rcx = current_y
    sub rcx, r12 ; height=current_y - corner_y
	imul rcx, 2 ; height * 2
    cmp rcx, r13 
    jne .not_a_marker_2 ; height*2!=width
    dec rbx     ; go back to top black arm two row
    dec r9    ; marker thickness -=1
    jmp .arm_two_top_loop

.arm_two_top_loop:
    mov rax, r10 ; restore x
    cmp rax, r11 
    je .arm_two_right ; x == corner_x
    test rax, rax 
    jz .arm_two_right ; x==0
    dec rax
    dec r9    ; marker thickness -=1
    mov r10, rax  ; save current x
    mov r14, rbx  ; save current y
    jmp .check_arm_two_column

.arm_top_above_pixel:
    mov rax, r10  ; restore x
    mov rbx, r14  ; restore y
    inc rbx ; y+=1
    call get_pixel
    test rax, rax
    jz .not_a_marker_2 ; if pixel above top is black it's not a marker
    dec rbx
    jmp .arm_two_top_loop

.check_arm_two_column:
    cmp rbx, r12 
    je .arm_top_above_pixel ; y==corner_y
    mov rax, r10  ; restore x
    call get_pixel
    test rax, rax
    jnz .not_a_marker_2     ; if pixels in column are not black it's not a marker
    dec rbx
    jmp .check_arm_two_column

.arm_two_right:
    cmp r9, 0 ; if thickness after substraction not 0, not_a_marker_2
    jne .not_a_marker_2
    mov r10, rax ; save current x
    jmp .arm_two_right_loop

.arm_two_right_loop:
    cmp rbx, r12 ; if we reach corner y, marker was found
    je .marker_found
    call get_pixel
    test rax, rax   ; check if arm pixel is black
    jnz .not_a_marker_2
    mov rax, r10  ; restore x
    test rax, rax
    jz .skip_right_check ;   if marker is next to file left border
    
    ; check pixel next to arm two pixel
    dec rax
    call get_pixel
    test rax, rax
    jz .not_a_marker_2
    mov rax, r10 ; restore x
    dec rbx
    jmp .arm_two_right_loop

.skip_right_check:
    dec rbx
    jmp .arm_two_right_loop

.marker_found:
    ; add x coordinate to list
    mov QWORD[rsi + 4*r8], rax     ; add x to list

    ; add y coordinate to list

    ; correct y coordinate
    mov rcx, QWORD[rbp-16]
    sub rcx, rbx    ; HEIGHT - corner_y
    dec rcx     ; corrected y coordinate

    ; mov QWORD[rdx + 4*r8], rcx     ; add y to list
    mov QWORD[rbp-24 + 4*r8], rcx     ; add y to list

    ;increment counter of markers
    inc r8
    
    jmp .not_a_marker_2 ;find new markers

.exit:
    mov rax, QWORD[rbp-4] ; load marker counter to rax

    pop QWORD[rbp-16]
    pop r14
    pop r13
    pop r12
    pop rbx

    mov rsp, rbp
    pop rbp
    ret

get_pixel:
; description:
;   returns color of specified pixel
; arguments:
;   rax - x coordinate
;   rdx - y coordinate
; return value:
;   rax - 0RGB - pixel color

    push rbp    
    mov rbp, rsp

    ;pixel address calculation
    xor rcx, rcx    ; reset rcx
    mov rcx, r15  ; move bytes per row to rcx
    imul rcx, rdx   ; rcx = y*bytes_per_row
    imul rax, 3     ; 3*x
    add rcx, rax    ; rcx += (3x)
    add rcx, rdi   ; pixel_address = bitmap_address + (3*x + y * bytes_per_row)

    ;get color
    xor rax, rax ;reset rax
    add al, BYTE[rcx+2] ; load R
    shl rax, 8 ;make space for G
    mov al, BYTE[rcx+1] ; load G
    shl rax, 8 ; make space for B
    mov al, BYTE[rcx] ; load B

    mov rsp, rbp
    pop rbp
    ret
