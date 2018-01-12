// Usage : node basic_proxy.js WORKER_PORT_0,WORKER_PORT_1,... [PROXY_PORT]
const worker_ports = process.argv[2].split(',')
const proxy_port = process.argv[3] || 12480
if (worker_ports.length === 0) { console.err('missing worker ports') ; process.exit(1) }

const proxy = require('http-proxy').createProxyServer({})
proxy.on('error', () => console.log('proxy error'))

let i = 0
require('http').createServer((req, res) => {
  proxy.web(req,res, {target: 'http://localhost:' + worker_ports[ (i++) % worker_ports.length ]})
}).listen(proxy_port)
console.log(`Proxying localhost:${proxy_port} to [${worker_ports.toString()}]`)

// spin up the ML workers
const { exec } = require('child_process')
worker_ports.map(port => exec(`/bin/bash ./tf_classify_server.sh ${port}`))

