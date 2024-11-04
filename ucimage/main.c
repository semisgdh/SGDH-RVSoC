// Modified by Laurentiu-Cristian Duca, 2021-12-22. 
// Added explanations in comments
//
/******************************************************************************************/
/**** SimCore/RISC-V since 2018-07-05                             ArchLab. TokyoTech   ****/
/******************************************************************************************/
//#include <cstdint.h>

#include <stdint.h>
#include <string.h>
#include "simrv.h"

//volatile uint8_t *HOGE = (uint8_t *)0x0;
#define DISK_DEBUG 1
//#include "define.h"
/**** VirtIO 0x40000000 ~                                                              ****/
/******************************************************************************************/
#define VIRTIO_BASE_ADDR (0x40000000) // NotChange
#define VIRTIO_SIZE      (0x08000000) //
#define VRING_DESC_F_NEXT     (1)
#define VRING_DESC_F_WRITE    (2)
#define VRING_DESC_F_INDIRECT (4)

/* console */
#define CONSOLE_MAX_QUEUE_NUM (2)
#define VIRTIO_CONSOLE_IRQ (1)

/* block device (disk) */
#define SECTOR_SIZE         (512)
#define DISK_BUF_SIZE       (512 * 512)
#define DISK_SIZE           (64 * 1024 * 1024)
#define DISK_MAX_QUEUE_NUM  (4)
#define VIRTIO_DISK_IRQ     (2)
#define VIRTIO_BLK_T_IN     (0)
#define VIRTIO_BLK_T_OUT    (1)
#define VIRTIO_BLK_S_OK     (0)
#define VIRTIO_BLK_S_IOERR  (1)
#define VIRTIO_BLK_S_UNSUPP (2)

/**** PLIC (Platform-Level Interrupt Contoroller) 0x50000000 ~                         ****/
/******************************************************************************************/
#define PLIC_BASE_ADDR   (0x50000000) // NotChange:
#define PLIC_SIZE        (0x00400000)
#define PLIC_HART_BASE   (0x200000)
#define PLIC_HART_SIZE   (0x1000)

/**** CLINT (Core Local Interruputer) 0x60000000 ~                                     ****/
/******************************************************************************************/
#define CLINT_BASE_ADDR  (0x60000000) // NotChange:
#define CLINT_SIZE       (0x000c0000) //

/**** DRAM (Main Memory) 0x80000000 ~                                                  ****/
/******************************************************************************************/
#define DRAM_BASE_ADDR (0x80000000)
#define DRAM_SIZE      (64 * 1024 * 1024)
#define DRAM_MASK      (0x3fffffff)
#define D_PAGE_SHIFT   (12)          // page shift for page size of4KB
#define D_PAGE_MASK    (0x00000fff)  // page mask  for page size of4KB
#define TLB_SIZE       (4)


/******************************************************************************************/
#define DISK_MAGIC_VALUE       0x74726976
#define DISK_VERSION           2
#define DISK_DEVIDE_ID         2
#define DISK_VENDOR_ID         0xffff
#define DISK_DEVICE_FEATURES   1
#define DISK_CONFIG_GENERATION 0
#define DISK_QUEUE_NUM_MAX     4

typedef struct QueueState {
    uint32_t Ready;
    uint32_t Notify;
    uint32_t DescLow;
    uint32_t DescHigh;
    uint32_t AvailLow;
    uint32_t AvailHigh;
    uint32_t UsedLow;
    uint32_t UsedHigh;
    uint16_t last_avail_idx;
}QueueState;

typedef struct BlockRequestHeader {
    uint32_t type;
    uint32_t ioprio;
    uint64_t sector_num;
}BlockRequestHeader;

/* vring_desc_t from linux */
typedef struct Descriptor {
    uint64_t adr;
    uint32_t len;
    uint16_t flags;
    uint16_t next;
}Descriptor;

