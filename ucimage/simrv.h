/*****************************************************************************/
/**** SimCore/RISC-V since 2018-07-05                ArchLab. TokyoTech   ****/
/*****************************************************************************/

#ifndef __simrv_h__
#define __simrv_h__

#define CMD_PRINT_CHAR 1
#define CMD_POWER_OFF  2

void simrv_exit ();
void simrv_putc (char c);
void simrv_puts (char *str);
void simrv_puth (unsigned int n);
#endif
