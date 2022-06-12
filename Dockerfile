FROM amigadev/docker-base:latest
WORKDIR /root
COPY ./ ./

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt install -y lhasa && \
    rm -rf /var/lib/apt/lists/* && \
    make update PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) all PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=ahi PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=camd PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=cgx PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=guigfx PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=mui PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=p96 PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=mcc_betterstring PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=mcc_guigfx PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=mcc_nlist PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=mcc_texteditor PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=mcc_thebar PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=render PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) sdk=warp3d PREFIX=/opt/m68k-amigaos && \
    make -j $(nproc) all-sdk PREFIX=/opt/m68k-amigaos && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/newstyle.h -O newstyle.h && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2.h -O sana2.h && \
    wget https://raw.githubusercontent.com/aros-development-team/AROS/master/compiler/include/devices/sana2specialstats.h -O sana2specialstats.h && \
    wget https://dl.amigadev.com/newstyle.diff -O newstyle.diff && \
    patch --ignore-whitespace < newstyle.diff && \
    mv -fv newstyle.h sana2.h sana2specialstats.h /opt/m68k-amigaos/m68k-amigaos/ndk-include/devices/ && \
    cd / && \
    rm -rf /root/amiga-gcc && \
    apt-get purge -y \
    autoconf \
    bison \
    flex \
    g++ \
    gcc \
    gettext \
    git \
    lhasa \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libncurses-dev \
    make \
    rsync \
    texinfo\
    wget \
    && apt-get -y autoremove

ENV PATH /opt/m68k-amigaos/bin:$PATH

