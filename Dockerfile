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
  "/watch1", "/watch2", "/watch3", "/watch4", "/watch5", "/watch6", "/watch7", "/watch8", "/watch9", "/watch10", \
  "/watch11", "/watch12", "/watch13", "/watch14", "/watch15", "/watch16", "/watch17", "/watch18", "/watch19", "/watch20"]

# Add default config file
ADD sample.conf /root/sample.conf

# Add scripts
ADD start.sh /root/start.sh
RUN chmod +x /root/start.sh
ADD monitor.sh /root/monitor.sh
RUN chmod +x /root/monitor.sh

CMD /root/start.sh
