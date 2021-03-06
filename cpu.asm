; 8080 emulator based on https://github.com/superzazu/8080
;
; Copyright (c) 2020-2021 Sven Michael Klose pixel@hugbox.org

.export _cpu_init

.export _reg_a = accu
.export _reg_b = b
.export _reg_c = c
.export _reg_d = d
.export _reg_e = e
.export _reg_h = h
.export _reg_l = l
.export _reg_bc = b
.export _reg_de = d
.export _reg_hl = h
.export _reg_pc = pc
.export _reg_sp = sp

.exportzp accu, b, c, d, e, h, l

FLAG_S  = $80
FLAG_Z  = $40
FLAG_H  = $10
FLAG_P  = $04
FLAG_1  = $02   ; Always 1.
FLAG_C  = $01
 
.zeropage

tmpptr:     .res 2  ; Must occupy $0000 to make unconditional branches work.

v:          .res 2
daa_correction:
tmp:        .res 1
tmp2:       .res 1
daa_lsb:    .res 1
daa_msb:    .res 1

register_start:
pc:         .res 2
accu:       .res 1
flags:      .res 1
bc:
b:          .res 1
c:          .res 1
de:
d:          .res 1
e:          .res 1
hl:
h:          .res 1
l:          .res 1
sp:         .res 2
flag_i:     .res 1
first_register_end:

second_register_start:
accu_:      .res 1
flags_:     .res 1
            .res 8
second_register_end:

ptr:        .res 2  ; Shadow PC pointing to BLK3.
register_end:


.bss

static_flags:   .res 256


.data

bits:
    .byt %00000001
    .byt %00000010
    .byt %00000100
    .byt %00001000
    .byt %00010000
    .byt %00100000
    .byt %01000000
    .byt %10000000

bitmasks:
    .byt %11111110
    .byt %11111101
    .byt %11111011
    .byt %11110111
    .byt %11101111
    .byt %11011111
    .byt %10111111
    .byt %01111111

opcodes_l:
    .byte <op_00, <op_01, <op_02, <op_03, <op_04, <op_05, <op_06, <op_07, <op_08, <op_09, <op_0a, <op_0b, <op_0c, <op_0d, <op_0e, <op_0f, <op_10, <op_11, <op_12, <op_13, <op_14, <op_15, <op_16, <op_17, <op_18, <op_19, <op_1a, <op_1b, <op_1c, <op_1d, <op_1e, <op_1f, <op_20, <op_21, <op_22, <op_23, <op_24, <op_25, <op_26, <op_27, <op_28, <op_29, <op_2a, <op_2b, <op_2c, <op_2d, <op_2e, <op_2f, <op_30, <op_31, <op_32, <op_33, <op_34, <op_35, <op_36, <op_37, <op_38, <op_39, <op_3a, <op_3b, <op_3c, <op_3d, <op_3e, <op_3f, <op_40, <op_41, <op_42, <op_43, <op_44, <op_45, <op_46, <op_47, <op_48, <op_49, <op_4a, <op_4b, <op_4c, <op_4d, <op_4e, <op_4f, <op_50, <op_51, <op_52, <op_53, <op_54, <op_55, <op_56, <op_57, <op_58, <op_59, <op_5a, <op_5b, <op_5c, <op_5d, <op_5e, <op_5f, <op_60, <op_61, <op_62, <op_63, <op_64, <op_65, <op_66, <op_67, <op_68, <op_69, <op_6a, <op_6b, <op_6c, <op_6d, <op_6e, <op_6f, <op_70, <op_71, <op_72, <op_73, <op_74, <op_75, <op_76, <op_77, <op_78, <op_79, <op_7a, <op_7b, <op_7c, <op_7d, <op_7e, <op_7f, <op_80, <op_81, <op_82, <op_83, <op_84, <op_85, <op_86, <op_87, <op_88, <op_89, <op_8a, <op_8b, <op_8c, <op_8d, <op_8e, <op_8f, <op_90, <op_91, <op_92, <op_93, <op_94, <op_95, <op_96, <op_97, <op_98, <op_99, <op_9a, <op_9b, <op_9c, <op_9d, <op_9e, <op_9f, <op_a0, <op_a1, <op_a2, <op_a3, <op_a4, <op_a5, <op_a6, <op_a7, <op_a8, <op_a9, <op_aa, <op_ab, <op_ac, <op_ad, <op_ae, <op_af, <op_b0, <op_b1, <op_b2, <op_b3, <op_b4, <op_b5, <op_b6, <op_b7, <op_b8, <op_b9, <op_ba, <op_bb, <op_bc, <op_bd, <op_be, <op_bf, <op_c0, <op_c1, <op_c2, <op_c3, <op_c4, <op_c5, <op_c6, <op_c7, <op_c8, <op_c9, <op_ca, <op_cb, <op_cc, <op_cd, <op_ce, <op_cf, <op_d0, <op_d1, <op_d2, <op_d3, <op_d4, <op_d5, <op_d6, <op_d7, <op_d8, <op_d9, <op_da, <op_db, <op_dc, <op_dd, <op_de, <op_df, <op_e0, <op_e1, <op_e2, <op_e3, <op_e4, <op_e5, <op_e6, <op_e7, <op_e8, <op_e9, <op_ea, <op_eb, <op_ec, <op_ed, <op_ee, <op_ef, <op_f0, <op_f1, <op_f2, <op_f3, <op_f4, <op_f5, <op_f6, <op_f7, <op_f8, <op_f9, <op_fa, <op_fb, <op_fc, <op_fd, <op_fe, <op_ff
opcodes_h:
    .byte >op_00, >op_01, >op_02, >op_03, >op_04, >op_05, >op_06, >op_07, >op_08, >op_09, >op_0a, >op_0b, >op_0c, >op_0d, >op_0e, >op_0f, >op_10, >op_11, >op_12, >op_13, >op_14, >op_15, >op_16, >op_17, >op_18, >op_19, >op_1a, >op_1b, >op_1c, >op_1d, >op_1e, >op_1f, >op_20, >op_21, >op_22, >op_23, >op_24, >op_25, >op_26, >op_27, >op_28, >op_29, >op_2a, >op_2b, >op_2c, >op_2d, >op_2e, >op_2f, >op_30, >op_31, >op_32, >op_33, >op_34, >op_35, >op_36, >op_37, >op_38, >op_39, >op_3a, >op_3b, >op_3c, >op_3d, >op_3e, >op_3f, >op_40, >op_41, >op_42, >op_43, >op_44, >op_45, >op_46, >op_47, >op_48, >op_49, >op_4a, >op_4b, >op_4c, >op_4d, >op_4e, >op_4f, >op_50, >op_51, >op_52, >op_53, >op_54, >op_55, >op_56, >op_57, >op_58, >op_59, >op_5a, >op_5b, >op_5c, >op_5d, >op_5e, >op_5f, >op_60, >op_61, >op_62, >op_63, >op_64, >op_65, >op_66, >op_67, >op_68, >op_69, >op_6a, >op_6b, >op_6c, >op_6d, >op_6e, >op_6f, >op_70, >op_71, >op_72, >op_73, >op_74, >op_75, >op_76, >op_77, >op_78, >op_79, >op_7a, >op_7b, >op_7c, >op_7d, >op_7e, >op_7f, >op_80, >op_81, >op_82, >op_83, >op_84, >op_85, >op_86, >op_87, >op_88, >op_89, >op_8a, >op_8b, >op_8c, >op_8d, >op_8e, >op_8f, >op_90, >op_91, >op_92, >op_93, >op_94, >op_95, >op_96, >op_97, >op_98, >op_99, >op_9a, >op_9b, >op_9c, >op_9d, >op_9e, >op_9f, >op_a0, >op_a1, >op_a2, >op_a3, >op_a4, >op_a5, >op_a6, >op_a7, >op_a8, >op_a9, >op_aa, >op_ab, >op_ac, >op_ad, >op_ae, >op_af, >op_b0, >op_b1, >op_b2, >op_b3, >op_b4, >op_b5, >op_b6, >op_b7, >op_b8, >op_b9, >op_ba, >op_bb, >op_bc, >op_bd, >op_be, >op_bf, >op_c0, >op_c1, >op_c2, >op_c3, >op_c4, >op_c5, >op_c6, >op_c7, >op_c8, >op_c9, >op_ca, >op_cb, >op_cc, >op_cd, >op_ce, >op_cf, >op_d0, >op_d1, >op_d2, >op_d3, >op_d4, >op_d5, >op_d6, >op_d7, >op_d8, >op_d9, >op_da, >op_db, >op_dc, >op_dd, >op_de, >op_df, >op_e0, >op_e1, >op_e2, >op_e3, >op_e4, >op_e5, >op_e6, >op_e7, >op_e8, >op_e9, >op_ea, >op_eb, >op_ec, >op_ed, >op_ee, >op_ef, >op_f0, >op_f1, >op_f2, >op_f3, >op_f4, >op_f5, >op_f6, >op_f7, >op_f8, >op_f9, >op_fa, >op_fb, >op_fc, >op_fd, >op_fe, >op_ff


.code

; Execute next instruction.
.proc next
    jsr fetch_byte
    tax
    lda opcodes_l,x
    pha
    lda opcodes_h,x
    pha
    rts
.endproc

.proc next_rebanked
    rts
.endproc

; Faster version of 'next' to be placed on the zero page.
.proc next_zp
ptr:
    ldx 12345

    inc ptr+1
    inc pc
    beq n1

