FROM alpine:3.7

MAINTAINER David Coppit <david@coppit.org>

ENV TERM=xterm-256color

RUN true && \
\
echo "http://dl-cdn.alpinelinux.org/alpine/v3.7/community" >> /etc/apk/repositories && \
apk --update upgrade && \
\
# Basics, including runit
apk add bash curl htop runit && \
\
# Needed by our code
apk add --no-cache python3 icu-libs shadow && \
pip3 install watchdog && \
wget https://raw.githubusercontent.com/phusion/baseimage-docker/9f998e1a09bdcb228af03595092dbc462f1062d0/image/bin/setuser -O /sbin/setuser && \
chmod +x /sbin/setuser && \
\
rm -rf /var/cache/apk/* && \
\
# RunIt stuff
adduser -h /home/user-service -s /bin/sh -D user-service -u 2000 && \
chown user-service:user-service /home/user-service && \
mkdir -p /etc/run_once /etc/service

# Boilerplate startup code
COPY ./boot.sh /sbin/boot.sh
RUN chmod +x /sbin/boot.sh
CMD [ "/sbin/boot.sh" ]

VOLUME ["/config", \
  "/dir1", "/dir2", "/dir3", "/dir4", "/dir5", "/dir6", "/dir7", "/dir8", "/dir9", "/dir10", \
  "/dir11", "/dir12", "/dir13", "/dir14", "/dir15", "/dir16", "/dir17", "/dir18", "/dir19", "/dir20"]

# Set the locale, to help Python and the user's applications deal with files that have non-ASCII characters
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ENV UMAP ""
ENV GMAP ""

COPY sample.conf monitor.py runas.sh /files/
# Make sure it's readable by $UID
RUN chmod a+rwX /files

# run-parts ignores files with "." in them
ADD 50_remap_ids.sh /etc/run_once/50_remap_ids
ADD 60_create_monitors.sh /etc/run_once/60_create_monitors
RUN chmod +x /etc/run_once/*