int disk_debug_num;
/******************************************************************************************/
void *memcpy(void *dest, const void *src, size_t n)
{
    int i;
    for(i = 0; i < n; i++)
    	((char *)dest)[i] = ((char *)src)[i];

    return dest;
}
/******************************************************************************************/
uint32_t ram_ld(uint32_t addr, int n, uint8_t *ram){
    if(n!=1 && n!=2 && n!=4){
        //printf("__ Error: ram_r() not supported n=%d\n", n);
        simrv_puts("__ Error: ram_r() not supported n=");
        simrv_puth(n);
        simrv_puts("\n");
        simrv_exit(0);
    }
    uint32_t data = 0;
    for (int i=0; i<n; i++) {
        //data |= ((uint32_t)ram[(addr + i) & DRAM_MASK]) << (8*i);     // NOTE!
        data |= ((uint32_t)ram[(addr + i) /*& DRAM_MASK*/]) << (8*i);
    }

    return data;
}
/******************************************************************************************/
void ram_st(uint32_t addr, uint32_t data, int n, uint8_t *ram){
    if(n!=1 && n!=2 && n!=4){
        //printf("__ Error: dsk_w() not supported n=%d\n", n);
        simrv_puts("__ Error: dsk_w() not supported n=");
        simrv_puth(n);
        simrv_puts("\n");
        simrv_exit(0);
    }
    if(n==1){
        ram[addr /*& DRAM_MASK*/] = data & 0xff;
    }
    else if (n==2){
        ram[ addr    /*& DRAM_MASK*/] =  data       & 0xff;
        ram[(addr+1) /*& DRAM_MASK*/] = (data >> 8) & 0xff;
    }
    else if (n==4){
        ram[ addr    /*& DRAM_MASK*/] =  data       & 0xff;
        ram[(addr+1) /*& DRAM_MASK*/] = (data >> 8) & 0xff;
        ram[(addr+2) /*& DRAM_MASK*/] = (data >>16) & 0xff;
        ram[(addr+3) /*& DRAM_MASK*/] = (data >>24) & 0xff;
    }
}

/***** disk load                                                                      *****/
/******************************************************************************************/
uint32_t dsk_ld(uint32_t addr, int n, uint8_t *dsk){
    if(n!=1 && n!=2 && n!=4){simrv_puts("__ Error: dsk_r() not supported n="); simrv_puth(n); simrv_puts("\n"); simrv_exit(0);}
    uint32_t data = 0;

    uint32_t* dsk_tmp = (uint32_t*)dsk;

    //for (int i=0; i<n; i++) { data |= ((uint32_t)dsk[addr + i]) << (8*i); }
    uint32_t t_data = (dsk_tmp[addr/4]);
    //uint32_t data2 = ((t_data & 0xff) << 24) | ((t_data & 0xff00) << 8) | ((t_data & 0xff0000) >> 8) | ((t_data & 0xff000000) >> 24);
    /*if(data != t_data){
        simrv_puth(addr);
        simrv_puts(" ");
        simrv_puth(data);
        simrv_puts(" ");
        simrv_puth(t_data);
        simrv_puts("\n");
    }*/
    //data = t_data;
    //if(DISK_DEBUG) printf("__%03d dsk r %d %08x %08x\n", disk_debug_num, n, addr, data);
    return t_data;
}

/***** disk store                                                                     *****/
/******************************************************************************************/
void dsk_st(uint32_t addr, uint32_t data, int n, uint8_t *dsk){
    // changed type of data from uint8_t to uint32_t
    if(n!=1 && n!=2 && n!=4){simrv_puts("__ Error: dsk_w() not supported n="); simrv_puth(n); simrv_puts("\n"); simrv_exit(0);}

    uint32_t* dsk_tmp = (uint32_t*)dsk;
    dsk_tmp[addr/4] = data;

    /*if(n==1){
        dsk[addr] = data & 0xff;
    }
    else if (n==2){
        dsk[ addr   ] =  data       & 0xff;
        dsk[(addr+1)] = (data >> 8) & 0xff;
    }
    else if (n==4){
        dsk[ addr   ] =  data       & 0xff;
        dsk[(addr+1)] = (data >> 8) & 0xff;
        dsk[(addr+2)] = (data >>16) & 0xff;
        dsk[(addr+3)] = (data >>24) & 0xff;
    }*/
    //if(DISK_DEBUG) printf("__%03d dsk w %d %08x %08x\n", disk_debug_num, 1, addr, data);
}

/*** update the used ring                                                              ****/
/******************************************************************************************/
void update_descriptor(uint32_t desc_idx, uint32_t desc_len, int q_num, 
                       QueueState *qs, uint8_t *mmem){
    /* vring_used_t is struct {__virtio16 flags, idx;  vring_used_elem_t {__virtio32 id, len;} ring[];}.*/
    uint32_t addr_used_idx = qs->UsedLow + 2;
    uint32_t index = (uint16_t)ram_ld(addr_used_idx, 2, mmem);

    ram_st(addr_used_idx, index+1, 2, mmem);

    // sizeof(vring_used_elem_t)=8. offsetof(vring_used_t, ring)=4.
    uint32_t addr_used_entry = qs->UsedLow + 4 + (index & (q_num - 1)) * 8;
    ram_st(addr_used_entry,   desc_idx, 4, mmem);
    ram_st(addr_used_entry+4, desc_len, 4, mmem);
}

