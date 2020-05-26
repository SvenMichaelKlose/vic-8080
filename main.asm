; 8080 emulator based on https://github.com/superzazu/8080
;
; Copyright (c) 2020 Sven Michael Klose pixel@hugbox.org

FLAG_S  = $80
FLAG_Z  = $40
FLAG_H  = $10
FLAG_P  = $04
FLAG_1  = $02   ; Always 1.
FLAG_C  = $01
 
.zeropage

register_start:
pc:     .res 2
accu:   .res 1
flags:  .res 1
bc:
b:      .res 1
c:      .res 1
de:
d:      .res 1
e:      .res 1
hl:
h:      .res 1
l:      .res 1
sp:     .res 2
flag_i: .res 1
register_end:

v:      .res 2
tmp:    .res 1

.data

static_flags:   .res 256

.code

.proc next
    rts
.endproc

.proc next_rebanked
    rts
.endproc

.proc fetch_byte
    rts
.endproc

.proc fetch_word
    rts
.endproc

.proc fetch_word_y
    rts
.endproc

.proc read_byte
    rts
.endproc

.proc read_byte_y
    rts
.endproc

.proc read_word
    rts
.endproc

.proc write_byte
    rts
.endproc

.proc write_word
    rts
.endproc

.proc write_word_call
    rts
.endproc

.proc _main
    rts
.endproc

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

.proc push8080
    dec sp
    ldx sp  ; -1?
    inx
    bne n2
n:  ldx #sp
    ;ldy #v
    jmp write_word
n2: dec sp+1
    jmp n
.endproc

.proc pop8080
    ldx #sp
    ;ldy #v
    jsr read_word
    inc sp
    beq n
    rts
n:  inc sp+1
    rts
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
    adc 0,y
    sta l
    lda h
    adc 1,y
    sta h
    rol flags
    jmp next
.endproc

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

    rol flags   ; Set carry

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
    jmp adr8080
.endproc

.proc adc8080
    lsr flags       ; Get and clear carry flag.
    jmp adr8080
.endproc

.proc sub8080
    lsr flags       ; Clear carry flag.
    clc
    jmp adr8080
.endproc

.proc sbb8080
    lsr flags       ; Get and clear carry flag.
    jmp adr8080
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

; // sets the program counter to a given address
; static inline void i8080_jmp(i8080* const c, uint16_t addr) {
;     c->pc = addr;
; }

;// jumps to next address pointed by the next word in memory if a condition
;// is met
;static inline void i8080_cond_jmp(i8080* const c, bool condition) {
;    uint16_t addr = i8080_next_word(c);
;    if (condition) {
;        c->pc = addr;
;    }
;}

;// pushes the current pc to the stack, then jumps to an address
;static inline void i8080_call(i8080* const c, uint16_t addr) {
;    i8080_push_stack(c, c->pc);
;    i8080_jmp(c, addr);
;}

;// calls to next word in memory if a condition is met
;static inline void i8080_cond_call(i8080* const c, bool condition) {
;    uint16_t addr = i8080_next_word(c);
;    if (condition) {
;        i8080_call(c, addr);
;        c->cyc += 6;
;    }
;}

;// returns from subroutine
;static inline void i8080_ret(i8080* const c) {
;    c->pc = i8080_pop_stack(c);
;}

;// returns from subroutine if a condition is met
;static inline void i8080_cond_ret(i8080* const c, bool condition) {
;    if (condition) {
;        i8080_ret(c);
;        c->cyc += 6;
;    }
;}

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

;// 8 bit transfer instructions
;case 0x7F: c->a = c->a; break; // MOV A,A

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
    ldy #hl
    jsr read_byte
    sta accu
    jmp next
.endproc

;case 0x0A: c->a = i8080_rb(c, i8080_get_bc(c)); break; // LDAX B
.proc op_0a
    ldy #bc
    jsr read_byte
    sta accu
    jmp next
.endproc

;case 0x1A: c->a = i8080_rb(c, i8080_get_de(c)); break; // LDAX D
.proc op_1a
    ldy #de
    jsr read_byte
    sta accu
    jmp next
.endproc

