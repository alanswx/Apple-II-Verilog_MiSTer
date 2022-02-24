#pragma once
#include <iostream>
#include <fstream>
#include "verilated_heavy.h"
#include "sim_console.h"


#ifndef _MSC_VER
#else
#define WIN32
#endif


struct SimBlockDevice {
public:

	IData* sd_lba[10];
	CData* sd_rd;
	CData* sd_wr;
	CData* sd_ack;
	SData* sd_buff_addr;
	CData* sd_buff_dout;
	CData* sd_buff_din[10];
	CData* sd_buff_wr;
	CData* img_mounted;
	CData* img_readonly;
	QData* img_size;

	int bytecnt;
        long int disk_size[10];
	bool reading;
	bool writing;
	int ack_delay;
	int current_disk;
	bool mountQueue[10];
	std::ifstream disk[10];

	void BeforeEval(int cycles);
	void AfterEval(void);
	//void QueueDownload(std::string file, int index);
	//void QueueDownload(std::string file, int index, bool restart);
	//bool HasQueue();
	void MountDisk( std::string file, int index);

	SimBlockDevice(DebugConsole c);
	~SimBlockDevice();


private:
	//std::queue<SimBus_DownloadChunk> downloadQueue;
	//SimBus_DownloadChunk currentDownload;
	//void SetDownload(std::string file, int index);
};
