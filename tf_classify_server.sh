#!/bin/bash
# usage: bash tf_classify_server.sh [PORT_NUMBER]
python tf_classify_server.py \
    --graph=/tmp/output_graph.pb \
    --labels=/tmp/output_labels.txt \
    --output_layer=final_result:0 \
    --image=$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg

