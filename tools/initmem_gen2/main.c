/* Modified by Laurentiu-Cristian Duca 
 * WITHOUT_DISK and SEARCH_CHECKSUM options 
 */
/******************************************************************************************/
/**** SimCore/RISC-V since 2018-07-05                               ArchLab. TokyoTech ****/
/******************************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define WITHOUT_DISK

void load_binfile(char *fname, uint8_t *mem);

#define DRAM_SIZE    (64*1024*1024) // 64MB main memory
#ifdef WITHOUT_DISK
#define DISK_SIZE    0
#define D_SIZE_DISK 0
#else
#define DISK_SIZE    (64*1024*1024) // 64MB disk
#define D_SIZE_DISK (16*1024*1024) // 16MB of disk image
#endif
#define D_INITD_ADDR (32*1024*1024) // after 32MB (instead of 16) area, write the dev tree data
//#define D_INITD_ADDR (0x01000000)

#define D_SIZE_DRAM (30*1024*1024)    //  30 MB of (bbl + kernel + initramfs) instead of 9.
#define D_SIZE_DEVT ( 4*1024)      //  4KB of device tree

/*****  generate binary image file for FPGA run                                       *****/
/******************************************************************************************/
int main(int argc, char *argv[]){

    printf("__ generate binary image file to initialize memory for FPGA run\n");
    printf("__ generate text image file to initialize memory for Verilog simulation run\n");
    printf("__ Version 2.0.0, 2020/08/24\n");

    if (argc!=1+3) {
        printf("__ The usage is wrong.\n");
        printf("__ The usage is as follows:\n");
        printf("__ $ ./initmem_gen [bbl binary file] [disk image file] [device tree file]\n");
        return 1;
    } 

    char *st_bbl  = argv[1];
    char *st_disk = argv[2];
    char *st_dtb  = argv[3];

    uint8_t *mmem;  // main memory
    //mmem = (uint8_t*) malloc(DRAM_SIZE);
    mmem = calloc(DRAM_SIZE, sizeof(uint8_t));
#ifndef WITHOUT_DISK
    uint8_t *disk;  // disk
    disk = (uint8_t*) malloc(DISK_SIZE);
    if(mmem==NULL || disk==NULL) {
        printf("__ Memory can not be allocated.\n");
        return 1;
    }
#endif

    load_binfile(st_bbl, mmem);
    load_binfile(st_dtb, mmem+D_INITD_ADDR);
    //printf("*(mmem+D_INITD_ADDR)=0x%x\n", 
    //	    *((unsigned long *)(mmem+D_INITD_ADDR)));
#ifndef WITHOUT_DISK
    load_binfile(st_disk, disk);
#endif

    FILE *fp = fopen("initmem.bin", "wb");
    fwrite(mmem,              sizeof(uint8_t), D_SIZE_DRAM, fp);
    fwrite(mmem+D_INITD_ADDR, sizeof(uint8_t), D_SIZE_DEVT, fp);
#ifndef WITHOUT_DISK
    fwrite(disk,              sizeof(uint8_t), D_SIZE_DISK, fp);
#endif
    fclose(fp);
    printf("__ File initmem.bin was generated.\n");

    FILE *fp_kernel = fopen("init_kernel.txt", "w");
    FILE *fp_disk   = fopen("init_disk.txt", "w");
    for(int i=0; i<DRAM_SIZE; i++) fprintf(fp_kernel, "%x\n", mmem[i]);
    fclose(fp_kernel);
    printf("__ File init_kernel.txt was generated.\n");
#ifndef WITHOUT_DISK
    for(int i=0; i<DISK_SIZE; i++) fprintf(fp_disk,   "%x\n", disk[i]);
#endif
    fclose(fp_disk);
    printf("__ File init_disk.txt was generated.\n");

    free(mmem);
#ifndef WITHOUT_DISK
    free(disk);
#endif

    fp = fopen("initmem.bin", "rb");
    int i=0;
#define SEARCH_CHECKSUM 1
#ifdef SEARCH_CHECKSUM
    int j=0;
#endif
    uint32_t sum=0;
    uint32_t buf;
    while(fread(&buf, 4, 1, fp)){
        sum += buf;
#ifdef SEARCH_CHECKSUM
        if(((i*4) >= (D_SIZE_DRAM - 4)) && (j == 0)) {
                printf("i=%d i*4=%d sum=%x\n", i, i*4, sum);
                j++;
        }
#endif
        i++;
    }
    fclose(fp);
    printf("__ %8d byte file, checksum %08x i=%d D_SIZE_DRAM=%d\n", i*4, sum, i, D_SIZE_DRAM);

    return 0;
}

/******************************************************************************************/
void load_binfile(char *fname, uint8_t *mem){
    FILE *fp;
    fp = fopen(fname, "rb");
    if(fp == NULL) {
        printf("__ The image file %s cannot be found\n", fname);
        exit(1);
    }
    int i=0;
    while(!feof(fp)){ mem[i++] = getc(fp); }
    fclose(fp);
}

/******************************************************************************************/
