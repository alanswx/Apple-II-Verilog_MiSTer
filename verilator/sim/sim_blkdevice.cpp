#include <iostream>
#include <queue>
#include <string>

#include "sim_blkdevice.h"
#include "sim_console.h"
#include "verilated_heavy.h"

#ifndef _MSC_VER
#else
#define WIN32
#endif


static DebugConsole console;

IData* sd_lba[10]= {NULL,NULL,NULL,NULL,NULL,
                   NULL,NULL,NULL,NULL,NULL};
CData* sd_rd=NULL;
CData* sd_wr=NULL;
CData* sd_ack=NULL;
SData* sd_buff_addr=NULL;
CData* sd_buff_dout=NULL;
CData* sd_buff_din[10]= {NULL,NULL,NULL,NULL,NULL,
                   NULL,NULL,NULL,NULL,NULL};
CData* sd_buff_wr=NULL;
CData* img_mounted=NULL;
CData* img_readonly=NULL;
QData* img_size=NULL;


#define bitset(byte,nbit)   ((byte) |=  (1<<(nbit)))
#define bitclear(byte,nbit) ((byte) &= ~(1<<(nbit)))
#define bitflip(byte,nbit)  ((byte) ^=  (1<<(nbit)))
#define bitcheck(byte,nbit) ((byte) &   (1<<(nbit)))


void SimBlockDevice::MountDisk( std::string file, int index) {
	disk[index].open(file.c_str(), std::ios::in | std::ios::binary | std::ios::ate);
        if (disk[index]) {
           // we shouldn't do the actual mount here..
           disk_size[index]= disk[index].tellg();
	//fprintf(stderr,"mount size %ld\n",disk_size[index]);
           disk[index].seekg(0);
           mountQueue[index]=1;
           printf("disk %d inserted (%s)\n",index,file.c_str());
        }

}


void SimBlockDevice::BeforeEval(int cycles)
{
//
// switch to a new disk if current_disk is -1
// check to see if we need a read or a write or a mount
//

// wait until the computer boots to start mounting, etc
 if (cycles<2000) return;

 for (int i=0; i<10;i++)
 {

    if (current_disk == i) {
    // send data
    if (ack_delay==1) {
      if (reading && (*sd_buff_wr==0) &&  (bytecnt<512)) {
         *sd_buff_dout = disk[i].get();
         *sd_buff_addr = bytecnt++;
         *sd_buff_wr= 1;
         //printf("cycles %x reading %X : %X \n",cycles,*sd_buff_addr,*sd_buff_dout );
      } else {
	  *sd_buff_wr=0;
          if (bytecnt==512)
	       reading=writing=0;	
      }
    } else {
	  *sd_buff_wr=0;
    } 
    }

    // issue a mount if we aren't doing anything, and the img_mounted has no bits set
    if (!reading && !writing && mountQueue[i] && !*img_mounted) {
//fprintf(stderr,"mounting.. %d\n",i);
           mountQueue[i]=0;
           *img_size = disk_size[i];
//fprintf(stderr,"img_size .. %ld\n",*img_size);
           disk[i].seekg(0);
           bitset(*img_mounted,i);
           ack_delay=1200;
    } else if (ack_delay==1 && bitcheck(*img_mounted,i) ) {
//fprintf(stderr,"mounting flag cleared  %d\n",i);
        bitclear(*img_mounted,i) ;
        *img_size = 0;
    }

    // start reading when sd_rd pulses high
    if ((current_disk==-1 || current_disk==i) && bitcheck(*sd_rd,i) ) {
       // set current disk here..
//fprintf(stderr,"setting current disk %d %x\n",i,*sd_rd);
       current_disk=i;
      if (!ack_delay) {
        int lba = *(sd_lba[i]);
        reading = true;
        disk[i].clear();
        disk[i].seekg((lba) * 512);
        printf("seek %06X lba: (%x) (%d,%d) drive %d\n", (lba) * 512,lba,lba,512,i);
        bytecnt = 0;
        ack_delay = 1200;
      }
    }

    if (current_disk == i) {
      if (ack_delay==1) 
      bitset(*sd_ack,i);
        else
      bitclear(*sd_ack,i);
      if((ack_delay > 1) || ((ack_delay == 1) && !reading && !writing))
        ack_delay--;
    }
  }
}

void SimBlockDevice::AfterEval()
{
}


SimBlockDevice::SimBlockDevice(DebugConsole c) {
	console = c;
        current_disk=-1;

        sd_rd = NULL;
        sd_wr = NULL;
        sd_ack = NULL;
        sd_buff_addr = NULL;
        sd_buff_dout = NULL;
	for (int i=0;i<10;i++) {
           sd_lba[i] = NULL;
	   sd_buff_din[i] = NULL;
           mountQueue[i]=0;
        }
        sd_buff_wr=NULL;
        img_mounted=NULL;
        img_readonly=NULL;
        img_size=NULL;
}

SimBlockDevice::~SimBlockDevice() {

}