jump:
    lda opcodes_l,x
    sta trampoline+1
    lda opcodes_h,x
    sta trampoline+2

trampoline:
    jmp 1234

n1: inc pc+1
    inc ptr+1
    bpl jump
    jmp rebank_pc
.endproc


; #####################
; ### MEMORY ACCESS ###
; #####################

; Fetch next code byte.
.proc fetch_byte
    ldy #0
    lda (ptr),y

    inc ptr
    inc pc
    beq n1
    rts

n1: inc pc+1
    inc ptr+1
    bmi rebank_pc
    rts
.endproc

.proc rebank_pc
    pha
    lda pc
    sta ptr
    lda pc+1
    lsr
    lsr
    lsr
    sta $9ffc
    lda pc+1
    and #%00000111
    ora #$60
    sta ptr+1
    pla
    rts
.endproc

.proc rebank_pc_zp
    lda pc
    sta ptr
    lda pc+1
    lsr
    lsr
    lsr
    sta $9ffc
    lda pc+1
    and #%00000111
    ora #$60
    sta ptr+1
    ;jmp jump
.endproc

; Fetch code word and store it in 'v'.
.proc fetch_word
    jsr fetch_byte
    sta v
    jsr fetch_byte
    sta v+1
    rts
.endproc

; Fetch code word and store it in address X.
.proc fetch_word_x
    jsr fetch_byte
    sta 0,x
    jsr fetch_byte
    sta 1,x
    rts
.endproc

; Read byte from emulated memory.
;
; In:
;   X: Zero page vector with the address to read.
; Out:
;   A: Read byte.
.proc read_byte
    lda 1,x
    lsr
    lsr
    lsr
    sta $9ffc
    lda 1,x
    and #%00000111
    ora #$60
    sta tmpptr+1
    lda 0,x
    sta tmpptr

    ldy #0
    lda (tmpptr),y
    rts
.endproc

; X: Zero page vector with the address to read.
;
; v: Read word.
.proc read_word
    jsr read_byte
    sta v
    lda 0,x
    sta tmp
    lda 1,x
    sta tmp2
    inc 0,x
    beq n

l1: jsr read_byte
    sta v+1
    lda tmp
    sta 0,x
    lda tmp2
    sta 1,x
    rts

n:  inc 1,x
    jmp l1
.endproc

.proc write_byte
    pha
    lda 1,x
    lsr
    lsr
    lsr
    sta $9ffc
    lda 1,x
    and #%00000111
    ora #$60
    sta tmpptr+1
    lda 0,x
    sta tmpptr

    ldy #0
    pla
    sta (tmpptr),y
    rts
.endproc

.proc write_word_call
    lda 0,x
    sta tmp
    lda 1,x
    sta tmp+1

    lda v
    jsr write_byte

    inc tmp
    bne l1
    inc tmp+1
l1: lda v+1
    ldx #tmp
    jmp write_byte
.endproc

.proc write_word
    jsr write_word_call
    jmp next
.endproc

; #############
; ### FLAGS ###
; #############

.proc get_flags
    lda flags
    and #(FLAG_Z + FLAG_S + FLAG_P) ^ $ff
    ldy v
    ora static_flags,y
    sta flags
    jmp next
.endproc

.proc get_logic_flags
    lda flags
    and #(FLAG_Z | FLAG_S | FLAG_P | FLAG_C | FLAG_H) ^ $ff
    ldy v
    ora static_flags,y
    sta flags
    jmp next
.endproc

.proc set_halfcarry
    sta tmp
    lda flags
    and #FLAG_H ^ $ff
    ldx tmp
    bne n
    ora #FLAG_H
n:  sta flags
    rts
.endproc

.proc set_halfcarry_inv
    jsr set_halfcarry
    lda flags
    eor #FLAG_H ^ $ff
    sta flags
    rts
.endproc

;case 0x00: break; // NOP
;// undocumented NOPs
;case 0x08:
;case 0x10: case 0x18:
;case 0x20: case 0x28:
;case 0x30: case 0x38:
;break;
.proc op_00
    rts
.endproc

; Z80: EX AF,AF'
.proc op_08
    lda accu
    ldx accu_
    stx accu
    ldx accu_
    lda flags
    ldx flags_
    stx flags
    ldx flags_
    jmp next
.endproc

; Z80: DJNZ
.proc op_10
    jsr fetch_byte

    dec b
    bne relative_jump

n2: jmp next
.endproc

; Z80: JR
.proc op_18
    jsr fetch_byte
.endproc

.proc relative_jump
    ; Convert byte to word.
    sta tmp
    ldx #0
    stx tmp+1
    cmp #0
    bpl n2
    dec tmp+1

    ; Add to PC.
n2: lda pc
    clc
    adc tmp
    sta pc
    lda pc+1
    adc tmp+1
    sta pc+1
    jmp next_rebanked
.endproc

; A: The flag on which to jump.
.proc cond_relative_jump
    and flags
    beq n
    jsr fetch_byte
    bne relative_jump   ; (jmp)
n:  jsr fetch_byte
    jmp next
.endproc

; A: The flag on which not to jump.
.proc cond_relative_jump_inv
    and flags
    bne n
    jsr fetch_byte
    bne relative_jump  ; (jmp)
n:  jsr fetch_byte
    jmp next
.endproc

; JR NZ,p
.proc op_20
    lda #FLAG_Z
    bne cond_relative_jump_inv  ; (jmp)
.endproc

; JR Z
.proc op_28
    lda #FLAG_Z
    bne cond_relative_jump      ; (jmp)
.endproc

; JR NC,p
.proc op_30
    lda #FLAG_C
    bne cond_relative_jump_inv  ; (jmp)
.endproc

; JR C,p
.proc op_38
    lda #FLAG_C
    bne cond_relative_jump      ; (jmp)
.endproc

;case 0x76: c->halted = 1; break; // HLT
.proc op_76
    jmp op_76
.endproc

; #################################
; ## 8 bit transfer instructions ##
; #################################

; #########
; ## MOV ##
; #########

;case 0x7F: c->a = c->a; break; // MOV A,A
op_7f = op_00

;case 0x78: c->a = c->b; break; // MOV A,B
.proc op_78
    lda b
    sta accu
    jmp next
.endproc

;case 0x79: c->a = c->c; break; // MOV A,C
.proc op_79
    lda c
    sta accu
    jmp next
.endproc

;case 0x7A: c->a = c->d; break; // MOV A,D
.proc op_7a
    lda d
    sta accu
    jmp next
.endproc

;case 0x7B: c->a = c->e; break; // MOV A,E
.proc op_7b
    lda e
    sta accu
    jmp next
.endproc

;case 0x7C: c->a = c->h; break; // MOV A,H
.proc op_7c
    lda h
    sta accu
    jmp next
.endproc

;case 0x7D: c->a = c->l; break; // MOV A,L
.proc op_7d
    lda l
    sta accu
    jmp next
.endproc

;case 0x7E: c->a = i8080_rb(c, i8080_get_hl(c)); break; // MOV A,M
.proc op_7e
    ldx #hl
    jsr read_byte
    sta accu
    jmp next
.endproc

;case 0x47: c->b = c->a; break; // MOV B,A
.proc op_47
    lda accu
    sta b
    jmp next
.endproc

;case 0x40: c->b = c->b; break; // MOV B,B
op_40 = op_00

;case 0x41: c->b = c->c; break; // MOV B,C
.proc op_41
    lda c
    sta b
    jmp next
.endproc
;case 0x42: c->b = c->d; break; // MOV B,D
.proc op_42
    lda d
    sta b
    jmp next
.endproc
;case 0x43: c->b = c->e; break; // MOV B,E
.proc op_43
    lda e
    sta b
    jmp next
.endproc
;case 0x44: c->b = c->h; break; // MOV B,H
.proc op_44
    lda h
    sta b
    jmp next
.endproc
;case 0x45: c->b = c->l; break; // MOV B,L
.proc op_45
    lda l
    sta b
    jmp next
.endproc
;case 0x46: c->b = i8080_rb(c, i8080_get_hl(c)); break; // MOV B,M
.proc op_46
    ldx #hl
    jsr read_byte
    sta b
    jmp next
.endproc


;case 0x4F: c->c = c->a; break; // MOV C,A
.proc op_4f
    lda accu
    sta c
    jmp next
.endproc

;case 0x48: c->c = c->b; break; // MOV C,B
.proc op_48
    lda b
    sta c
    jmp next
.endproc

;case 0x49: c->c = c->c; break; // MOV C,C
op_49 = op_00

;case 0x4A: c->c = c->d; break; // MOV C,D
.proc op_4a
    lda d
    sta c
    jmp next
.endproc

;case 0x4B: c->c = c->e; break; // MOV C,E
.proc op_4b
    lda e
    sta c
    jmp next
.endproc

;case 0x4C: c->c = c->h; break; // MOV C,H
.proc op_4c
    lda h
    sta c
    jmp next
.endproc

;case 0x4D: c->c = c->l; break; // MOV C,L
.proc op_4d
    lda l
    sta c
    jmp next
.endproc

;case 0x4E: c->c = i8080_rb(c, i8080_get_hl(c)); break; // MOV C,M
.proc op_4e
    ldx #hl
    jsr read_byte
    sta c
    jmp next
.endproc

;case 0x57: c->d = c->a; break; // MOV D,A
.proc op_57
    lda accu
    sta d
    jmp next
