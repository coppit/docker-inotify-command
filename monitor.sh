#!/bin/bash

CONFIG_FILE=$1
NAME=$(basename $CONFIG_FILE .conf)

function ts {
  echo [`date '+%b %d %X' $NAME: `]
}

echo "$(ts) Starting monitor for $CONFIG_FILE"

tr -d '\r' < $CONFIG_FILE > /tmp/$NAME.conf

. /tmp/$NAME.conf

if [[ ! -d "$WATCH_DIR" ]]; then
  echo "$(ts) WATCH_DIR specified in $CONFIG_FILE must be a directory."
  exit 1
fi

if [[ ! "$SETTLE_DURATION" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
  echo "$(ts) SETTLE_DURATION must be defined in $CONFIG_FILE as HH:MM:SS or MM:SS or SS."
  exit 1
fi

if [[ ! "$MAX_WAIT_TIME" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
  echo "$(ts) MAX_WAIT_TIME must be defined in $CONFIG_FILE as HH:MM:SS or MM:SS or SS."
  exit 1
fi

if [[ ! "$MIN_PERIOD" =~ ^([0-9]{1,2}:){0,2}[0-9]{1,2}$ ]]; then
  echo "$(ts) MIN_PERIOD must be defined in $CONFIG_FILE as HH:MM:SS or MM:SS or SS."
  exit 1
fi

if [ -z "$COMMAND" ]; then
  echo "$(ts) COMMAND must be defined in $CONFIG_FILE"
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
MIN_PERIOD=$(to_seconds $MIN_PERIOD)

pipe=$(mktemp -u)
mkfifo $pipe

echo "$(ts) Waiting for changes..."
inotifywait -m -q --format '%e %f' /media >$pipe &

last_run_time=0

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
          echo "$(ts) Input directory didn't stabilize after $MAX_WAIT_TIME seconds. Triggering command anyway."
          break
        fi
      else
        echo "$(ts) Input directory stabilized for $SETTLE_DURATION seconds. Triggering command."
        break
      fi
    done

    time_since_last_run=$(($(date +"%s")-$last_run_time))
    if [ $time_since_last_run -lt $MIN_PERIOD ]
    then
      remaining_time=$(($MIN_PERIOD-$time_since_last_run))

      echo "$(ts) Waiting an additional $remaining_time seconds before running command"
    fi

    # Process events while we wait for $MIN_PERIOD to expire
    while [ $time_since_last_run -lt $MIN_PERIOD ]
    do
      remaining_time=$(($MIN_PERIOD-$time_since_last_run))

      read -t $remaining_time RECORD

      time_since_last_run=$(($(date +"%s")-$last_run_time))
    done

    echo "$(ts) Running command"
    $COMMAND
    last_run_time=$(date +"%s")
  fi
done <$pipe
