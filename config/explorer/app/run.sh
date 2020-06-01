#!/bin/sh
mkdir -p /opt/explorer/app/platform/fabric/
mkdir -p /tmp/

mv /opt/explorer/app/platform/fabric/connection-profile/first-network.json /opt/explorer/app/platform/fabric/connection-profile/first-network.json.vanilla
cp /fabric/config/explorer/app/config.json /opt/explorer/app/platform/fabric/connection-profile/first-network.json

cd /opt/explorer
node $EXPLORER_APP_PATH/main.js && tail -f /dev/null
