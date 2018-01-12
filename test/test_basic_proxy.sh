#!/bin/bash
# tests that the basic load balancer proxy works

cd "$HOME"

node basic_proxy.js 12481,12482,12483 &
PID="$!"
echo 'started servers ; sleeping 5'
sleep 5
bash tf_classify_client.sh
kill -- -"$(ps -o pgid= "$PID")"
