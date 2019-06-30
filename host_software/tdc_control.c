#include "tdc_control.h"
// POSIX header
#include <termios.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>

// C header
#include <stdio.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

tdc_t *tdc_open(const char *filename)
{
    int fd = open(filename, O_RDWR );//| O_NOCTTY | O_NDELAY);
	if (fd == -1)
	{
		printf("Couldn't open serial port\n");
		return NULL;
	}	

    struct termios raw;
	if (tcgetattr(fd, &raw) == 0)
	{
		// input modes - clear indicated ones giving: no break, no CR to NL, 
		//   no parity check, no strip char, no start/stop output (sic) control 
		raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);

		// output modes - clear giving: no post processing such as NL to CR+NL 
		raw.c_oflag &= ~(OPOST);

		// control modes - set 8 bit chars 
		raw.c_cflag |= (CS8);

		// local modes - clear giving: echoing off, canonical off (no erase with 
		//   backspace, ^U,...),  no extended functions, no signal chars (^Z,^C) 
		raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);

		// control chars - set return condition: min number of bytes and timer 
		raw.c_cc[VMIN] = 5; raw.c_cc[VTIME] = 8; // after 5 bytes or .8 seconds
		                                         //   after first byte seen   
		raw.c_cc[VMIN] = 0; raw.c_cc[VTIME] = 0; // immediate - anything      
		raw.c_cc[VMIN] = 2; raw.c_cc[VTIME] = 0; // after two bytes, no timer 
		raw.c_cc[VMIN] = 0; raw.c_cc[VTIME] = 8; // after a byte or .8 seconds

		// put terminal in raw mode after flushing 
		if (tcsetattr(fd,TCSAFLUSH,&raw) < 0) 
		{
			int err = errno;
			printf("Error, cant set raw mode: %s\n", strerror(err));
			return NULL;
		}
	}

	tdc_t *new_tdc = malloc(sizeof(tdc_t));
	new_tdc->fd               = fd;
	for (int i = 0; i < TDC_N_CHANNELS; ++i) {
		new_tdc->time[i] = 0;
		new_tdc->previous_time[i] = 0;
		new_tdc->overflow_count[i] = 0;
		new_tdc->sample[i] = 0;
		new_tdc->sample_idx[i] = 0;
		for (int s = 0; s < 8; ++s) {
			new_tdc->sample_stat[i][s] = 0;
		}
		new_tdc->sample_stat_total = 0;
	}
	return new_tdc;
}

void tdc_close(tdc_t *tdc)
{
	free(tdc);
}

void tdc_enable_channels(tdc_t *tdc, char pattern)
{
	// reset the overflow counters for all deactivated channels
	for (int ch = 0; ch < TDC_N_CHANNELS; ++ch) {
		if (!(pattern & (1<<ch))) { // if channel is disabled 
			printf("resetting overflow_count for ch=%d\n", ch);
			tdc->overflow_count[ch] = 0;
		}
	}
	// build the message;
	unsigned char msg = 0;
	msg |= (0xf<<4);
	msg |= ((pattern>>0) & 0xf);
	write(tdc->fd, &msg, 1);
}


void tdc_set_channel_threshold(tdc_t *tdc, int channel, int threshold)
{
	if (threshold < 0 || threshold > 0xfff) {
		fprintf(stderr, "infalid threshold: %d\n", threshold);
		return;
	}
	// build the message;
	unsigned char msg[3] = {0,0,0};
	msg[0] |= ((channel*3+0)<<4);
	msg[0] |= ((threshold>>0) & 0xf);
	msg[1] |= ((channel*3+1)<<4);
	msg[1] |= ((threshold>>4) & 0xf);
	msg[2] |= ((channel*3+2)<<4);
	msg[2] |= ((threshold>>8) & 0xf);
	write(tdc->fd, msg, 3);
}


int unpack_raw_event(unsigned char *five_bytes, raw_event_t *new_raw_event)
{
	new_raw_event->channel = (five_bytes[0]>>4)&0x7;

	if (new_raw_event->channel >= TDC_N_CHANNELS) {
		//printf("impossible channel number %d\n", new_raw_event->channel);
		return 0;
	}

	new_raw_event->time = 0;
	new_raw_event->time |= (five_bytes[1]&0x07); new_raw_event->time <<= 7;
	new_raw_event->time |= (five_bytes[2]&0x7f); new_raw_event->time <<= 7;
	new_raw_event->time |= (five_bytes[3]&0x7f); new_raw_event->time <<= 7;
	new_raw_event->time |= (five_bytes[4]&0x7f);  

	new_raw_event->sample = 0;
	new_raw_event->sample |= (five_bytes[0]&0x0f)   ; new_raw_event->sample <<= 4;
	new_raw_event->sample |= (five_bytes[1]&0x78)>>3;

	return 1;	
}

