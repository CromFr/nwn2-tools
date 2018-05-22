
GCCFLAGS=
LDFLAGS=

all:
	gcc $(GCCFLAGS) -O2 -Wall -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
	ld $(LDFLAGS) -r Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o -o lzma.o
	rm Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o
	strip --strip-symbol=main lzma.o


win-x86:
	i686-w64-mingw32-gcc $(GCCFLAGS) -O2 -Wall -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
	ld $(LDFLAGS) -r Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o -o lzma.o
	rm Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o
	strip --strip-symbol=main lzma.o