.endproc

;case 0x50: c->d = c->b; break; // MOV D,B
.proc op_50
    lda b
    sta d
    jmp next
.endproc

;case 0x51: c->d = c->c; break; // MOV D,C
.proc op_51
    lda c
    sta d
    jmp next
.endproc

;case 0x52: c->d = c->d; break; // MOV D,D
op_52 = op_00

;case 0x53: c->d = c->e; break; // MOV D,E
.proc op_53
    lda e
    sta d
    jmp next
.endproc

;case 0x54: c->d = c->h; break; // MOV D,H
.proc op_54
    lda h
    sta d
    jmp next
.endproc

;case 0x55: c->d = c->l; break; // MOV D,L
.proc op_55
    lda l
    sta d
    jmp next
.endproc

;case 0x56: c->d = i8080_rb(c, i8080_get_hl(c)); break; // MOV D,M
.proc op_56
    ldx #hl
    jsr read_byte
    sta d
    jmp next
.endproc

;case 0x5F: c->e = c->a; break; // MOV E,A
.proc op_5f
    lda accu
    sta e
    jmp next
.endproc

;case 0x58: c->e = c->b; break; // MOV E,B
.proc op_58
    lda b
    sta e
    jmp next
.endproc

;case 0x59: c->e = c->c; break; // MOV E,C
.proc op_59
    lda c
    sta e
    jmp next
.endproc

;case 0x5A: c->e = c->d; break; // MOV E,D
.proc op_5a
    lda d
    sta e
    jmp next
.endproc

;case 0x5B: c->e = c->e; break; // MOV E,E
op_5b = op_00

;case 0x5C: c->e = c->h; break; // MOV E,H
.proc op_5c
    lda h
    sta e
    jmp next
.endproc

;case 0x5D: c->e = c->l; break; // MOV E,L
.proc op_5d
    lda l
    sta e
    jmp next
.endproc

;case 0x5E: c->e = i8080_rb(c, i8080_get_hl(c)); break; // MOV E,M
.proc op_5e
    ldx #hl
    jsr read_byte
    sta e
    jmp next
.endproc

;case 0x67: c->h = c->a; break; // MOV H,A
.proc op_67
    lda accu
    sta h
    jmp next
.endproc

;case 0x60: c->h = c->b; break; // MOV H,B
.proc op_60
    lda b
    sta h
    jmp next
.endproc

;case 0x61: c->h = c->c; break; // MOV H,C
.proc op_61
    lda c
    sta h
    jmp next
.endproc

;case 0x62: c->h = c->d; break; // MOV H,D
.proc op_62
    lda d
    sta h
    jmp next
.endproc

;case 0x63: c->h = c->e; break; // MOV H,E
.proc op_63
    lda e
    sta h
    jmp next
.endproc

;case 0x64: c->h = c->h; break; // MOV H,H
op_64 = op_00

;case 0x65: c->h = c->l; break; // MOV H,L
.proc op_65
    lda l
    sta h
    jmp next
.endproc

;case 0x66: c->h = i8080_rb(c, i8080_get_hl(c)); break; // MOV H,M
.proc op_66
    ldx #hl
    jsr read_byte
    sta h
    jmp next
.endproc

;case 0x6F: c->l = c->a; break; // MOV L,A
.proc op_6f
    lda accu
    sta l
    jmp next
.endproc

;case 0x68: c->l = c->b; break; // MOV L,B
.proc op_68
    lda b
    sta l
    jmp next
.endproc

;case 0x69: c->l = c->c; break; // MOV L,C
.proc op_69
    lda c
    sta l
    jmp next
.endproc

;case 0x6A: c->l = c->d; break; // MOV L,D
.proc op_6a
    lda d
    sta l
    jmp next
.endproc

;case 0x6B: c->l = c->e; break; // MOV L,E
.proc op_6b
    lda e
    sta l
    jmp next
.endproc

;case 0x6C: c->l = c->h; break; // MOV L,H
.proc op_6c
    lda h
    sta l
    jmp next
.endproc

;case 0x6D: c->l = c->l; break; // MOV L,L
op_6d = op_00

;case 0x6E: c->l = i8080_rb(c, i8080_get_hl(c)); break; // MOV L,M
.proc op_6e
    ldx #hl
    jsr read_byte
    sta l
    jmp next
.endproc

;case 0x77: i8080_wb(c, i8080_get_hl(c), c->a); break; // MOV M,A
.proc op_77
    lda accu
    ldy #hl
    jmp write_byte
.endproc

;case 0x70: i8080_wb(c, i8080_get_hl(c), c->b); break; // MOV M,B
.proc op_70
    lda b
    ldy #hl
    jmp write_byte
.endproc

;case 0x71: i8080_wb(c, i8080_get_hl(c), c->c); break; // MOV M,C
.proc op_71
    lda c
    ldy #hl
    jmp write_byte
.endproc

;case 0x72: i8080_wb(c, i8080_get_hl(c), c->d); break; // MOV M,D
.proc op_72
    lda d
    ldy #hl
    jmp write_byte
.endproc

;case 0x73: i8080_wb(c, i8080_get_hl(c), c->e); break; // MOV M,E
.proc op_73
    lda e
    ldy #hl
    jmp write_byte
.endproc

;case 0x74: i8080_wb(c, i8080_get_hl(c), c->h); break; // MOV M,H
.proc op_74
    lda h
    ldy #hl
    jmp write_byte
.endproc

;case 0x75: i8080_wb(c, i8080_get_hl(c), c->l); break; // MOV M,L
.proc op_75
    lda l
    ldy #hl
    jmp write_byte
.endproc

; ###########
; ### MVI ###
; ###########

;case 0x3E: c->a = i8080_next_byte(c); break; // MVI A,byte
.proc op_3e
    jsr fetch_byte
    sta accu
    jmp next
.endproc

;case 0x06: c->b = i8080_next_byte(c); break; // MVI B,byte
.proc op_06
    jsr fetch_byte
    sta b
    jmp next
.endproc

;case 0x0E: c->c = i8080_next_byte(c); break; // MVI C,byte
.proc op_0e
    jsr fetch_byte
    sta c
    jmp next
.endproc

;case 0x16: c->d = i8080_next_byte(c); break; // MVI D,byte
.proc op_16
    jsr fetch_byte
    sta d
    jmp next
.endproc

;case 0x1E: c->e = i8080_next_byte(c); break; // MVI E,byte
.proc op_1e
    jsr fetch_byte
    sta e
    jmp next
.endproc

;case 0x26: c->h = i8080_next_byte(c); break; // MVI H,byte
.proc op_26
    jsr fetch_byte
    sta h
    jmp next
.endproc

;case 0x2E: c->l = i8080_next_byte(c); break; // MVI L,byte
.proc op_2e
    jsr fetch_byte
    sta l
    jmp next
.endproc

;case 0x36: i8080_wb(c, i8080_get_hl(c), i8080_next_byte(c)); break; // MVI M,byte
.proc op_36
    jsr fetch_byte
    ldy #hl
    jmp write_byte
.endproc

; ##########
; ## LDAX ##
; ##########

;case 0x0A: c->a = i8080_rb(c, i8080_get_bc(c)); break; // LDAX B
.proc op_0a
    ldx #bc
    jsr read_byte
    sta accu
    jmp next
.endproc

;case 0x1A: c->a = i8080_rb(c, i8080_get_de(c)); break; // LDAX D
.proc op_1a
    ldx #de
    jsr read_byte
    sta accu
    jmp next
.endproc


; #########
; ## LDA ##
; #########

;case 0x3A: c->a = i8080_rb(c, i8080_next_word(c)); break; // LDA word
.proc op_3a
    jsr fetch_word
    ldx #v
    jsr read_byte
    sta accu
    jmp next
.endproc


; ##########
; ## STAX ##
; ##########

;case 0x02: i8080_wb(c, i8080_get_bc(c), c->a); break; // STAX B
.proc op_02
    lda accu
    ldy #bc
    jmp write_byte
.endproc

;case 0x12: i8080_wb(c, i8080_get_de(c), c->a); break; // STAX D
.proc op_12
    lda accu
    ldy #de
    jmp write_byte
.endproc


; #########
; ## STA ##
; #########

;case 0x32: i8080_wb(c, i8080_next_word(c), c->a); break; // STA word
.proc op_32
    jsr fetch_word
    lda accu
    ldy #v
    jmp write_byte
.endproc

; #########
; ## LXI ##
; #########

;// 16 bit transfer instructions
;case 0x01: i8080_set_bc(c, i8080_next_word(c)); break; // LXI B,word
.proc op_01
    ldx #bc
    jmp fetch_word_x
.endproc

;case 0x11: i8080_set_de(c, i8080_next_word(c)); break; // LXI D,word
.proc op_11
    ldx #de
    jmp fetch_word_x
.endproc

;case 0x21: i8080_set_hl(c, i8080_next_word(c)); break; // LXI H,word
.proc op_21
    ldx #hl
    jmp fetch_word_x
.endproc

;case 0x31: c->sp = i8080_next_word(c); break; // LXI SP,word
.proc op_31
    ldx #sp
    jmp fetch_word_x
.endproc


; ###############
; ## LDHD/SHLD ##
; ###############

;case 0x2A: i8080_set_hl(c, i8080_rw(c, i8080_next_word(c))); break; // LHLD
.proc op_2a
    jsr fetch_word
    ldx #hl
    jsr read_word
    jmp next
