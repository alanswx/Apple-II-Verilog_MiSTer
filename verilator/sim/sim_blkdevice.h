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

	IData* sd_lba[2];
	CData* sd_rd;
	CData* sd_wr;
	CData* sd_ack;
	SData* sd_buff_addr;
	CData* sd_buff_dout;
	CData* sd_buff_din[2];
	CData* sd_buff_wr;
	CData* img_mounted;
	CData* img_readonly;
	QData* img_size;

	int bytecnt;
	bool reading;
	bool writing;
	int old_dsk_rd;
	int old_lba;
	int ack_delay;
	
	std::ifstream disk[2];

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
