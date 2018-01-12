https://github.com/hiveml/simple-ml-serving

https://blog.thehive.ai

# simple-ml-serving
# Or, I just trained a machine learning model - now what ?

This post goes over a quick and dirty way to deploy a trained machine learning model to production.

Read this if: You've successfully trained a ML model using an ML framework such as Tensorflow or Caffe that you would like to put up as a demo, preferably sooner rather than later, and you prefer lighter solutions rather than spinning up an entire tech stack.

Reading time: 10-15 mins

### ML in production ###

When we first entered the machine learning space here at Hive, we already had millions of ground truth labeled images, allowing us to train a state-of-the-art deep convolutional image classification model from scratch (i.e. randomized weights) in under a week, specialized for our use case. The more typical ML use case, though, is usually on the order of hundreds of images, for which I would recommend fine-tuning an existing model. For instance, https://www.tensorflow.org/tutorials/image_retraining has a great tutorial on how to fine-tune an Imagenet model (trained on 1.2M images, 1000 classes) to classify a sample dataset of flowers (3647 images, 5 classes).

For a quick tl;dr of the linked Tensorflow tutorial, after installing bazel and tensorflow, you would need to run the following code, which takes around 30 mins to build and 5 minutes to train:

```
(
  cd "$HOME" && \
  curl -O http://download.tensorflow.org/example_images/flower_photos.tgz && \
  tar xzf flower_photos.tgz ;
) && \
bazel build tensorflow/examples/image_retraining:retrain \
            tensorflow/examples/image_retraining:label_image \
  && \
bazel-bin/tensorflow/examples/image_retraining/retrain \
    --image_dir "$HOME"/flower_photos \
    --how_many_training_steps=200 
  && \
bazel-bin/tensorflow/examples/image_retraining/label_image \
    --graph=/tmp/output_graph.pb \
    --labels=/tmp/output_labels.txt \
    --output_layer=final_result:0 \
    --image=$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg
```

