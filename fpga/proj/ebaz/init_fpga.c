#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>


const int slotinfo[] = {
	0xa17c000c,
	0x364e494b,
	0x6b696e6e,
	0x6f776662,
	0x2c380000
};

const int kinnowregs[] = {
	0x00043000,
	0x00000c00
};


int main (int argc, char** argv) {
	int f = open("/dev/mem", O_RDWR);
	if (f == -1 || f == 0) {
		printf("Error opening /dev/mem\n");
		return 1;
	}

	uint32_t *ptr = (uint32_t*) mmap(NULL, 0x200000, PROT_READ | PROT_WRITE, MAP_SHARED, f, 0x0FE00000);
	if (ptr == MAP_FAILED || ptr == 0) {
		printf("Error mapping upper DRAM\n");
		return 1;
	}
	
	for (int i = 0; i < 5; i++) {
		ptr[i] = slotinfo[i];
	}

	ptr[0xc00] = kinnowregs[0];
	ptr[0xc01] = kinnowregs[1];

	for (int i = 0x40000; i < 0x80000; i++) {
		int j = (i - 0x40000) * 4;
		ptr[i] = ((j + 3) << 24) + ((j + 2) << 16) + ((j + 1) << 8) + j;
	}
		
}
