# 部署指南

## 使用 Docker 部署

1. 启动所有服务
```bash
docker-compose up -d
```

2. 查看日志
```bash
docker-compose logs -f app
```

3. 停止服务
```bash
docker-compose down
```

## 数据库迁移

1. 生成迁移文件
```bash
alembic revision --autogenerate -m "描述"
```

2. 执行迁移
```bash
alembic upgrade head
```

3. 回滚迁移
```bash
alembic downgrade -1
```

## 运行测试

```bash
pytest tests/ -v
```

## 功能说明

- ✅ 日志系统：结构化日志输出
- ✅ Redis缓存：自动降级到无缓存模式
- ✅ 限流保护：每IP每分钟100次请求
- ✅ Docker部署：包含Redis和Qdrant
- ✅ 数据库迁移：Alembic支持
