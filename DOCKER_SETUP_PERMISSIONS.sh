#!/bin/bash

# 为所有脚本添加执行权限

echo "为 Docker 部署脚本添加执行权限..."

# 主启动脚本
chmod +x docker-start.sh

# 运维脚本
chmod +x scripts/backup.sh
chmod +x scripts/restore.sh
chmod +x scripts/health-check.sh
chmod +x scripts/setup-ssl.sh

echo "✓ 执行权限已添加"
echo ""
echo "现在可以使用以下命令："
echo "  ./docker-start.sh start    # 启动服务"
echo "  ./docker-start.sh init     # 初始化数据"
echo "  ./scripts/backup.sh        # 备份数据"
echo "  ./scripts/health-check.sh  # 健康检查"
