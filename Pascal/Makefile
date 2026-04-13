FPC = fpc
FPCFLAGS = -O2 -Mobjfpc -Sh -Fl/opt/homebrew/lib

spectrumify: spectrumify.pas sdl2.pas
	$(FPC) $(FPCFLAGS) spectrumify.pas

clean:
	rm -f spectrumify spectrumify.o spectrumify.ppu *.o *.ppu

.PHONY: clean
