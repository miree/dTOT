#include "tdc_control.h"

#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

void write_raw_event(int fd, int channel, int timestamp, unsigned char sample)
{
	unsigned char data[5] = {
		0x80 | ((channel&0x7)<<4) | (sample>>4),
		0x00 | (( sample&0xf)<<3) | ((timestamp>>21)&0x7),
		0x00                      | ((timestamp>>14)&0x7f),
		0x00                      | ((timestamp>> 7)&0x7f),
		0x00                      | ((timestamp>> 0)&0x7f)
	 };
	 write(fd, data, 5);
}

char* sample_to_text(unsigned char ch, unsigned long time, int edge)
{
	static char str_out[9] = {0,};
	for(int i = 0; i < 8; ++i) {
		str_out[i] = (ch&0x80?'-':'_');
		ch <<= 1;
	}
	int idx = time%8;
	if (edge) {
		str_out[idx]='/';
	} else {
		str_out[idx]='\\';
	}
	return str_out;
}


void write_nanosecond_event(int fd, int channel, long delta_t, int reset)
{
	static long int time[TDC_N_CHANNELS] = {0,}; // time in units of 8ns
	static int level[TDC_N_CHANNELS] = {0,};
	if (reset) {
		for (int ch = 0; ch < TDC_N_CHANNELS; ++ch) {
			level[ch] = time[ch] = 0;
		}
	}
	time[channel] += delta_t;
	unsigned char sample = 0xff>>(time[channel]%8);
	if (level[channel]) {
		sample = ~sample;
	}

	// handle overflow
	while (time[channel] >= 0x8000000) {
		if (time[channel] > 0x8000000) {
			write_raw_event(fd, channel, 0, level[channel]?0xff:0x00);
		}
		time[channel] -= 0x8000000;
	} 

	//printf("write sample %s\n", sample_to_text(sample, sample, !level[channel]));
	write_raw_event(fd, channel, time[channel]/8, sample);

	level[channel] = !level[channel];
}

void pulser(int fd, int channel, int period, int pulse_length, int n_pulses) 
{
	for (int i = 0; i < n_pulses; ++i) {
		write_nanosecond_event(fd, channel, period-pulse_length, i==0);
		write_nanosecond_event(fd, channel, pulse_length, 0);
		int other_channel = channel;
		while (other_channel == channel) {
			other_channel = rand()%TDC_N_CHANNELS;
		}
		//write_nanosecond_event(fd, other_channel, rand()%period, 0);
		write_raw_event(fd, other_channel, rand()%0xfffffff, rand()%0xff);
	}
}

void run_pulser_test(int channel, int pulse_length, int n_pulses) {
	// create test data
	int fd = open("testdata.raw", O_CREAT | O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR);
	printf("fd=%d\n",fd);
	pulser(fd, channel, 10000001, pulse_length, n_pulses);
	close(fd);

	tdc_t *tdc = tdc_open("testdata.raw");
	tdc_event_t event;
	for(;;) {
		event = tdc_next_event(tdc);
		if (event.channel == -1) {
			break;
		}
		printf("%d %d %20ld     sample=0x%02x:%s   dt=%ld\n",	
			event.channel, 
			event.edge, 
			event.time, 
			event.sample,
			sample_to_text(event.sample, event.time, event.edge),
			event.dt);
		
		if (event.edge == TDC_EDGE_FALLING && event.channel == channel) {
			assert(event.dt == pulse_length);
		}
	} 
	tdc_close(tdc);
}

int main()
{

	for (int ch = 0; ch < TDC_N_CHANNELS; ++ch) {
		run_pulser_test(ch, 101, 1000);
	}


	printf("All tests passed!\n");

	return 0;
}