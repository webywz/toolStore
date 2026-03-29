# 船用五金 AI 识别与查询工具

基于 FastAPI + Claude AI + 向量检索的船用五金配件智能识别和查询系统。

## 功能特性

- 🔍 AI 图像识别：使用 Claude 识别船用五金配件
- 💬 智能问答：基于 RAG 的产品知识问答
- 📦 产品管理：分类、搜索、收藏功能
- 📚 知识库：文档解析和向量检索
- 👤 用户系统：注册、登录、个人中心

## 技术栈

- FastAPI - Web 框架
- SQLAlchemy - ORM
- Claude API - AI 图像识别
- 智谱 AI - 文本向量化
- Qdrant - 向量数据库
- 阿里云 OSS - 对象存储

## 快速开始

1. 安装依赖
```bash
pip install -r requirements.txt
```

2. 配置环境变量
```bash
cp .env.example .env
# 编辑 .env 文件，填入必要的 API 密钥
```

3. 启动服务
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

4. 访问 API 文档
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API 接口

### 认证相关
- POST /api/v1/auth/register - 用户注册
- POST /api/v1/auth/login - 用户登录
- POST /api/v1/auth/change-password - 修改密码

### AI 功能
- POST /api/v1/ai/recognize-image - 图像识别
- POST /api/v1/ai/rag-chat - 智能问答
- GET /api/v1/ai/recognitions - 识别历史
- GET /api/v1/ai/conversations - 对话历史

### 产品相关
- GET /api/v1/products - 产品列表
- GET /api/v1/products/{id} - 产品详情
- GET /api/v1/categories - 分类列表

### 搜索功能
- POST /api/v1/search/intelligent-search - 智能搜索
- GET /api/v1/search/suggestions - 搜索建议
- GET /api/v1/search/histories - 搜索历史

### 收藏功能
- POST /api/v1/favorites - 添加收藏
- DELETE /api/v1/favorites/{id} - 取消收藏
- GET /api/v1/favorites - 收藏列表

### 管理后台
- POST /api/v1/internal/knowledge/upload-document - 上传文档
- GET /api/v1/internal/knowledge/items - 知识列表
- POST /api/v1/internal/knowledge/reindex - 重建索引
- POST /api/v1/internal/products - 创建产品
- PUT /api/v1/internal/products/{id} - 更新产品

## 项目结构

```
toolStore/
├── app/
│   ├── api/v1/          # API 路由
│   ├── core/            # 核心功能（安全、异常）
│   ├── models/          # 数据模型
│   ├── schemas/         # Pydantic 模型
│   ├── services/        # 业务逻辑
│   ├── bootstrap.py     # 数据初始化
│   ├── config.py        # 配置
│   ├── database.py      # 数据库连接
│   └── main.py          # 应用入口
├── data/                # 数据文件
├── requirements.txt     # 依赖列表
└── .env                 # 环境变量
```

## 开发说明

默认测试账号：
- 手机号：13800138000
- 密码：123456

## License

MIT
