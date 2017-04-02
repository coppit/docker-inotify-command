FROM phusion/baseimage:0.9.19

MAINTAINER David Coppit <david@coppit.org>

ENV DEBIAN_FRONTEND noninteractive

# Speed up APT
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup \
  && echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache

RUN set -x \
  && apt-get update \
  && apt-get install -y python3-watchdog wget \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

VOLUME ["/config", \
  "/dir1", "/dir2", "/dir3", "/dir4", "/dir5", "/dir6", "/dir7", "/dir8", "/dir9", "/dir10", \
  "/dir11", "/dir12", "/dir13", "/dir14", "/dir15", "/dir16", "/dir17", "/dir18", "/dir19", "/dir20"]

ENV UMAP ""
ENV GMAP ""

# Create dir to keep things tidy. Make sure it's readable by $UID
RUN mkdir /files
RUN chmod a+rwX /files

# Add default config file. Make sure it's readable by $UID
ADD sample.conf /files/sample.conf
RUN chmod a+r /files/sample.conf

# Add scripts. Make sure start.sh and monitor.py are executable by $UID
ADD start.sh /files/
RUN chmod a+x /files/start.sh
ADD monitor.py /files/
RUN chmod a+x /files/monitor.py
ADD runas.sh /files/
RUN chmod +x /files/runas.sh
ADD mapids.sh /files/
RUN chmod +x /files/mapids.sh

# Set the locale, to help Python and the user's applications deal with files that have non-ASCII characters
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

CMD /files/mapids.sh "$UMAP" "$GMAP" && /files/start.sh