;case 0x3A: c->a = i8080_rb(c, i8080_next_word(c)); break; // LDA word
.proc op_3a
    jsr fetch_word
    ldy #v
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
    ldy #hl
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
    ldy #hl
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
    ldy #hl
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
    ldy #hl
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
;case 0x65: c->h = c->l; break; // MOV H,L
.proc op_65
    lda l
    sta h
    jmp next
.endproc
;case 0x66: c->h = i8080_rb(c, i8080_get_hl(c)); break; // MOV H,M
.proc op_66
    ldy #hl
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
;case 0x6E: c->l = i8080_rb(c, i8080_get_hl(c)); break; // MOV L,M
.proc op_6e
    ldy #hl
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

;case 0x3E: c->a = i8080_next_byte(c); break; // MVI A,byte
.proc op_3e
    jsr fetch_byte
    sta accu
    jmp next
.endproc
;case 0x06: c->b = i8080_next_byte(c); break; // MVI B,byte
.proc op_06
    jsr fetch_byte
    sta accu
    jmp next
.endproc
;case 0x0E: c->c = i8080_next_byte(c); break; // MVI C,byte
.proc op_0e
    jsr fetch_byte
    sta accu
    jmp next
.endproc
;case 0x16: c->d = i8080_next_byte(c); break; // MVI D,byte
.proc op_16
    jsr fetch_byte
    sta accu
    jmp next
.endproc
;case 0x1E: c->e = i8080_next_byte(c); break; // MVI E,byte
.proc op_1e
    jsr fetch_byte
    sta accu
    jmp next
.endproc
;case 0x26: c->h = i8080_next_byte(c); break; // MVI H,byte
.proc op_26
    jsr fetch_byte
    sta accu
    jmp next
.endproc
;case 0x2E: c->l = i8080_next_byte(c); break; // MVI L,byte
.proc op_2e
    jsr fetch_byte
    sta accu
    jmp next
.endproc

;case 0x36: i8080_wb(c, i8080_get_hl(c), i8080_next_byte(c)); break; // MVI M,byte
.proc op_36
    jsr fetch_byte
    ldy #hl
    jmp write_byte
.endproc

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

;case 0x32: i8080_wb(c, i8080_next_word(c), c->a); break; // STA word
.proc op_32
    jsr fetch_word
    lda accu
    ldy #v
    jmp write_byte
.endproc

;// 16 bit transfer instructions
;case 0x01: i8080_set_bc(c, i8080_next_word(c)); break; // LXI B,word
.proc op_01
    ldy #bc
    jmp fetch_word_y
.endproc

;case 0x11: i8080_set_de(c, i8080_next_word(c)); break; // LXI D,word
.proc op_11
    ldy #de
    jmp fetch_word_y
.endproc
;case 0x21: i8080_set_hl(c, i8080_next_word(c)); break; // LXI H,word
.proc op_21
    ldy #hl
    jmp fetch_word_y
.endproc
;case 0x31: c->sp = i8080_next_word(c); break; // LXI SP,word
.proc op_31
    ldy #sp
    jmp fetch_word_y
.endproc
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

;case 0xF9: c->sp = i8080_get_hl(c); break; // SPHL
.proc op_f9
    lda l
    sta sp
    lda h
    sta sp+1
    jmp next
.endproc

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

;case 0xE3: i8080_xthl(c); break; // XTHL
;// switches the value of a word at (sp) and HL
;static inline void i8080_xthl(i8080* const c) {
;    const uint16_t val = i8080_rw(c, c->sp);
;    i8080_ww(c, c->sp, i8080_get_hl(c));
;    i8080_set_hl(c, val);
;}

;// add byte instructions
;case 0x87: i8080_add(c, &c->a, c->a, 0); break; // ADD A
.proc op_87
    ldx #accu
    jmp add8080
.endproc
    
;case 0x80: i8080_add(c, &c->a, c->b, 0); break; // ADD B
.proc op_80
    ldx #b
    jmp add8080
.endproc
;case 0x81: i8080_add(c, &c->a, c->c, 0); break; // ADD C
.proc op_81
    ldx #c
    jmp add8080
.endproc
;case 0x82: i8080_add(c, &c->a, c->d, 0); break; // ADD D
.proc op_82
    ldx #d
    jmp add8080
.endproc
;case 0x83: i8080_add(c, &c->a, c->e, 0); break; // ADD E
.proc op_83
    ldx #e
    jmp add8080
