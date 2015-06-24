FROM phusion/baseimage:0.9.11

MAINTAINER David Coppit <david@coppit.org>

ENV DEBIAN_FRONTEND noninteractive

# Speed up APT
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup \
  && echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

RUN set -x \
  && apt-get update \
  && apt-get install -y inotify-tools wget \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

VOLUME ["/config", \
  "/dir1", "/dir2", "/dir3", "/dir4", "/dir5", "/dir6", "/dir7", "/dir8", "/dir9", "/dir10", \
  "/dir11", "/dir12", "/dir13", "/dir14", "/dir15", "/dir16", "/dir17", "/dir18", "/dir19", "/dir20"]

# Add default config file
ADD sample.conf /root/sample.conf

# Add scripts
ADD start.sh /root/start.sh
RUN chmod +x /root/start.sh
ADD monitor.sh /root/monitor.sh
RUN chmod +x /root/monitor.sh

CMD /root/start.sh
