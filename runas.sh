#!/bin/bash

USER=docker
GROUP=docker

#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo [`date '+%b %d %X'`]
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
  local UID_GID=$1

  # Create a new user with the proper user and group ID.
  local USER_ID=${UID_GID%:*}
  local GROUP_ID=${UID_GID#*:}

  echo "$(ts) Creating user \"$USER\" (ID $USER_ID) and group \"$GROUP\" (ID $GROUP_ID) to run the command..."

  # We could be aliasing this new user to some existing user. Let's assume that's harmless.
  groupadd -o -g $GROUP_ID $GROUP
  useradd -o -u $USER_ID -r -g $GROUP -s /sbin/nologin -c "Docker image user" $USER
}

#-----------------------------------------------------------------------------------------------------------------------

# Shift off the args as we go so that we can exec $@
UMAP=$1
shift
GMAP=$1
shift
UID_GID=$1
shift

update_users "$UMAP"
update_groups "$GMAP"
create_user "$UID_GID"

echo "$(ts) Running command as user \"$USER\"..."
exec /sbin/setuser $USER "$@"