/******************************************************************************************/
#define DESC_SIZE 16 /* Descriptor type size is 16 bytes */
/******************************************************************************************/
/*** console_request for display output                                                ****/
/******************************************************************************************/
void cons_request(uint8_t *mmem, uint32_t q_num, QueueState *qs){
    Descriptor desc;
    uint8_t *p;
    disk_debug_num++; /* just for debug */

    /* vring_avail_t is struct {__virtio16 flags, idx, ring[];} */
    uint16_t avail_idx = (uint16_t)ram_ld(qs->AvailLow+2, 2, mmem);
    while (qs->last_avail_idx != avail_idx) { ///// Note!!

        // sizeof(__virtio16)=2 and ring[] is of type __virtio16. offsetof(vring_avail_t, ring)=4.
        uint32_t adr = qs->AvailLow + 4 + (qs->last_avail_idx & (q_num - 1)) * 2;
        uint16_t desc_idx_header = ram_ld(adr, 2, mmem);
        uint32_t desc_adr_header = desc_idx_header * DESC_SIZE + qs->DescLow;

        p = (uint8_t*)&desc;
        for(int i=0; i<DESC_SIZE; i++){ *p = ram_ld(desc_adr_header+i, 1, mmem); p++; }

        for(int i=0; i<(int)desc.len; i++){ /***** write to stdout *****/
            uint8_t d = ram_ld(desc.adr+i, 1, mmem);
            simrv_putc(d);
        }

        update_descriptor(desc_idx_header, 0, q_num, qs, mmem);
	// verilog console.v stores this incrementation result.
        qs->last_avail_idx++;
    }
}

/******************************************************************************************/
/*** disc sector read & write                                                          ****/
/******************************************************************************************/
void disk_request(uint8_t *mmem, uint8_t *mdsk, int q_num, QueueState *qs){
    Descriptor desc;
    BlockRequestHeader header;
    uint8_t *p;
    disk_debug_num++; /* just for debug */

    uint16_t avail_idx = (uint16_t)ram_ld(qs->AvailLow+2, 2, mmem);
    while (qs->last_avail_idx != avail_idx) { /***** header -> sector -> footer *****/

        // (1) header
        uint32_t adr = qs->AvailLow + 4 + (qs->last_avail_idx & (q_num - 1)) * 2;
        uint16_t desc_idx_header = ram_ld(adr, 2, mmem);
        uint32_t desc_adr_header = desc_idx_header * DESC_SIZE + qs->DescLow;

        p = (uint8_t*)&desc;
        for(int i=0; i<DESC_SIZE; i++){ *p = ram_ld(desc_adr_header+i, 1, mmem); p++; }

        p = (uint8_t*)&header;
        for(int i=0; i<(int)desc.len; i++){ *p = ram_ld(desc.adr+i, 1, mmem); p++; }
        if (desc.len!=16) { simrv_puts("__ ERROR: disk_request() desc.len!=16\n"); simrv_exit(0); }

        // (2) sector
        uint16_t desc_idx_sector = desc.next;
        uint32_t desc_adr_sector = desc_idx_sector * DESC_SIZE + qs->DescLow;
        p = (uint8_t*)&desc;
        for(int i=0; i<DESC_SIZE; i++){ *p = ram_ld(desc_adr_sector+i, 1, mmem); p++; }

        uint32_t sector_len = desc.len;
        uint32_t sector_adr = (uint32_t)desc.adr;
        
        // (3) footer
        uint16_t desc_idx_footer = desc.next;
        uint32_t desc_adr_footer = desc_idx_footer * DESC_SIZE + qs->DescLow;
        p = (uint8_t*)&desc;
        for(int i=0; i<DESC_SIZE; i++){ *p = ram_ld(desc_adr_footer+i, 1, mmem); p++; }

        uint32_t footer_adr = (uint32_t)desc.adr;
 
        uint32_t request_size = 0;
        switch (header.type) {
        case VIRTIO_BLK_T_IN: { /////  disk -> dram
            request_size = sector_len + 1;
            for(int i=0; i<(int)sector_len; i=i+4){ //++){
                uint32_t d = dsk_ld(header.sector_num * SECTOR_SIZE + i, 4, mdsk);
                ram_st(sector_adr+i, d, 4, mmem);
            }
            ram_st(footer_adr, 0, 1, mmem); //  VIRTIO_BLK_S_OK
            break; }
        case VIRTIO_BLK_T_OUT: { ///// dram -> disk
            request_size = 1;
            for(int i=0; i<(int)sector_len; i=i+4){
                uint32_t d = ram_ld(sector_adr, 4, mmem);
                dsk_st(header.sector_num * SECTOR_SIZE + i, d, 4, mdsk);
            }
            ram_st(sector_adr+sector_len-1, 0, 1, mmem); //  VIRTIO_BLK_S_OK
            break; }
        default: { simrv_puts("__ ERROR: disk unknown header "); simrv_puth(header.type); simrv_puts("\n"); simrv_exit(0); }
        }

        update_descriptor(desc_idx_header, request_size, q_num, qs, mmem);
        qs->last_avail_idx++;
    }
}

