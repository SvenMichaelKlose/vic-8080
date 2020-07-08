#define ED_TRAP_OPCODE	        0xBC
#define CBIOS_JUMP_TABLE_ADDR	0xFE00
#define CBIOS_ENTRIES		    ((0x10000 - CBIOS_JUMP_TABLE_ADDR) / 3)
#define BDOS_ENTRY_ADDR		    0xFD00
#define MAX_OPEN_FILES          8

#define DEBUG(...)              fprintf(stderr, __VA_ARGS__)

typedef unsigned int uint;
