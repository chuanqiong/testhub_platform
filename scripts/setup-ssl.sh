#!/bin/bash

# SSL 证书自动配置脚本
# 使用 Let's Encrypt 免费 SSL 证书

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
if [ -z "$1" ]; then
    print_error "请提供域名"
    echo "用法: ./setup-ssl.sh your-domain.com your-email@example.com"
    exit 1
fi

if [ -z "$2" ]; then
    print_error "请提供邮箱地址"
    echo "用法: ./setup-ssl.sh your-domain.com your-email@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

print_info "开始为域名 $DOMAIN 配置 SSL 证书"

# 检查 certbot
if ! command -v certbot &> /dev/null; then
    print_warn "certbot 未安装，正在安装..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot
    else
        print_error "无法自动安装 certbot，请手动安装"
        exit 1
    fi
fi

# 创建证书目录
print_info "创建证书目录..."
mkdir -p ./docker/nginx/ssl
mkdir -p ./docker/nginx/certbot

# 停止 nginx 容器（如果正在运行）
print_info "停止 nginx 容器..."
docker-compose stop frontend || true

# 获取证书
print_info "获取 SSL 证书..."
sudo certbot certonly --standalone \
    -d $DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --preferred-challenges http

# 复制证书到项目目录
print_info "复制证书..."
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./docker/nginx/ssl/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./docker/nginx/ssl/
sudo chmod 644 ./docker/nginx/ssl/*.pem

# 更新 nginx 配置
print_info "更新 nginx 配置..."
cp ./docker/nginx/nginx-ssl.conf ./docker/frontend/nginx.conf
sed -i "s/your-domain.com/$DOMAIN/g" ./docker/frontend/nginx.conf

# 更新 docker-compose.yml
print_info "更新 docker-compose.yml..."
cat >> docker-compose.yml << EOF

  # SSL 证书自动续期
  certbot:
    image: docker.aityp.com/certbot/certbot
    container_name: testhub_certbot
    volumes:
      - ./docker/nginx/certbot:/etc/letsencrypt
      - ./docker/nginx/ssl:/etc/nginx/ssl
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"
    networks:
      - testhub_network
EOF

# 重启服务
print_info "重启服务..."
docker-compose up -d

print_info ""
print_info "=========================================="
print_info "SSL 证书配置完成！"
print_info "=========================================="
print_info "域名: $DOMAIN"
print_info "证书位置: ./docker/nginx/ssl/"
print_info "证书有效期: 90 天"
print_info "自动续期: 已配置"
print_info "=========================================="
print_info ""
print_info "现在可以通过 HTTPS 访问："
print_info "https://$DOMAIN"
print_info "=========================================="
