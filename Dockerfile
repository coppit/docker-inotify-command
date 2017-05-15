FROM phusion/baseimage:0.9.19

MAINTAINER David Coppit <david@coppit.org>


# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

ENV DEBIAN_FRONTEND noninteractive
ADD dpkg-excludes /etc/dpkg/dpkg.cfg.d/excludes

RUN \

set -x && \

# Create dir to keep things tidy. Make sure it's readable by $UID
mkdir /files && \
chmod a+rwX /files && \

# Speed up APT
echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup && \
echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache && \

apt-get update && \
apt-get install -qy python3-watchdog wget && \

# clean up
apt-get clean && \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
/usr/share/man /usr/share/groff /usr/share/info \
/usr/share/lintian /usr/share/linda /var/cache/man && \
(( find /usr/share/doc -depth -type f ! -name copyright|xargs rm || true )) && \
(( find /usr/share/doc -empty|xargs rmdir || true ))

VOLUME ["/config", \
  "/dir1", "/dir2", "/dir3", "/dir4", "/dir5", "/dir6", "/dir7", "/dir8", "/dir9", "/dir10", \
  "/dir11", "/dir12", "/dir13", "/dir14", "/dir15", "/dir16", "/dir17", "/dir18", "/dir19", "/dir20"]

# Set the locale, to help Python and the user's applications deal with files that have non-ASCII characters
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ENV UMAP ""
ENV GMAP ""

# Add local files
COPY sample.conf monitor.py runas.sh /files/

ADD 50_remap_ids.sh /etc/my_init.d/

RUN mkdir /etc/service/monitor
ADD monitor.sh /etc/service/monitor/run
RUN chmod +x /etc/service/monitor/run
