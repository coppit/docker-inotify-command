#!/bin/bash

USER=docker
GROUP=docker

#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo [`date '+%b %d %X'`]
}

#-----------------------------------------------------------------------------------------------------------------------

function process_args {
  # Shift off the args as we go so that we can exec $@ later. These are meant to be globals.
  UMAP=$1
  shift
  GMAP=$1
  shift
  UGID=$1
  shift

  for NAME_UID_GID in $UMAP
  do
    if [[ ! "$NAME_UID_GID" =~ ^[A-Za-z0-9._][-A-Za-z0-9._]*:[0-9]{1,}:[0-9]{1,}$ ]]
    then
      echo "UMAP value $NAME_UID_GID is not valid. It should be of the form <user name>:<uid>:<gid>"
      exit 1
    fi
  done

  for NAME_GID in $GMAP
  do
    if [[ ! "$NAME_GID" =~ ^[A-Za-z0-9._][-A-Za-z0-9._]*:[0-9]{1,}$ ]]
    then
      echo "GMAP value $NAME_GID is not valid. It should be of the form <group name>:<gid>"
      exit 1
    fi
  done

  if [[ ! "$UGID" =~ ^[0-9]{1,}:[0-9]{1,}$ ]]
  then
    echo "UGID value is not valid. It should be of the form <uid>:<gid>"
    exit 1
  fi
}

#-----------------------------------------------------------------------------------------------------------------------

function update_users {
  local UMAP=$1

  if [[ "$UMAP" == "" ]]; then return; fi

  echo "$(ts) Updating existing users..."

  for NAME_UID_GID in $UMAP
  do
    local NAME=${NAME_UID_GID%:*:*}
    local USER_ID=${NAME_UID_GID#*:}
    USER_ID=${USER_ID%:*}
    local GROUP_ID=${NAME_UID_GID#*:*:}

    echo "$(ts) Setting user \"$NAME\" to user ID=\"$USER_ID\" and default group ID=\"$GROUP_ID\""
    usermod -o -u $USER_ID -g $GROUP_ID $NAME
  done
}

#-----------------------------------------------------------------------------------------------------------------------

function update_groups {
  local GMAP=$1

  if [[ "$GMAP" == "" ]]; then return; fi

  echo "$(ts) Updating existing groups..."

  for NAME_GID in $GMAP
  do
    local NAME=${NAME_GID%:*}
    local GROUP_ID=${NAME_GID#*:}

    echo "$(ts) Setting group \"$NAME\" to ID=\"$GROUP_ID\""
    groupmod -o -g $GROUP_ID $NAME
  done
}

#-----------------------------------------------------------------------------------------------------------------------

function create_user {
  local UGID=$1

  # Create a new user with the proper user and group ID.
  local USER_ID=${UGID%:*}
  local GROUP_ID=${UGID#*:}

  echo "$(ts) Creating user \"$USER\" (ID $USER_ID) and group \"$GROUP\" (ID $GROUP_ID) to run the command..."

  # We could be aliasing this new user to some existing user. Let's assume that's harmless.
  groupadd -o -g $GROUP_ID $GROUP
  useradd -o -u $USER_ID -r -g $GROUP -s /sbin/nologin -c "Docker image user" $USER
}

#-----------------------------------------------------------------------------------------------------------------------

process_args

update_users "$UMAP"
update_groups "$GMAP"
create_user "$UGID"

echo "$(ts) Running command as user \"$USER\"..."
exec /sbin/setuser $USER "$@"
