section .text
global find_markers


find_markers:
    push ebp
    mov ebp, esp
    
    sub esp, 40

    push ebx
    push edi
    push esi
    push edx

    mov DWORD[ebp-4], 0     ; counter of detected markers
    mov DWORD[ebp-8], 0     ; marker thickness counter
    mov DWORD[ebp-12], 0    ; local variable where current x coordiante is stored
    mov DWORD[ebp-16], 0    ; current marker corner x coordinate
    mov DWORD[ebp-20], 0    ; current marker corner y coordinate
    mov DWORD[ebp-24], 0    ; marker width
    mov DWORD[ebp-28], 0    ; local variable where current y coordiante is stored
    mov DWORD[ebp-32], 0    ; image height
    mov DWORD[ebp-36], 0    ; image width
    mov DWORD[ebp-40], 0    ; bytes per row

.analyze_bitmap:
    mov edx, DWORD[ebp+8]   ; load address of bitmap to edx

    ;get image height from header
    mov cl, BYTE[edx+23]
    shl ecx, 8
    mov cl, BYTE[edx+22]
    mov DWORD[ebp-32], ecx  ; move image height to ebp-32

    
    ;get image width from header
    xor ecx, ecx    ; reset ecx
    mov cl, BYTE[edx+19]
    shl ecx, 8
    mov cl, BYTE[edx+18]
    mov DWORD[ebp-36], ecx  ; move image width to ebp-36

    ;calculate bytes per row - ((BitPerPixel * Width + 31) // 32) * 4
    imul ecx, 24    ; BitPerPixel * Width
    add ecx, 31     ; (BitPerPixel * Width + 31)
    
    xor edx, edx    ; clear dividend
    mov eax, ecx    ; store dividend in eax
    mov ecx, 32     ; divisor
    
    div ecx     ; (BitPerPixel * Width + 31) // 32
    shl eax, 2  ; (BitPerPixel * Width + 31) // 32) * 4
    mov DWORD[ebp-40], eax  ; move bytes per row to ebp-40

    ; get offset to pixel data
    xor ecx, ecx    ; clear ecx after div
    mov edx, DWORD[ebp+8]   ; load address of bitmap to edx
    mov cl, BYTE[edx+11]
    shl ecx, 8
    mov cl, BYTE[edx+10]

    add edx, ecx    ; add offset to address of bitmap

    xor eax, eax    ; eax - current x coordinate
    xor ebx, ebx    ; ebx - current y coordinate

.find_corner_in_row_loop:
    cmp ebx, DWORD[ebp-32]
    jge .exit   ; if y >= HEIGHT exit
    cmp eax, DWORD[ebp-36] 
    jge .next_row   ; if x >= WIDTH next_row
    mov DWORD[ebp-12], eax  ; store x
    call get_pixel
    test eax, eax
    jz .possible_corner ; if pixel is black - possible corner
    mov eax, DWORD[ebp-12] ; restore x
    inc eax
    jmp .find_corner_in_row_loop


.next_row:
    xor eax, eax    ; x=0
    inc ebx     ; y+=1
    cmp ebx, DWORD[ebp-32]
    jge .exit ; if y >= HEIGHT exit
    jmp .find_corner_in_row_loop

.possible_corner:
    mov eax, DWORD[ebp-12] ; restore x

.arm_one:
    mov DWORD[ebp-16], eax ; save corner's x for later
    mov DWORD[ebp-20], ebx ; save corner's y for later

    ;check pixel_below_corner
    test ebx, ebx
    jz .arm_one_row_0   ; if arm one is at x=0 don't check below pixels
    dec ebx     ; y-=1
    mov DWORD[ebp-12], eax  ; save current x
    call get_pixel  ; get color of pixel below corner
    test eax, eax
    jz .not_a_marker_1 ; if pixel below corner is black it's not a marker
    mov eax, DWORD[ebp-12] ; restore x
    inc eax ; x+=1

.arm_one_loop:
    cmp eax, DWORD[ebp-36]  ; if x>= WIDTH end of arm_one
    jge .end_of_arm_one_file_border
    mov DWORD[ebp-12], eax  ; save current x
    call get_pixel  ; get color of pixel in row below corner
    test eax, eax
    jz .not_a_marker_1
    mov eax, DWORD[ebp-12]  ; restore x
    inc ebx     
    call get_pixel ; check pixel in corner row
    test eax, eax
    jnz .end_of_arm_one ; if pixel in corner row not black jump to end_of_arm_one
    mov eax, DWORD[ebp-12]  ; restore x
    inc eax     ; x+=1
    dec ebx     ; y-=1 - move back to row below corner
    jmp .arm_one_loop


.arm_one_row_0:
    cmp eax, DWORD[ebp-36]  ; if x>= WIDTH end of arm_one
    jge .end_of_arm_one_file_border
    mov DWORD[ebp-12], eax  ; save current x
    call get_pixel
    test eax, eax
    jnz .end_of_arm_one     ; if pixel in corner row not black jump to end_of_arm_one
    mov eax, DWORD[ebp-12]  ; restore x
    inc eax     ; x+=1
    jmp .arm_one_row_0

.not_a_marker_1:
    mov DWORD[ebp-8], 0 ; reset marker thickness
    mov ebx, DWORD[ebp-20] ; go back to row where incorrect corner was found
    mov eax, DWORD[ebp-12] ; restore x
    call get_pixel ; check pixel in corner row to determine whether to increase current_x by 1 or 2
    test eax, eax
    jz .increase_by_2
    mov eax, DWORD[ebp-12]  ; restore x
    inc eax     ; x+=1
    jmp .find_corner_in_row_loop

    .increase_by_2:
        mov eax, DWORD[ebp-12]  ; restore x
        add eax, 2  ; x+=1
        jmp .find_corner_in_row_loop

.end_of_arm_one:
    mov eax, DWORD[ebp-12]  ; restore x
    mov ecx, eax
    sub ecx, DWORD[ebp-16]  ; width = current_x - corner_x
    mov DWORD[ebp-24], ecx  ; store width
    test ecx, 1     ; check if width even
    jnz .not_a_marker_1
    dec eax     ; go to the last black pixel in arm
    mov DWORD[ebp-12], eax  ; save current x
    jmp .find_arm_one_top_row

.end_of_arm_one_file_border:
    mov eax, DWORD[ebp-12]  ; restore x
    mov ecx, eax
    sub ecx, DWORD[ebp-16]  ; width = current_x - corner_x
    inc ecx     ; width correction - width+=1
    mov DWORD[ebp-24], ecx  ; store width
    test ecx, 1     ; check if width even
    jnz .not_a_marker_1
    dec eax     ; go to the last black pixel in arm
    mov DWORD[ebp-12], eax  ; save current x
    jmp .find_arm_one_top_skip_right_check

.find_arm_one_top_row:
    mov eax, DWORD[ebp-12]  ; restore x
    inc ebx     ; y+=1
    cmp ebx, DWORD[ebp-32]
    jge .not_a_marker_2
    inc eax     ; x+=1
    call get_pixel  ; check if right pixel white
    test eax, eax
    jz .not_a_marker_2
    mov eax, DWORD[ebp-12]  ; restore x
    call get_pixel
    test eax, eax
    jnz .go_to_arm_two ; when arm one top was found go to arm two
    jmp .find_arm_one_top_row

.find_arm_one_top_skip_right_check:
    mov eax, DWORD[ebp-12]  ; restore x
    inc ebx     ; y+=1
    cmp ebx, DWORD[ebp-32] 
    jge .not_a_marker_2 ; if y >= HEIGHT not_a_marker_2
    call get_pixel
    test eax, eax
    jnz .go_to_arm_two  ; when arm one top was found go to arm two
    jmp .find_arm_one_top_skip_right_check

.not_a_marker_2:
    mov DWORD[ebp-8], 0 ; reset marker thickness counter
    mov eax, DWORD[ebp-16] ; x = corner_x
    add eax, DWORD[ebp-24] ; x+=width
    inc eax
    mov ebx, DWORD[ebp-20] ; y = corner_y
    jmp .find_corner_in_row_loop

.go_to_arm_two:
    ; marker thickness calculations
    mov ecx, ebx    ; ecx = current_y
    sub ecx, DWORD[ebp-20]  ; arm one thickness = current_y - corner_y
    mov DWORD[ebp-8], ecx   ; move thickness value to ebp-8

    mov eax, DWORD[ebp-12]  ; restore x
    dec eax ; x-=1
    mov DWORD[ebp-12], eax  ; save current x

.check_arm_one_column:
    cmp ebx, DWORD[ebp-20]  ; compare current_y and corner_y
    je .check_above_pixel   ; if current_y == corner_y jmp check_above_pixel
    dec ebx     ; y-=1
    call get_pixel
    test eax, eax
    jnz .not_a_marker_2
    mov eax, DWORD[ebp-12]  ; restore x
    jmp .check_arm_one_column

.check_above_pixel:
    mov eax, DWORD[ebp-12]  ; restore x
    add ebx, DWORD[ebp-8]   ; go to row above arm one y+=arm_one_thickness
    call get_pixel
    test eax, eax
    jz .find_arm_two_top
    mov eax, DWORD[ebp-12]  ; restore x
    cmp eax, DWORD[ebp-16]  ; if current_x=corner_x its not a marker (cause there is no arm two - pixel above is not black)
    je .not_a_marker_2
    jmp .go_to_arm_two

.find_arm_two_top:
    mov eax, DWORD[ebp-12]  ; restore x
    inc ebx     ; y+=1
    cmp ebx, DWORD[ebp-32]
    jge .marker_at_top_border   ; if y >=HEIGHT
    inc eax     ; x+=1
    call get_pixel
    test eax, eax
    jz .not_a_marker_2  ; if pixel to the right of arm two is black, it's not a marker
    mov eax, DWORD[ebp-12]  ; restore x
    call get_pixel
    test eax, eax
    jnz .arm_two_top_found  ; now check arm two right border pixels
    mov eax, DWORD[ebp-12]  ; restore x
    jmp .find_arm_two_top

.marker_at_top_border:
    ; calculate_height_and_ratio
    mov ecx, ebx    ; ecx = current_y
    sub ecx, DWORD[ebp-20]  ; height=current_y - corner_y
	imul ecx, 2     ; height * 2
    cmp ecx, DWORD[ebp-24] 
    jne .not_a_marker_2 ; if height*2!=width not_a_marker_2
    dec ebx     ; back to y=HEIGHT-1
    dec DWORD[ebp-8]    ; marker thickness -=1, start of check if arms thickness is the same
    jmp .marker_at_top_border_top_loop

.marker_at_top_border_top_loop:
    test eax, eax
    jz .arm_two_right
    cmp eax, DWORD[ebp-16]  ; if top_most_right_x == corner_x jmp to check arm two right_side
    je .arm_two_right
    dec DWORD[ebp-8]    ; marker thickness -=1
    dec eax
    mov DWORD[ebp-12], eax  ; save current x
    mov DWORD[ebp-28], ebx  ; save current y
    jmp .check_arm_two_column_matb

.restore_y:
    mov eax, DWORD[ebp-12]  ; restore x
    mov ebx, DWORD[ebp-28]  ; restore y
    jmp .marker_at_top_border_top_loop

.check_arm_two_column_matb:     ; matb - marker at top border
    cmp ebx, DWORD[ebp-20] 
    je .restore_y ; y==corner_y
    mov eax, DWORD[ebp-12] ; restore x
    call get_pixel
    test eax, eax
    jnz .not_a_marker_2     ; if pixels in column are not black it's not a marker
    dec ebx     ; y-=1
    jmp .check_arm_two_column_matb

.arm_two_top_found:
    ; calculate_height_and_ratio
    mov ecx, ebx ; ecx = current_y
    sub ecx, DWORD[ebp-20] ; height=current_y - corner_y
	imul ecx, 2 ; height * 2
    cmp ecx, DWORD[ebp-24] 
    jne .not_a_marker_2 ; height*2!=width
    dec ebx     ; go back to top black arm two row
    dec DWORD[ebp-8]    ; marker thickness -=1
    jmp .arm_two_top_loop

.arm_two_top_loop:
    mov eax, DWORD[ebp-12] ; restore x
    cmp eax, DWORD[ebp-16] 
    je .arm_two_right ; x == corner_x
    test eax, eax 
    jz .arm_two_right ; x==0
    dec eax
    dec DWORD[ebp-8]    ; marker thickness -=1
    mov DWORD[ebp-12], eax  ; save current x
    mov DWORD[ebp-28], ebx  ; save current y
    jmp .check_arm_two_column

.arm_top_above_pixel:
    mov eax, DWORD[ebp-12]  ; restore x
    mov ebx, DWORD[ebp-28]  ; restore y
    inc ebx ; y+=1
    call get_pixel
    test eax, eax
    jz .not_a_marker_2 ; if pixel above top is black it's not a marker
    dec ebx
    jmp .arm_two_top_loop

.check_arm_two_column:
    cmp ebx, DWORD[ebp-20] 
    je .arm_top_above_pixel ; y==corner_y
    mov eax, DWORD[ebp-12]  ; restore x
    call get_pixel
    test eax, eax
    jnz .not_a_marker_2     ; if pixels in column are not black it's not a marker
    dec ebx
    jmp .check_arm_two_column

.arm_two_right:
    cmp DWORD[ebp-8], 0 ; if thickness after substraction not 0, not_a_marker_2
    jne .not_a_marker_2
    mov DWORD[ebp-12], eax ; save current x
    jmp .arm_two_right_loop

.arm_two_right_loop:
    cmp ebx, DWORD[ebp-20] ; if we reach corner y, marker was found
    je .marker_found
    call get_pixel
    test eax, eax   ; check if arm pixel is black
    jnz .not_a_marker_2
    mov eax, DWORD[ebp-12]  ; restore x
    test eax, eax
    jz .skip_right_check ;   if marker is next to file left border
    
    ; check pixel next to arm two pixel
    dec eax
    call get_pixel
    test eax, eax
    jz .not_a_marker_2
    mov eax, DWORD[ebp-12] ; restore x
    dec ebx
    jmp .arm_two_right_loop

.skip_right_check:
    dec ebx
    jmp .arm_two_right_loop

.marker_found:
    ; add x coordinate to list
    mov esi, DWORD[ebp+12]  ; load pointer to x_positions
    mov ecx, DWORD[ebp-4]   ; load count of markers
    mov DWORD[esi + 4*ecx], eax     ; add x to list

    ; add y coordinate to list
    mov esi, DWORD[ebp+16]  ; load pointer to y_positions

    ; correct y coordinate
    mov edi, DWORD[ebp-32]
    sub edi, ebx    ; HEIGHT - corner_y
    dec edi     ; corrected y coordinate

    mov ecx, DWORD[ebp-4]   ; load count of markers
    mov DWORD[esi + 4*ecx], edi     ; add y to list

    ;increment counter of markers
    inc DWORD[ebp-4]
    
    jmp .not_a_marker_2 ;find new markers

.exit:
    mov eax, DWORD[ebp-4] ; load marker counter to eax

    pop edx
    pop esi
    pop edi
    pop ebx

    mov esp, ebp
    pop ebp
    ret

get_pixel:
; description:
;   returns color of specified pixel
; arguments:
;   eax - x coordinate
;   ebx - y coordinate
; return value:
;   eax - 0RGB - pixel color

    push ebp
    mov ebp, esp

    ;pixel address calculation
    xor ecx, ecx    ; reset ecx
    mov ecx, DWORD[ebp+24]  ; move bytes per row to ecx
    imul ecx, ebx   ; ecx = y*bytes_per_row
    imul eax, 3     ; 3*x
    add ecx, eax    ; ecx += (3x)
    add ecx, edx    ; pixel_address = bitmap_address + (3*x + y * bytes_per_row)

    ;get color
    xor eax, eax ;reset eax
    add al, BYTE[ecx+2] ; load R
    shl eax, 8 ;make space for G
    mov al, BYTE[ecx+1] ; load G
    shl eax, 8 ; make space for B
    mov al, BYTE[ecx] ; load B

    mov esp, ebp
    pop ebp
    ret
