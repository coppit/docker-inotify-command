#!/bin/bash

function ts {
  echo [`date '+%b %d %X'`] MASTER:
}

echo "$(ts) Starting master controller"

if [ -f /config/sample.conf ]; then
  echo "$(ts) /config/sample.conf exists. Rename it, check the settings, then rerun the container. Exiting."
  exit 1
fi

readarray -t CONFIG_FILES < <(ls /config/*.conf)

# If there is no config file copy the default one
if [[ "$CONFIG_FILES" == "" ]]
then
  echo "$(ts) Creating sample config file. Rename it, check the settings, then rerun the container. Exiting."
  cp /root/sample.conf /config/sample.conf
  chmod a+w /config/sample.conf
  exit 1
fi

PIDS=()

for CONFIG_FILE in "${CONFIG_FILES[@]}" 
do 
  echo "$(ts) Launching monitor for $CONFIG_FILE"
  /root/monitor.sh $CONFIG_FILE &
  PIDS+=($!)
done

# Sleep for a second to allow the monitors to check their config files
sleep 1

while true
do
  for ((i = 0; i < ${#PIDS[@]}; i++))
  do
    if ps -p ${PIDS[$i]} > /dev/null
    then
      continue
    fi

    echo "$(ts) Monitor for ${CONFIG_FILES[$i]} has died (PID ${PIDS[$i]}). Killing other monitors and exiting."

    for PID in "${PIDS[@]}" 
    do 
      kill -9 $PID >/dev/null 2>&1
    done

    exit 2
  done

  sleep 60
done
