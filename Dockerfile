FROM tensorflow/tensorflow:latest-devel

MAINTAINER Bowei Liu <liubowei@gmail.com>

WORKDIR /root

RUN apt-get update && apt-get install -y --no-install-recommends \
        screen \
        tmux \
        vim

RUN curl -O http://download.tensorflow.org/example_images/flower_photos.tgz && \
    tar xzf flower_photos.tgz 

RUN bazel build tensorflow/examples/image_retraining:retrain \
                tensorflow/examples/image_retraining:label_image

RUN bazel-bin/tensorflow/examples/image_retraining/retrain \
        --image_dir "$HOME"/flower_photos \
        --how_many_training_steps=200

EXPOSE 12480
CMD /bin/bash



