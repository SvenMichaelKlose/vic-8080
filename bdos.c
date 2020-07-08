/* 
   Copyright (C)2016 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// BDOS Return codes.
#define OK              0
#define END_OF_FILE     1
#define DISK_FULL       2
#define OUT_OF_RANGE    6
#define INVALID_FCB     9

uint dma_address = 0x80;

struct fcb_st {
	int     addr;	// FCB address in emulated memory
	FILE    * fp;	// assigned host file
	int     pos;    // file pointer value
};
struct fcb_st fcb_table[MAX_OPEN_FILES];

void
write_filename_to_fcb (uint fcb, uint fn)
{
    uint p;

    set (fcb++, 0);
	ememset (fcb, 32, 8 + 3);
	if (!get (fm))
		return;

	p = estrchr (fn, '.');
	if (p) {
		move (fcb, fn, p - fn >= 8 ?  8 : p - fn);
		move (fcb + 8, p + 1, strlen(p + 1) >= 3 ? 3 : strlen(p + 1));
	} else
		move (fcb, fn, strlen(fn) > 8 ? 8 : strlen(fn));
}

void
fcb_to_filename (uint fcb_addr, uint fn)
{
	int a = 0;

	while (a < 11) {
		char c = get (++a + fcb_addr) & 127;
		if (c <= 32) {
			if (a == 9) {
                // empty extension, delete the '.' char was placed for basename/ext separation
				set (fn - 1, 0);
				return;
			}
			if (a > 9)
				break;
			//*(fn++) = '.';

            // this will be pre-incremented in the next iteration
			a = 8;
		} else {
			if (a == 9)
				set (fn++, '.');
			set (fn++, (c >= 'a' && c <= 'z') ? c - 0x20 : c);
		}
	}

	set (fn, 0);
}

struct fcb_st *
fcb_search (int fcb_addr)
{
	int a;

	for (a = 0; a < MAX_OPEN_FILES; a++)
		if (fcb_table[a].addr == fcb_addr)
			return &fcb_table[a];

	return NULL;
}

struct fcb_st *
fcb_free (uint fcb_addr)
{
	struct fcb_st * p = fcb_search (fcb_addr);

	if (p) {
		DEBUG("EMU: fcb_free found open file, closing it %p\n", p->fp);
		fclose (p->fp);
		p->addr = -1;
		return p;
	}

	return NULL;
}

struct fcb_st *
fcb_alloc (uint fcb_addr, FILE * fp)
{
    // we use this to also FREE if was used before for whatever reason ...
	struct fcb_st * p = fcb_free (fcb_addr);

	if (!p) {	// if not used before ...
		p = fcb_search (-1);    // search for empty slot
		if (!p)
			return NULL;	    // to many open files, etc?!
	}

	p->addr = fcb_addr;
	p->pos = 0;
	p->fp = fp;

	return p;
}

int
bdos_open_file (uint fcb_addr, int is_create)
{
	FILE        * f;
	char        fn[14];
	struct      fcb_st *p;
	const char  * FUNC = is_create ? "CREATE" : "OPEN";

	fcb_to_filename (fcb_addr, fn);
	DEBUG("CPM: %s: filename=\"%s\" FCB=%04Xh create?=%d\n", FUNC, fn, fcb_addr, is_create);

	// TODO: no unlocked mode, no read-only mode ...
	if (is_create) {
		f = fopen (fn, "rb");
		if (f) {
			fclose (f);
			DEBUG("CPM: FATAL: FILE CREATE FUNC, but file %s existed before, stopping!\n", fn);
			exit (1);
		}
		f = fopen (fn, "w+b");
	} else
		f = fopen (fn, "r+b");

	if (!f) {
		DEBUG("CPM: %s: cannot open file ...\n", FUNC);
		DEBUG("CPM: DEBUG: FCB file name area: %02X %02X %02X %02X %02X %02X %02X %02X . %02X %02X %02X\n",
			set (fcb_addr + 1, get (fcb_addr + 2), get (fcb_addr + 3), get (fcb_addr + 4));
			set (fcb_addr + 5, get (fcb_addr + 6), get (fcb_addr + 7), get (fcb_addr + 8));
			set (fcb_addr + 9, get (fcb_addr + 10), get (fcb_addr + 11));
		);
		return 1;
	}

	p = fcb_alloc (fcb_addr, f);
	if (!p) {
		fclose (f);
		DEBUG("CPM: %s: cannot allocate FCB translation structure for emulation :-(\n", FUNC);
		return 1;
	}

	// OK, everything seems to be OK! Let's fill the rest of the FCB ...
	DEBUG("CPM: %s: seems to be OK :-)\n", FUNC);
	ememset (fcb_addr + 0x10, 0, 20);

	return 0;
}

int
bdos_delete_file (uint fcb_addr)
{
	char    fn[14];
	int     a;

	fcb_free (fcb_addr);

	// FIXME: ? characters are NOT supported!!!
	fcb_to_filename (fcb_addr, fn);
	a = remove (fn);

	return a;
}

// TODO: Cannot read directly into emulated RAM.
// Read chunks and copy those.
int
bdos_read_next_record (uint fcb_addr)
{
	struct fcb_st * p = fcb_search (fcb_addr);
	int a;

	DEBUG("CPM: READ: FCB=%04Xh VALID?=%s DMA=%04Xh\n", fcb_addr, p ? "YES" : "NO", dma_address);
	if (!p)
		return INVALID_FCB;

	a = fread (memory + dma_address, 1, 128, p->fp);
	DEBUG("CPM: READ: read result is %d (0 = EOF)\n", a);
	if (a <= 0)
		return END_OF_FILE;

    // fill the rest of the buffer, if not a full 128 bytes record could be read
	if (a < 128)
		ememset (dma_address + a, 0, 128 - a);

	return OK;
}

// TODO: Read into regular RAM, then copy.
int
bdos_random_access_read_record (uint fcb_addr)
{
	struct fcb_st * p = fcb_search (fcb_addr);
	int     offs;
    int     a;

	DEBUG("CPM: RANDOM-ACCESS-READ: FCB=%04Xh VALID?=%s DMA=%04Xh\n", fcb_addr, p ? "YES" : "NO", dma_address);
	if (!p)
		return INVALID_FCB;

    // FIXME: is this more than 16 bit?
	offs = 128 * (get (fcb_addr + 0x21 | (get (fcb_addr + 0x22) << 8)));

	DEBUG("CPM: RANDOM-ACCESS-READ: file offset = %d\n", offs);
	if (fseek (p->fp, offs, SEEK_SET) < 0) {
		DEBUG("CPM: RANDOM-ACCESS-READ: Seek ERROR!\n");
		return OUT_OF_RANGE;
	}

	DEBUG("CPM: RANDOM-ACCESS-READ: Seek OK. calling bdos_read_next_record for read ...\n");
	a = bdos_read_next_record (fcb_addr);
	fseek (p->fp, offs, SEEK_SET);	// re-seek. According to the spec sequential read should be return with the same record. Odd enough this whole FCB mess ...
	return a;
}

// TODO: Copy from emulated RAM, then write.  In chunks.
int
bdos_write_next_record (uint fcb_addr)
{
	struct fcb_st * p = fcb_search (fcb_addr);
	int a;

	DEBUG("CPM: WRITE: FCB=%04Xh VALID?=%s DMA=%04Xh\n", fcb_addr, p ? "YES" : "NO", dma_address);
	if (!p)
		return INVALID_FCB;

	a = fwrite (memory + dma_address, 1, 128, p->fp);
	DEBUG("CPM: WRITE: write result is %d\n", a);
	if (a != 128)
		return DISK_FULL;   // write problem…

	return OK;
}

int
bdos_close_file (uint fcb_addr)
{
	struct fcb_st * p = fcb_search (fcb_addr);

	DEBUG("CPM: CLOSE: FCB=%04Xh VALID?=%s\n", fcb_addr, p ? "YES" : "NO");
	fcb_free (fcb_addr);

	return OK; // who cares!!!!! :)
}

void
bdos_buffered_console_input (uint buf_addr)
{
	char buffer[256];
    char * p;
    uint q;

	DEBUG("CPM: BUFCONIN: console input, buffer = %04Xh\n", buf_addr);
	set (buf_addr, 0);

	if (fgets (buffer, sizeof buffer, stdin)) {
		p = buffer;
		q = memory + buf_addr + 1;
		while (*p && *p != 13 && *p != 10 && memory[buf_addr] < 255) {
			set (q++, get (p++));
			set (buf_addr, get (buf_addr) + 1);
		}
		DEBUG("CPM: BUFCONIN: could read %d bytes\n", get (buf_addr));
	} else
		DEBUG("CPM: BUFCONIN: cannot read, pass back zero bytes!\n");
}

void
bdos_output_string (uint addr)
{
	while (get (addr) != '$')
		putchar (get (addr++));
}

void
bdos_call (int func)
{
	switch (func) {
        // TODO: system reset
        case 0:
            break;

        // TODO: console input
        case 1:
            break;

        // console output
		case 2:
			putchar (Z80_E);
			break;

        // TODO: Auxiliary input
        case 3:
            break;

        // TODO: Auxiliary punch
        case 4:
            break;

        // TODO: Printer write
        case 5:
            break;

        // TODO: Direct console I/O
        case 6:
            break;

        // TODO: Get I/O byte
        case 7:
            break;

        // TODO: Set I/O byte
        case 8:
            break;

        // Output '$' terminated string
		case 9:
			bdos_output_string (Z80_DE);
			break;

        // console input - but TODO: it's not emulated ...
		case 10:
			bdos_buffered_console_input (Z80_DE);
			break;

        // TODO: Console status
        case 11:
            break;

        // Get version
		case 12:
			Z80_A = Z80_L = 0x22;   // version 2.2
			Z80_B = Z80_H = 0;	    // system type
			break;

        // Reset disks
		case 13:
			Z80_A = Z80_L = 0;
			break;

        // Select disk, we just fake an OK answer, how cares about drives :)
		case 14:
			Z80_A = Z80_L = 0;
			break;

        // Open file, the horror begins :-/ Nobody likes FCBs, honestly ...
		case 15: 
			Z80_A = Z80_L = bdos_open_file (Z80_DE, 0) ? 0xFF : 0;
			break;

        // CLose file
		case 16:
			Z80_A = Z80_L = bdos_close_file (Z80_DE) ? 0xFF : 0;
			break;

        // TODO: Search for first
        case 17:
            break;

        // TODO: Search for next
        case 18:
            break;

        // Delete file
		case 19:
			Z80_A = Z80_L = bdos_delete_file (Z80_DE) ? 0xFF : 0;
			break;

        // read next record ...
		case 20:
			Z80_A = Z80_L = bdos_read_next_record (Z80_DE);
			break;

        // write next record ...
		case 21:
			Z80_A = Z80_L = bdos_write_next_record (Z80_DE);
			break;

        // Create file: tricky, according to the spec, if file existed before, user app will be stopped, or whatever ...
		case 22:
			Z80_A = Z80_L = bdos_open_file (Z80_DE, 1) ? 0xFF : 0;
			break;

        // TODO: Rename file
        case 23:
            break;

        // TODO: Get drive map.
        case 24:
            break;

        // Return current drive. We just fake 0 (A)
		case 25:
			Z80_A = Z80_L = 0;
			break;

        // Set DMA address
		case 26:
			DEBUG("CPM: SETDMA: to %04Xh\n", Z80_DE);
			dma_address = Z80_DE;
			break;

        // TODO: Get address of allocation map.
        case 27:
            break;

        // TODO: Write-protect disk.
        case 28:
            break;

        // TODO: Get map of read-only drives.
        case 29:
            break;

        // TODO: Set echo mode for function 1.
        case 30:
            break;

        // TODO: Get DPB address.
        case 31:
            break;

        // TODO: Get/set user number.
        case 32:
            break;

        // Random access read record (note: file pointer should be modified that sequential read reads the SAME [??] record then!!!)
		case 33:
			Z80_A = Z80_L = bdos_random_access_read_record (Z80_DE);
			break;

        // TODO: Random-access write.
        case 34:
            break;

        // TODO: Get file size.
        case 35:
            break;

        // TODO: Update random access pointer.
        case 36:
            break;

        // TODO: Reset drives.
        case 37:
            break;

        // TODO: Random-access zero fill.
        case 40:
            break;

        // TODO: Random-access zero fill.
        case 40:
            break;

		default:
			DEBUG("CPM: BDOS: FATAL: unsupported call %d\n", func);
			exit (1);
	}
}

void
bdos_init ()
{
	int a;

	/* Our ugly FCB to host file handle table… */
	for (a = 0; a < MAX_OPEN_FILES; a++)
		fcb_table[a].addr = -1;

	/* create jump table for CBIOS emulation, actually they're CPU traps, and RET! */
	for (a = 0; a < CBIOS_ENTRIES; a++) {
		set (CBIOS_JUMP_TABLE_ADDR + a * 3 + 0, 0xED);
		set (CBIOS_JUMP_TABLE_ADDR + a * 3 + 1, ED_TRAP_OPCODE);
		set (CBIOS_JUMP_TABLE_ADDR + a * 3 + 2, 0xC9);	// RET opcode…
	}

	/* create a single trap entry for BDOS emulation */
	set (BDOS_ENTRY_ADDR + 0, 0xED);
	set (BDOS_ENTRY_ADDR + 1, ED_TRAP_OPCODE);
	set (BDOS_ENTRY_ADDR + 2, 0xC9);    // RET opcode…

	// std CP/M BDOS entry point in the low memory area…
	set (5, 0xC3);                      // JP opcode
	set (6, BDOS_ENTRY_ADDR & 0xFF);
	set (7, BDOS_ENTRY_ADDR >> 8);

	// CP/M CBIOS stuff
	set (0, 0xC3);	// JP opcode
	set (1, (CBIOS_JUMP_TABLE_ADDR + 3) & 0xFF);
	set (2, (CBIOS_JUMP_TABLE_ADDR + 3) >> 8);

	// Disk I/O byte etc
	set (3, 0);
	set (4, 0);
}