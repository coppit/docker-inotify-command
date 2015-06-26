#!/bin/bash

#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo [`date '+%b %d %X'`]
}

#-----------------------------------------------------------------------------------------------------------------------

function process_args {
  # These are intended to be global
  USER_ID=$1
  GROUP_ID=$2

  if [[ ! "$USER_ID" =~ ^[0-9]{1,}$ ]]
  then
    echo "User ID value $USER_ID is not valid. It must be a whole number"
    exit 1
  fi

  if [[ ! "$GROUP_ID" =~ ^[0-9]{1,}$ ]]
  then
    echo "Group ID value $GROUP_ID is not valid. It must be a whole number"
    exit 1
  fi
}

#-----------------------------------------------------------------------------------------------------------------------

function create_user {
  local USER_ID=$1
  local GROUP_ID=$2

  USER="user_${USER_ID}_$GROUP_ID"
  GROUP="group_${USER_ID}_$GROUP_ID"

  if id -u $USER >/dev/null 2>&1
  then
    echo "$(ts) User \"$USER\" already exists. Skipping creation of user and group..."
    return
  fi

  echo "$(ts) Creating user \"$USER\" (ID $USER_ID) and group \"$GROUP\" (ID $GROUP_ID) to run the command..."

  # We could be aliasing this new user to some existing user. I assume that's harmless.
  groupadd -o -g $GROUP_ID $GROUP
  useradd -o -u $USER_ID -r -g $GROUP -d /home/$USER -s /sbin/nologin -c "Docker image user" $USER

  mkdir -p /home/$USER
  chown -R $USER:$GROUP /home/$USER
}

#-----------------------------------------------------------------------------------------------------------------------

process_args "$@"

# Shift off the args so that we can exec $@ below
shift; shift

create_user $USER_ID $GROUP_ID

echo "$(ts) Running command as user \"$USER\"..."
exec /sbin/setuser $USER "$@"
