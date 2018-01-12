#!/bin/bash
# tests that the seaport proxy works

cd "$HOME"

(
  node seaport_proxy.js &
  node tf_classify_server.js &
  sleep 5
  bash tf_classify_client.sh
  
  node tf_classify_server.js &
  node tf_classify_server.js &
  sleep 5
  bash tf_classify_client.sh
  bash tf_classify_client.sh
  bash tf_classify_client.sh
  sleep 1000
) &
PID=$!
PGID=$(echo `ps -o pgid= "$PID"`)
sleep 15
kill -- -"$PGID"

