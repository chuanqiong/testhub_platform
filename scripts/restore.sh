#!/bin/bash

# 数据恢复脚本
# 从备份恢复数据库和媒体文件

set -e

# 配置
DB_PASSWORD="${DB_PASSWORD:-testhub123}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

show_usage() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -d, --database FILE    恢复数据库备份文件"
    echo "  -m, --media FILE       恢复媒体文件备份"
    echo "  -c, --config FILE      恢复配置文件备份"
    echo "  -a, --all PREFIX       恢复所有备份（使用时间戳前缀）"
    echo "  -h, --help             显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -d backups/db_20260116_120000.sql.gz"
    echo "  $0 -m backups/media_20260116_120000.tar.gz"
    echo "  $0 -a backups/20260116_120000"
    exit 1
}

restore_database() {
    local db_file=$1
    
    if [ ! -f "$db_file" ]; then
        print_error "数据库备份文件不存在: $db_file"
        exit 1
    fi
    
    print_warn "警告: 此操作将覆盖当前数据库！"
    read -p "确认继续？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "操作已取消"
        exit 0
    fi
    
    print_info "恢复数据库: $db_file"
    
    # 检查文件是否压缩
    if [[ $db_file == *.gz ]]; then
        gunzip -c "$db_file" | docker-compose exec -T mysql mysql -u root -p$DB_PASSWORD testhub
    else
        docker-compose exec -T mysql mysql -u root -p$DB_PASSWORD testhub < "$db_file"
    fi
    
    print_info "数据库恢复完成"
}

restore_media() {
    local media_file=$1
    
    if [ ! -f "$media_file" ]; then
        print_error "媒体文件备份不存在: $media_file"
        exit 1
    fi
    
    print_warn "警告: 此操作将覆盖当前媒体文件！"
    read -p "确认继续？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "操作已取消"
        exit 0
    fi
    
    print_info "恢复媒体文件: $media_file"
    
    # 备份当前媒体文件
    if [ -d "./media" ]; then
        print_info "备份当前媒体文件..."
        mv media media.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # 解压媒体文件
    tar -xzf "$media_file"
    
    print_info "媒体文件恢复完成"
}

restore_config() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        print_error "配置文件备份不存在: $config_file"
        exit 1
    fi
    
    print_warn "警告: 此操作将覆盖当前配置文件！"
    read -p "确认继续？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "操作已取消"
        exit 0
    fi
    
    print_info "恢复配置文件: $config_file"
    
    # 解压配置文件
    tar -xzf "$config_file"
    
    print_info "配置文件恢复完成"
}

restore_all() {
    local prefix=$1
    
    print_info "查找备份文件: $prefix*"
    
    # 查找备份文件
    db_file=$(ls ${prefix}*db*.sql.gz 2>/dev/null | head -1)
    media_file=$(ls ${prefix}*media*.tar.gz 2>/dev/null | head -1)
    config_file=$(ls ${prefix}*config*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$db_file" ] && [ -z "$media_file" ] && [ -z "$config_file" ]; then
        print_error "未找到备份文件"
        exit 1
    fi
    
    print_info "找到以下备份文件:"
    [ ! -z "$db_file" ] && echo "  数据库: $db_file"
    [ ! -z "$media_file" ] && echo "  媒体文件: $media_file"
    [ ! -z "$config_file" ] && echo "  配置文件: $config_file"
    echo ""
    
    print_warn "警告: 此操作将覆盖当前所有数据！"
    read -p "确认继续？(yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "操作已取消"
        exit 0
    fi
    
    # 恢复数据库
    if [ ! -z "$db_file" ]; then
        print_info "恢复数据库..."
        gunzip -c "$db_file" | docker-compose exec -T mysql mysql -u root -p$DB_PASSWORD testhub
        print_info "数据库恢复完成"
    fi
    
    # 恢复媒体文件
    if [ ! -z "$media_file" ]; then
        print_info "恢复媒体文件..."
        if [ -d "./media" ]; then
            mv media media.backup.$(date +%Y%m%d_%H%M%S)
        fi
        tar -xzf "$media_file"
        print_info "媒体文件恢复完成"
    fi
    
    # 恢复配置文件
    if [ ! -z "$config_file" ]; then
        print_info "恢复配置文件..."
        tar -xzf "$config_file"
        print_info "配置文件恢复完成"
    fi
    
    print_info ""
    print_info "=========================================="
    print_info "所有数据恢复完成！"
    print_info "=========================================="
    print_info "请重启服务: docker-compose restart"
}

# 解析参数
if [ $# -eq 0 ]; then
    show_usage
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--database)
            restore_database "$2"
            shift 2
            ;;
        -m|--media)
            restore_media "$2"
            shift 2
            ;;
        -c|--config)
            restore_config "$2"
            shift 2
            ;;
        -a|--all)
            restore_all "$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            print_error "未知选项: $1"
            show_usage
            ;;
    esac
done
