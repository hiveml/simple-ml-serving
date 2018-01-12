// Usage : node seaport_proxy.js
const seaportServer = require('seaport').createServer()
seaportServer.listen(12481)
const proxy = require('http-proxy').createProxyServer({})
proxy.on('error', () => console.log('proxy error'))

let i = 0
require('http').createServer((req, res) => {
  seaportServer.get('tf_classify_server', worker_ports => {
    console.log({ i , worker_ports })
    proxy.web(req,res, {target: 'http://localhost:' + worker_ports[ (i++) % worker_ports.length ]})
  })
}).listen(12480)
