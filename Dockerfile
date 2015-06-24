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

VOLUME ["/media", "/config"]

# Add default config file
ADD sagetv-rescan.conf /root/sagetv-rescan.conf

# Add scripts
ADD start.sh /root/start.sh
RUN chmod +x /root/start.sh

CMD /root/start.sh
