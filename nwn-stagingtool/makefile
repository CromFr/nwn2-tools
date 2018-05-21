

all:
	gcc -O2 -Wall -D_7ZIP_ST -c lzma/Alloc.c lzma/LzFind.c lzma/LzmaDec.c lzma/LzmaEnc.c lzma/7zFile.c lzma/7zStream.c lzma/Util/Lzma/LzmaUtil.c
	#ar rvs liblzma.a Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o
	ld -r Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o -o lzma.o
	strip --strip-symbol=main lzma.o
	rm Alloc.o LzFind.o LzmaDec.o LzmaEnc.o 7zFile.o 7zStream.o LzmaUtil.o


