#Download base image ubuntu 18.04
FROM ubuntu:18.04
 
# Update Software repository
RUN apt-get update

WORKDIR /usr/src/fpga

# Install and setup pre-requisites for IceCore Getting Started
# @see: https://github.com/folknology/IceCore/wiki/IceCore-Getting-Started

RUN DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential clang bison flex libreadline-dev gawk tcl-dev \
    libffi-dev git mercurial graphviz xdot pkg-config python python3 libftdi-dev \
    qt5-default python3-dev libboost-all-dev cmake libeigen3-dev

# Downloading and installing IceStorm 
RUN git clone https://github.com/cliffordwolf/icestorm.git icestorm
RUN cd icestorm && make -j$(nproc) && make install

# Downloading and installing Arachne-pnr
RUN git clone https://github.com/cseed/arachne-pnr.git arachne-pnr
RUN cd arachne-pnr && make -j$(nproc) && make install

# Optional Installing NextPNR place&route tool, Arachne-PNR replacement
RUN git clone https://github.com/YosysHQ/nextpnr nextpnr
RUN cd nextpnr && cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=/usr/local . && make -j$(nproc) && make install

# Downloading and installing Yosys
RUN git clone https://github.com/cliffordwolf/yosys.git yosys
RUN cd yosys && make -j$(nproc) && make install

# Get ARM gcc toolchain
RUN apt-get install wget
RUN mkdir opt
RUN cd opt && wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/8-2019q3/RC1.1/gcc-arm-none-eabi-8-2019-q3-update-linux.tar.bz2
RUN cd opt && tar xjf gcc-arm-none-eabi-8-2019-q3-update-linux.tar.bz2
RUN echo "export PATH='$PATH:$HOME/opt/gcc-arm-none-eabi-8-2019-q3-update-linux/bin'" >> ~/.bashrc

# The MyStorm tutorial examples & firmware
RUN git clone https://github.com/folknology/IceCore.git -b USB-CDC-issue-3

RUN cd IceCore/Examples/blink && make clean && make
RUN cd IceCore/Examples/trail && make clean && make
RUN sed -i "s|/mnt/c/Users/awood/arm-gcc/|$(pwd)/opt/|g" IceCore/firmware/myStorm/makefile
RUN mv IceCore/firmware/mystorm-inc/Spi.h IceCore/firmware/mystorm-inc/spi.h
RUN cd IceCore/firmware/myStorm && make clean && make

# The DFU utility (for updating STM32 firmware)
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install autoconf libusb-1.0
RUN git clone https://github.com/mystorm-org/dfu-util.git
RUN cd dfu-util && ./autogen.sh && ./configure && make && make install

# Now grab Lawrie's blackice-mx examples
RUN git clone https://github.com/lawrie/blackicemx_examples.git
RUN cd blackicemx_examples/writeflash && make

# Now start installing SaxonSoc pre-requisites

# Install the SpinalHDL pre-requisites
RUN apt-get install -y software-properties-common 
RUN add-apt-repository -y ppa:openjdk-r/ppa
RUN apt-get update
RUN apt-get install openjdk-8-jdk -y
RUN echo "deb https://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823
RUN apt-get update
RUN apt-get install -y sbt

# Install the RISCV toolchain
# Ubuntu packages needed:
RUN apt-get install -y autoconf automake autotools-dev curl libmpc-dev \
        libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo \
        gperf libtool patchutils bc zlib1g-dev git libexpat1-dev

RUN mkdir /opt/riscv32i
RUN git clone https://github.com/riscv/riscv-gnu-toolchain riscv-gnu-toolchain-rv32i
RUN cd riscv-gnu-toolchain-rv32i && git checkout 411d134 && git submodule update --init --recursive
RUN cd riscv-gnu-toolchain-rv32i && mkdir build && cd build && ../configure --with-arch=rv32i --prefix=/opt/riscv32i && make -j$(nproc)

# Install SaxonSOC
RUN git clone -b Bmb https://github.com/SpinalHDL/SaxonSoc
RUN cd SaxonSoc && git submodule init && git submodule update

# The following is just for test. For corret build check the discussion here
# @see: https://forum.mystorm.uk/t/running-saxonsoc-on-blackice-mx/687

# Make minimal examples
RUN export RISCV_BIN=/opt/riscv32i/bin/riscv32-unknown-elf- && cd SaxonSoc/software/standalone/blinkAndEcho && make BSP=BlackiceMxMinimal
RUN export RISCV_BIN=/opt/riscv32i/bin/riscv32-unknown-elf- && cd SaxonSoc/software/standalone/readSdcard && make BSP=BlackiceMxMinimal

# Make a blackice-mx minimal BSP
RUN export RISCV_BIN=/opt/riscv32i/bin/riscv32-unknown-elf- && cd SaxonSoc/hardware/synthesis/blackicemx/ && cp makefile.minimal makefile && make generate
# This will fail due to lack of a device
#RUN export RISCV_BIN=/opt/riscv32i/bin/riscv32-unknown-elf- && cd SaxonSoc/hardware/synthesis/blackicemx/ && make prog 

# Dummy startup script so container keeps running
COPY start.sh start.sh
CMD ["./start.sh"]
