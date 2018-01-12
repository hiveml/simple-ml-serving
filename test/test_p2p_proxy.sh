#!/bin/bash
# tests that the p2p proxy works

cd "$HOME"

node seaport_proxy.js &
node tf_classify_server.js &
sleep 5
bash p2p_client.sh
node tf_classify_server.js &
node tf_classify_server.js &
sleep 5
bash p2p_client.sh
bash p2p_client.sh
bash p2p_client.sh
