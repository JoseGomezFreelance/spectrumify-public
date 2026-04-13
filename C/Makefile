CC = cc
CFLAGS = -O2 -Wall -Wno-unused-function $(shell sdl2-config --cflags)
LDFLAGS = $(shell sdl2-config --libs)

spectrumify: main.c palette.h converter.h exporter.h ui.h stb_image.h stb_image_write.h msf_gif.h
	$(CC) $(CFLAGS) -o spectrumify main.c $(LDFLAGS) -lm

clean:
	rm -f spectrumify

.PHONY: clean
