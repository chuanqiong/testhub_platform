# TestHub Docker 管理 Makefile
# 使用 make 命令简化 Docker 操作

.PHONY: help build up down restart logs status init backup clean

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

help: ## 显示帮助信息
	@echo "$(BLUE)TestHub Docker 管理命令$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## 构建所有镜像
	@echo "$(BLUE)构建 Docker 镜像...$(NC)"
	docker-compose build

build-no-cache: ## 不使用缓存构建镜像
	@echo "$(BLUE)不使用缓存构建 Docker 镜像...$(NC)"
	docker-compose build --no-cache

up: ## 启动所有服务
	@echo "$(BLUE)启动服务...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)服务已启动！$(NC)"
	@echo "前端: http://localhost"
	@echo "后端: http://localhost:8000"
	@echo "API 文档: http://localhost:8000/api/docs/"

down: ## 停止并删除所有容器
	@echo "$(BLUE)停止服务...$(NC)"
	docker-compose down

stop: ## 停止所有服务
	@echo "$(BLUE)停止服务...$(NC)"
	docker-compose stop

restart: ## 重启所有服务
	@echo "$(BLUE)重启服务...$(NC)"
	docker-compose restart

logs: ## 查看所有服务日志
	docker-compose logs -f

logs-backend: ## 查看后端日志
	docker-compose logs -f backend

logs-frontend: ## 查看前端日志
	docker-compose logs -f frontend

logs-mysql: ## 查看 MySQL 日志
	docker-compose logs -f mysql

logs-redis: ## 查看 Redis 日志
	docker-compose logs -f redis

status: ## 查看服务状态
	@echo "$(BLUE)服务状态:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)资源使用:$(NC)"
	@docker stats --no-stream $$(docker-compose ps -q)

ps: ## 查看容器列表
	docker-compose ps

init: ## 初始化数据库
	@echo "$(BLUE)初始化数据库...$(NC)"
	@echo "等待数据库启动..."
	@sleep 15
	@echo "执行数据库迁移..."
	docker-compose exec -T backend python manage.py migrate --noinput
	@echo "初始化定位策略..."
	docker-compose exec -T backend python manage.py init_locator_strategies
	@echo "收集静态文件..."
	docker-compose exec -T backend python manage.py collectstatic --noinput
	@echo "$(GREEN)初始化完成！$(NC)"
	@echo "$(YELLOW)请运行 'make createsuperuser' 创建管理员账号$(NC)"

createsuperuser: ## 创建超级用户
	@echo "$(BLUE)创建管理员账号...$(NC)"
	docker-compose exec backend python manage.py createsuperuser

migrate: ## 执行数据库迁移
	@echo "$(BLUE)执行数据库迁移...$(NC)"
	docker-compose exec backend python manage.py migrate

makemigrations: ## 创建数据库迁移文件
	@echo "$(BLUE)创建数据库迁移文件...$(NC)"
	docker-compose exec backend python manage.py makemigrations

shell: ## 进入 Django shell
	docker-compose exec backend python manage.py shell

bash: ## 进入后端容器 bash
	docker-compose exec backend bash

mysql: ## 进入 MySQL 容器
	docker-compose exec mysql mysql -u root -p

redis-cli: ## 进入 Redis CLI
	docker-compose exec redis redis-cli -a 1234

backup: ## 备份数据库和媒体文件
	@echo "$(BLUE)备份数据...$(NC)"
	@mkdir -p backups
	@DATE=$$(date +%Y%m%d_%H%M%S); \
	echo "备份数据库..."; \
	docker-compose exec -T mysql mysqldump -u root -ptesthub123 testhub > backups/db_$$DATE.sql; \
	echo "备份媒体文件..."; \
	tar -czf backups/media_$$DATE.tar.gz media/; \
	echo "$(GREEN)备份完成: backups/db_$$DATE.sql, backups/media_$$DATE.tar.gz$(NC)"

restore-db: ## 恢复数据库 (使用: make restore-db FILE=backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(YELLOW)请指定备份文件: make restore-db FILE=backup.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)恢复数据库...$(NC)"
	docker-compose exec -T mysql mysql -u root -ptesthub123 testhub < $(FILE)
	@echo "$(GREEN)数据库恢复完成$(NC)"

