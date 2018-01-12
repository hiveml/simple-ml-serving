#!/bin/bash
# tests that the seaport proxy works

cd "$HOME"

node seaport_proxy.js &
node tf_classify_server.js &
sleep 5
curl -v -XPOST localhost:12480 -F"data=@$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg"
node tf_classify_server.js &
node tf_classify_server.js &
sleep 5
curl -v -XPOST localhost:12480 -F"data=@$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg"
curl -v -XPOST localhost:12480 -F"data=@$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg"
curl -v -XPOST localhost:12480 -F"data=@$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg"