.endproc
;case 0x84: i8080_add(c, &c->a, c->h, 0); break; // ADD H
.proc op_84
    ldx #h
    jmp add8080
.endproc
;case 0x85: i8080_add(c, &c->a, c->l, 0); break; // ADD L
.proc op_85
    ldx #l
    jmp add8080
.endproc
;case 0x86: i8080_add(c, &c->a, i8080_rb(c, i8080_get_hl(c)), 0); break; // ADD M
.proc op_86
    ldy #hl
    jsr read_byte_y
    sta v
    ldx #v
    jmp add8080
.endproc
;case 0xC6: i8080_add(c, &c->a, i8080_next_byte(c), 0); break; // ADI byte
.proc op_c6
    jsr fetch_byte
    ldx #v
    jmp add8080
.endproc

;// add byte with carry-in instructions
;case 0x8F: i8080_add(c, &c->a, c->a, c->cf); break; // ADC A
.proc op_8f
    ldx #accu
    jmp adc8080
.endproc
;case 0x88: i8080_add(c, &c->a, c->b, c->cf); break; // ADC B
.proc op_88
    ldx #b
    jmp adc8080
.endproc
;case 0x89: i8080_add(c, &c->a, c->c, c->cf); break; // ADC C
.proc op_89
    ldx #c
    jmp adc8080
.endproc
;case 0x8A: i8080_add(c, &c->a, c->d, c->cf); break; // ADC D
.proc op_8a
    ldx #d
    jmp adc8080
.endproc
;case 0x8B: i8080_add(c, &c->a, c->e, c->cf); break; // ADC E
.proc op_8b
    ldx #e
    jmp adc8080
.endproc
;case 0x8C: i8080_add(c, &c->a, c->h, c->cf); break; // ADC H
.proc op_8c
    ldx #h
    jmp adc8080
.endproc
;case 0x8D: i8080_add(c, &c->a, c->l, c->cf); break; // ADC L
.proc op_8d
    ldx #l
    jmp adc8080
.endproc

;case 0x8E: i8080_add(c, &c->a, i8080_rb(c, i8080_get_hl(c)), c->cf); break; // ADC M
.proc op_8e
    ldy #hl
    jsr read_byte_y
    sta v
    ldx #v
    jmp adc8080
.endproc
;case 0xCE: i8080_add(c, &c->a, i8080_next_byte(c), c->cf); break; // ACI byte
.proc op_ce
    jsr fetch_byte
    ldx #v
    jmp adc8080
.endproc

;// substract byte instructions
;case 0x97: i8080_sub(c, &c->a, c->a, 0); break; // SUB A
.proc op_97
    ldx #accu
    jmp sub8080
.endproc
;case 0x90: i8080_sub(c, &c->a, c->b, 0); break; // SUB B
.proc op_90
    ldx #b
    jmp sub8080
.endproc
;case 0x91: i8080_sub(c, &c->a, c->c, 0); break; // SUB C
.proc op_91
    ldx #c
    jmp sub8080
.endproc
;case 0x92: i8080_sub(c, &c->a, c->d, 0); break; // SUB D
.proc op_92
    ldx #d
    jmp sub8080
.endproc
;case 0x93: i8080_sub(c, &c->a, c->e, 0); break; // SUB E
.proc op_93
    ldx #e
    jmp sub8080
.endproc
;case 0x94: i8080_sub(c, &c->a, c->h, 0); break; // SUB H
.proc op_94
    ldx #h
    jmp sub8080
.endproc
;case 0x95: i8080_sub(c, &c->a, c->l, 0); break; // SUB L
.proc op_95
    ldx #l
    jmp sub8080
.endproc
;case 0x96: i8080_sub(c, &c->a, i8080_rb(c, i8080_get_hl(c)), 0); break; // SUB M
.proc op_96
    ldx #hl
    jsr read_byte_y
    sta v
    ldx #v
    jmp sub8080
.endproc
;case 0xD6: i8080_sub(c, &c->a, i8080_next_byte(c), 0); break; // SUI byte
.proc op_d6
    jsr fetch_byte
    ldx #v
    jmp sub8080
.endproc

