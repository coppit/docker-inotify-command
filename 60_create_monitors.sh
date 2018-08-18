#!/bin/bash

function ts {
  echo [`date '+%Y-%m-%d %H:%M:%S'`] MASTER:
}

echo "$(ts) Starting master controller"

if [ -f /config/sample.conf ]; then
  echo "$(ts) /config/sample.conf exists. Rename it to <monitor name>.conf, check the settings, then rerun the container. Exiting."
  exit 1
fi

readarray -t CONFIG_FILES < <(ls /config/*.conf)

# If there is no config file copy the default one
if [[ "$CONFIG_FILES" == "" ]]
then
  echo "$(ts) Creating sample config file. Rename it to <monitor name>.conf, check the settings, then rerun the container. Exiting."
  cp /files/sample.conf /config/sample.conf
  chmod a+w /config/sample.conf
  exit 1
fi

for CONFIG_FILE in "${CONFIG_FILES[@]}" 
do 
  FILENAME=$(basename "$CONFIG_FILE")

  echo "$(ts) Creating monitor for $FILENAME"

  FILEBASE="${FILENAME%.*}"
  
  mkdir -p /etc/service/$FILEBASE

  cat > /etc/service/$FILEBASE/run <<EOF
#!/bin/bash

/files/monitor.py "$CONFIG_FILE"
EOF

  chmod a+x /etc/service/$FILEBASE/run
done
