
CFLAGS=
LDFLAGS=

all:
	gcc $(CFLAGS) -O2 -Wall -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
	ld $(LDFLAGS) -r Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o -o lzma.o
	rm Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o
	strip --strip-symbol=main lzma.o


wine-dmc:
	wine dmc $(CFLAGS) -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
	wine lib -c liblzma.lib *.obj
	sed -i 's/\x05_main/\x05_____/' liblzma.lib

msvc:
	# Provided as example, you'll need to set correct executable paths and run sed from a Linux terminal
	# Tested with VS2015 x64 Native
	cl /c lzma/*.c lzma/Util/Lzma/*.c
	lib /out:liblzma.lib *.obj
	sed -i 's/\x00main\x00/\x00____\x00/' liblzma.lib
