// Usage : node seaport_worker.js
const seaport = require('seaport')
seaport.connect(12480)
const port = seaport.register('tf_classify_server')
console.log(`Launching tf classify worker on ${port}`)
const { exec } = require('child_process')
exec(`/bin/bash ./tf_classify_server.sh ${port}`)
