#!/bin/bash

GROUP=docker

#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo [`date '+%b %d %X'`]
}

#-----------------------------------------------------------------------------------------------------------------------

function process_args {
  local USER_UID_GID=$1

  if [[ ! "$USER_UID_GID" =~ ^[A-Za-z0-9._][-A-Za-z0-9._]*:[0-9]{1,}:[0-9]{1,}$ ]]
  then
    echo "USER_UID_GID value $USER_UID_GID is not valid. It should be of the form <user>:<uid>:<gid>"
    exit 1
  fi

  # These are meant to be global.
  USER=${USER_UID_GID%:*:*}
  USER_ID=${USER_UID_GID#*:}
  USER_ID=${USER_ID%:*}
  GROUP_ID=${USER_UID_GID#*:*:}
}

#-----------------------------------------------------------------------------------------------------------------------

function create_user {
  local USER=$1
  local USER_ID=$2
  local GROUP=$3
  local GROUP_ID=$4

  echo "$(ts) Creating user \"$USER\" (ID $USER_ID) and group \"$GROUP\" (ID $GROUP_ID) to run the command..."

  # We could be aliasing this new user to some existing user. I assume that's harmless.
  groupadd -o -g $GROUP_ID $GROUP
  useradd -o -u $USER_ID -r -g $GROUP -d /home/$USER -s /sbin/nologin -c "Docker image user" $USER

  mkdir -p /home/$USER
  chown -R $USER:$GROUP /home/$USER
}

#-----------------------------------------------------------------------------------------------------------------------

process_args "$@"

# Shift off the arg so that we can exec $@ below
shift

create_user $USER $USER_ID $GROUP $GROUP_ID

echo "$(ts) Running command as user \"$USER\"..."
exec /sbin/setuser $USER "$@"
