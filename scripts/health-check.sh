#!/bin/bash

# 服务健康检查脚本
# 用于监控所有服务的健康状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

check_service() {
    local service_name=$1
    local check_command=$2
    
    echo -n "检查 $service_name... "
    
    if eval $check_command > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 正常${NC}"
        return 0
    else
        echo -e "${RED}✗ 异常${NC}"
        return 1
    fi
}

check_http() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    echo -n "检查 $name ($url)... "
    
    http_code=$(curl -s -o /dev/null -w '%{http_code}' $url 2>/dev/null || echo "000")
    
    if [ "$http_code" = "$expected_code" ]; then
        echo -e "${GREEN}✓ 正常 (HTTP $http_code)${NC}"
        return 0
    else
        echo -e "${RED}✗ 异常 (HTTP $http_code)${NC}"
        return 1
    fi
}

# 主检查流程
main() {
    print_header "TestHub 服务健康检查"
    echo ""
    
    # 检查 Docker 服务
    print_header "Docker 容器状态"
    docker-compose ps
    echo ""
    
    # 检查各个服务
    print_header "服务连接检查"
    
    total=0
    success=0
    
    # 检查前端
    if check_http "前端服务" "http://localhost" "200"; then
        ((success++))
    fi
    ((total++))
    
    # 检查后端
    if check_http "后端 API" "http://localhost:8000" "200,301,302"; then
        ((success++))
    fi
    ((total++))
    
    # 检查 API 文档
    if check_http "API 文档" "http://localhost:8000/api/docs/" "200"; then
        ((success++))
    fi
    ((total++))
    
    # 检查 MySQL
    if check_service "MySQL 数据库" "docker-compose exec -T mysql mysqladmin ping -h localhost -u root -ptesthub123"; then
        ((success++))
    fi
    ((total++))
    
    # 检查 Redis
    if check_service "Redis 缓存" "docker-compose exec -T redis redis-cli -a 1234 ping"; then
        ((success++))
    fi
    ((total++))
    
    echo ""
    print_header "资源使用情况"
    docker stats --no-stream $(docker-compose ps -q) 2>/dev/null || echo "无法获取资源使用情况"
    
    echo ""
    print_header "检查结果"
    echo -e "总计: $total 个服务"
    echo -e "正常: ${GREEN}$success${NC} 个"
    echo -e "异常: ${RED}$((total - success))${NC} 个"
    
    if [ $success -eq $total ]; then
        echo -e "${GREEN}所有服务运行正常！${NC}"
        exit 0
    else
        echo -e "${RED}部分服务异常，请检查日志${NC}"
        echo "查看日志: docker-compose logs -f"
        exit 1
    fi
}

# 执行检查
main
