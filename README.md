# nginx-unit-lua

## 中文文档 / [English doc](README.en.md)

#### 介绍
Nginx-Unit 的 Lua5.4/LuaJIT 支持。
可运行 Lor 框架，有针对性的做了 Openresty 适配。

只初步实现了 HTTP 功能。
只在 MacOS 上测试过。


#### 软件架构
Lua 并非像 Unit 官方支持的那些语言一样集成到 Unit 中，
而是外部应用的形式（配置类型为 `external` ）。

Unit 启动时（或者应用配置变更时），根据配置启动 Lua 应用进程，
通过已经编译为 Lua 共享库的 Unit 通信模块交互。
Unit 主进程会启动三个功能性进程控制器、路由器、应用原型，
以及若干应用进程，各类进程间互有通信。


#### 安装教程

1.  依赖：
    - [lua-cjson](https://github.com/openresty/lua-cjson)
    - [base64](https://github.com/aklomp/base64)

2.  编译 `build/deps/base64` ：
    1.  - 解压 `build/deps/` 中的 [base64](https://github.com/aklomp/base64) 源码包，
        - `MacOS`: 修改 `./Makefile` ，注释掉目标 `lib/libbase64.o` 下的 `$(OBJCOPY)` 指令，
        - （ MacOS 中会导致编译失败、运行失败，找不到符号。）
    2. ```
        # 生成文件 lib/libbase64.o, lib/config.h
        # x86
        SSSE3_CFLAGS=-mssse3 \
        SSE41_CFLAGS=-msse4.1 \
        SSE42_CFLAGS=-msse4.2 \
        AVX2_CFLAGS=-mavx2 \
        AVX_CFLAGS=-mavx \
            make lib/libbase64.o
        ```
    3. ```(cd test; make test) # 执行 test 和 benchmark```

3.  构建 `nginx-unit-lua` ：
    ```
    cd ..
    # 针对 Lua5.4 生成 ./Makefile 及各共享库的 Makefile
    # 编译配置： ./make/inc.lua 以及各个共享库目录中的 make.lua
    # luajit make.lua
    ./make.lua # -g 生成调试信息， -r 无调试信息
    make
    make clean
    ```

#### 使用说明

1.  ```
    cd lor_demo
    # 如用 luajit 执行脚本，生成的配置启动 luajit 。
    ./unitd.lua        # 查看配置， demo 的 Unit 配置在 conf/config.lor.lua
    ./unitd.lua save   # 生成并存储 json 格式的配置到文件
    ./unitd.lua start  # 启动 Unit 服务器， stop/restart
    ./unitd.lua config # save 然后推送配置到 Unit
    ```

#### 参与贡献

1.  Fork 本仓库
2.  新建 Feat_xxx 分支
3.  提交代码
4.  新建 Pull Request

