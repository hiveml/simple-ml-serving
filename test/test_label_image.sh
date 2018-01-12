#!/bin/bash
# verifies that label_image.py works on multiple images quickly and successfully

cd "$HOME"

{ for i in `seq 1 5` ; do echo $HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg ; done ; } | python label_image.py \
    --graph=/tmp/output_graph.pb \
    --labels=/tmp/output_labels.txt \
    --output_layer=final_result:0 \
    --image=$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg
