#!/bin/bash

function ts {
  echo [`date '+%b %d %X'`]
}

echo "$(ts) Starting SageTV-Rescan container"

# Search for custom config file, if it doesn't exist, copy the default one
if [ ! -f /config/sagetv-rescan.conf ]; then
  echo "$(ts) Creating config file and exiting. Check the settings, then rerun the container."
  cp /root/sagetv-rescan.conf /config/sagetv-rescan.conf
  chmod a+w /config/sagetv-rescan.conf
  exit 1
fi

tr -d '\r' < /config/sagetv-rescan.conf > /tmp/sagetv-rescan.conf

. /tmp/sagetv-rescan.conf

if [[ ! "$SETTLE_DURATION" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
  echo "$(ts) SETTLE_DURATION must be defined in sagetv-rescan.conf as HH:MM:SS or MM:SS or SS."
  exit 1
fi

if [[ ! "$MAX_WAIT_TIME" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
  echo "$(ts) MAX_WAIT_TIME must be defined in sagetv-rescan.conf as HH:MM:SS or MM:SS or SS."
  exit 1
fi

if [ -z "$NOTIFY_COMMAND" ]; then
  echo "$(ts) NOTIFY_COMMAND must be defined in sagetv-rescan.conf"
  exit 1
elif [ "$NOTIFY_COMMAND" = "YOUR_SERVER" ]; then
  echo "$(ts) Please replace \"YOUR_SERVER\" in sagetv-rescan.conf"
  exit 1
fi

to_seconds () {
  readarray elements < <(echo $1 | sed 's/:/\n/g' | tac)

  SECONDS=0
  POWER=1

  for (( i=0 ; i<${#elements[@]}; i++ )) ; do
    SECONDS=$(( 10#$SECONDS + 10#${elements[i]} * 10#$POWER ))
    POWER=$(( 10#$POWER * 60 ))
  done

  echo "$SECONDS"
}

SETTLE_DURATION=$(to_seconds $SETTLE_DURATION)
MAX_WAIT_TIME=$(to_seconds $MAX_WAIT_TIME)

pipe=$(mktemp -u)
mkfifo $pipe

echo "$(ts) Waiting for changes..."
inotifywait -m -q --format '%e %f' /media >$pipe &

while true
do
  if read RECORD
  then
    EVENT=$(echo "$RECORD" | cut -d' ' -f 1)
    FILE=$(echo "$RECORD" | cut -d' ' -f 2-)

#    echo "$RECORD"
#    echo "  EVENT=$EVENT"
#    echo "  FILE=$FILE"

    if [ "$EVENT" == "CREATE,ISDIR" ]
    then
      echo "$(ts) Detected new directory: $FILE"
    elif [ "$EVENT" == "CLOSE_WRITE,CLOSE" ]
    then
      echo "$(ts) Detected new file: $FILE"
    elif [ "$EVENT" == "MOVED_TO" ]
    then
      echo "$(ts) Detected moved file: $FILE"
    else
      continue
    fi

    # Monster up as many events as possible, until we hit the either the settle duration, or the max wait threshold.
    start_time=$(date +"%s")

    while true
    do
      if read -t $SETTLE_DURATION RECORD
      then
        end_time=$(date +"%s")

        if [ $(($end_time-$start_time)) -gt $MAX_WAIT_TIME ]
        then
          echo "$(ts) Input directory didn't stabilize after $MAX_WAIT_TIME seconds. Notifying SageTV anyway."
          break
        fi
      else
        echo "$(ts) Input directory stabilized for $SETTLE_DURATION seconds. Notifying SageTV."
        break
      fi
    done

    $NOTIFY_COMMAND
  fi
done <$pipe
