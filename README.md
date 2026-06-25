# nl-relay

把 Scaleway serverless 容器当 **IPv4 前置**，经 Scaleway 内网 (Private Network) 中转到一台 **IPv6-only** 的 nl VPS 上的 shadowsocks(ss2022) 节点。

```
客户端(IPv4) → 本容器(vmess+ws, 公网 https 端点) → [Scaleway 内网私网IPv4] → nl VPS ss 节点(28265) → nl 出口
```

GitHub Actions 自动构建并发布到 `ghcr.io/<owner>/nl-relay:latest`（linux/amd64）。

## 设计原则：密钥绝不进镜像
镜像零密钥；`entrypoint.sh` 在容器启动时从**注入的环境变量**生成 xray 配置。凭据用 **Scaleway Secret** 注入，存 Scaleway 密钥库，不在公开镜像里。

## 部署时注入的变量

| 变量 | 类型 | 说明 |
|---|---|---|
| `VMESS_UUID` | **Secret** | 客户端连本中转用的 vmess UUID |
| `NL_SS_PASSWORD` | **Secret** | nl ss 节点的密码/密钥 |
| `WS_PATH` | env | ws 路径，默认 `/relay` |
| `NL_PRIVATE_IP` | env | nl VPS 在 PN 内的固定私网 IPv4 (IPAM Reserve) |
| `NL_SS_METHOD` | env | 默认 `2022-blake3-aes-256-gcm` |
| `NL_PORT` | env | 默认 `28265` |

## 前置条件（硬约束）
- 中转容器与 nl VPS 必须**同一 Scaleway 账号 + 同 region(nl-ams) + 同一 Private Network**（PN 不跨账号/region）。
- nl VPS 先 attach PN 并用 IPAM **Reserve 固定私网 IPv4**，把它填进 `NL_PRIVATE_IP`。
- 容器入站只 ws（serverless 入口 HTTP-only）；ss2022 仅用于容器→nl 的**内网出站**。
