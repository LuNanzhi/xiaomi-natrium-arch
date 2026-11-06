// Minimal HTTP/HTTPS (CONNECT) proxy for the natrium phone.
// Runs on 0.0.0.0:3128 so 172.16.42.1 (the phone) can reach it at 172.16.42.101.
// node proxy.js
const http = require('http');
const net = require('net');

const PORT = 3128;

const server = http.createServer((req, res) => {
    let target;
    try {
        target = new URL(req.url);
    } catch (e) {
        res.writeHead(400);
        res.end('bad request');
        return;
    }
    const opts = {
        host: target.hostname,
        port: target.port || 80,
        path: target.pathname + target.search,
        method: req.method,
        headers: req.headers
    };
    const up = http.request(opts, (ur) => {
        res.writeHead(ur.statusCode, ur.headers);
        ur.pipe(res);
    });
    up.on('error', (e) => {
        res.writeHead(502);
        res.end('proxy error: ' + e.message);
    });
    req.pipe(up);
});

server.on('connect', (req, socket, head) => {
    const [host, port] = req.url.split(':');
    const up = net.connect(Number(port) || 443, host, () => {
        socket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
        if (head && head.length) up.write(head);
        up.pipe(socket);
        socket.pipe(up);
    });
    up.on('error', () => {
        try { socket.end('HTTP/1.1 502 Bad Gateway\r\n\r\n'); } catch (e) {}
    });
    socket.on('error', () => up.destroy());
});

server.listen(PORT, '0.0.0.0', () => {
    console.log('natrium proxy listening on 0.0.0.0:' + PORT);
});
