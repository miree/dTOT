#include <stdio.h> 
#include <unistd.h> 
#include <time.h>

#include "tdc_control.h"

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


int too_quickly2(double threshold_sec)
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


int main(int argc, char *argv[]) 
{ 
	int opt; 

	int enable_pattern = -1;
	int thresholds[TDC_N_CHANNELS] = {-1,-1,-1,-1};
	int channel, threshold;
	int snoop = 1;
	tdc_t *tdc = 0;

	
	// put ':' in the starting of the 
	// string so that program can 
	//distinguish between '?' and ':' 
	while((opt = getopt(argc, argv, ":se:t:")) != -1) 
	{ 
		switch(opt) 
		{ 
			case 'e': 
				snoop = 0;
				enable_pattern = 0;
				for (int i = 0; i < 4; ++i) {
					if (optarg[i] == '\0' || (optarg[i] != '0' && optarg[i] != '1')) {
						fprintf(stderr, "invalid enable bit pattern %s, must be a sequenc of for characters: '0' or '1'\n", optarg);
					} else {
						if (optarg[i] == '1') {
							enable_pattern |= 1<<i;
							printf("enable channel %d\n", i);
						} else {
							printf("disable channel %d\n", i);
						}
					}
				}
				break; 
			case 't': 
				snoop = 0;
				channel = threshold = -1;
				printf("threshold: %s\n", optarg); 
				sscanf(optarg,"%d:%d",&channel,&threshold);
				if (threshold < 0 || threshold >= TDC_THRESHOLD_RANGE) {
					fprintf(stderr, "invalid threshold %d, must be in range [%d,%d]\n", threshold, 0, TDC_THRESHOLD_RANGE-1);
					return 1;
				}
				if (channel < 0 || channel >= TDC_N_CHANNELS) {
					fprintf(stderr, "invalid channel number %d, must be in range [%d,%d]\n", channel, 0, TDC_N_CHANNELS);
					return 1;
				}
				thresholds[channel] = threshold;
				break; 
			case ':': 
				printf("option needs a value\n"); 
				break; 
			case '?': 
				printf("unknown option: %c\n", optopt); 
				break; 
		} 
	} 
	
	// optind is for the extra arguments 
	// which are not parsed 
	for(; optind < argc; optind++){	 
		//printf("extra arguments: %s\n", argv[optind]); 
		printf("device: %s\n", argv[optind]); 
		tdc = tdc_open(argv[optind]);
		if (!tdc) {
			fprintf(stderr, "cannot open device %s\n", optarg);
			return 1;
		} else {
			break;
		}
	} 

	if (tdc && enable_pattern != -1) {
		printf("enable pattern = %d\n", enable_pattern);
		tdc_enable_channels(tdc, enable_pattern);
	}

	for (int ch = 0; ch < TDC_N_CHANNELS; ++ch) {
		if (tdc && thresholds[ch] != -1) {
			tdc_set_channel_threshold(tdc, ch, thresholds[ch]);
		}
	}

	if (snoop) {
		long int previous_time = 0;
		for (;;) {
			tdc_event_t event = tdc_next_event(tdc);
			if (event.channel == -1) {
				break;
			}
			if (event.time < previous_time) {
				printf("%d %d %20ld     sample=0x%02x:%s   dt=%ld\n",	
					event.channel, 
					event.edge, 
					event.time, 
					event.sample,
					sample_to_text(event.sample, event.time, event.edge),
					event.dt);
			}
			previous_time = event.time;
		}
	}

	
	if (tdc) {
		tdc_close(tdc);
	}
	return 0; 
} 