.endproc

;case 0x22: i8080_ww(c, i8080_next_word(c), i8080_get_hl(c)); break; // SHLD
.proc op_22
    jsr fetch_word
    ldx #hl
    jsr write_word
    jmp next
.endproc


; ##########
; ## SPHL ##
; ##########

;case 0xF9: c->sp = i8080_get_hl(c); break; // SPHL
.proc op_f9
    lda l
    sta sp
    lda h
    sta sp+1
    jmp next
.endproc


; ##########
; ## XCHG ##
; ##########

;// register exchange instructions
;case 0xEB: i8080_xchg(c); break; // XCHG
;// switches the value of registers DE and HL
;static inline void i8080_xchg(i8080* const c) {
;    const uint16_t de = i8080_get_de(c);
;    i8080_set_de(c, i8080_get_hl(c));
;    i8080_set_hl(c, de);
;}
.proc op_eb
    lda d
    ldx h
    sta h
    stx d
    lda e
    ldx l
    sta l
    stx e
    jmp next
.endproc


; ##########
; ## XTHL ##
; ##########

;case 0xE3: i8080_xthl(c); break; // XTHL
;// switches the value of a word at (sp) and HL
;static inline void i8080_xthl(i8080* const c) {
;    const uint16_t val = i8080_rw(c, c->sp);
;    i8080_ww(c, c->sp, i8080_get_hl(c));
;    i8080_set_hl(c, val);
;}
.proc op_e3
    ldx #sp
    ldy #v
    jsr read_word
    ldx #sp
    ldy #hl
    jsr write_word_call
    lda v
    sta l
    lda v+1
    sta h
    jmp next
.endproc

;// adds a value (+ an optional carry flag) to a register
;static inline void i8080_add(i8080* const c, uint8_t* const reg, uint8_t val,
;                             bool cy) {
;    const uint8_t result = *reg + val + cy;
;    c->cf = carry(8, *reg, val, cy);
;    c->hf = carry(4, *reg, val, cy);
;    SET_ZSP(c, result);
;    *reg = result;
;}
.proc adr8080
    lda accu
    adc 0,x
    sta accu

    rol flags       ; Copy carry flag

    eor 0,x
    eor v
    and #$04
    asl
    asl
    ora flags
    sta flags
    jmp next
.endproc

.proc add8080
    lsr flags       ; Clear carry flag.
    clc
    bcc adr8080
.endproc


;// add byte instructions
;case 0x87: i8080_add(c, &c->a, c->a, 0); break; // ADD A
.proc op_87
    ldx #accu
    bne add8080
.endproc
    
;case 0x80: i8080_add(c, &c->a, c->b, 0); break; // ADD B
.proc op_80
    ldx #b
    bne add8080
.endproc
    
;case 0x81: i8080_add(c, &c->a, c->c, 0); break; // ADD C
.proc op_81
    ldx #c
    bne add8080
.endproc
    
;case 0x82: i8080_add(c, &c->a, c->d, 0); break; // ADD D
.proc op_82
    ldx #d
    bne add8080
.endproc
    
;case 0x83: i8080_add(c, &c->a, c->e, 0); break; // ADD E
.proc op_83
    ldx #e
    bne add8080
.endproc
    
;case 0x84: i8080_add(c, &c->a, c->h, 0); break; // ADD H
.proc op_84
    ldx #h
    bne add8080
.endproc
    
;case 0x85: i8080_add(c, &c->a, c->l, 0); break; // ADD L
.proc op_85
    ldx #l
    bne add8080
.endproc
    
;case 0x86: i8080_add(c, &c->a, i8080_rb(c, i8080_get_hl(c)), 0); break; // ADD M
.proc op_86
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne add8080
.endproc
    
;case 0xC6: i8080_add(c, &c->a, i8080_next_byte(c), 0); break; // ADI byte
.proc op_c6
    jsr fetch_byte
    ldx #v
    bne add8080
.endproc

.proc adc8080
    lsr flags       ; Get and clear carry flag.
    jmp adr8080
.endproc

;// add byte with carry-in instructions
;case 0x8F: i8080_add(c, &c->a, c->a, c->cf); break; // ADC A
.proc op_8f
    ldx #accu
    bne adc8080
.endproc
    
;case 0x88: i8080_add(c, &c->a, c->b, c->cf); break; // ADC B
.proc op_88
    ldx #b
    bne adc8080
.endproc
    
;case 0x89: i8080_add(c, &c->a, c->c, c->cf); break; // ADC C
.proc op_89
    ldx #c
    bne adc8080
.endproc
    
;case 0x8A: i8080_add(c, &c->a, c->d, c->cf); break; // ADC D
.proc op_8a
    ldx #d
    bne adc8080
.endproc
    
;case 0x8B: i8080_add(c, &c->a, c->e, c->cf); break; // ADC E
.proc op_8b
    ldx #e
    bne adc8080
.endproc
    
;case 0x8C: i8080_add(c, &c->a, c->h, c->cf); break; // ADC H
.proc op_8c
    ldx #h
    bne adc8080
.endproc
    
;case 0x8D: i8080_add(c, &c->a, c->l, c->cf); break; // ADC L
.proc op_8d
    ldx #l
    bne adc8080
.endproc

;case 0x8E: i8080_add(c, &c->a, i8080_rb(c, i8080_get_hl(c)), c->cf); break; // ADC M
.proc op_8e
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne adc8080
.endproc
    
;case 0xCE: i8080_add(c, &c->a, i8080_next_byte(c), c->cf); break; // ACI byte
.proc op_ce
    jsr fetch_byte
    ldx #v
    bne adc8080
.endproc

.proc sbr8080
    lda accu
    sbc 0,x
    sta accu

    rol flags       ; Copy carry flag

    eor 0,x
    eor v
    and #$04
    asl
    asl
    ora flags
    sta flags
    jmp next
.endproc

.proc sub8080
    lsr flags       ; Clear carry flag.
    sec
    bcs sbr8080
.endproc

;// substract byte instructions
;case 0x97: i8080_sub(c, &c->a, c->a, 0); break; // SUB A
.proc op_97
    ldx #accu
    bne sub8080
.endproc
    
;case 0x90: i8080_sub(c, &c->a, c->b, 0); break; // SUB B
.proc op_90
    ldx #b
    bne sub8080
.endproc
    
;case 0x91: i8080_sub(c, &c->a, c->c, 0); break; // SUB C
.proc op_91
    ldx #c
    bne sub8080
.endproc
    
;case 0x92: i8080_sub(c, &c->a, c->d, 0); break; // SUB D
.proc op_92
    ldx #d
    bne sub8080
.endproc
    
;case 0x93: i8080_sub(c, &c->a, c->e, 0); break; // SUB E
.proc op_93
    ldx #e
    bne sub8080
.endproc
    
;case 0x94: i8080_sub(c, &c->a, c->h, 0); break; // SUB H
.proc op_94
    ldx #h
    bne sub8080
.endproc
    
;case 0x95: i8080_sub(c, &c->a, c->l, 0); break; // SUB L
.proc op_95
    ldx #l
    bne sub8080
.endproc
    
;case 0x96: i8080_sub(c, &c->a, i8080_rb(c, i8080_get_hl(c)), 0); break; // SUB M
.proc op_96
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne sub8080
.endproc
    
;case 0xD6: i8080_sub(c, &c->a, i8080_next_byte(c), 0); break; // SUI byte
.proc op_d6
    jsr fetch_byte
    ldx #v
    bne sub8080
.endproc

.proc sbb8080
    lsr flags       ; Get and clear carry flag.
    jmp sbr8080
.endproc

;// substract byte with borrow-in instructions
;case 0x9F: i8080_sub(c, &c->a, c->a, c->cf); break; // SBB A
.proc op_9f
    ldx #accu
    bne sbb8080
.endproc
    
;case 0x98: i8080_sub(c, &c->a, c->b, c->cf); break; // SBB B
.proc op_98
    ldx #b
    bne sbb8080
.endproc
    
;case 0x99: i8080_sub(c, &c->a, c->c, c->cf); break; // SBB C
.proc op_99
    ldx #c
    bne sbb8080
.endproc
    
;case 0x9A: i8080_sub(c, &c->a, c->d, c->cf); break; // SBB D
.proc op_9a
    ldx #d
    bne sbb8080
.endproc
    
;case 0x9B: i8080_sub(c, &c->a, c->e, c->cf); break; // SBB E
.proc op_9b
    ldx #e
    bne sbb8080
.endproc
    
;case 0x9C: i8080_sub(c, &c->a, c->h, c->cf); break; // SBB H
.proc op_9c
    ldx #h
    bne sbb8080
.endproc
    
;case 0x9D: i8080_sub(c, &c->a, c->l, c->cf); break; // SBB L
.proc op_9d
    ldx #l
    bne sbb8080
.endproc
    
;case 0x9E: i8080_sub(c, &c->a, i8080_rb(c, i8080_get_hl(c)), c->cf); break; // SBB M
.proc op_9e
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne sbb8080
.endproc

;case 0xDE: i8080_sub(c, &c->a, i8080_next_byte(c), c->cf); break; // SBI byte
.proc op_de
    jsr fetch_byte
    ldx #v
    bne sbb8080
.endproc

