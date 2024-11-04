// Modified by Laurentiu-Cristian Duca, 2021-12-20.
// Added sleep_fct() to wait the uart tx to send the character to be printed.
//
/*****************************************************************************/
/**** SimCore/RISC-V since 2018-07-05                ArchLab. TokyoTech   ****/
/*****************************************************************************/

#include "simrv.h"

volatile int *TOHOST_ADDR = (int *)0x40008000;

int sleep_fct(int n)
{
        // a fibonacci sleep fct
        volatile int i, s1=1, s2=1, s3;
        for(i = 0; i < n; i++) {
                s3 = s1 + s2;
                s1 = s2;
                s2 = s3;
        }
        return s3;
}

void simrv_exit () {
    *TOHOST_ADDR = CMD_POWER_OFF << 16;
}

void simrv_putc (char c) {
    *TOHOST_ADDR = CMD_PRINT_CHAR << 16 | c;
    // wait the uart to put the char on the txd line, for 8Mbps: 10bits*13cycles/bit=130 cpu cycles
    sleep_fct(100);
}

void simrv_puts (char *str) {
    for (char *c = str; *c != '\0'; c++) {
        simrv_putc(*c);
    }
}

void simrv_puth (unsigned int n) {
    char str[8];
    unsigned int  hexn = 0;
    unsigned int  size = 0;

    do {
        hexn = n & 0xf;
        if(hexn < 10) str[size++] = (char) (hexn + '0');
        else          str[size++] = (char) (hexn - 10 + 'A');
        n = n >> 4;
    } while (n != 0);

    for (int i = size-1; i >= 0; i--) {
        simrv_putc(str[i]);
    }
}
