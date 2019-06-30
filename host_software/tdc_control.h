#ifndef GET_EVENT_H
#define GET_EVENT_H

#define TDC_N_CHANNELS 4
#define TDC_THRESHOLD_RANGE 4096

//////////////////////////////////////////
// main tdc data structure 
// don't touch the fields 
//////////////////////////////////////////
typedef struct s_tdc_t
{
	int           fd;
	unsigned long time[TDC_N_CHANNELS];
	unsigned long previous_time[TDC_N_CHANNELS];
	unsigned long overflow_count[TDC_N_CHANNELS];
	unsigned char sample[TDC_N_CHANNELS];
	int           sample_idx[TDC_N_CHANNELS];
	int           sample_stat[TDC_N_CHANNELS][8];
	int           sample_stat_total;
} tdc_t;


//////////////////////////////////////////
// functions and structures for the user
//////////////////////////////////////////

tdc_t *tdc_open(const char *filename);
void   tdc_close(tdc_t *tdc);


enum tdc_enable_channel_bits {
	TDC_CH0 = 0x01,
	TDC_CH1 = 0x02,
	TDC_CH2 = 0x04,
	TDC_CH3 = 0x08,
};
void tdc_enable_channels(tdc_t *tdc, char pattern);
void tdc_reset_overflow_counter(tdc_t *tdc, char pattern);
void tdc_set_channel_threshold(tdc_t *tdc, int channel, int threshold);

typedef enum e_edge_t
{
	TDC_EDGE_FALLING,
	TDC_EDGE_RISING,
} edge_t;

typedef struct s_event_t
{
	int           channel;
	unsigned long time;    // in units of [1 ns]
	edge_t        edge;
	unsigned char sample;
	unsigned long dt; // ns since previous pulse
} tdc_event_t;

tdc_event_t   tdc_next_event(tdc_t *tdc);
double    tdc_smooth_time(tdc_t *tdc, tdc_event_t *event);

int tdc_get_level(tdc_t *tdc, int channel);

//////////////////////////////////////////
// internal data structures
//////////////////////////////////////////

typedef struct s_raw_event_t
{
	int           channel;
	unsigned long time;    // in units of [8 ns]
	unsigned char sample;
} raw_event_t;

raw_event_t upack_raw_event(unsigned char *five_bytes);
raw_event_t next_raw_event(tdc_t *tdc);

int stays_high_between_samples(unsigned char last_sample, unsigned char new_sample);
int stays_low_between_samples (unsigned char last_sample, unsigned char new_sample);
int goes_high_between_samples (unsigned char last_sample, unsigned char new_sample);
int goes_low_between_samples  (unsigned char last_sample, unsigned char new_sample);






#endif

