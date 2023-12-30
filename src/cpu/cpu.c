#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include "cpu.h"


void hcf(void) {
    asm ("cli");
    for (;;) {
        asm ("hlt");
    }
}
