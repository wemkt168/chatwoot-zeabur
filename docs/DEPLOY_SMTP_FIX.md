# SMTP 修复部署指南

## 📋 已完成的修改

1. ✅ 修改了 `config/initializers/mailer.rb`，强制 production 环境使用 SMTP
2. ✅ 代码已推送到 GitHub (`develop` 分支)
3. ✅ Zeabur 服务已配置为使用 GitHub 储存库作为部署来源

## 🚀 部署方式：GitHub 储存库（已配置）

### 当前配置

你的 Zeabur 服务已经配置为使用 GitHub 储存库作为部署来源：

- **rails 服务**：`https://github.com/wemkt168/chatwoot-zeabur` (分支: `develop`)
- **sidekiq 服务**：`https://github.com/wemkt168/chatwoot-zeabur` (分支: `develop`)

### 自动部署流程

```
代码推送到 GitHub
    ↓
Zeabur 自动检测到更新（Webhook）
    ↓
Zeabur 自动构建 Docker 镜像（2-5 分钟）
    ↓
Zeabur 自动部署新版本（1-2 分钟）
    ↓
服务重启，新代码生效
```

### 当前状态

✅ **代码已推送**：SMTP 修复已推送到 `develop` 分支  
✅ **服务已绑定**：rails 和 sidekiq 都已绑定到 GitHub 储存库  
⏳ **等待部署**：Zeabur 应该正在自动构建和部署

---

## ✅ 验证部署

### 1. 检查 Zeabur 部署状态

在 Zeabur 控制台中：

1. 打开 `rails` 服务的「服務狀態」标签
   - 查看是否显示「正在部署」或「部署中」
   - 等待部署完成（通常 3-7 分钟）

2. 打开 `sidekiq` 服务的「服務狀態」标签
   - 同样检查部署状态
   - 等待部署完成

### 2. 检查环境变量

确保以下环境变量已正确设置（在「環境變數」标签中）：

```
RAILS_ENV=production
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=<你的 Gmail 应用程式密码>
SMTP_DOMAIN=gmail.com
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true
MAILER_SENDER_EMAIL=your-email@gmail.com
FRONTEND_URL=<你的前端 URL>
```

### 3. 测试邮件发送

部署完成后：

1. **触发测试邮件**
   - 在 Chatwoot 中尝试「忘记密码」功能
   - 或邀请新的 Agent

2. **检查日志**
   - 在 Zeabur 的 `rails` 服务中查看日志
   - 应该看到：
     - ✅ 不再出现 `Mail::Sendmail::DeliveryError`
     - ✅ 不再调用 `/usr/sbin/sendmail`
     - ✅ SMTP 连接成功的信息

3. **验证邮件发送**
   - 检查收件箱是否收到邮件
   - 确认邮件发送成功

---

## 🔍 故障排除

### 如果部署失败

1. **检查 GitHub 绑定**
   - 确认仓库 URL 正确：`https://github.com/wemkt168/chatwoot-zeabur`
   - 确认分支正确：`develop`

2. **检查构建日志**
   - 在 Zeabur 服务状态页面查看构建日志
   - 查找错误信息

3. **手动触发部署**
   - 在服务设置中，可以尝试「重新部署」按钮

### 如果邮件仍然发送失败

1. **检查环境变量**
   - 确认所有 SMTP 环境变量都已正确设置
   - 特别注意 `SMTP_PASSWORD` 是 Gmail 应用程式密码，不是普通密码

2. **检查日志**
   - 查看 Zeabur 服务日志中的错误信息
   - 确认 SMTP 连接是否成功

3. **验证 Gmail 设置**
   - 确认已启用 Gmail 的「允许不够安全的应用程式存取」
   - 或使用应用程式专用密码

---

## 📝 修改说明

### 修改的文件

- `config/initializers/mailer.rb`

### 关键变更

**修改前：**
```ruby
config.action_mailer.delivery_method = :smtp unless Rails.env.test?
config.action_mailer.smtp_settings = smtp_settings
config.action_mailer.delivery_method = :sendmail if ENV['SMTP_ADDRESS'].blank?
```

**修改后：**
```ruby
# Delivery method configuration
# In production, always use SMTP (never use sendmail)
if Rails.env.production?
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = smtp_settings
elsif Rails.env.test?
  config.action_mailer.delivery_method = :test
else
  # Development and other non-production environments
  config.action_mailer.delivery_method = :smtp unless ENV['SMTP_ADDRESS'].blank?
  config.action_mailer.smtp_settings = smtp_settings
  config.action_mailer.delivery_method = :sendmail if ENV['SMTP_ADDRESS'].blank?
end
```

### 工作原理

- **Production 环境**：强制使用 SMTP，不再回退到 sendmail
- **Test 环境**：使用 `:test` 模式
- **其他环境**：有 SMTP 配置时使用 SMTP，否则使用 sendmail

---

## 🎯 优势

使用 GitHub 储存库作为部署来源的优势：

- ✅ **无需配置 Docker Hub Token**
- ✅ **无需手动构建镜像**
- ✅ **自动检测代码更新**
- ✅ **自动构建和部署**
- ✅ **配置简单，流程直接**

---

**最后更新**：2025-12-26  
**部署方式**：GitHub 储存库自动部署