; // adds a word to HL
; static inline void i8080_dad(i8080* const c, uint16_t val) {
;     c->cf = ((i8080_get_hl(c) + val) >> 16) & 1;
;     i8080_set_hl(c, i8080_get_hl(c) + val);
; }
; Add word register to HL.
.proc dad
    lsr flags
    clc
    lda l
    adc 0,x
    sta l
    lda h
    adc 1,x
    sta h
    rol flags
    jmp next
.endproc

;// double byte add instructions
;case 0x09: i8080_dad(c, i8080_get_bc(c)); break; // DAD B
.proc op_09
    ldx #bc
    bne dad
.endproc
    
;case 0x19: i8080_dad(c, i8080_get_de(c)); break; // DAD D
.proc op_19
    ldx #de
    bne dad
.endproc
    
;case 0x29: i8080_dad(c, i8080_get_hl(c)); break; // DAD H
.proc op_29
    ldx #hl
    bne dad
.endproc
    
;case 0x39: i8080_dad(c, c->sp); break; // DAD SP
.proc op_39
    ldx #sp
    bne dad
.endproc


; ################
; ## INTERRUPTS ##
; ################

;case 0xF3: c->iff = 0; break; // DI
.proc op_f3
    lda #1
    sta flag_i
    jmp next
.endproc

;case 0xFB: c->iff = 1; c->interrupt_delay = 1; break; // EI
.proc op_fb
    lda #0
    sta flag_i
    jmp next
.endproc

; ###########################
; ## INCREMENT / DECREMENT ##
; ###########################

; // increments a byte
; static inline uint8_t i8080_inr(i8080* const c, uint8_t val) {
;     const uint8_t result = val + 1;
;     c->hf = (result & 0xF) == 0;
;     SET_ZSP(c, result);
;     return result;
; }
.proc inr
    inc 0,x
    lda 0,x
    sta v
    and #$0f
    jsr set_halfcarry_inv
    jmp get_flags
.endproc

;// increment byte instructions
;case 0x3C: c->a = i8080_inr(c, c->a); break; // INR A
.proc op_3c
    ldx #accu
    bne inr
.endproc

;case 0x04: c->b = i8080_inr(c, c->b); break; // INR B
.proc op_04
    ldx #b
    bne inr
.endproc
    
;case 0x0C: c->c = i8080_inr(c, c->c); break; // INR C
.proc op_0c
    ldx #c
    bne inr
.endproc
    
;case 0x14: c->d = i8080_inr(c, c->d); break; // INR D
.proc op_14
    ldx #d
    bne inr
.endproc
    
;case 0x1C: c->e = i8080_inr(c, c->e); break; // INR E
.proc op_1c
    ldx #e
    bne inr
.endproc
    
;case 0x24: c->h = i8080_inr(c, c->h); break; // INR H
.proc op_24
    ldx #h
    bne inr
.endproc
    
;case 0x2C: c->l = i8080_inr(c, c->l); break; // INR L
.proc op_2c
    ldx #l
    bne inr
.endproc

;case 0x34: i8080_wb(c, i8080_get_hl(c), i8080_inr(c, i8080_rb(c, i8080_get_hl(c)))); break; // INR M
.proc op_34
    ldy #hl
    ldx #v
    jsr read_word
    inc v
    ldy #hl
    ldx #v
    jsr write_word
    lda v
    and #$0f
    jsr set_halfcarry_inv
    jmp get_flags
.endproc

; // decrements a byte
; static inline uint8_t i8080_dcr(i8080* const c, uint8_t val) {
;     const uint8_t result = val - 1;
;     c->hf = !((result & 0xF) == 0xF);
;     SET_ZSP(c, result);
;     return result;
; }
.proc dcr
    dec 0,x
    lda 0,x
    sta v
    and #$0f
    cmp #$0f
    jsr set_halfcarry
    jmp get_flags
.endproc

;// decrement byte instructions
;case 0x3D: c->a = i8080_dcr(c, c->a); break; // DCR A
.proc op_3d
    ldx #accu
    bne dcr
.endproc
    
;case 0x05: c->b = i8080_dcr(c, c->b); break; // DCR B
.proc op_05
    ldx #b
    bne dcr
.endproc
    
;case 0x0D: c->c = i8080_dcr(c, c->c); break; // DCR C
.proc op_0d
    ldx #c
    bne dcr
.endproc
    
;case 0x15: c->d = i8080_dcr(c, c->d); break; // DCR D
.proc op_15
    ldx #d
    bne dcr
.endproc
    
;case 0x1D: c->e = i8080_dcr(c, c->e); break; // DCR E
.proc op_1d
    ldx #e
    bne dcr
.endproc
    
;case 0x25: c->h = i8080_dcr(c, c->h); break; // DCR H
.proc op_25
    ldx #h
    bne dcr
.endproc
    
;case 0x2D: c->l = i8080_dcr(c, c->l); break; // DCR L
.proc op_2d
    ldx #l
    bne dcr
.endproc
    
;case 0x35: i8080_wb(c, i8080_get_hl(c), i8080_dcr(c, i8080_rb(c, i8080_get_hl(c)))); break; // DCR M
.proc op_35
    ldx #hl
    jsr read_byte
    sta v
    dec v
    ldy #v
    jsr write_byte
    lda v
    and #$0f
    cmp #$0f
    jsr set_halfcarry
    jmp get_flags
.endproc

;// increment register pair instructions
;case 0x03: i8080_set_bc(c, i8080_get_bc(c) + 1); break; // INX B
.proc op_03
    inc c
    beq n
    jmp next
n:  inc b
    jmp next
.endproc
    
;case 0x13: i8080_set_de(c, i8080_get_de(c) + 1); break; // INX D
.proc op_13
    inc e
    beq n
    jmp next
n:  inc d
    jmp next
.endproc
    
;case 0x23: i8080_set_hl(c, i8080_get_hl(c) + 1); break; // INX H
.proc op_23
    inc l
    beq n
    jmp next
n:  inc h
    jmp next
.endproc
    
;case 0x33: c->sp += 1; break; // INX SP
.proc op_33
    inc sp
    beq n
    jmp next
n:  inc sp+1
    jmp next
.endproc

;// decrement register pair instructions
;case 0x0B: i8080_set_bc(c, i8080_get_bc(c) - 1); break; // DCX B
.proc op_0b
    sec
    lda c
    sbc #1
    sta c
    lda b
    sbc #0
    sta b
    jmp next
.endproc
    
;case 0x1B: i8080_set_de(c, i8080_get_de(c) - 1); break; // DCX D
.proc op_1b
    sec
    lda e
    sbc #1
    sta e
    lda d
    sbc #0
    sta d
    jmp next
.endproc
    
;case 0x2B: i8080_set_hl(c, i8080_get_hl(c) - 1); break; // DCX H
.proc op_2b
    sec
    lda l
    sbc #1
    sta l
    lda h
    sbc #0
    sta h
    jmp next
.endproc
    
;case 0x3B: c->sp -= 1; break; // DCX SP
.proc op_3b
    sec
    lda sp
    sbc #1
    sta sp
    lda sp+1
    sbc #0
    sta sp+1
    jmp next
.endproc

;// special accumulator and flag instructions
;case 0x27: i8080_daa(c); break; // DAA
;// Decimal Adjust Accumulator: the eight-bit number in register A is adjusted
;// to form two four-bit binary-coded-decimal digits.
;// For example, if A=$2B and DAA is executed, A becomes $31.
;static inline void i8080_daa(i8080* const c) {
;    bool cy = c->cf;
;    uint8_t correction = 0;
;
;    const uint8_t lsb = c->a & 0x0F;
;    const uint8_t msb = c->a >> 4;
;
;    if (c->hf || lsb > 9) {
;        correction += 0x06;
;    }
;    if (c->cf || msb > 9 || (msb >= 9 && lsb > 9)) {
;        correction += 0x60;
;        cy = 1;
;    }
;    i8080_add(c, &c->a, correction, 0);
;    c->cf = cy;
;}
.proc op_27
    lda #0
    sta daa_correction
    lda accu
    and #$0f
    sta daa_lsb
    lda accu
    lsr
    lsr
    lsr
    lsr
    sta daa_msb

    lda flags
    and #FLAG_H
    bne n1
    lda daa_lsb
    cmp #9
    bcc n2
n1: lda #$06
    sta daa_correction

n2: lda flags
    and #FLAG_C
    bne n3
    lda daa_msb
    cmp #9
    bcs n3
    bne n4
n3: lda daa_correction
    ora #$60
    sta daa_correction

n4: clc
    lda accu
    adc daa_correction
    sta accu
    jmp next
.endproc

;case 0x2F: c->a = ~c->a; break; // CMA
.proc op_2f
    lda accu
    eor #$ff
    sta accu
    jmp next
.endproc

;case 0x37: c->cf = 1; break; // STC
.proc op_37
    lda flags
    ora #FLAG_C
    sta flags
    jmp next
.endproc

;case 0x3F: c->cf = !c->cf; break; // CMC
.proc op_3f
    lda flags
    eor #FLAG_C
    sta flags
    jmp next
.endproc

;// rotate instructions
;case 0x07: i8080_rlc(c); break; // RLC (rotate left)
;// rotate register A left
;static inline void i8080_rlc(i8080* const c) {
;    c->cf = c->a >> 7;
;    c->a = (c->a << 1) | c->cf;
;}
.proc op_07
    lsr flags
    lda accu
    tax
    asl
    rol flags
    txa
    asl
    rol accu
    jmp next
.endproc

