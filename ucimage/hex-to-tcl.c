#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

#define HALFWORDS_PER_LINE 64
// 16 bits on 4 digits
#define SLICE_SIZE_DIGITS (16/4)
int main()
{
	FILE *f, *ftcl;
	int i, ret, eof=0, j=0, k=0, l=0;
	char s[9]={0}, str[1000]={0};
	// 256 bit hexa
	char t0[HALFWORDS_PER_LINE+1]={0}, t1[HALFWORDS_PER_LINE+1]={0};

	if((ftcl = fopen("ucimage.tcl", "w")) == NULL) {
                perror("can not open tcl file");
                return -1;
        }
	if((f = fopen("ucimage.hex", "r")) == NULL) {
		perror("can not open hex file");
		return -1;
	}

	// 8KB code / 4B per line = 2k lines
	for(i = 0; i < 2048; i++) {
		if(eof == 0) {
			ret = fscanf(f, "%s", s);
			printf("%s\n", s);
			if(ret == EOF) {
				eof = 1;
				printf("EOF\n");
				s[7]=s[6]=s[5]=s[4]=s[3]=s[2]=s[1]=s[0]='0';
	                        s[8]=0;
			}
		} else {
			s[7]=s[6]=s[5]=s[4]=s[3]=s[2]=s[1]=s[0]='0';
			s[8]=0;
		}
		for(l = 0; l < SLICE_SIZE_DIGITS; l++) {
			t1[HALFWORDS_PER_LINE-j-l-1] = s[SLICE_SIZE_DIGITS-l-1];
			// s has 8 chars (1 per digit), so add 4
			t0[HALFWORDS_PER_LINE-j-l-1] = s[SLICE_SIZE_DIGITS-l+SLICE_SIZE_DIGITS-1];
		}
		j = j+4;
		if(j == HALFWORDS_PER_LINE) {
			sprintf(str, "set_property INIT_%02x 256'h%s [get_cells {c/mc/lm_mc/mem_reg_0}]\n", k, t0);
			fprintf(ftcl, "%s", str);
			printf("%s", str);
			sprintf(str, "set_property INIT_%02x 256'h%s [get_cells {c/mc/lm_mc/mem_reg_1}]\n", k, t1);
			fprintf(ftcl, "%s", str);
			printf("%s", str);
                        j = 0;
			k = k+1;
		}
	}

	fclose(f);
	fclose(ftcl);
	return 0;
}

/*
[Vivado] How to change firmware ROM by modifying bitstream (updateMem)

a)#get_cells -hierarchical filter {PARENT == m_main/c/mc/lm_mc}
get_cells -hierarchical -filter { PRIMITIVE_GROUP == BMEM }
get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.*.* }

b) Getting a list of all BRAMS:
set my_rams [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.bram.* }]
c/debug_KEY/buff_reg c/mc/lm_mc/mem_reg_0 c/mc/lm_mc/mem_reg_1

c) Counting the length of the list:
llength $my_rams

d) Reporting out the properties of all the brams:
#foreach test $my_rams {report_property -all [get_cells $test]}
report_property -all [get_cells c/mc/lm_mc/mem_reg_0]
ram_addr_begin                              int      false      0
ram_addr_end                                int      false      2047
ram_offset                                  int      false      0
ram_slice_begin                             int      false      0
ram_slice_end                               int      false      15

report_property -all [get_cells c/mc/lm_mc/mem_reg_1]
ram_addr_begin                              int      false      0
ram_addr_end                                int      false      2047
ram_offset                                  int      false      0
ram_slice_begin                             int      false      16
ram_slice_end                               int      false      31

first 16 bits in mem_reg_0 then in mem_reg_1

e) Location info can be obtained by:
get_property LOC [get_cells c/mc/lm_mc/mem_reg_0]
RAMB36_X1Y9
get_property LOC [get_cells c/mc/lm_mc/mem_reg_1]
RAMB36_X2Y9

f) Run File > Checkpoint > Open
	nexys4.runs/impl_1/m_main_postroute_physopt.dcp or
	m_main_routed.dcp if first does not exist
source ucimage.tcl
write_bitstream -force laur.bit
*/

