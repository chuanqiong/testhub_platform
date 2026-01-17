#!/bin/bash

# 自动备份脚本
# 备份数据库和媒体文件

set -e

# 配置
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
DB_PASSWORD="${DB_PASSWORD:-testhub123}"

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

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 生成时间戳
DATE=$(date +%Y%m%d_%H%M%S)

print_info "开始备份 - $DATE"

# 备份数据库
print_info "备份数据库..."
DB_BACKUP_FILE="$BACKUP_DIR/db_$DATE.sql"

if docker-compose exec -T mysql mysqldump -u root -p$DB_PASSWORD testhub > "$DB_BACKUP_FILE" 2>/dev/null; then
    DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
    print_info "数据库备份完成: $DB_BACKUP_FILE ($DB_SIZE)"
else
    print_error "数据库备份失败"
    exit 1
fi

# 压缩数据库备份
print_info "压缩数据库备份..."
gzip "$DB_BACKUP_FILE"
DB_BACKUP_FILE="$DB_BACKUP_FILE.gz"
DB_SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
print_info "数据库备份已压缩: $DB_BACKUP_FILE ($DB_SIZE)"

# 备份媒体文件
print_info "备份媒体文件..."
MEDIA_BACKUP_FILE="$BACKUP_DIR/media_$DATE.tar.gz"

if [ -d "./media" ]; then
    tar -czf "$MEDIA_BACKUP_FILE" media/ 2>/dev/null
    MEDIA_SIZE=$(du -h "$MEDIA_BACKUP_FILE" | cut -f1)
    print_info "媒体文件备份完成: $MEDIA_BACKUP_FILE ($MEDIA_SIZE)"
else
    print_warn "媒体目录不存在，跳过媒体文件备份"
fi

# 备份配置文件
print_info "备份配置文件..."
CONFIG_BACKUP_FILE="$BACKUP_DIR/config_$DATE.tar.gz"

tar -czf "$CONFIG_BACKUP_FILE" \
    .env \
    docker-compose.yml \
    docker-compose.prod.yml \
    docker/backend/pip.conf \
    docker/frontend/nginx.conf \
    2>/dev/null || true

CONFIG_SIZE=$(du -h "$CONFIG_BACKUP_FILE" | cut -f1)
print_info "配置文件备份完成: $CONFIG_BACKUP_FILE ($CONFIG_SIZE)"

# 清理旧备份
print_info "清理 $RETENTION_DAYS 天前的备份..."
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

REMAINING=$(ls -1 "$BACKUP_DIR" | wc -l)
print_info "保留 $REMAINING 个备份文件"

# 生成备份清单
print_info "生成备份清单..."
cat > "$BACKUP_DIR/backup_$DATE.txt" << EOF
TestHub 备份清单
================

备份时间: $(date '+%Y-%m-%d %H:%M:%S')
备份目录: $BACKUP_DIR

文件列表:
---------
数据库: $DB_BACKUP_FILE ($DB_SIZE)
媒体文件: $MEDIA_BACKUP_FILE ($MEDIA_SIZE)
配置文件: $CONFIG_BACKUP_FILE ($CONFIG_SIZE)

恢复命令:
---------
# 恢复数据库
gunzip -c $DB_BACKUP_FILE | docker-compose exec -T mysql mysql -u root -p$DB_PASSWORD testhub

# 恢复媒体文件
tar -xzf $MEDIA_BACKUP_FILE

# 恢复配置文件
tar -xzf $CONFIG_BACKUP_FILE

备份保留策略: $RETENTION_DAYS 天
EOF

print_info ""
print_info "=========================================="
print_info "备份完成！"
print_info "=========================================="
print_info "备份目录: $BACKUP_DIR"
print_info "数据库: $DB_BACKUP_FILE"
print_info "媒体文件: $MEDIA_BACKUP_FILE"
print_info "配置文件: $CONFIG_BACKUP_FILE"
print_info "备份清单: $BACKUP_DIR/backup_$DATE.txt"
print_info "=========================================="

# 可选：上传到远程存储
if [ ! -z "$BACKUP_REMOTE_PATH" ]; then
    print_info "上传备份到远程存储..."
    # 这里可以添加 rsync、scp 或云存储上传命令
    # 例如: rsync -avz "$BACKUP_DIR/" "$BACKUP_REMOTE_PATH/"
    print_warn "远程备份功能需要配置 BACKUP_REMOTE_PATH 环境变量"
fi

exit 0
