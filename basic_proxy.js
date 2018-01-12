// Usage : node basic_proxy.js WORKER_PORT_0,WORKER_PORT_1,...
var proxy = require('http-proxy').createProxyServer({})
var worker_ports = process.argv[2].split(',')
if (worker_ports.length === 0) { console.err('missing worker ports') ; process.exit(1) }
var i = 0
require('http').createServer((req, res) => {
  var this_port = worker_ports[ (i++) % worker_ports.length ]
  console.log(this_port)
  proxy.web(req,res, {target: 'http://localhost:' + this_port})
}).listen(12480)
console.log(`Proxying localhost:${12480} to [${worker_ports.toString()}]`)
proxy.on('error', () => console.log('proxy error'))
  
