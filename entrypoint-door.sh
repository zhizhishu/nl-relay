#!/bin/sh
# 法国容器"门面+落地"一体: caddy 按 path 分发, xray 本地终结落地节点(走容器自己的法国 IPv4 出口)。
#   /LAND_PATH  -> 本地 xray(vmess+ws) -> freedom (容器自带法国 IPv4 出口, 不蹭第三方 NAT64)
#   /NL_PATH    -> fr-relay 私网IP:NL_PORT (nl 中转, vmess 在 fr-relay 终结, 本容器零 nl 密钥)
# 注入(env): LAND_UUID(secret) ; 可选 LAND_PATH/NL_PATH/FR_RELAY_IP/NL_PORT/PORT
set -e
: "${PORT:=443}"
: "${LAND_PATH:=/2d730q48eh}"
: "${NL_PATH:=/nlrelay}"
: "${FR_RELAY_IP:=172.16.4.2}"
: "${NL_PORT:=50000}"
: "${LAND_LOCAL_PORT:=8081}"

cat > /tmp/xray.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    { "tag": "landing", "listen": "127.0.0.1", "port": ${LAND_LOCAL_PORT}, "protocol": "vmess",
      "settings": { "clients": [ { "id": "${LAND_UUID}", "alterId": 0 } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "${LAND_PATH}" } } }
  ],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" } ]
}
EOF

cat > /tmp/Caddyfile <<EOF
{
	auto_https off
	admin off
}
:${PORT} {
	handle ${LAND_PATH} {
		reverse_proxy 127.0.0.1:${LAND_LOCAL_PORT}
	}
	handle ${NL_PATH} {
		reverse_proxy ${FR_RELAY_IP}:${NL_PORT}
	}
	handle {
		respond "OK" 200
	}
}
EOF

/usr/local/bin/xray run -c /tmp/xray.json &
exec caddy run --config /tmp/Caddyfile --adapter caddyfile