;case 0x0F: i8080_rrc(c); break; // RRC (rotate right)
;// rotate register A right
;static inline void i8080_rrc(i8080* const c) {
    ;c->cf = c->a & 1;
    ;c->a = (c->a >> 1) | (c->cf << 7);
;}
.proc op_0f
    lsr flags
    lda accu
    tax
    lsr
    rol flags
    txa
    lsr
    ror accu
    jmp next
.endproc

;case 0x17: i8080_ral(c); break; // RAL
;// rotate register A left with the carry flag
;static inline void i8080_ral(i8080* const c) {
;    const bool cy = c->cf;
;    c->cf = c->a >> 7;
;    c->a = (c->a << 1) | cy;
;}
.proc op_17
    lsr flags
    rol accu
    rol flags
    jmp next
.endproc

;case 0x1F: i8080_rar(c); break; // RAR
;// rotate register A right with the carry flag
;static inline void i8080_rar(i8080* const c) {
;    const bool cy = c->cf;
;    c->cf = c->a & 1;
;    c->a = (c->a >> 1) | (cy << 7);
;}
.proc op_1f
    lsr flags
    ror accu
    rol flags
    jmp next
.endproc

; // executes a logic "and" between register A and a byte, then stores the
; // result in register A
; static inline void i8080_ana(i8080* const c, uint8_t val) {
;     uint8_t result = c->a & val;
;     c->cf = 0;
;     c->hf = ((c->a | val) & 0x08) != 0;
;     SET_ZSP(c, result);
;     c->a = result;
; }
.proc ana
    lda accu
    tax
    and 0,x
    sta accu
    sta v
    txa
    ora 0,x
    and #$08
    jsr set_halfcarry
    lda flags
    and #FLAG_C ^ $ff
    sta flags
    jmp get_flags
.endproc

;// logical byte instructions
;case 0xA7: i8080_ana(c, c->a); break; // ANA A
.proc op_a7
    ldx #accu
    bne ana
.endproc
    
;case 0xA0: i8080_ana(c, c->b); break; // ANA B
.proc op_a0
    ldx #b
    bne ana
.endproc
    
;case 0xA1: i8080_ana(c, c->c); break; // ANA C
.proc op_a1
    ldx #c
    bne ana
.endproc
    
;case 0xA2: i8080_ana(c, c->d); break; // ANA D
.proc op_a2
    ldx #d
    bne ana
.endproc
    
;case 0xA3: i8080_ana(c, c->e); break; // ANA E
.proc op_a3
    ldx #e
    bne ana
.endproc
    
;case 0xA4: i8080_ana(c, c->h); break; // ANA H
.proc op_a4
    ldx #h
    bne ana
.endproc
    
;case 0xA5: i8080_ana(c, c->l); break; // ANA L
.proc op_a5
    ldx #l
    bne ana
.endproc
    
;case 0xA6: i8080_ana(c, i8080_rb(c, i8080_get_hl(c))); break; // ANA M
.proc op_a6
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne ana
.endproc
    
;case 0xE6: i8080_ana(c, i8080_next_byte(c)); break; // ANI byte
.proc op_e6
    jsr fetch_byte
    ldx #v
    bne ana
.endproc

; // executes a logic "xor" between register A and a byte, then stores the
; // result in register A
; static inline void i8080_xra(i8080* const c, uint8_t val) {
;     c->a ^= val;
;     c->cf = 0;
;     c->hf = 0;
;     SET_ZSP(c, c->a);
; }
.proc xra
    lda accu
    eor 0,x
    sta accu
    jmp get_logic_flags
.endproc

;case 0xAF: i8080_xra(c, c->a); break; // XRA A
.proc op_af
    ldx #accu
    bne xra
.endproc
    
;case 0xA8: i8080_xra(c, c->b); break; // XRA B
.proc op_a8
    ldx #b
    bne xra
.endproc
    
;case 0xA9: i8080_xra(c, c->c); break; // XRA C
.proc op_a9
    ldx #c
    bne xra
.endproc
    
;case 0xAA: i8080_xra(c, c->d); break; // XRA D
.proc op_aa
    ldx #d
    bne xra
.endproc
    
;case 0xAB: i8080_xra(c, c->e); break; // XRA E
.proc op_ab
    ldx #e
    bne xra
.endproc
    
;case 0xAC: i8080_xra(c, c->h); break; // XRA H
.proc op_ac
    ldx #h
    bne xra
.endproc
    
;case 0xAD: i8080_xra(c, c->l); break; // XRA L
.proc op_ad
    ldx #l
    bne xra
.endproc
    
;case 0xAE: i8080_xra(c, i8080_rb(c, i8080_get_hl(c))); break; // XRA M
.proc op_ae
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne xra
.endproc
    
;case 0xEE: i8080_xra(c, i8080_next_byte(c)); break; // XRI byte
.proc op_ee
    jsr fetch_byte
    ldx #v
    bne xra
.endproc

; // executes a logic "or" between register A and a byte, then stores the
; // result in register A
; static inline void i8080_ora(i8080* const c, uint8_t val) {
;     c->a |= val;
;     c->cf = 0;
;     c->hf = 0;
;     SET_ZSP(c, c->a);
; }
.proc ora8080
    lda accu
    ora 0,x
    sta accu
    jmp get_logic_flags
.endproc

;case 0xB7: i8080_ora(c, c->a); break; // ORA A
.proc op_b7
    ldx #accu
    bne ora8080
.endproc
    
;case 0xB0: i8080_ora(c, c->b); break; // ORA B
.proc op_b0
    ldx #b
    bne ora8080
.endproc
    
;case 0xB1: i8080_ora(c, c->c); break; // ORA C
.proc op_b1
    ldx #c
    bne ora8080
.endproc
    
;case 0xB2: i8080_ora(c, c->d); break; // ORA D
.proc op_b2
    ldx #d
    bne ora8080
.endproc
    
;case 0xB3: i8080_ora(c, c->e); break; // ORA E
.proc op_b3
    ldx #e
    bne ora8080
.endproc
    
;case 0xB4: i8080_ora(c, c->h); break; // ORA H
.proc op_b4
    ldx #h
    bne ora8080
.endproc
    
;case 0xB5: i8080_ora(c, c->l); break; // ORA L
.proc op_b5
    ldx #l
    bne ora8080
.endproc
    
;case 0xB6: i8080_ora(c, i8080_rb(c, i8080_get_hl(c))); break; // ORA M
.proc op_b6
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne ora8080
.endproc
    
;case 0xF6: i8080_ora(c, i8080_next_byte(c)); break; // ORI byte
.proc op_f6
    jsr fetch_byte
    ldx #v
    bne ora8080
.endproc

; // compares the register A to another byte
; static inline void i8080_cmp(i8080* const c, uint8_t val) {
;     const int16_t result = c->a - val;
;     c->cf = result >> 8;
;     c->hf = ~(c->a ^ result ^ val) & 0x10;
;     SET_ZSP(c, result & 0xFF);
; }
.proc cmp8080
    lsr flags
    lda accu
    sec
    sbc 0,x
    sta v
    rol flags
    lda accu
    eor tmp
    eor 0,x
    and #$10
    jsr set_halfcarry
    jmp get_flags
.endproc

;case 0xBF: i8080_cmp(c, c->a); break; // CMP A
.proc op_bf
    ldx #accu
    bne cmp8080
.endproc
    
;case 0xB8: i8080_cmp(c, c->b); break; // CMP B
.proc op_b8
    ldx #b
    bne cmp8080
.endproc
    
;case 0xB9: i8080_cmp(c, c->c); break; // CMP C
.proc op_b9
    ldx #c
    bne cmp8080
.endproc
    
;case 0xBA: i8080_cmp(c, c->d); break; // CMP D
.proc op_ba
    ldx #d
    bne cmp8080
.endproc
    
;case 0xBB: i8080_cmp(c, c->e); break; // CMP E
.proc op_bb
    ldx #e
    bne cmp8080
.endproc
    
;case 0xBC: i8080_cmp(c, c->h); break; // CMP H
.proc op_bc
    ldx #h
    bne cmp8080
.endproc
    
;case 0xBD: i8080_cmp(c, c->l); break; // CMP L
.proc op_bd
    ldx #l
    bne cmp8080
.endproc
    
;case 0xBE: i8080_cmp(c, i8080_rb(c, i8080_get_hl(c))); break; // CMP M
.proc op_be
    ldx #hl
    jsr read_byte
    sta v
    ldx #v
    bne cmp8080
.endproc
    
;case 0xFE: i8080_cmp(c, i8080_next_byte(c)); break; // CPI byte
.proc op_fe
    jsr fetch_byte
    ldx #v
    bne cmp8080
.endproc

;// branch control/program counter load instructions
;case 0xC3: i8080_jmp(c, i8080_next_word(c)); break; // JMP
;// undocumented JMP
;case 0xCB: i8080_jmp(c, i8080_next_word(c)); break;
.proc op_c3
    ldx #pc
    jsr fetch_word_x
    jmp next_rebanked
.endproc

; Z80: Call bit instructions
; TODO: Halfcarry
.proc op_cb
    jsr fetch_byte
    tax
;    lda bits_opcodes_l,x
    pha
;    lda bits_opcodes_h,x
    pha
    rts
.endproc

; Z80: RLC rb
.proc op_rlc_rb
    lsr flags
    lda 0,x
    rol
    sta v
    php
    rol flags
    plp
    rol 0,x
    jmp get_flags
.endproc