int too_quickly(double threshold_sec)
{
	static struct timespec then = {.tv_sec=0};
	struct timespec now;
	int result = clock_gettime(CLOCK_REALTIME, &now);

	if (result == -1) {
		return 1; // failure to get time is also "too quickly"
	}

	result = 0;
	if (then.tv_sec != 0) {
		double delta_t = now.tv_sec - then.tv_sec + 1e-9*(now.tv_nsec - then.tv_nsec);
		if (delta_t < threshold_sec) {
			result = 1;
		}
	}
	then = now;
	return result;
}

raw_event_t eof_raw_event() {
	raw_event_t eof_raw_evt = {.channel = -1};
	return eof_raw_evt;
}

raw_event_t next_raw_event(tdc_t *tdc)
{
	raw_event_t new_raw_evt;
	unsigned char data[5]; // 5 bytes for one event
	do {
		data[0] = data[1] = data[2] = data[3] = data[4] = 0;
		int result;
		// read 5 bytes;
			while( ((result=read(tdc->fd, &data[0], 5)) != 5) ) {
				if (!result && too_quickly(0.1)) {// EOF
					return eof_raw_event();
				}
			}

		// check if data[0] is a header, if not read and shift until this is the case
		while((data[0]&0x80) != 0x80 ) {
			data[0] = data[1];
			data[1] = data[2];
			data[2] = data[3];
			data[3] = data[4];
			while((result=read(tdc->fd, &data[4], 1)) != 1) {
				if (!result && too_quickly(0.1)) {
		 			return eof_raw_event();
				}
			}
		}
	} while (!unpack_raw_event(data, &new_raw_evt));
	// check for impossible channel number because that could cause SEGFAULTS later
	return new_raw_evt;
}

