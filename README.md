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

Controlling File Ownership
--------------------------

If your command writes to the directory, you may want to use the `UMAP` and `GMAP` environment variables to update user
IDs and group IDs inside the container so that they match those of the host. For example, if your command is `chown -R
nobody:users /dir1`, then you'll want to make sure that the "nobody" user in the container has the same ID as in the
host. You can set the UMAP environment variable to the value specified by
``echo nobody:`id -u nobody`:`id -g nobody` ``. Similarly, to remap the primary group for the "nobody" user, you would set
GMAP to the value specified by ``echo `id -gn nobody`:`id -g nobody` ``.

You can specify multiple users or groups to update by separating them with spaces in the UMAP and GMAP variables. For
example, these -e arguments to the `docker run` command will update the "nobody" and "www" users, as well as the "users"
and "wheel" groups:

`-e UMAP="nobody:99:100 www:80:800" -e GMAP="users:100 wheel:800"`

For commands that create files without an explicit user or group name, you may want to set the `USER_ID` and `GROUP_ID`
in the config file.  For example, if your command is `echo foo > /dir1/foo.txt`, then by default the file will be
created as the "root" user of the container. If you want it to be created with the user ID and group ID of "nobody" in
the host, you would set these config values to the output of `id -u nobody` and `id -g nobody` in the host.

Examples
--------

This example is to run a permissions-repairing utility whenever there's a change in the directory:

    WATCH_DIR=/dir2
    SETTLE_DURATION=5
    MAX_WAIT_TIME=30
    MIN_PERIOD=30
    COMMAND="/root/newperms /dir2"
    # Need to run as root to have the authority to fix the permissions
    USER_ID=0
    GROUP_ID=0
    # This is important because chmod/chown will change files in the monitored directory
    IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING=1

Since the `newperms` utility does an explicit "chown -R nobody:users", we need to use the UMAP and GMAP environment
variables to update the user and group in the container so that it will match the host. For example:

`docker run -e UMAP=nobody:99:100 -e GMAP=users:100 --name=inotify-command -d -v /etc/localtime:/etc/localtime -v
/config/dir/path:/config:rw -v /dir/path:/dir2:rw -v /usr/local/sbin/newperms:/newperms coppit/inotify-command`

This example tells SageTV to rescan its imported media when the media directory changes:

    WATCH_DIR=/dir1
    SETTLE_DURATION=5
    MAX_WAIT_TIME=05:00
    MIN_PERIOD=10:00
    COMMAND="wget -nv -O /dev/null --auth-no-challenge http://sage:frey@192.168.1.102:8080/sagex/api?c=RunLibraryImportScan&1="
    # User and group don't really matter for the wget command. But we need to specify them in the config file.
    USER_ID=0
    GROUP_ID=0
    IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING=0

We don't need to ignore events while the command is running because the wget command is a "fire and forget" asynchronous
operation. We also don't need to use UMAP or GMAP.
