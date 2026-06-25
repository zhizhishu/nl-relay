#!/bin/sh
# nl-relay xray entrypoint —— 零密钥镜像; 配置在运行时由注入的环境变量生成。
# 部署时注入 (Scaleway Secret/Env):
#   VMESS_UUID      (secret) 客户端连本中转用的 vmess UUID
#   WS_PATH         (env)    ws 路径, 如 /relay
#   NL_PRIVATE_IP   (env)    nl VPS 在 PN 内的固定私网 IPv4 (IPAM Reserve)
#   NL_SS_PASSWORD  (secret) nl ss 节点的密码/密钥
#   NL_SS_METHOD    (env, 默认 2022-blake3-aes-256-gcm)
#   NL_PORT         (env, 默认 28265)
set -e
: "${WS_PATH:=/relay}"
: "${NL_PORT:=28265}"
: "${NL_SS_METHOD:=2022-blake3-aes-256-gcm}"

cat > /tmp/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "${VMESS_UUID}", "alterId": 0 } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "${WS_PATH}" } }
    }
  ],
  "outbounds": [
    {
      "tag": "to-nl",
      "protocol": "shadowsocks",
      "settings": { "servers": [ { "address": "${NL_PRIVATE_IP}", "port": ${NL_PORT}, "method": "${NL_SS_METHOD}", "password": "${NL_SS_PASSWORD}" } ] }
    },
    { "tag": "direct", "protocol": "freedom" }
  ],
  "routing": { "rules": [ { "type": "field", "outboundTag": "to-nl", "network": "tcp,udp" } ] }
}
EOF

exec /usr/bin/xray -config /tmp/config.json
