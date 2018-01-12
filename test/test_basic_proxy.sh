#!/bin/bash
# tests that the basic load balancer proxy works

cd "$HOME"

node tf_classify_server.sh 12481,12482,12483
echo 'started servers ; sleeping 5'
sleep 5
bash tv_classify_client.sh