/******************************************************************************************/
/*** input from keyboard                                                               ****/
/******************************************************************************************/
void kbrd_request(uint8_t *mmem, uint32_t q_num, QueueState *qs, uint8_t buf){
    Descriptor desc;
    uint8_t *p;

    //buf = 'a';
    if (!qs->Ready) return;

    //simrv_puts("READY\n");

    /* vring_avail_t is struct {__virtio16 flags, idx, ring[];} */
    uint16_t avail_idx = (uint16_t)ram_ld(qs->AvailLow+2, 2, mmem);
    if (qs->last_avail_idx == avail_idx) return;
    //simrv_puts("AVAIL\n");
    // sizeof(__virtio16)=2 and ring[] is of type __virtio16. offsetof(vring_avail_t, ring)=4.
    uint32_t adr = qs->AvailLow + 4 + (qs->last_avail_idx & (q_num - 1)) * 2;
    uint16_t desc_idx_header = ram_ld(adr, 2, mmem);
    uint32_t desc_adr_header = desc_idx_header * DESC_SIZE + qs->DescLow;

    p = (uint8_t*)&desc;
    for(int i=0; i<DESC_SIZE; i++){ *p = ram_ld(desc_adr_header+i, 1, mmem); p++; }

    ram_st(desc.adr, (uint32_t)buf, 1, mmem); /*****/

    update_descriptor(desc_idx_header, 1, q_num/*2*/, qs, mmem);
    qs->last_avail_idx++;
    //simrv_puts("RET\n");
}

/******************************************************************************************/
int main(){

    // Mode (1: Console, 2: Disk). This is r_mc_mode in verilog.
    uint32_t *MODE = (uint32_t*)0x40009000;
    uint32_t mode = *MODE;

    // QNUM
    uint32_t* QNUM;
    QNUM = (uint32_t*)0x40009004;
    int qnum = *QNUM;
    
    // QSEL
    uint32_t* QSEL;
    QSEL = (uint32_t*)0x40009008;
    int idx = *QSEL;

    // Queues for Console
    QueueState *CONS_Q;
    CONS_Q = (QueueState *)0x4000a000;
    // Queues for Disk
    QueueState *DISK_Q;
    DISK_Q = (QueueState *)0x4000b000;

    // Keyboard input buffer
    uint8_t *CONS_FIFO = (uint8_t*)0x4000c000;
    int cons_fifo = *CONS_FIFO;

    if((idx > 1 && mode==1)){
        simrv_puts("ERROR! INDEX OVERFLOW MODE1\n");
    }
    else if((idx > 3 && mode==2)){
        simrv_puts("ERROR! INDEX OVERFLOW MODE2\n");
    }
    /*else if((idx > 0 && mode==3)){
        simrv_puts("ERROR! INDEX OVERFLOW MODE3\n");
    }*/

    QueueState* tc_queue = (idx==0) ? &CONS_Q[0] : &CONS_Q[1];
    QueueState* td_queue = (idx==0) ? &DISK_Q[0] : (idx==1) ? &DISK_Q[1] : (idx==2) ? &DISK_Q[2] : &DISK_Q[3];

//#define DEBUG_ONLY
#ifdef DEBUG_ONLY
    int n=1000000, sum=0;
    simrv_putc('a');
    sum += sleep_fct(n);
    simrv_putc('u');
    sum += sleep_fct(n);
    simrv_putc('r');
    simrv_puth(sum);
    simrv_exit();
#endif

    if(mode == 1){
	//simrv_puts("MODE1\n");
	// qnum=idx=1 tc_queue = &CONS_Q[1].
	//simrv_puts("MODE1 qnum="); simrv_puth(qnum); simrv_puts("\n");
        cons_request(0, qnum, tc_queue);
    }
    else if(mode == 2){
	//simrv_puts("MODE2\n");
        disk_request(0, (uint8_t *)0x90000000, qnum, td_queue);
    }
    else if(mode == 3){
	//simrv_puts("MODE3 qnum="); simrv_puth(qnum); simrv_puts(" cons_fifo="); simrv_puth(cons_fifo); simrv_puts("\n");
	// qnum=2
        kbrd_request(0, qnum, &CONS_Q[0], cons_fifo);
    } else {
	simrv_puts("Unknown MODE!\n");
    }

    simrv_exit();
}
/******************************************************************************************/
