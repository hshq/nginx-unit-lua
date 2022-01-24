return {
    LIB_NAME = 'lcodec',
    DEP_OBJS = {'../deps/base64/lib/libbase64.o'},
    O_FILES  = {'lib-codec.o',
                '../deps/gityf_crc/crc32.o'},
    INC_DIRS = {'../deps',
                '/usr/local/opt/openssl/include/',},
}