Alternatively, if you have [Docker](https://www.docker.com/get-docker) installed, you can use this [prebuilt Docker image](https://hub.docker.com/r/liubowei/simple-ml-serving/) like so:

```
sudo docker run -it --net=host liubowei/simple-ml-serving:latest /bin/bash

>>> cat test.sh && bash test.sh
```

which puts you into an interactive shell inside the container and runs the above command; you can also follow along with the rest of this post inside the container if you wish.

Now, tensorflow has saved the model information into `/tmp/output_graph.pb` and `/tmp/output_labels.txt`, which are passed above as command-line parameters to the [label_image.py](https://github.com/tensorflow/tensorflow/blob/r1.4/tensorflow/examples/image_retraining/label_image.py) script . Google's image_recognition tutorial also links to [another inference script](https://github.com/tensorflow/models/blob/master/tutorials/image/imagenet/classify_image.py#L130), but we will be sticking with label_image.py for now.

## Converting one-shot inference to online inference ##

If we just want to accept file names from standard input, one per line, we can do "online" inference quite easily:

```
while read line ; do 
bazel-bin/tensorflow/examples/image_retraining/label_image \
--graph=/tmp/output_graph.pb --labels=/tmp/output_labels.txt \
--output_layer=final_result:0 \
--image="$line" ;
done
```

From a performance standpoint, though, this is terrible - we are reloading the neural net, the weights, the entire Tensorflow framework, and python itself, for every input example!

We can do better. Let's start by editing the label_image.py script -- for me, this is located in `bazel-bin/tensorflow/examples/image_retraining/label_image.runfiles/org_tensorflow/tensorflow/examples/image_retraining/label_image.py`.

Let's change the lines

```
141:  run_graph(image_data, labels, FLAGS.input_layer, FLAGS.output_layer,
142:        FLAGS.num_top_predictions)
```

to

```
141:  for line in sys.stdin:
142:    run_graph(load_image(line), labels, FLAGS.input_layer, FLAGS.output_layer,
142:        FLAGS.num_top_predictions)
```

This is indeed a lot faster, but this is still not the best we can do!

The reason is the `with tf.Session() as sess` construction on line 100. Tensorflow is essentially loading all the computation into memory every time `run_graph` is called. This becomes apparent once you start trying to do inference on the GPU -- you can see the GPU memory go up and down as Tensorflow loads and unloads the model parameters to and from the GPU. As far as I know, this construction is not present in other ML frameworks like Caffe or Pytorch.

The solution is then to pull the `with` statement out, and pass in a `sess` variable to `run_graph`:

```
def run_graph(image_data, labels, input_layer_name, output_layer_name,
              num_top_predictions, sess):
    # Feed the image_data as input to the graph.
    #   predictions will contain a two-dimensional array, where one
    #   dimension represents the input image count, and the other has
    #   predictions per class
    softmax_tensor = sess.graph.get_tensor_by_name(output_layer_name)
    predictions, = sess.run(softmax_tensor, {input_layer_name: image_data})
    # Sort to show labels in order of confidence
    top_k = predictions.argsort()[-num_top_predictions:][::-1]
    for node_id in top_k:
      human_string = labels[node_id]
      score = predictions[node_id]
      print('%s (score = %.5f)' % (human_string, score))
    return [ (labels[node_id], predictions[node_id]) for node_id in top_k ]

...

  with tf.Session() as sess:
    for line in sys.stdin:
      run_graph(load_image(line), labels, FLAGS.input_layer, FLAGS.output_layer,
          FLAGS.num_top_predictions, sess)
```

(see code at https://github.com/hiveml/simple-ml-serving/blob/master/label_image.py)

If you run this, you should find that it takes around 0.1 sec per image, quite fast enough for online use.

## Deployment ##
The plan is to wrap this code in a Flask app. If you haven't heard of it, Flask is a very lightweight Python web framework which allows you to spin up an http api server with minimal work.

As a quick reference, here's a flask app that receives POST requests with multipart form data:

```
#!/usr/bin/env python
# usage: python echo.py to launch the server ; and then in another session, do
# curl -v -XPOST 127.0.0.1:12480 -F "data=@./image.jpg"
from flask import Flask, request
app = Flask(__name__)
@app.route('/', methods=['POST'])
def classify():
    try:
        data = request.files.get('data').read()
        print repr(data)[:1000]
        return data, 200
    except Exception as e:
        return repr(e), 500
app.run(host='127.0.0.1',port=12480)
```

And here is the corresponding flask app hooked up to `run_graph` above:

```
#!/usr/bin/env python
from flask import Flask, request
app = Flask(__name__)
import label_image as tf_classify
FLAGS = tf_classify.FLAGS
labels = tf_classify.load_labels(FLAGS.labels)
tf_classify.load_graph(FLAGS.graph)
sess = tf.Session()
@app.route('/', methods=['POST'])
def classify():
    try:
        data = request.files.get('data').read()
        result = tf_classify.run_graph(data, labels, FLAGS.input_layer, FLAGS.output_layer, FLAGS.num_top_predictions, sess)
        return json.dumps(result), 200
    except Exception as e:
        return repr(e), 500
app.run(host='127.0.0.1',port=12480)
```

This looks quite good, except for the fact that flask and tensorflow are both fully synchronous - flask processes one request at a time in the order they are received, and Tensorflow fully occupies the thread when doing the image classification.

As it's written, the speed bottleneck is probably still in the actual computation work, so there's not much point upgrading the Flask wrapper code. And maybe this code is sufficient to handle your load, for now.

There are 2 obvious ways to scale up request thoroughput : scale up horizontally by increasing the number of workers, which is covered in the next section, or scale up vertically by utilizing a GPU and batching logic. Implementing the latter requires a webserver that is able to handle multiple pending requests at once, and decide whether to keep waiting for a larger batch or send it off to the Tensorflow graph thread to be classified, for which this Flask app is horrendously unsuited. My personal preference is Twisted + Klein for keeping code in Python, or Node.js + ZeroMQ if you prefer first class event loop support and the ability to hook into non-Python ML frameworks such as Torch.

## Scaling up: Load Balancing and Service Discovery ##

OK, so now we have a single server serving our model, but maybe it's too slow or our load is getting too high. We'd like to spin up more of these servers - how can we distribute requests across each of them?

The ordinary method is to add a proxy layer, perhaps haproxy or nginx, which balances the load between the backend servers while presenting a single uniform interface to the client. To automatically detect how many backend servers are up and where they are located, people generally use a "service discovery" tool, which may be bundled with the load balancer or be separate.

Setting up and learning how to use these tools is beyond the scope of this article, so I've included a very rudimentary proxy using the node.js service discovery package `seaport`.

```
INSERT CODE HERE
WITH GITHUB LINK
```

However, as applied to ML, this setup runs into a bandwidth problem.

At anywhere from tens to hundreds of images a second, the system becomes bottlenecked on network bandwidth. In the current setup, all the data has to go through our single `seaport` master, which is the single endpoint presented to the client.

To solve this, we need our clients to not hit the single endpoint at `http://127.0.0.1:9090`, but instead to automatically rotate between backend servers to hit. If you know some networking, this sounds precisely like a job for DNS!

However, setting up a custom DNS server is again beyond the scope of this article. Instead, by changing the clients to follow a 2-step "manual DNS" protocol, we can reuse our rudimentary seaport proxy to implement a "peer-to-peer" protocol in which clients connect directly to their servers:

```
INSERT CODE HERE
```

## Conclusion and further reading - WIP ##

At this point you should have something working in production, but it's certainly not futureproof. There are several important topics that were not covered in this guide:

* Automatically deploying and setting up on new hardware. 
  - Notable tools include Openstack/VMware if you're on your own hardware, Chef/Puppet for installing Docker and handling networking routes, and Docker for installing Tensorflow, Python, and everything else.
  - Kubernetes or Marathon/Mesos are also great if you're on the cloud
* Model version management
  - Not too hard to handle this manually at first
  - Tensorflow Serving is a great tool that handles this, as well as batching and overall deployment, very thoroughly. The downsides are that it's a bit hard to setup and to write client code for, and in addition doesn't support Caffe/PyTorch.
* How to migrate your ML code off Matlab
  - Don't do matlab in production.
* GPU drivers, Cuda, CUDNN
  - Use nvidia-docker and try to find some Dockerfiles online.
* Postprocesing layers. Once you get a few different ML models in production, you might start wanting to mix and match them for different use cases -- run model A only if model B is inconclusive, run model C in Caffe and pass the results to model D in Tensorflow, etc. 
 

