from flask import Flask
app = Flask(__name__)
import label_image as tf_classify
FLAGS = tf_classify.FLAGS
labels = tf_classify.load_labels(FLAGS.labels)
tf_classify.load_graph(FLAGS.graph)
sess = tf.Session()
@app.route('/', methods=['POST']):
def classify():
    try:
        data = request.files.get('data').read()
        result = tf_classify.run_graph(data, labels, FLAGS.input_layer, FLAGS.output_layer, FLAGS.num_top_predictions, sess)
        return json.dumps(result), 200
    except Exception as e:
        return repr(e), 500
app.run(host='127.0.0.1',port=12480)
