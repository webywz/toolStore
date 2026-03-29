# API接口文档

> **产品定位**：船用五金 AI 识别与查询工具
> **基础 URL**：`https://api.example.com`
> **版本**：`v1`
> **认证方式**：Bearer Token（游客能力可按需开放）

---

## 一、接口范围

对外接口仅覆盖以下能力：
- 用户注册与登录
- 商品浏览与详情查询
- 智能搜索与搜索建议
- 拍照识别
- AI 问答
- 识别历史、问答历史、收藏
- 识别纠错与回答反馈

不在当前接口范围内：
- 订单
- 支付
- 购物车
- 后台管理
- 角色权限

---

## 二、认证接口

### 2.1 用户注册
```http
POST /api/v1/auth/register
Content-Type: application/json
```

请求：
```json
{
  "phone": "13800138000",
  "password": "123456",
  "nickname": "张三"
}
```

响应：
```json
{
  "success": true,
  "data": {
    "user_id": 1,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "nickname": "张三"
  }
}
```

### 2.2 用户登录
```http
POST /api/v1/auth/login
Content-Type: application/json
```

请求：
```json
{
  "phone": "13800138000",
  "password": "123456"
}
```

响应：
```json
{
  "success": true,
  "data": {
    "user_id": 1,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "nickname": "张三"
  }
}
```

### 2.3 当前用户信息
```http
GET /api/v1/users/me
Authorization: Bearer {token}
```

响应：
```json
{
  "success": true,
  "data": {
    "id": 1,
    "phone": "13800138000",
    "nickname": "张三",
    "avatar_url": "https://oss.example.com/avatar.jpg"
  }
}
```

---

## 三、商品与分类接口

### 3.1 商品列表
```http
GET /api/v1/products?page=1&limit=20&category_id=1&keyword=滤芯
```

响应：
```json
{
  "success": true,
  "data": {
    "total": 150,
    "page": 1,
    "limit": 20,
    "products": [
      {
        "id": 101,
        "name": "雅马哈F40机油滤芯",
        "price": 89.0,
        "images": ["url1", "url2"],
        "category": "挂机配件",
        "compatibility": ["F40", "F50", "F60"]
      }
    ]
  }
}
```

### 3.2 商品详情
```http
GET /api/v1/products/101
```

响应：
```json
{
  "success": true,
  "data": {
    "id": 101,
    "name": "雅马哈F40机油滤芯",
    "price": 89.0,
    "images": ["url1", "url2"],
    "description": "适用于雅马哈F40挂机...",
    "specs": {
      "型号": "69J-13440-03",
      "更换周期": "100小时"
    },
    "compatibility": ["F40", "F50", "F60"],
    "usage_scenarios": "挂机保养、定期更换",
    "safety_tips": ["检查 O 型圈", "按保养周期更换"],
    "keywords": ["雅马哈", "F40", "机油滤芯"],
    "created_at": "2026-03-20T10:00:00Z"
  }
}
```

### 3.3 分类列表
```http
GET /api/v1/categories
```

