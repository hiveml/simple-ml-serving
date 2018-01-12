#!/bin/bash
# verifies that bazel and tensorflow installed correctly

cd /tensorflow && \
  bazel-bin/tensorflow/examples/image_retraining/label_image \
    --graph=/tmp/output_graph.pb \
    --labels=/tmp/output_labels.txt \
    --output_layer=final_result:0 \
    --image=$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg

