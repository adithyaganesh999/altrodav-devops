#!/bin/bash
set -e

dnf update -y

curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

npm install -g pm2

env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root | tail -1 | bash

mkdir -p /app
cat > /app/app.js <<'EOF'
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end('<h1>Altrodav DevOps Assignment Running</h1>');
}).listen(3000, '0.0.0.0');
EOF

cd /app
pm2 start app.js --name "web"
pm2 save