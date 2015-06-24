docker-inotify-command
======================

This is a Docker container for triggering a command based on changes to a monitored directory. Multiple monitors can be set
up for different directories.

Usage
-----

This docker image is available as a [trusted build on the docker index](https://index.docker.io/u/coppit/inotify-command/).

Run:

`sudo docker run --name=inotify-command -d -v /etc/localtime:/etc/localtime -v /config/dir/path:/config:rw -v /dir/path:/dir1 coppit/inotify-command`

To check the status, run:

`docker logs inotify-command`

When the container detects a change to a directory, it will invoke the specified command. There are different parameters
for controlling how frequently the command runs in response to changes.

Configuration
-------------

When run for the first time, a file named `sample.conf` will be created in the config dir, and the container will exit.
Rename this file, then edit it, customizing how you want the command to run. For example, you might want to increase the
stabilization time and/or minimum period to avoid running the command too frequently.

Copy the config file to set up multiple monitors. Be sure to also map the appropriate dir1/dir2/etc. to directories on
the host. Up to 20 directories can be monitored. If your commands need to write to directories, you can also configure
them to be used that way as well.

After creating your conf files, restart the container and it will begin monitoring.

Examples
--------

### Run a permissions-repairing utility whenever there's a change in the directory

 WATCH_DIR=/dir2
 SETTLE_DURATION=5
 MAX_WAIT_TIME=30
 MIN_PERIOD=30
 COMMAND="/root/newperms /dir2"
 # This is important because chmod/chown will change files in the monitored directory
 IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING=1

### Tell SageTV to rescan its imported media when the media directory changes

 WATCH_DIR=/dir1
 SETTLE_DURATION=5
 MAX_WAIT_TIME=05:00
 MIN_PERIOD=10:00
 COMMAND="wget -nv -O /dev/null --auth-no-challenge http://sage:frey@192.168.1.102:8080/sagex/api?c=RunLibraryImportScan&1="
 # This is not important because the above is a "fire and forget" asynchronous operation
 IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING=0
