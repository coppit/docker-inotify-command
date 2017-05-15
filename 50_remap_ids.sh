#!/bin/bash

#-----------------------------------------------------------------------------------------------------------------------

function ts {
  echo [`date '+%Y-%m-%d %H:%M:%S'`]
}

#-----------------------------------------------------------------------------------------------------------------------

function check_env_vars {
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

# Uses UMAP and GMAP
check_env_vars "$@"

update_users "$UMAP"
update_groups "$GMAP"

chmod a+r /files/sample.conf
chmod a+x /files/monitor.py
chmod +x /files/runas.sh