tdc_event_t tdc_next_event(tdc_t *tdc)
{
	tdc_event_t new_event;
	int need_to_scan = 1;
	for (;;) {
		if (need_to_scan) {
			//printf("scanning\n");
			for (int ch = 0; ch < TDC_N_CHANNELS; ++ch) {
				int           *idx   = &tdc->sample_idx[ch];
				unsigned char sample = tdc->sample[ch];
				while (*idx != 0) { // we are not done processing the sample
					// look at bits idx and idx-1 and see if they form a rising or falling edge
					// ~~~~____
					//    ^idx
					//     ^idx-1
					// indicator = ~_ = 10 = 2
					int indicator = (sample>>(*idx-1))&0x03;
					//printf("idx %d    indicator %d\n", *idx, indicator);
					--*idx;
					switch(indicator) {
						case 1: //rising edge
							new_event.channel = ch;
							new_event.time    = ( ( tdc->time[ch] + (tdc->overflow_count[ch]<<24) ) << 3 ) + (7-*idx);
							new_event.dt      = new_event.time - tdc->previous_time[ch];
							tdc->previous_time[ch] = new_event.time;
							new_event.edge    = TDC_EDGE_RISING;
							new_event.sample  = sample;
							if (tdc->sample_stat_total < 100000) {
								++tdc->sample_stat[ch][7-*idx];
								++tdc->sample_stat_total;
							}
							return new_event;
						break;
						case 2: //falling edge
							new_event.channel = ch;
							new_event.time    = ( ( tdc->time[ch] + (tdc->overflow_count[ch]<<24) ) << 3 ) + (7-*idx);
							new_event.dt      = new_event.time - tdc->previous_time[ch];
							tdc->previous_time[ch] = new_event.time;
							new_event.edge    = TDC_EDGE_FALLING;
							new_event.sample  = sample;
							if (tdc->sample_stat_total < 100000) {
								++tdc->sample_stat[ch][7-*idx];
								++tdc->sample_stat_total;
							}
							return new_event;
						break;
					}
				}
			}
		}

		// no events pending. Load new data
		raw_event_t revent = next_raw_event(tdc);
		int           ch = revent.channel;
		if (ch == -1) { // EOF raw event
			new_event.channel = -1;
			return new_event;
		}
		unsigned char new_sample = revent.sample;
		//if (ch == 0)
			//printf("NEW channel %d, time %d, old_sample %02x, sample %02x\n", revent.channel, revent.time, tdc->sample[ch], new_sample);
		if (revent.time == 0) {
			++tdc->overflow_count[ch]; // overflow of the hardware counter
			//printf("cahnnel %d overflow %ld  time %ld \n", ch, tdc->overflow_count[ch], revent.time);
		} 
		tdc->time[ch] = revent.time;
		if (stays_high_between_samples(tdc->sample[ch], new_sample)) {
			tdc->sample[ch] = new_sample;
			if (new_sample == 0xff) { // no edge there
				need_to_scan = 0;  // we don't need to look at all indices again, directly load next raw event, sample idx stays at 0
			} else { // the edge is in the middle of the sample
				need_to_scan = 1;
				tdc->sample_idx[ch] = 7;
			}
			continue;
		}
		if (stays_low_between_samples(tdc->sample[ch], new_sample)) {
			tdc->sample[ch] = new_sample;
			if (new_sample == 0x00) { // no edge there
				need_to_scan = 0;  // we don't need to look at all indices again, directly load next raw event, sample idx stays at 0
			} else { // the edge is in the middle of the sample
				need_to_scan = 1;
				tdc->sample_idx[ch] = 7;
			}
			continue;
		}
		new_event.channel = ch;
		new_event.time    = (tdc->time[ch] + (tdc->overflow_count[ch]<<24)) << 3; 
		new_event.dt      = new_event.time - tdc->previous_time[ch];
		tdc->previous_time[ch] = new_event.time;
		new_event.sample   = new_sample;
		//printf("goes goes_low_between_samples?\n");
		if (goes_low_between_samples(tdc->sample[ch], new_sample)) {
			//printf("goes goes_low_between_samples!\n");
			new_event.edge  = TDC_EDGE_FALLING;
			tdc->sample[ch] = new_sample;
			tdc->sample_idx[ch] = 7;
			if (tdc->sample_stat_total < 100000) {
				++tdc->sample_stat[ch][0];
				++tdc->sample_stat_total;
			}
			return new_event;
		}
		//printf("goes goes_high_between_samples?\n");
		if (goes_high_between_samples(tdc->sample[ch], new_sample)) {
			//printf("goes goes_high_between_samples!\n");
			new_event.edge  = TDC_EDGE_RISING;
			tdc->sample[ch] = new_sample;
			tdc->sample_idx[ch] = 7;
			if (tdc->sample_stat_total < 100000) {
				++tdc->sample_stat[ch][0];
				++tdc->sample_stat_total;
			}
			return new_event;
		}
		printf("you should never see this text\n" );
	}

}

int stays_high_between_samples(unsigned char last_sample, unsigned char new_sample)
{   
	// last_sample  new_sample
	//  ____~~~~    ~~~~____
	//         ^    ^  both are high
	return ((last_sample&0x01) == 0x01) && ((new_sample&0x80) == 0x80);
}
int stays_low_between_samples (unsigned char last_sample, unsigned char new_sample)
{
	// last_sample  new_sample
	//  ~~~_____    __~~~~~~
	//         ^    ^  both are low
	return ((last_sample&0x01) == 0x00) && ((new_sample&0x80) == 0x00);
}
int goes_high_between_samples (unsigned char last_sample, unsigned char new_sample)
{
	// last_sample  new_sample
	//  ~~~_____    ~~~~~~__
	//         ^    ^  goes high
	return ((last_sample&0x01) == 0x00) && ((new_sample&0x80) == 0x80);
}
int goes_low_between_samples  (unsigned char last_sample, unsigned char new_sample)
{
	// last_sample  new_sample
	//  ~~~__~~~    ________
	//         ^    ^  goes low
	return ((last_sample&0x01) == 0x01) && ((new_sample&0x80) == 0x00);
}

double tdc_smooth_time(tdc_t *tdc, tdc_event_t *event) 
{
	int ch = event->channel;
	int sample = event->time % 8;
	double time = event->time - sample;
	for (int i = 0; i < sample; ++i) {
		time += 8.0*tdc->sample_stat[ch][i]/tdc->sample_stat_total;
	}
	time += 8.0*tdc->sample_stat[ch][sample]/tdc->sample_stat_total * rand()/RAND_MAX;
	return time;
}

int tdc_get_level(tdc_t *tdc, int channel)
{
	return (tdc->sample[channel]>>tdc->sample_idx[channel]) & 0x01;
}
