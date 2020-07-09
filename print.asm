MODE_OR = 0
MODE_XOR = 1

.export blit_char
.exportzp mode
.exportzp MODE_OR
.exportzp MODE_XOR
.exportzp xpos, xcpos, ypos, scr, scrbase
.exportzp s, tmp

.import push_cursor_disable
.import pop_cursor_disable
.import calcscr
.import moveram
.import __SCREEN_SIZE__

screen_columns = 20
screen_rows = 12
screen_width = screen_columns * 8
screen_height = screen_rows * 16

charset_size = screen_columns * screen_rows * 16

.segment "SCREEN"

    .res $2000 - $120d

.zeropage

s:      .res 2
d:      .res 2
c:      .res 2
tmp:    .res 2
tmp2:   .res 2
tmp3:   .res 2
mode:   .res 1
xpos:   .res 1
xcpos:  .res 1
ypos:   .res 1
scr:    .res 2
scrbase:.res 2

cursor_x:   .res 1
cursor_y:   .res 1

.data

charset:    .incbin "charset-4x8.bin"

.code

.proc print_string
    ldy #0
l:  lda (s),y
    beq +n
    jsr print_ctrl

    inc s
    bne l
    inc s+1
    bne l

n:  rts
.endproc

.proc print_return
    jsr pop_cursor_disable

    pla
    tay
    pla
    tax
    pla
    rts
.endproc

.proc print_ctrl
    sta tmp3
    pha
    txa
    pha
    tya
    pha

    jsr push_cursor_disable

    lda tmp3
    beq print_return
    cmp #10
    bne l
    jmp next_line

print:
    sta tmp3
    pha
    txa
    pha
    tya
    pha

    jsr push_cursor_disable

l:  lda tmp3
    jsr draw_char

    inc cursor_x
    lda cursor_x
    cmp #screen_width / 4
    bne n

next_line:
    lda #0
    sta cursor_x

    lda cursor_y
    cmp #(screen_height / 8) - 1
    bne l2
    jsr scroll_up
    jmp n

l2: inc cursor_y
n:  jmp print_return

scroll_up:
    lda s
    pha
    lda s+1
    pha

    lda #<(charset + 8)
    sta s
    lda #<charset
    sta d
    lda #>charset
    sta s+1
    sta d+1
    lda #<(charset_size - 8)
    sta c
    lda #>(charset_size - 8)
    sta c+1
    lda #0
    jsr moveram

last_screen_row = charset + screen_height - 8
    lda #<last_screen_row
    sta s
    lda #>last_screen_row
    sta s+1

    ldx #screen_columns
m:  ldy #7
    lda #0
l3: sta (s),y
    dey
    bpl l3

    lda s
    clc
    adc #screen_height
    sta s
    bcc n2
    inc s+1
n2: dex
    bne m

    pla
    sta s+1
    pla
    sta s

    rts
.endproc

.proc draw_char
    ldy #0
    sty tmp2
    asl
    rol tmp2
    asl
    rol tmp2
    asl
    rol tmp2
    sta tmp
    lda tmp2
    ora #$20
    sta tmp2

    rts
.endproc

.proc blit_char
    lda cursor_x
    asl
    asl
    sta xpos
    lda cursor_y
    asl
    asl
    asl
    sta ypos
    jsr calcscr

    lda mode
    bne xor_mode

    lda cursor_x
    lsr
    bcs +n

    ldy #7
l:  lda (tmp),y
    asl
    asl
    asl
    asl
    ora (scr),y
    sta (scr),y
    dey
    bpl l
    bmi m

n:  ldy #7
l2: lda (tmp),y
    ora (scr),y
    sta (scr),y
    dey
    bpl l2
    bmi m

xor_mode:
    lda cursor_x
    lsr
    bcs n4

    ldy #7
l3: lda (tmp),y
    asl
    asl
    asl
    asl
    eor (scr),y
    sta (scr),y
    dey
    bpl l3
    bmi m

n4: ldy #7
l4: lda (tmp),y
    eor (scr),y
    sta (scr),y
    dey
    bpl l4

m:  rts
.endproc
