#!/bin/bash
# tests that launching a single classifier worker works and we are able to POST to it

cd "$HOME"

bash tf_classify_server.sh &
PID="$!"
echo 'started server ; sleeping 5'
sleep 5
bash tf_classify_client.sh
kill "$PID"
