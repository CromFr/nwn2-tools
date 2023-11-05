
CFLAGS=
LDFLAGS=

LZMA_SRC= \
	Alloc.c \
	CpuArch.c \
	LzFind.c \
	LzmaDec.c \
	LzmaEnc.c \
	LzFindMt.c \
	7zFile.c \
	7zStream.c \
	Util/Lzma/LzmaUtil.c \
	Threads.c

all:
	cd lzma/ && gcc $(CFLAGS) -O2 -Wall -D_7ZIP_ST -Dmain=lzma_main -c $(LZMA_SRC)
	cd lzma/ && ld $(LDFLAGS) -o ../lzma.o -r $(notdir $(LZMA_SRC:.c=.o))
	strip -K lzma_main -K _lzma_main -K eh_frame lzma.o

mingw-i686:
	cd lzma/ && i686-w64-mingw32-gcc $(CFLAGS) -m32 -O2 -Wall -D_7ZIP_ST -Dmain=lzma_main -c $(LZMA_SRC)
	cd lzma/ && i686-w64-mingw32-ld $(LDFLAGS) -o ../lzma.obj -r $(notdir $(LZMA_SRC:.c=.o))
	i686-w64-mingw32-strip -K lzma_main -K _lzma_main -K eh_frame lzma.obj

mingw-x86_64:
	cd lzma/ && x86_64-w64-mingw32-gcc $(CFLAGS) -O2 -Wall -D_7ZIP_ST -Dmain=lzma_main -c $(LZMA_SRC)
	cd lzma/ && x86_64-w64-mingw32-ld $(LDFLAGS) -o ../lzma.obj -r $(notdir $(LZMA_SRC:.c=.o))
	x86_64-w64-mingw32-strip -K lzma_main -K _lzma_main -K eh_frame lzma.obj
