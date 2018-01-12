// Usage : node basic_proxy.js [--port=PROXY_PORT] [--worker_ports=WORKER_PORT_0,WORKER_PORT_1,...]

var proxy = require('http-proxy')
var argv = require('minimist')(process.argv)

if (argv.worker_ports.length === 0) { process.exit(1) }

var i = 0
proxy.createServer((req, res, proxy) => {
  var this_port = argv.worker_ports[ (i++) % argv.worker_ports.length ]
  proxy.proxyRequest(req,res, this_port)
}).listen(argv.port || 12480)
  