; Z80: RLC (HL)
.proc op_rlc_hl
    lsr flags
    ldy #0
    lda (hl),y
    rol
    sta v
    php
    rol flags
    lda (hl),y
    plp
    rol
    sta (hl),y
    jmp get_flags
.endproc

; Z80: RRC rb
.proc op_rrc_rb
    lsr flags
    lda 0,x
    ror
    sta v
    php
    rol flags
    plp
    ror 0,x
    jmp get_flags
.endproc

; Z80: RRC (HL)
.proc op_rrc_hl
    lsr flags
    ldy #0
    lda (hl),y
    ror
    sta v
    php
    rol flags
    lda (hl),y
    plp
    ror
    sta (hl),y
    jmp get_flags
.endproc

; Z80: RL rb
.proc op_rl_rb
    lsr flags
    rol 0,x
    rol flags
    lda 0,x
    sta v
    jmp get_flags
.endproc

; Z80: RL (HL)
.proc op_rl_hl
    lsr flags
    ldy #0
    lda (hl),y
    rol
    sta v
    sta (hl),y
    rol flags
    jmp get_flags
.endproc

; Z80: RR rb
.proc op_rr_rb
    lsr flags
    ror 0,x
    rol flags
    lda 0,x
    sta v
    jmp get_flags
.endproc

; Z80: SLA rb
.proc op_sla_rb
    lsr flags
    lda 0,x
    asl
    sta v
    php
    rol flags
    plp
    asl 0,x
    jmp get_flags
.endproc

; Z80: SLA (HL)
.proc op_sla_hl
    lsr flags
    ldy #0
    lda (hl),y
    asl
    sta v
    php
    rol flags
    plp
    lda (hl),y
    asl
    sta (hl),y
    jmp get_flags
.endproc

; Z80: SRA rb
.proc op_sra_rb
    lsr flags
    lda 0,x
    lsr
    sta v
    php
    rol flags
    plp
    lsr 0,x
    jmp get_flags
.endproc

; Z80: SRA (HL)
.proc op_sra_hl
    lsr flags
    ldy #0
    lda (hl),y
    lsr
    sta v
    php
    rol flags
    plp
    lda (hl),y
    lsr
    sta (hl),y
    jmp get_flags
.endproc

; Z80: SLL rb (undocumented)
.proc op_sll_rb
    lsr flags
    lda 0,x
    asl
    sta v
    php
    rol flags
    plp
    sec
    rol 0,x
    jmp get_flags
.endproc

; Z80: SLL (HL) (undocumented)
.proc op_sll_hl
    lsr flags
    ldy #0
    lda (hl),y
    asl
    sta v
    php
    rol flags
    plp
    lda (hl),y
    sec
    rol
    sta (hl),y
    jmp get_flags
.endproc

; Z80: SRL rb
.proc op_srl_rb
    lsr flags
    lda 0,x
    lsr
    sta v
    php
    rol flags
    plp
    sec
    ror 0,x
    jmp get_flags
.endproc

; Z80: SRL (HL)
.proc op_srl_hl
    lsr flags
    ldy #0
    lda (hl),y
    lsr
    sta v
    php
    rol flags
    plp
    lda (hl),y
    sec
    ror
    sta (hl),y
    jmp get_flags
.endproc

; Z80: BIT x,r
.proc op_bit_r
    lda flags
    and #FLAG_Z ^ $ff
    sta flags
    lda 0,y
    and bits,x
    beq n
    lda flags
    ora #FLAG_Z
    sta flags
n:  jmp next
.endproc

; Z80: BIT x,(HL)
.proc op_bit_hl
    lda flags
    and #FLAG_Z ^ $ff
    sta flags
    ldy #0
    lda (hl),y
    and bits,x
    beq n
    lda flags
    ora #FLAG_Z
    sta flags
n:  jmp next
.endproc

; Z80: RES x,r
.proc op_res_r
    lda 0,y
    and bitmasks,x
    sta 0,y
    jmp next
.endproc

; Z80: RES x,(HL)
.proc op_res_hl
    ldy #0
    lda (hl),y
    and bitmasks,x
    sta (hl),y
    jmp next
.endproc

; Z80: SET x,r
.proc op_set_r
    lda 0,y
    and bitmasks,x
    sta 0,y
    jmp next
.endproc

; Z80: SET x,(HL)
.proc op_set_hl
    ldy #0
    lda (hl),y
    ora bits,x
    sta (hl),y
    jmp next
.endproc


;// jumps to next address pointed by the next word in memory if a condition
;// is met
;static inline void i8080_cond_jmp(i8080* const c, bool condition) {
;    uint16_t addr = i8080_next_word(c);
;    if (condition) {
;        c->pc = addr;
;    }
;}
.proc cond_jmp
    jsr fetch_word
    tya
    and flags
    bne n
    lda v
    sta pc
    lda v+1
    sta pc+1
n:  jmp next_rebanked
.endproc

.proc cond_jmp_inv
    jsr fetch_word
    tya
    and flags
    beq n
    lda v
    sta pc
    lda v+1
    sta pc+1
n:  jmp next_rebanked
.endproc

;case 0xC2: i8080_cond_jmp(c, c->zf == 0); break; // JNZ
.proc op_c2
    ldy #FLAG_Z
    bne cond_jmp_inv
.endproc

;case 0xCA: i8080_cond_jmp(c, c->zf == 1); break; // JZ
.proc op_ca
    ldy #FLAG_Z
    bne cond_jmp
.endproc

;case 0xD2: i8080_cond_jmp(c, c->cf == 0); break; // JNC
.proc op_d2
    ldy #FLAG_C
    bne cond_jmp_inv
.endproc

;case 0xDA: i8080_cond_jmp(c, c->cf == 1); break; // JC
.proc op_da
    ldy #FLAG_C
    bne cond_jmp
.endproc

;case 0xE2: i8080_cond_jmp(c, c->pf == 0); break; // JPO
.proc op_e2
    ldy #FLAG_P
    bne cond_jmp_inv
.endproc

;case 0xEA: i8080_cond_jmp(c, c->pf == 1); break; // JPE
.proc op_ea
    ldy #FLAG_P
    bne cond_jmp
.endproc

;case 0xF2: i8080_cond_jmp(c, c->sf == 0); break; // JP
.proc op_f2
    ldy #FLAG_S
    bne cond_jmp_inv
.endproc

;case 0xFA: i8080_cond_jmp(c, c->sf == 1); break; // JM
.proc op_fa
    ldy #FLAG_S
    bne cond_jmp
.endproc

;case 0xE9: c->pc = i8080_get_hl(c); break; // PCHL
.proc op_e9
    lda l
    sta c
    lda h
    sta pc+1
    jmp next_rebanked
.endproc

; Z80: Call IX instructions
.proc op_dd
    jsr fetch_byte
    tax
;    lda ix_opcodes_l,x
    pha
;    lda ix_opcodes_h,x
    pha
    rts
.endproc

; Z80: Call IX BITS instructions
.proc op_ddcb
    jsr fetch_byte
    tax
;    lda ix_bits_opcodes_l,x
    pha
;    lda ix_bits_opcodes_h,x
    pha
    rts
.endproc

; Z80: Call EXTD instructions
.proc op_ed
    jsr fetch_byte
    tax
;    lda extd_opcodes_l,x
    pha
;    lda exts_opcodes_h,x
    pha
    rts
.endproc

; Z80: LDI
.proc op_ldi
    ldy #hl
    ldx #v
    jsr read_byte
    ldy #de
    ldx #v
    jsr write_byte
    inc l
    beq n1
l1: inc e
    beq n2
    jmp next
n1: inc h
    jmp l1
n2: inc d
    jmp next
.endproc


; Z80: LDIR
.proc op_ldir
    ldy #hl
    ldx #v
    jsr read_byte
    ldy #de
    ldx #v
    jsr write_byte
    inc l
    beq n1
l1: inc e
    beq n2
l2: dec c
    lda c
    cmp #$ff
    bne op_ldir
    dec c+1
    cmp #$ff
    bne op_ldir
    jmp next
n1: inc h
    jmp l1
n2: inc d
    jmp l2
.endproc

; Z80: Call IY instructions
.proc op_fd
    jsr fetch_byte
    tax
;    lda iy_opcodes_l,x
    pha
;    lda iy_opcodes_h,x
    pha
    rts
.endproc

; Z80: Call IY BITS instructions
.proc op_fdcb
    jsr fetch_byte
    tax
;    lda iy_bits_opcodes_l,x
    pha
;    lda iy_bits_opcodes_h,x
    pha
    rts
.endproc


;case 0xCD: i8080_call(c, i8080_next_word(c)); break; // CALL
;undocumented CALLs (8080) case 0xDD: case 0xED: case 0xFD: i8080_call(c, i8080_next_word(c));
;// pushes the current pc to the stack, then jumps to an address
;static inline void i8080_call(i8080* const c, uint16_t addr) {
;    i8080_push_stack(c, c->pc);
;    i8080_jmp(c, addr);
;}
.proc op_cd
    dec sp
    ldx sp  ; -1?
    inx
    bne n2
n:  ldx #sp
    ldy #pc
    jsr write_word_call
    ldx #pc
    jsr fetch_word_x
    jmp next_rebanked
n2: dec sp+1
    jmp n
.endproc