clean: ## 清理所有容器、镜像和数据卷（危险操作）
	@echo "$(YELLOW)警告: 此操作将删除所有容器、镜像和数据卷！$(NC)"
	@read -p "确认继续？(yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "$(BLUE)清理中...$(NC)"; \
		docker-compose down -v --rmi all; \
		echo "$(GREEN)清理完成$(NC)"; \
	else \
		echo "操作已取消"; \
	fi

prune: ## 清理未使用的 Docker 资源
	@echo "$(BLUE)清理未使用的 Docker 资源...$(NC)"
	docker system prune -f
	@echo "$(GREEN)清理完成$(NC)"

update: ## 更新代码并重启服务
	@echo "$(BLUE)更新代码...$(NC)"
	git pull origin main
	@echo "$(BLUE)重新构建镜像...$(NC)"
	docker-compose build
	@echo "$(BLUE)重启服务...$(NC)"
	docker-compose up -d
	@echo "$(BLUE)执行数据库迁移...$(NC)"
	docker-compose exec backend python manage.py migrate
	@echo "$(GREEN)更新完成$(NC)"

dev: ## 开发模式启动（显示日志）
	@echo "$(BLUE)开发模式启动...$(NC)"
	docker-compose up

test: ## 运行测试
	@echo "$(BLUE)运行测试...$(NC)"
	docker-compose exec backend python manage.py test

check: ## 检查项目配置
	@echo "$(BLUE)检查项目配置...$(NC)"
	docker-compose exec backend python manage.py check

collectstatic: ## 收集静态文件
	@echo "$(BLUE)收集静态文件...$(NC)"
	docker-compose exec backend python manage.py collectstatic --noinput

install: ## 完整安装（构建、启动、初始化）
	@echo "$(BLUE)开始完整安装...$(NC)"
	@if [ ! -f .env ]; then \
		echo "创建 .env 文件..."; \
		cp .env.example .env; \
		echo "$(YELLOW)请编辑 .env 文件配置环境变量$(NC)"; \
	fi
	@echo "构建镜像..."
	@make build
	@echo "启动服务..."
	@make up
	@echo "初始化数据..."
	@make init
	@echo "$(GREEN)安装完成！$(NC)"
	@echo "$(YELLOW)请运行 'make createsuperuser' 创建管理员账号$(NC)"

health: ## 检查服务健康状态
	@echo "$(BLUE)检查服务健康状态...$(NC)"
	@echo ""
	@echo "Frontend: $$(curl -s -o /dev/null -w '%{http_code}' http://localhost || echo 'DOWN')"
	@echo "Backend: $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8000 || echo 'DOWN')"
	@echo "MySQL: $$(docker-compose exec -T mysql mysqladmin ping -h localhost -u root -ptesthub123 2>/dev/null && echo 'UP' || echo 'DOWN')"
	@echo "Redis: $$(docker-compose exec -T redis redis-cli -a 1234 ping 2>/dev/null || echo 'DOWN')"

info: ## 显示项目信息
	@echo "$(BLUE)TestHub 项目信息$(NC)"
	@echo ""
	@echo "访问地址:"
	@echo "  前端: http://localhost"
	@echo "  后端: http://localhost:8000"
	@echo "  API 文档: http://localhost:8000/api/docs/"
	@echo "  Admin: http://localhost:8000/admin/"
	@echo ""
	@echo "服务端口:"
	@echo "  Frontend: 80"
	@echo "  Backend: 8000"
	@echo "  MySQL: 3306"
	@echo "  Redis: 6379"
	@echo ""
	@echo "数据目录:"
	@echo "  媒体文件: ./media"
	@echo "  日志文件: ./logs"
	@echo "  备份文件: ./backups"

env: ## 创建环境变量文件
	@if [ -f .env ]; then \
		echo "$(YELLOW).env 文件已存在$(NC)"; \
	else \
		echo "$(BLUE)创建 .env 文件...$(NC)"; \
		cp .env.example .env; \
		echo "$(GREEN).env 文件已创建$(NC)"; \
		echo "$(YELLOW)请编辑 .env 文件配置环境变量$(NC)"; \
	fi
