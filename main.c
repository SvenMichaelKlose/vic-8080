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

/*

TODO for the VIC:

* Functions to copy between host and emulated RAM.
* Functions to get/set singe bytes in emulated RAM.
* Adapt the rest.
* Connect to 8080 emulation.
* Finish implementing 8080 emulation.
* Wedge in the 40-column renderer from G.
* Implement terminal emulation as described in bios.asm.
* Bang head on keyboard… emulation.
* Patch WordStar and Turbo Pascal to run in 40-column mode.
* Add a FE3 driver.
* Release on April Fool's day.

*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "bdos.h"

#define ED_TRAP_OPCODE	        0xBC
#define CBIOS_JUMP_TABLE_ADDR	0xFE00
#define CBIOS_ENTRIES		    ((0x10000 - CBIOS_JUMP_TABLE_ADDR) / 3)
#define BDOS_ENTRY_ADDR		    0xFD00
#define MAX_OPEN_FILES          8

#define DEBUG(...)              fprintf(stderr, __VA_ARGS__)

typedef unsinged int uint;

// TODO: Read into regular RAM and copy in chunks.
void
load_program ()
{
	FILE * f = fopen (argv[1], "rb");

	if (!f) {
		fprintf (stderr, "Cannot open program file: %s\n", argv[1]);
		return 1;
	}

	a = fread (memory + 0x100, 1, BDOS_ENTRY_ADDR - 0x100 + 1, f);
	fclose (f);
	if (a < 10) {
		fprintf (stderr, "Too short CP/M program file: %s\n", argv[1]);
		return 1;
	}
	if (a > 0xC000) {
		fprintf (stderr, "Too large CP/M program file: %s\n", argv[1]);
		return 1;
	}
}

int
main (int argc, char ** argv)
{
	int a;

	if (argc < 2) {
		fprintf (stderr, "Usage error: at least one parameter expected, the name of the CP/M program\n"
                         "After that, you can give the switches/etc for the CP/M program itself\n");
		return ERROR;
	}

    bdos_init ();

	// Now fill buffer of the command line
	set (0x81, 0);
	ememset (0x5C + 1, 32, 11);
	ememset (0x6C + 1, 32, 11);
	for (a = 2; a < argc; a++) {
		if (a <= 3)
			write_filename_to_fcb (a == 2 ? 0x5C : 0x6C, argv[a]);
		if (get (0x81))
			estrcat (0x81, " ");
		estrcat (0x81, argv[a]);
		if (estrlen (0x81) > 0x7F) {
			fprintf (stderr, "Too long command line for the CP/M program!\n");
			return ERROR;
		}
	}
	set (0x80, estrlen (0x81));

    load_program ();

	Z80_PC = 0x100;
	Z80_SP = BDOS_ENTRY_ADDR;
	DEBUG("*** Starting program: %s with parameters %s\n", argv[1], get (0x81));

	return 0;
}


int
main (int argc, char ** argv)
{
    // TODO: Init terminal emulation.

	if (cpm_init (argc, argv))
		return ERROR;

    // TODO: Call 8080 emulation here.

	return 0;
}
