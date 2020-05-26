.export bios_boot
.export bios_const
.export bios_conin
.export bios_conout
.export bios_list
.export bios_reader
.export bios_home
.export bios_seldsk
.export bios_settrk
.export bios_setsec
.export bios_setdma
.export bios_read
.export bios_write

.importzp accu, b, c, d, e, h, l, flags

.proc bios_boot
    rts         ; TODO: Start BASIC.
.endproc

; Get console status.
;
; A: $00: no char
;    $ff: 
.proc bios_const
.endproc

; Wait for char and return it in A.
.proc bios_conin
.endproc

; Write char to the console.
.proc bios_conout
.endproc

; Write char to the printer.
.proc bios_list
.endproc

; Write char to auxiliary device.
.proc bios_punch
.endproc

; Wait for char from auxiliary device (eg. tape drive) and return it.
; If the is no device 26(^Z) is being returned.
.proc bios_reader
    lda #26
    sta accu
    rts
.endproc

; Move current drive to track 0.
.proc bios_home
.endproc

; Move current drive to track 0.
.proc bios_seldsk
    lda #0
    sta h
    sta l
    rts
.endproc

; Set track number.
.proc bios_settrk
    rts
.endproc

; Set sector number.
.proc bios_setsec
    rts
.endproc

; Set read/write address.
.proc bios_setdma
    rts
.endproc

; Read sector.
.proc bios_read
    lda #1      ; Unrecoverable error.
    sta accu
    rts
.endproc

; Write sector.
.proc bios_write
    lda #1      ; Unrecoverable error.
    sta accu
    rts
.endproc
