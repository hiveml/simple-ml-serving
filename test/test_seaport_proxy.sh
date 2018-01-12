#!/bin/bash
# tests that the seaport proxy works

cd "$HOME"

node seaport_proxy.js &
node tf_classify_server.js &
sleep 5
bash tv_classify_client.js

node tf_classify_server.js &
node tf_classify_server.js &
sleep 5
bash tv_classify_client.js
bash tv_classify_client.js
bash tv_classify_client.js