;// substract byte with borrow-in instructions
;case 0x9F: i8080_sub(c, &c->a, c->a, c->cf); break; // SBB A
.proc op_9f
    ldx #accu
    jmp sbb8080
.endproc
;case 0x98: i8080_sub(c, &c->a, c->b, c->cf); break; // SBB B
.proc op_98
    ldx #b
    jmp sbb8080
.endproc
;case 0x99: i8080_sub(c, &c->a, c->c, c->cf); break; // SBB C
.proc op_99
    ldx #c
    jmp sbb8080
.endproc
;case 0x9A: i8080_sub(c, &c->a, c->d, c->cf); break; // SBB D
.proc op_9a
    ldx #d
    jmp sbb8080
.endproc
;case 0x9B: i8080_sub(c, &c->a, c->e, c->cf); break; // SBB E
.proc op_9b
    ldx #e
    jmp sbb8080
.endproc
;case 0x9C: i8080_sub(c, &c->a, c->h, c->cf); break; // SBB H
.proc op_9c
    ldx #h
    jmp sbb8080
.endproc
;case 0x9D: i8080_sub(c, &c->a, c->l, c->cf); break; // SBB L
.proc op_9d
    ldx #l
    jmp sbb8080
.endproc
;case 0x9E: i8080_sub(c, &c->a, i8080_rb(c, i8080_get_hl(c)), c->cf); break; // SBB M
.proc op_9e
    ldy #hl
    jsr read_byte_y
    sta v
    ldx #v
    jmp sbb8080
.endproc

;case 0xDE: i8080_sub(c, &c->a, i8080_next_byte(c), c->cf); break; // SBI byte
.proc op_de
    jsr fetch_byte
    ldx #v
    jmp sbb8080
.endproc

;// double byte add instructions
;case 0x09: i8080_dad(c, i8080_get_bc(c)); break; // DAD B
.proc op_09
    ldy #bc
    jmp dad
.endproc
;case 0x19: i8080_dad(c, i8080_get_de(c)); break; // DAD D
.proc op_19
    ldy #de
    jmp dad
.endproc
;case 0x29: i8080_dad(c, i8080_get_hl(c)); break; // DAD H
.proc op_29
    ldy #hl
    jmp dad
.endproc
;case 0x39: i8080_dad(c, c->sp); break; // DAD SP
.proc op_39
    ldy #sp
    jmp dad
.endproc

;// control instructions
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

;case 0x00: break; // NOP

;case 0x76: c->halted = 1; break; // HLT

;// increment byte instructions
;case 0x3C: c->a = i8080_inr(c, c->a); break; // INR A
.proc op_3c
    ldy #accu
    jmp inr
.endproc

;case 0x04: c->b = i8080_inr(c, c->b); break; // INR B
.proc op_04
    ldy #b
    jmp inr
.endproc
;case 0x0C: c->c = i8080_inr(c, c->c); break; // INR C
.proc op_0c
    ldy #c
    jmp inr
.endproc
;case 0x14: c->d = i8080_inr(c, c->d); break; // INR D
.proc op_14
    ldy #d
    jmp inr
.endproc
;case 0x1C: c->e = i8080_inr(c, c->e); break; // INR E
.proc op_1c
    ldy #e
    jmp inr
.endproc
;case 0x24: c->h = i8080_inr(c, c->h); break; // INR H
.proc op_24
    ldy #h
    jmp inr
.endproc
;case 0x2C: c->l = i8080_inr(c, c->l); break; // INR L
.proc op_2c
    ldy #l
    jmp inr
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

;// decrement byte instructions
;case 0x3D: c->a = i8080_dcr(c, c->a); break; // DCR A
.proc op_3d
    ldy #accu
    jmp dcr
.endproc
;case 0x05: c->b = i8080_dcr(c, c->b); break; // DCR B
.proc op_05
    ldy #b
    jmp dcr
.endproc
;case 0x0D: c->c = i8080_dcr(c, c->c); break; // DCR C
.proc op_0d
    ldy #c
    jmp dcr
.endproc
;case 0x15: c->d = i8080_dcr(c, c->d); break; // DCR D
.proc op_15
    ldy #d
    jmp dcr
.endproc
;case 0x1D: c->e = i8080_dcr(c, c->e); break; // DCR E
.proc op_1d
    ldy #e
    jmp dcr
