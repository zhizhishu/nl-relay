# nl-relay: vmess+ws 入(客户端经容器公网IPv4端点) → ss2022 出(经 Scaleway 内网 PN 到 nl 私网IPv4:28265)
# 零密钥镜像; 公开发布到 ghcr.io。凭据部署时由 Scaleway Secret 注入。
# 必须 linux/amd64; 控制在 <500MB。
FROM teddysun/xray:latest
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