;// calls to next word in memory if a condition is met
;static inline void i8080_cond_call(i8080* const c, bool condition) {
;    uint16_t addr = i8080_next_word(c);
;    if (condition) {
;        i8080_call(c, addr);
;        c->cyc += 6;
;    }
;}
.proc cond_call
    and flags
    bne op_cd
    jsr fetch_word
    jmp next
.endproc

.proc cond_call_inv
    and flags
    beq op_cd
    jsr fetch_word
    jmp next
.endproc

;case 0xC4: i8080_cond_call(c, c->zf == 0); break; // CNZ
.proc op_c4
    lda #FLAG_Z
    bne cond_call_inv
.endproc
    
;case 0xCC: i8080_cond_call(c, c->zf == 1); break; // CZ
.proc op_cc
    lda #FLAG_Z
    bne cond_call
.endproc
    
;case 0xD4: i8080_cond_call(c, c->cf == 0); break; // CNC
.proc op_d4
    lda #FLAG_C
    bne cond_call_inv
.endproc
    
;case 0xDC: i8080_cond_call(c, c->cf == 1); break; // CC
.proc op_dc
    lda #FLAG_C
    bne cond_call
.endproc
    
;case 0xE4: i8080_cond_call(c, c->pf == 0); break; // CPO
.proc op_e4
    lda #FLAG_P
    bne cond_call_inv
.endproc
    
;case 0xEC: i8080_cond_call(c, c->pf == 1); break; // CPE
.proc op_ec
    lda #FLAG_P
    bne cond_call
.endproc
    
;case 0xF4: i8080_cond_call(c, c->sf == 0); break; // CP
.proc op_f4
    lda #FLAG_S
    bne cond_call_inv
.endproc
    
;case 0xFC: i8080_cond_call(c, c->sf == 1); break; // CM
.proc op_fc
    lda #FLAG_S
    bne cond_call
.endproc

;case 0xC9: i8080_ret(c); break; // RET
;// undocumented RET
;case 0xD9: i8080_ret(c); break;
;// returns from subroutine
;static inline void i8080_ret(i8080* const c) {
;    c->pc = i8080_pop_stack(c);
;}
.proc op_c9
    ldx #sp
    ldy #pc
    jsr read_word
    inc sp
    beq n
    jmp next_rebanked
n:  inc sp+1
    jmp next_rebanked
.endproc

op_d9 = op_c9

;// returns from subroutine if a condition is met
;static inline void i8080_cond_ret(i8080* const c, bool condition) {
;    if (condition) {
;        i8080_ret(c);
;        c->cyc += 6;
;    }
;}
.proc cond_ret
    and flags
    bne op_c9
    jmp next_rebanked
.endproc

.proc cond_ret_inv
    and flags
    beq op_c9
    jmp next_rebanked
.endproc

;case 0xC0: i8080_cond_ret(c, c->zf == 0); break; // RNZ
.proc op_c0
    lda #FLAG_Z
    bne cond_ret_inv
.endproc
    
;case 0xC8: i8080_cond_ret(c, c->zf == 1); break; // RZ
.proc op_c8
    lda #FLAG_Z
    bne cond_ret
.endproc
    
;case 0xD0: i8080_cond_ret(c, c->cf == 0); break; // RNC
.proc op_d0
    lda #FLAG_C
    bne cond_ret_inv
.endproc
    
;case 0xD8: i8080_cond_ret(c, c->cf == 1); break; // RC
.proc op_d8
    lda #FLAG_C
    bne cond_ret
.endproc
    
;case 0xE0: i8080_cond_ret(c, c->pf == 0); break; // RPO
.proc op_e0
    lda #FLAG_P
    bne cond_ret_inv
.endproc
    
;case 0xE8: i8080_cond_ret(c, c->pf == 1); break; // RPE
.proc op_e8
    lda #FLAG_P
    bne cond_ret
.endproc
    
;case 0xF0: i8080_cond_ret(c, c->sf == 0); break; // RP
.proc op_f0
    lda #FLAG_S
    bne cond_ret_inv
.endproc
    
;case 0xF8: i8080_cond_ret(c, c->sf == 1); break; // RM
.proc op_f8
    lda #FLAG_S
    bne cond_ret
.endproc

.proc rst
    sta v
    dec sp
    ldx sp  ; -1?
    inx
    bne n2
n:  ldx #sp
    ldy #pc
    jsr write_word_call
    lda v
    sta pc
    lda #0
    sta pc+1
    jmp next_rebanked
n2: dec sp+1
    jmp n
.endproc


;case 0xC7: i8080_call(c, 0x00); break; // RST 0
.proc op_c7
    lda #$00
    jmp rst
.endproc
    
;case 0xCF: i8080_call(c, 0x08); break; // RST 1
.proc op_cf
    lda #$08
    bne rst
.endproc
    
;case 0xD7: i8080_call(c, 0x10); break; // RST 2
.proc op_d7
    lda #$10
    bne rst
.endproc
    
;case 0xDF: i8080_call(c, 0x18); break; // RST 3
.proc op_df
    lda #$18
    bne rst
.endproc
    
;case 0xE7: i8080_call(c, 0x20); break; // RST 4
.proc op_e7
    lda #$20
    bne rst
.endproc
    
;case 0xEF: i8080_call(c, 0x28); break; // RST 5
.proc op_ef
    lda #$28
    bne rst
.endproc
    
;case 0xF7: i8080_call(c, 0x30); break; // RST 6
.proc op_f7
    lda #$30
    bne rst
.endproc
    
;case 0xFF: i8080_call(c, 0x38); break; // RST 7
.proc op_ff
    lda #$38
    bne rst
.endproc

.proc push8080
    dec sp
    ldx sp  ; -1?
    inx
    beq n2
n:  ldx #sp
    jmp write_word
n2: dec sp+1
    jmp n
.endproc

;// stack operation instructions
;case 0xC5: i8080_push_stack(c, i8080_get_bc(c)); break; // PUSH B
.proc op_c5
    ldy #bc
    bne push8080
.endproc
    
;case 0xD5: i8080_push_stack(c, i8080_get_de(c)); break; // PUSH D
.proc op_d5
    ldy #de
    bne push8080
.endproc
    
;case 0xE5: i8080_push_stack(c, i8080_get_hl(c)); break; // PUSH H
.proc op_e5
    ldy #hl
    bne push8080
.endproc

;case 0xF5: i8080_push_psw(c); break; // PUSH PSW
;// pushes register A and the flags into the stack
;static inline void i8080_push_psw(i8080* const c) {
;    // note: bit 3 and 5 are always 0
;    uint8_t psw = 0;
;    psw |= c->sf << 7;
;    psw |= c->zf << 6;
;    psw |= c->hf << 4;
;    psw |= c->pf << 2;
;    psw |= 1 << 1; // bit 1 is always 1
;    psw |= c->cf << 0;
;    i8080_push_stack(c, c->a << 8 | psw);
;}
.proc op_f5
    lda flags
    sta v
    lda accu
    sta v+1
    ldx #v
    jmp push8080
.endproc

.proc pop8080
    ldx #sp
    jsr read_word
    inc sp
    beq n
    jmp next
n:  inc sp+1
    jmp next
.endproc

;case 0xC1: i8080_set_bc(c, i8080_pop_stack(c)); break; // POP B
.proc op_c1
    ldy #bc
    bne pop8080
.endproc
    
;case 0xD1: i8080_set_de(c, i8080_pop_stack(c)); break; // POP D
.proc op_d1
    ldy #de
    bne pop8080
.endproc
    
;case 0xE1: i8080_set_hl(c, i8080_pop_stack(c)); break; // POP H
.proc op_e1
    ldy #hl
    bne pop8080
.endproc

;case 0xF1: i8080_pop_psw(c); break; // POP PSW
;// pops register A and the flags from the stack
;static inline void i8080_pop_psw(i8080* const c) {
;    const uint16_t af = i8080_pop_stack(c);
;    c->a = af >> 8;
;    const uint8_t psw = af & 0xFF;
;
;    c->sf = (psw >> 7) & 1;
;    c->zf = (psw >> 6) & 1;
;    c->hf = (psw >> 4) & 1;
;    c->pf = (psw >> 2) & 1;
;    c->cf = (psw >> 0) & 1;
;}
.proc op_f1
    ldx #sp
    ldy #v
    jsr read_word
    inc sp
    beq n
    lda v
    sta flags
    lda #v+1
    sta accu
r:  jmp next
n:  inc sp+1
    jmp r
.endproc

;// input/output instructions
;case 0xDB: // IN
    ;c->a = c->port_in(c->userdata, i8080_next_byte(c));
;break;
.proc op_db
    jsr fetch_byte
    jmp next
.endproc

;case 0xD3: // OUT
    ;c->port_out(c->userdata, i8080_next_byte(c), c->a);
;break;
.proc op_d3
    jsr fetch_byte
    jmp next
.endproc

.proc _cpu_init
    lda #0
    ldx #register_end-register_start-1
n:  sta register_start,x
    dex
    bpl n

    ;;; Make flag tables

    ; Parity flags
    ldx #0
n5: stx tmp
    lda #0
    ldy #8
n2: asl tmp
    bcc n3
    eor #FLAG_P
n3: dey
    bne n2
    sta static_flags,x
    inx
    bne n5

    ; Zero flag
    lda #FLAG_Z
    sta static_flags

    ; Sign flags
    ldx #127
n4: lda static_flags+128,x
    ora #FLAG_S
    sta static_flags+128,x
    dex
    bpl n4

    rts
.endproc