.endproc
;case 0x25: c->h = i8080_dcr(c, c->h); break; // DCR H
.proc op_25
    ldy #h
    jmp dcr
.endproc
;case 0x2D: c->l = i8080_dcr(c, c->l); break; // DCR L
.proc op_2d
    ldy #l
    jmp dcr
.endproc
;case 0x35: i8080_wb(c, i8080_get_hl(c), i8080_dcr(c, i8080_rb(c, i8080_get_hl(c)))); break; // DCR M
.proc op_35
    ldx #hl
    ldy #v
    jsr read_byte
    sta v
    dec v
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

;// logical byte instructions
;case 0xA7: i8080_ana(c, c->a); break; // ANA A
.proc op_a7
    ldx #accu
    jmp ana
.endproc
;case 0xA0: i8080_ana(c, c->b); break; // ANA B
.proc op_a0
    ldx #b
    jmp ana
.endproc
;case 0xA1: i8080_ana(c, c->c); break; // ANA C
.proc op_a1
    ldx #c
    jmp ana
.endproc
;case 0xA2: i8080_ana(c, c->d); break; // ANA D
.proc op_a2
    ldx #d
    jmp ana
.endproc
;case 0xA3: i8080_ana(c, c->e); break; // ANA E
.proc op_a3
    ldx #e
    jmp ana
.endproc
;case 0xA4: i8080_ana(c, c->h); break; // ANA H
.proc op_a4
    ldx #h
    jmp ana
.endproc
;case 0xA5: i8080_ana(c, c->l); break; // ANA L
.proc op_a5
    ldx #l
    jmp ana
.endproc
;case 0xA6: i8080_ana(c, i8080_rb(c, i8080_get_hl(c))); break; // ANA M
.proc op_a6
    ldy #hl
    jsr read_byte
    sta v
    ldx #v
    jmp ana
.endproc
;case 0xE6: i8080_ana(c, i8080_next_byte(c)); break; // ANI byte
.proc op_e6
    jsr fetch_byte
    ldx #v
    jmp ana
.endproc

;case 0xAF: i8080_xra(c, c->a); break; // XRA A
.proc op_af
    ldx #accu
    jmp xra
.endproc
;case 0xA8: i8080_xra(c, c->b); break; // XRA B
.proc op_a8
    ldx #b
    jmp xra
.endproc
;case 0xA9: i8080_xra(c, c->c); break; // XRA C
.proc op_a9
    ldx #c
    jmp xra
.endproc
;case 0xAA: i8080_xra(c, c->d); break; // XRA D
.proc op_aa
    ldx #d
    jmp xra
.endproc
;case 0xAB: i8080_xra(c, c->e); break; // XRA E
.proc op_ab
    ldx #e
    jmp xra
.endproc
;case 0xAC: i8080_xra(c, c->h); break; // XRA H
.proc op_ac
    ldx #h
    jmp xra
.endproc
;case 0xAD: i8080_xra(c, c->l); break; // XRA L
.proc op_ad
    ldx #l
    jmp xra
.endproc
;case 0xAE: i8080_xra(c, i8080_rb(c, i8080_get_hl(c))); break; // XRA M
.proc op_ae
    ldy #hl
    jsr read_byte
    sta v
    ldx #v
    jmp xra
.endproc
;case 0xEE: i8080_xra(c, i8080_next_byte(c)); break; // XRI byte
.proc op_ee
    jsr fetch_byte
    ldx #v
    jmp xra
.endproc

;case 0xB7: i8080_ora(c, c->a); break; // ORA A
.proc op_b7
    ldx #accu
    jmp ora8080
.endproc
;case 0xB0: i8080_ora(c, c->b); break; // ORA B
.proc op_b0
    ldx #b
    jmp ora8080
.endproc
;case 0xB1: i8080_ora(c, c->c); break; // ORA C
.proc op_b1
    ldx #c
    jmp ora8080
.endproc
;case 0xB2: i8080_ora(c, c->d); break; // ORA D
.proc op_b2
    ldx #d
    jmp ora8080
.endproc
;case 0xB3: i8080_ora(c, c->e); break; // ORA E
.proc op_b3
    ldx #e
    jmp ora8080
