obj-$(CONFIG_CRYPTO_LZ4KD) += lz4kd.o

lz4kd-objs := \
	lz4kd_crypto.o \
	lz4kd_encode.o \
	lz4kd_decode.o \
	lz4kd_encode_delta.o \
	lz4kd_decode_delta.o

ccflags-y += -I$(src)/include -DLZ4K_DELTA -O3

