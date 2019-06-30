CFLAGS = -Wall -g
LDFLAGS = -lm
all: tdc-ctl tdc-tests
test: tdc-tests
	./tdc-tests

tdc-ctl:   tdc_control.o
tdc-tests: tdc_control.o

.PHONY: clean

clean:
	rm -f *.o tdc-ctl tdc-tests


	