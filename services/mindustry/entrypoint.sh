#!/bin/sh
set -eu

SERVER_NAME=${MINDUSTRY_SERVER_NAME:-LAN Arcade Mindustry}
SERVER_DESC=${MINDUSTRY_SERVER_DESC:-Offline Raspberry Pi LAN server}
SERVER_PORT=${MINDUSTRY_PORT:-6567}
SERVER_MAP=${MINDUSTRY_MAP:-groundZero}
SERVER_MODE=${MINDUSTRY_MODE:-survival}
JAVA_XMS=${MINDUSTRY_XMS:-128m}
JAVA_XMX=${MINDUSTRY_XMX:-512m}
SERVER_COMMANDS="config name $SERVER_NAME,config desc $SERVER_DESC,config port $SERVER_PORT,config startCommands host $SERVER_MAP $SERVER_MODE"

exec java "-Xms${JAVA_XMS}" "-Xmx${JAVA_XMX}" -jar /opt/mindustry/server-release.jar \
  "$SERVER_COMMANDS"
