# 100% Assembly — sin C
AS = as
CC = clang
LDFLAGS = $(shell sdl2-config --libs) -lc

OBJS = main.o palette.o converter.o exporter.o ui.o font_data.o bmploader.o htmlwriter.o

spectrumify: $(OBJS)
	$(CC) -o $@ $(OBJS) $(LDFLAGS)

%.o: %.s
	$(AS) -o $@ $<

clean:
	rm -f spectrumify *.o

.PHONY: clean
