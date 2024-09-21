FROM ubuntu:22.04 as stage-ubuntu

LABEL maintainer="Patrick Pedersen"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        inetutils-ping \
        lsb-release \
        net-tools \
        curl \
        sudo \
        wget \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*

FROM stage-ubuntu as stage-xfce

ENV \
    LANG='en_US.UTF-8' \
    LANGUAGE='en_US:en' \
    LC_ALL='en_US.UTF-8'

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        mousepad \
        locales \
        supervisor \
        xfce4 \
        xfce4-terminal \
    && locale-gen en_US.UTF-8 \
    && apt-get purge -y \
        pm-utils \
        xscreensaver* \
    && rm -rf /var/lib/apt/lists/*

FROM stage-xfce as stage-vnc

# RUN wget -qO- https://sourceforge.net/projects/tigervnc/files/stable/1.14.0/tigervnc-1.14.0.x86_64.tar.gz | tar xz --strip 1 -C /
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        tigervnc-standalone-server \
    && rm -rf /var/lib/apt/lists/*

FROM stage-vnc as stage-novnc

### Same parent path as VNC
ENV NO_VNC_HOME=/usr/share/usr/local/share/noVNCdim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3-pip \
    && pip3 install --no-cache-dir \
        numpy \
    && mkdir -p "${NO_VNC_HOME}/utils/websockify" \
    && wget -qO- "https://github.com/novnc/noVNC/archive/v1.5.0.tar.gz" | tar xz --strip 1 -C "${NO_VNC_HOME}" \
    && wget -qO- "https://github.com/novnc/websockify/archive/v0.12.0.tar.gz" | tar xz --strip 1 -C "${NO_VNC_HOME}/utils/websockify" \
    && chmod +x -v "${NO_VNC_HOME}/utils/novnc_proxy" \
    && rm -rf /var/lib/apt/lists/*

### Add 'index.html' for choosing noVNC client
RUN echo \
"<!DOCTYPE html>\n" \
"<html>\n" \
"    <head>\n" \
"        <title>noVNC</title>\n" \
"        <meta charset=\"utf-8\"/>\n" \
"    </head>\n" \
"    <body>\n" \
"        <p><a href=\"vnc.html\">noVNC Full Client</a></p>\n" \
"    </body>\n" \
"</html>" \
> ${NO_VNC_HOME}/index.html

FROM stage-novnc as stage-wine

RUN dpkg --add-architecture i386
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 76F1A20FF987672F
RUN wget -nc https://dl.winehq.org/wine-builds/winehq.key ; apt-key add winehq.key ; apt-add-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ jammy main'
RUN apt update -y ; apt install -y --install-recommends winehq-devel
    
FROM stage-wine as stage-wrapper

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gettext \
        libnss-wrapper \
    && rm -rf /var/lib/apt/lists/*

### Arguments can be provided during build
ARG ARG_HOME
ARG ARG_REFRESHED_AT
ARG ARG_VNC_BLACKLIST_THRESHOLD
ARG ARG_VNC_BLACKLIST_TIMEOUT
ARG ARG_VNC_PW
ARG ARG_VNC_RESOLUTION

ENV \
    DISPLAY=:1 \
    HOME=${ARG_HOME:-/home/headless} \
    NO_VNC_PORT="6901" \
    REFRESHED_AT=${ARG_REFRESHED_AT} \
    STARTUPDIR=/dockerstartup \
    VNC_BLACKLIST_THRESHOLD=${ARG_VNC_BLACKLIST_THRESHOLD:-20} \
    VNC_BLACKLIST_TIMEOUT=${ARG_VNC_BLACKLIST_TIMEOUT:-0} \
    VNC_COL_DEPTH=24 \
    VNC_PORT="5901" \
    VNC_PW=${ARG_VNC_PW:-headless} \
    VNC_RESOLUTION=${ARG_VNC_RESOLUTION:-1360x768} \
    VNC_VIEW_ONLY=false

### Creates home folder
WORKDIR ${HOME}

COPY [ "./src/startup", "${STARTUPDIR}/" ]

### Preconfigure Xfce
COPY [ "./src/home/Desktop", "./Desktop/" ]
COPY [ "./src/home/config/xfce4/panel", "./.config/xfce4/panel/" ]
COPY [ "./src/home/config/xfce4/xfconf/xfce-perchannel-xml", "./.config/xfce4/xfconf/xfce-perchannel-xml/" ]

### 'generate_container_user' has to be sourced to hold all env vars correctly
RUN echo 'source $STARTUPDIR/generate_container_user' >> ${HOME}/.bashrc

### Fix permissions
RUN chmod +x \
        "${STARTUPDIR}/set_user_permissions.sh" \
        "${STARTUPDIR}/vnc_startup.sh" \
        "${STARTUPDIR}/srs-install.sh" \
        "${STARTUPDIR}/srs-run.sh" \
    && gtk-update-icon-cache -f /usr/share/icons/hicolor \
    && "${STARTUPDIR}"/set_user_permissions.sh "${STARTUPDIR}" "${HOME}"    

EXPOSE ${VNC_PORT} ${NO_VNC_PORT}

### Issue #7: Mitigating problems with foreground mode
WORKDIR ${STARTUPDIR}
ENTRYPOINT ["./vnc_startup.sh"]
CMD [ "--wait" ]