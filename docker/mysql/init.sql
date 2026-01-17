-- 初始化 TestHub 数据库
-- 设置字符集
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS testhub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE testhub;

-- 设置时区
SET time_zone = '+08:00';

-- 授权
GRANT ALL PRIVILEGES ON testhub.* TO 'testhub'@'%';
FLUSH PRIVILEGES;
