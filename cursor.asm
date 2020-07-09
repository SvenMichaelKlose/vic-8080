.export push_cursor_disable
.export pop_cursor_disable
.export draw_cursor

.import blit_char
.importzp mode, tmp, tmp2
.importzp MODE_XOR

push_cursor_disable:
pop_cursor_disable:
draw_cursor:
    pha
    lda mode
    pha

    lda #MODE_XOR
    sta mode
    lda #<gfx_cursor_normal
    sta tmp
    lda #>gfx_cursor_normal
    sta tmp2
    jsr blit_char

    pla
    sta mode
    pla
    rts

gfx_cursor_normal:
    .byt %1000
    .byt %1000
    .byt %1000
    .byt %1000
    .byt %1000
    .byt %1000
    .byt %1000
    .byt %1000
