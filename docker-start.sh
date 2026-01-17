#!/bin/bash

# TestHub Docker 快速启动脚本
# 用法: ./docker-start.sh [start|stop|restart|logs|status|init]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 和 Docker Compose
check_requirements() {
    print_info "检查环境要求..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    print_info "环境检查通过 ✓"
}

# 检查环境变量文件
check_env_file() {
    if [ ! -f .env ]; then
        print_warn ".env 文件不存在，从模板创建..."
        if [ -f .env.example ]; then
            cp .env.example .env
            print_info ".env 文件已创建，请根据需要修改配置"
            print_warn "生产环境请务必修改 SECRET_KEY 和数据库密码！"
        else
            print_error ".env.example 文件不存在"
            exit 1
        fi
    fi
}

# 创建必要的目录
create_directories() {
    print_info "创建必要的目录..."
    mkdir -p media/ai_recording
    mkdir -p media/allure-reports
    mkdir -p media/allure-results
    mkdir -p media/requirement_docs
    mkdir -p logs
    mkdir -p allure
    print_info "目录创建完成 ✓"
}

# 启动服务
start_services() {
    print_info "启动 TestHub 服务..."
    docker-compose up -d
    
    print_info "等待服务启动..."
    sleep 10
    
    print_info "服务状态:"
    docker-compose ps
    
    print_info ""
    print_info "=========================================="
    print_info "TestHub 服务已启动！"
    print_info "=========================================="
    print_info "前端地址: http://localhost"
    print_info "后端 API: http://localhost:8000"
    print_info "API 文档: http://localhost:8000/api/docs/"
    print_info "Admin 后台: http://localhost:8000/admin/"
    print_info "=========================================="
    print_info ""
    print_warn "首次启动请执行: ./docker-start.sh init"
}

# 停止服务
stop_services() {
    print_info "停止 TestHub 服务..."
    docker-compose stop
    print_info "服务已停止 ✓"
}

# 重启服务
restart_services() {
    print_info "重启 TestHub 服务..."
    docker-compose restart
    print_info "服务已重启 ✓"
}

# 查看日志
view_logs() {
    print_info "查看服务日志 (Ctrl+C 退出)..."
    docker-compose logs -f
}

# 查看状态
view_status() {
    print_info "服务状态:"
    docker-compose ps
    
    print_info ""
    print_info "资源使用情况:"
    docker stats --no-stream $(docker-compose ps -q)
}

# 初始化数据
init_data() {
    print_info "初始化数据库..."
    
    # 等待数据库就绪
    print_info "等待数据库启动..."
    sleep 15
    
    # 执行数据库迁移
    print_info "执行数据库迁移..."
    docker-compose exec -T backend python manage.py migrate --noinput
    
    # 初始化定位策略
    print_info "初始化元素定位策略..."
    docker-compose exec -T backend python manage.py init_locator_strategies
    
    # 收集静态文件
    print_info "收集静态文件..."
    docker-compose exec -T backend python manage.py collectstatic --noinput
    
    # 创建超级用户
    print_info ""
    print_info "=========================================="
    print_info "创建管理员账号"
    print_info "=========================================="
    docker-compose exec backend python manage.py createsuperuser
    
    print_info ""
    print_info "=========================================="
    print_info "初始化完成！"
    print_info "=========================================="
    print_info "现在可以访问应用了："
    print_info "前端: http://localhost"
    print_info "后台: http://localhost:8000/admin/"
    print_info "=========================================="
}

# 完全清理
clean_all() {
    print_warn "警告：此操作将删除所有容器、镜像和数据卷！"
    read -p "确认继续？(yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        print_info "停止并删除所有容器..."
        docker-compose down -v
        
        print_info "删除镜像..."
        docker-compose down --rmi all
        
        print_info "清理完成 ✓"
    else
        print_info "操作已取消"
    fi
}

# 备份数据
backup_data() {
    BACKUP_DIR="./backups"
    DATE=$(date +%Y%m%d_%H%M%S)
    
    print_info "开始备份数据..."
    mkdir -p $BACKUP_DIR
    
    # 备份数据库
    print_info "备份数据库..."
    docker-compose exec -T mysql mysqldump -u root -ptesthub123 testhub > $BACKUP_DIR/db_$DATE.sql
    
    # 备份媒体文件
    print_info "备份媒体文件..."
    tar -czf $BACKUP_DIR/media_$DATE.tar.gz media/
    
    print_info "备份完成 ✓"
    print_info "备份文件保存在: $BACKUP_DIR"
}

# 显示帮助信息
show_help() {
    echo "TestHub Docker 管理脚本"
    echo ""
    echo "用法: ./docker-start.sh [命令]"
    echo ""
    echo "命令:"
    echo "  start      启动所有服务"
    echo "  stop       停止所有服务"
    echo "  restart    重启所有服务"
    echo "  logs       查看服务日志"
    echo "  status     查看服务状态"
    echo "  init       初始化数据库和创建管理员"
    echo "  backup     备份数据库和媒体文件"
    echo "  clean      完全清理（删除所有数据）"
    echo "  help       显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  ./docker-start.sh start    # 启动服务"
    echo "  ./docker-start.sh init     # 首次启动后初始化"
    echo "  ./docker-start.sh logs     # 查看日志"
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            check_requirements
            check_env_file
            create_directories
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        logs)
            view_logs
            ;;
        status)
            view_status
            ;;
        init)
            init_data
            ;;
        backup)
            backup_data
            ;;
        clean)
            clean_all
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