.endproc
;case 0xB4: i8080_ora(c, c->h); break; // ORA H
.proc op_b4
    ldx #h
    jmp ora8080
.endproc
;case 0xB5: i8080_ora(c, c->l); break; // ORA L
.proc op_b5
    ldx #l
    jmp ora8080
.endproc
;case 0xB6: i8080_ora(c, i8080_rb(c, i8080_get_hl(c))); break; // ORA M
.proc op_b6
    ldy #hl
    jsr read_byte
    sta v
    ldx #v
    jmp ora8080
.endproc
;case 0xF6: i8080_ora(c, i8080_next_byte(c)); break; // ORI byte
.proc op_f6
    jsr fetch_byte
    ldx #v
    jmp ora8080
.endproc

;case 0xBF: i8080_cmp(c, c->a); break; // CMP A
.proc op_bf
    ldx #accu
    jmp cmp8080
.endproc
;case 0xB8: i8080_cmp(c, c->b); break; // CMP B
.proc op_b8
    ldx #b
    jmp cmp8080
.endproc
;case 0xB9: i8080_cmp(c, c->c); break; // CMP C
.proc op_b9
    ldx #c
    jmp cmp8080
.endproc
;case 0xBA: i8080_cmp(c, c->d); break; // CMP D
.proc op_ba
    ldx #d
    jmp cmp8080
.endproc
;case 0xBB: i8080_cmp(c, c->e); break; // CMP E
.proc op_bb
    ldx #e
    jmp cmp8080
.endproc
;case 0xBC: i8080_cmp(c, c->h); break; // CMP H
.proc op_bc
    ldx #h
    jmp cmp8080
.endproc
;case 0xBD: i8080_cmp(c, c->l); break; // CMP L
.proc op_bd
    ldx #l
    jmp cmp8080
.endproc
;case 0xBE: i8080_cmp(c, i8080_rb(c, i8080_get_hl(c))); break; // CMP M
.proc op_be
    ldy #hl
    jsr read_byte
    sta v
    ldx #v
    jmp cmp8080
.endproc
;case 0xFE: i8080_cmp(c, i8080_next_byte(c)); break; // CPI byte
.proc op_fe
    jsr fetch_byte
    ldx #v
    jmp cmp8080
.endproc

;// branch control/program counter load instructions
;case 0xC3: i8080_jmp(c, i8080_next_word(c)); break; // JMP
.proc op_c3
    jsr fetch_word
    lda v
    sta pc
    lda v+1
    sta pc+1
    jmp next_rebanked
.endproc

;case 0xC2: i8080_cond_jmp(c, c->zf == 0); break; // JNZ
;case 0xCA: i8080_cond_jmp(c, c->zf == 1); break; // JZ
;case 0xD2: i8080_cond_jmp(c, c->cf == 0); break; // JNC
;case 0xDA: i8080_cond_jmp(c, c->cf == 1); break; // JC
;case 0xE2: i8080_cond_jmp(c, c->pf == 0); break; // JPO
;case 0xEA: i8080_cond_jmp(c, c->pf == 1); break; // JPE
;case 0xF2: i8080_cond_jmp(c, c->sf == 0); break; // JP
;case 0xFA: i8080_cond_jmp(c, c->sf == 1); break; // JM

;case 0xE9: c->pc = i8080_get_hl(c); break; // PCHL
;case 0xCD: i8080_call(c, i8080_next_word(c)); break; // CALL

;case 0xC4: i8080_cond_call(c, c->zf == 0); break; // CNZ
;case 0xCC: i8080_cond_call(c, c->zf == 1); break; // CZ
;case 0xD4: i8080_cond_call(c, c->cf == 0); break; // CNC
;case 0xDC: i8080_cond_call(c, c->cf == 1); break; // CC
;case 0xE4: i8080_cond_call(c, c->pf == 0); break; // CPO
;case 0xEC: i8080_cond_call(c, c->pf == 1); break; // CPE
;case 0xF4: i8080_cond_call(c, c->sf == 0); break; // CP
;case 0xFC: i8080_cond_call(c, c->sf == 1); break; // CM

