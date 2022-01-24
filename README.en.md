# nginx-unit-lua

## English doc / [中文文档](README.md)

#### Description
From Baidu translation.

Lua5.4/luajit of Nginx-Unit support.
It can run the Lor framework and make targeted openresty adaptation.

Only the HTTP function is preliminarily realized.
Only tested on MacOS.

#### Software Architecture
Lua is not integrated into Unit like those languages officially supported by Unit,
It is in the form of an external application (the configuration type is `external`).

When the Unit starts (or when the application configuration changes), start the Lua application process according to the configuration.
Interact with the Unit communication module that has been compiled into the Lua shared library.
The Unit main process will start three functional process controllers, routers and application prototypes,
And several application processes, and various processes communicate with each other.

#### Installation

1.  dependence：
    - [lua-cjson](https://github.com/openresty/lua-cjson)
    - [base64](https://github.com/aklomp/base64)

2.  Compile `build/deps/base64` :
    1.  - Unzip [base64](https://github.com/aklomp/base64) Source package in `build/deps/`,
        - `MacOS`: modify `./Makefile`, comment out the `$(OBJCOPY)` instruction under the target `lib/libbase64.o`,
        - (In MacOS, it will cause compilation failure, operation failure and symbol not found.)
    2. ```
        # Generate files lib/libbase64.o, lib/config.h
        # x86
        SSSE3_CFLAGS=-mssse3 \
        SSE41_CFLAGS=-msse4.1 \
        SSE42_CFLAGS=-msse4.2 \
        AVX2_CFLAGS=-mavx2 \
        AVX_CFLAGS=-mavx \
            make lib/libbase64.o
        ```
    3. ```(cd test; make test) # Execute test and benchmark```

3.  Build `nginx-unit-lua` :
    ```
    cd ..
    # For lua5.4 generate ./Makefile and Makefile of each shared library
    # Compile configuration: ./make/inc.lua and make.lua in each shared library directory
    # luajit make.lua
    ./make.lua # -g generate debug information, -r release
    make
    make clean
    ```

#### Instructions

1.  ```
    cd lor_demo
    # If you execute the script with luajit, the generated configuration will start luajit.
    ./unitd.lua        # View the configuration. The Unit configuration of the demo is in conf/config.lor.lua
    ./unitd.lua save   # Generate and store configuration files in JSON format
    ./unitd.lua start  # Start the Unit server, stop/restart
    ./unitd.lua config # *save* and then push the configuration to Unit
    ```

#### Contribution

1.  Fork the repository
2.  Create Feat_xxx branch
3.  Commit your code
4.  Create Pull Request
