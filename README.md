# docker-inotify-command

docker-inotify-command
======================

This is a Docker container for triggering a command based on changes to a monitored directory. Multiple monitors can be set
up for different directories.

Usage
-----

This docker image is available as a [trusted build on the docker index](https://index.docker.io/u/coppit/inotify-command/).

Run:

`sudo docker run --name=inotify-command -d -v /etc/localtime:/etc/localtime -v /config/dir/path:/config:rw -v /media/dir/path:/dir1 coppit/inotify-command`

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