;case 0xC9: i8080_ret(c); break; // RET
;case 0xC0: i8080_cond_ret(c, c->zf == 0); break; // RNZ
;case 0xC8: i8080_cond_ret(c, c->zf == 1); break; // RZ
;case 0xD0: i8080_cond_ret(c, c->cf == 0); break; // RNC
;case 0xD8: i8080_cond_ret(c, c->cf == 1); break; // RC
;case 0xE0: i8080_cond_ret(c, c->pf == 0); break; // RPO
;case 0xE8: i8080_cond_ret(c, c->pf == 1); break; // RPE
;case 0xF0: i8080_cond_ret(c, c->sf == 0); break; // RP
;case 0xF8: i8080_cond_ret(c, c->sf == 1); break; // RM

;case 0xC7: i8080_call(c, 0x00); break; // RST 0
;case 0xCF: i8080_call(c, 0x08); break; // RST 1
;case 0xD7: i8080_call(c, 0x10); break; // RST 2
;case 0xDF: i8080_call(c, 0x18); break; // RST 3
;case 0xE7: i8080_call(c, 0x20); break; // RST 4
;case 0xEF: i8080_call(c, 0x28); break; // RST 5
;case 0xF7: i8080_call(c, 0x30); break; // RST 6
;case 0xFF: i8080_call(c, 0x38); break; // RST 7

;// stack operation instructions
;case 0xC5: i8080_push_stack(c, i8080_get_bc(c)); break; // PUSH B
.proc op_c5
    ldy #bc
    jmp push8080
.endproc
;case 0xD5: i8080_push_stack(c, i8080_get_de(c)); break; // PUSH D
.proc op_d5
    ldy #de
    jmp push8080
.endproc
;case 0xE5: i8080_push_stack(c, i8080_get_hl(c)); break; // PUSH H
.proc op_e5
    ldy #hl
    jmp push8080
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

;case 0xC1: i8080_set_bc(c, i8080_pop_stack(c)); break; // POP B
.proc op_c1
    ldy #bc
    jmp pop8080
.endproc
;case 0xD1: i8080_set_de(c, i8080_pop_stack(c)); break; // POP D
.proc op_d1
    ldy #bc
    jmp pop8080
.endproc
;case 0xE1: i8080_set_hl(c, i8080_pop_stack(c)); break; // POP H
.proc op_e1
    ldy #bc
    jmp pop8080
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

;// input/output instructions
;case 0xDB: // IN
    ;c->a = c->port_in(c->userdata, i8080_next_byte(c));
;break;
;case 0xD3: // OUT
    ;c->port_out(c->userdata, i8080_next_byte(c), c->a);
;break;

;// undocumented NOPs
;case 0x08:
;case 0x10: case 0x18:
;case 0x20: case 0x28:
;case 0x30: case 0x38:
;break;

;// undocumented RET
;case 0xD9: i8080_ret(c); break;
.proc op_d9
    ldx #sp
    ldy #pc
    jsr read_word
    inc sp
    beq n
    jmp next_rebanked
n:  inc sp+1
    jmp next_rebanked
.endproc

;// undocumented CALLs
;case 0xDD: case 0xED: case 0xFD: i8080_call(c, i8080_next_word(c));
.proc op_dd
    dec sp
    ldx sp  ; -1?
    inx
    bne n2
n:  ldx #sp
    ldy #pc
    jsr write_word_call
    ldy #pc
    jsr fetch_word_y
    jmp next_rebanked
n2: dec sp+1
    jmp n
.endproc

;// undocumented JMP
;case 0xCB: i8080_jmp(c, i8080_next_word(c)); break;
.proc op_cb
    ldy #pc
    jsr fetch_word_y
    jmp next_rebanked
.endproc

.proc make_flags
    ; Parity flags
    ldx #0
n:  stx tmp
    lda #0
    ldy #8
n2: asl tmp
    bcc n3
    eor #FLAG_P
n3: dey
    bne n2
    sta static_flags,x
    inx
    bne n

    ; Zero flag
    lda #FLAG_Z
    sta static_flags

    ; Sign flags
    ldx #127
n4: lda static_flags,x
    ora #FLAG_S
    sta static_flags,x
    dex
    bpl n4

    rts
.endproc

.proc init8080
    lda #0
    ldx #register_end-register_start-1
n:  sta register_start,x
    dex
    bpl n
    rts
.endproc