响应：
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "挂机配件",
      "icon_url": "url",
      "children": [
        {
          "id": 11,
          "name": "滤芯",
          "icon_url": "url"
        }
      ]
    }
  ]
}
```

---

## 四、搜索接口

### 4.1 智能搜索
```http
POST /api/v1/search/intelligent-search
Content-Type: application/json
```

请求：
```json
{
  "query": "F40 机油滤芯",
  "search_type": "auto"
}
```

`search_type` 说明：
- `auto`：自动判断
- `keyword`：关键词匹配
- `model`：型号优先
- `semantic`：语义搜索

响应：
```json
{
  "success": true,
  "data": {
    "query": "F40 机油滤芯",
    "search_type": "model",
    "results": [
      {
        "product_id": 101,
        "name": "雅马哈F40机油滤芯",
        "price": 89.0,
        "image": "url",
        "score": 0.97,
        "match_reason": "型号匹配 + 适配机型匹配"
      }
    ]
  }
}
```

### 4.2 搜索建议
```http
GET /api/v1/search/suggestions?q=F40
```

响应：
```json
{
  "success": true,
  "data": {
    "suggestions": [
      "F40 机油滤芯",
      "F40 火花塞",
      "F40 保养套件"
    ]
  }
}
```

### 4.3 搜索历史
```http
GET /api/v1/search/histories
Authorization: Bearer {token}
```

响应：
```json
{
  "success": true,
  "data": [
    "F40 机油滤芯",
    "316 不锈钢螺丝",
    "O 型圈"
  ]
}
```

---

## 五、AI 识别接口

### 5.1 拍照识别商品
```http
POST /api/v1/ai/recognize-image
Content-Type: multipart/form-data
Authorization: Bearer {token}
```

请求：
```text
file: [图片文件]
source: camera | album
```

响应：
```json
{
  "success": true,
  "data": {
    "recognition_id": "rec_123456",
    "image_url": "https://oss.example.com/uploads/xxx.jpg",
    "confidence": 0.86,
    "result": {
      "item_name": "M6 不锈钢螺丝",
      "category": "螺丝",
      "description": "这是一款船用不锈钢螺丝...",
      "features": ["316 不锈钢", "防腐蚀", "M6×20mm"],
      "usage": "适用于船体固定、挂机安装",
      "safety_tips": ["定期检查", "避免过度拧紧"]
    },
    "matched_products": [
      {
        "product_id": 101,
        "name": "316 不锈钢螺丝 M6×20",
        "price": 12.0,
        "similarity": 0.95,
        "image": "https://oss.example.com/products/101.jpg"
      }
    ],
    "needs_more_images": false
  }
}
```

### 5.2 识别历史
```http
GET /api/v1/ai/recognitions?page=1&limit=20
Authorization: Bearer {token}
```

响应：
```json
{
  "success": true,
  "data": {
    "total": 12,
    "records": [
      {
        "recognition_id": "rec_123456",
        "thumbnail": "https://oss.example.com/uploads/thumb.jpg",
        "item_name": "M6 不锈钢螺丝",
        "created_at": "2026-03-27T08:30:00Z"
      }
    ]
  }
}
```

### 5.3 识别纠错反馈
```http
POST /api/v1/ai/recognitions/{recognition_id}/feedback
Authorization: Bearer {token}
Content-Type: application/json
```

请求：
```json
{
  "feedback_type": "incorrect_match",
  "comment": "识别成 M6，实际是 M8",
  "correct_product_id": 205
}
```

响应：
```json
{
  "success": true,
  "data": {
    "message": "反馈已记录"
  }
}
```

---

## 六、AI 问答接口

### 6.1 AI 问答
```http
POST /api/v1/ai/rag-chat
Authorization: Bearer {token}
Content-Type: application/json
```

请求：
```json
{
  "question": "雅马哈 F40 挂机需要什么型号的机油滤芯？",
  "session_id": "session_123"
}
```

响应：
```json
{
  "success": true,
  "data": {
    "answer": "雅马哈 F40 挂机推荐使用 69J-13440-03 机油滤芯...",
    "citations": [
      {
        "knowledge_id": 1001,
        "title": "雅马哈F40机油滤芯适配",
        "snippet": "适用机型：F40、F50A..."
      }
    ],
    "recommended_products": [
      {
        "product_id": 201,
        "name": "雅马哈 10W-40 机油",
        "price": 120.0,
        "image": "https://oss.example.com/products/201.jpg"
      }
    ],
    "session_id": "session_123"
  }
}
```

### 6.2 问答历史
```http
GET /api/v1/ai/conversations?page=1&limit=20
Authorization: Bearer {token}
```

响应：
```json
{
  "success": true,
  "data": {
    "total": 8,
    "sessions": [
      {
        "session_id": "session_123",
        "last_question": "F40 用什么机油滤芯？",
        "updated_at": "2026-03-27T09:20:00Z"
      }
    ]
  }
}
```

### 6.3 AI 回答反馈
```http
POST /api/v1/ai/conversations/{session_id}/feedback
Authorization: Bearer {token}
Content-Type: application/json
```

请求：
```json
{
  "message_id": "msg_001",
  "rating": 1,
  "comment": "回答过于笼统，没有给出型号"
}
```

响应：
```json
{
  "success": true,
  "data": {
    "message": "反馈已记录"
  }
}
```

---

## 七、收藏接口

### 7.1 收藏商品
```http
POST /api/v1/favorites/101
Authorization: Bearer {token}
```

响应：
```json
{
  "success": true,
  "data": {
    "message": "收藏成功"
  }
}
```

### 7.2 取消收藏
```http
DELETE /api/v1/favorites/101
Authorization: Bearer {token}
```

响应：
```json
{
  "success": true,
  "data": {
    "message": "已取消收藏"
  }
}
```

### 7.3 收藏列表
```http
GET /api/v1/favorites?page=1&limit=20
Authorization: Bearer {token}
```

响应：
```json
{
  "success": true,
  "data": {
    "total": 5,
    "products": [
      {
        "id": 101,
        "name": "雅马哈F40机油滤芯",
        "price": 89.0,
        "image": "url"
      }
    ]
  }
}
```

---

## 八、内部维护接口（非移动端）

这部分用于知识库维护脚本或内部工具调用，不属于移动端正式功能。

### 8.1 导入知识文档
```http
POST /api/v1/internal/knowledge/upload-document
Content-Type: multipart/form-data
```

请求：
```text
file: [PDF/Word/Excel 文件]
product_ids: "101,102"
```

响应：
```json
{
  "success": true,
  "data": {
    "message": "成功提取 5 条知识",
    "knowledge_ids": [1001, 1002, 1003, 1004, 1005]
  }
}
```

### 8.2 重建知识向量
```http
POST /api/v1/internal/knowledge/reindex
Content-Type: application/json
```

请求：
```json
{
  "knowledge_ids": [1001, 1002],
  "rebuild_mode": "incremental"
}
```

---

## 九、错误码定义

```text
200    成功
400    请求参数错误
401    未授权（token 无效或过期）
404    资源不存在
409    重复操作
422    业务校验失败
500    服务器错误

业务错误码：
10001  用户不存在
10002  密码错误
10003  手机号已注册
20001  商品不存在
20002  分类不存在
30001  AI 识别失败
30002  图片格式不支持
30003  图片过大
30004  识别结果置信度过低
40001  知识库检索失败
40002  知识片段不足，无法回答
```

---

## 十、通用响应格式

### 成功响应
```json
{
  "success": true,
  "data": {}
}
```

### 失败响应
```json
{
  "success": false,
  "error": {
    "code": 10001,
    "message": "用户不存在"
  }
}
```
