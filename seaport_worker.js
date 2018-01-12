// Usage : node seaport_worker.js
const port = require('seaport').connect(12481).register('tf_classify_server')
console.log(`Launching tf classify worker on ${port}`)
require('child_process').exec(`/bin/bash ./tf_classify_server.sh ${port}`)
