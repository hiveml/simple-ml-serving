#!/bin/bash

node tf_classify_server.sh 12481,12482,12483
echo 'started servers ; sleeping 5'
sleep 5
curl -v -XPOST localhost:12480 -F"data=@$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg"
