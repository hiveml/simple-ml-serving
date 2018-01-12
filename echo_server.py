#!/usr/bin/env python
# usage: python echo_server.py to launch the server ; and then in another session, do
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
