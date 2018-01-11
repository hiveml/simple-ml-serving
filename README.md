# simple-ml-serving

This post code goes over a quick and dirty way to deploy a trained machine learning model to production.

Read this if: You've successfully trained a ML model using an ML framework such as Tensorflow or Caffe that you would like to put up as a demo, preferably sooner rather than later, and you prefer lighter solutions rather than spinning up an entire tech stack.

Reading time: 20 mins

### ML in production ###

When we started exploring the machine learning space here at Hive, we already had millions of ground truth labeled images, allowing us to train from scratch a contemporary image classification model in under a week. The more typical ML use case, though, is usually on the order of hundreds of images, for which I would recommend fine-tuning an existing model. For instance, https://www.tensorflow.org/tutorials/image_retraining has a great tutorial on how to fine-tune an Imagenet model (trained on 1.2M images, 1000 classes) to classify a sample dataset (3647 images, 5 classes).
For a quick tl;dr, after installing bazel and tensorflow, you would need to do the following:
```
(
  cd ~ && \
  curl -O http://download.tensorflow.org/example_images/flower_photos.tgz && \
  tar xzf flower_photos.tgz ;
)
bazel build tensorflow/examples/image_retraining:retrain && \
bazel-bin/tensorflow/examples/image_retraining/retrain --image_dir ~/flower_photos --how_many_training_steps=200
bazel build tensorflow/examples/image_retraining:label_image && \
bazel-bin/tensorflow/examples/image_retraining/label_image \
--graph=/tmp/output_graph.pb --labels=/tmp/output_labels.txt \
--output_layer=final_result:0 \
--image=$HOME/flower_photos/daisy/21652746_cc379e0eea_m.jpg
```
If you're having trouble installing tensorflow and bazel, especially if you're not on linux, I'm personally a huge fan of docker -- I tested this code using
```
sudo docker run -it tensorflow/tensorflow:latest-devel /bin/bash
```
which dropped me in a bash terminal where i ran the steps above.
Now, tensorflow has saved the model information into /tmp/output_graph.pb and /tmp/output_labels.txt, which are passed in as parameters to their label_image.py script (https://github.com/tensorflow/tensorflow/blob/r1.4/tensorflow/examples/image_retraining/label_image.py). Google also gives us another inference script (https://github.com/tensorflow/models/blob/master/tutorials/image/imagenet/classify_image.py#L130), linked from https://www.tensorflow.org/tutorials/image_recognition. 
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
From a performance standpoint, though, this is terrible - we are reloading python, tensorflow, and the entire neural network, for every input example!

We can do better. Let's start by editing the label_image.py script -- for me, this is located in bazel-bin/tensorflow/examples/image_retraining/label_image.runfiles/org_tensorflow/tensorflow/examples/image_retraining/label_image.py.
Let's change the lines
```
141:  run_graph(image_data, labels, FLAGS.input_layer, FLAGS.output_layer,
142:        FLAGS.num_top_predictions)
```
To
```
141:  for line in sys.stdin:
142:    run_graph(load_image(line), labels, FLAGS.input_layer, FLAGS.output_layer,
142:        FLAGS.num_top_predictions)
```
This is indeed a lot faster, but this is still not the best we can do!
The reason is the `with tf.Session() as sess` construction on line 100. Tensorflow is essentially loading all the computation into memory every time run_graph is called. This becomes apparent once you start trying to do inference on the GPU -- you can see the GPU memory go up and down as Tensorflow loads and unloads the model parameters to and from the GPU. As far as I know, this construction is not present in other ML frameworks like Caffe or Pytorch.
The solution is then to pull the `with` statement out, and pass in a `sess` variable to run_graph:
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
…
  with tf.Session() as sess:
    for line in sys.stdin:
      run_graph(load_image(line), labels, FLAGS.input_layer, FLAGS.output_layer,
          FLAGS.num_top_predictions, sess)
```
(see code at [INSERT LINK HERE])
If you run this, you should find that it takes around 0.1 sec per image, quite fast enough for online use.
## Deployment ##
The plan is to wrap this code in a flask app (quite simple), and then enable concurrent requests by upgrading to Twisted.
For a reminder, here's a flask app that receives POST requests with multipart form data:
```
# usage: pip install flask && python echo.py
# curl -v -XPOST 127.0.0.1:9876 -F "data=./image.jpg"
from flask import Flask
app = Flask(__name__)
@app.route(‘/', methods=[‘POST']):
def classify():
    try:
        data = request.files.get(‘data').read()
        print data
        return data, 200
    except Exception as e:
        return repr(e), 500
app.run(host='127.0.0.1',port=9876)
```
 
And here is the corresponding flask app hooked up to run_graph above:
```
from flask import Flask
app = Flask(__name__)
from classify import load_labels, load_graph, run_graph, FLAGS
labels = load_labels(FLAGS.labels)
load_graph(FLAGS.graph)
sess = tf.Session()
@app.route(‘/', methods=[‘POST']):
def classify():
    try:
        data = request.files.get(‘data').read()
        result = run_graph(data, labels, FLAGS.input_layer, FLAGS.output_layer, FLAGS.num_top_predictions, sess)
        return json.dumps(result), 200
    except Exception as e:
        return repr(e), 500
app.run(host='127.0.0.1',port=9876)
```
This looks quite good, except for the fact that flask and tensorflow are both fully synchronous - flask processes one request at a time in the order they are received, and tensorflow fully occupies the thread when doing the image classification.
As it's written, the bottleneck is probably still in running the actual neural net. The main potential performance gain is adding batching logic, which provides a rather large speedup on gpu-accelerated hardware. Doing so requires moving to an asynchronous web framework such as Twisted/Klein and running the Tensorflow computation in a separate thread.
## Scaling up: Load Balancing and Service Discovery ##
OK, so now we have a single server serving our model, but maybe it's too slow or our load is getting too high. We'd like to spin up more of these servers - how can we distribute requests across each of them ?
The ordinary method is to add a proxy layer, perhaps haproxy or nginx, which balances the load between the backend servers while presenting a single uniform interface to the client. To automatically detect how many backend servers are up and where they are located, people generally use a "service discovery" tool, which may be bundled with the load balancer or be separate.
Setting up and learning how to use these tools is beyond the scope of this article, so I've included a very rudimentary proxy using the node.js package `seaport`.
```
INSERT CODE HERE
WITH GITHUB LINK
```
However, as applied to ML, this concept runs into a bandwidth problem.
At anywhere from tens to hundreds of images a second, the system becomes bottlenecked on network bandwidth. In the current setup, all the data has to go through our single seaport master, which is the single endpoint presented to the client.
To solve this, we need our clients to not hit the single endpoint at http://127.0.0.1:9090, but instead to automatically rotate between backend servers to hit - which, in other words, a DNS config!
Again, setting up a custom DNS server is beyond the scope of this article, but by changing the clients to follow a 2-step "manual DNS" protocol, we can reuse our rudimentary seaport proxy:
```
INSERT CODE HERE
```
## Conclusion ##
Now that we have something working, now is probably a good time to plan for scaling up in the near future -- there's a slew of tools to learn, and many other helpful guides out there on the internet. 
Certain tasks were completely skipped over in this article, including automating scaling to new boxes, and any way at all of handling model versions. 
After read
By now, you should have a good idea of how to spin up servers 
## Addendum ##


GPU acceleration: Before proceeding, I strongly recommend nvidia-docker to manage cuda/cudnn dependencies.

