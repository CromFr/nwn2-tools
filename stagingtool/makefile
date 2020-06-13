
CFLAGS=
LDFLAGS=

all:
	gcc $(CFLAGS) -O2 -Wall -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
	ld $(LDFLAGS) -r Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o -o lzma.o
	strip --keep-symbol=main2 lzma.o
	rm Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o

# mingw-i686:
# 	i686-w64-mingw32-gcc $(CFLAGS) -m32 -O2 -Wall -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
# 	i686-w64-mingw32-ld $(LDFLAGS) -r Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o -o lzma.obj
# 	i686-w64-mingw32-strip --keep-symbol=_main2 lzma.obj
# 	# i686-w64-mingw32-strip --strip-symbol=_main lzma.obj
# 	rm *.o

mingw-x86_64:
	x86_64-w64-mingw32-gcc $(CFLAGS) -O2 -Wall -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
	x86_64-w64-mingw32-ld $(LDFLAGS) -r Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o -o lzma.obj
	x86_64-w64-mingw32-strip --keep-symbol=main2 lzma.obj
	rm *.o
