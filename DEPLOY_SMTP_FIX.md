# SMTP 修复部署指南

## 📋 已完成的修改

1. ✅ 修改了 `config/initializers/mailer.rb`，强制 production 环境使用 SMTP
2. ✅ 创建了 GitHub Actions workflow (`.github/workflows/build-smtp-fix.yml`)

## 🚀 部署步骤

### 选项 1：使用 GitHub Actions 自动构建（推荐）

#### 1.1 配置 GitHub Secrets

在 GitHub 仓库设置中添加 Docker Hub 认证信息：

1. 前往：`https://github.com/wemkt168/chatwoot-zeabur/settings/secrets/actions`
2. 添加以下 Secrets：
   - **Name**: `DOCKERHUB_USERNAME`
   - **Value**: `wemkt168`
   
   - **Name**: `DOCKERHUB_TOKEN`
   - **Value**: 你的 Docker Hub Access Token（在 Docker Hub → Account Settings → Security 中生成）

#### 1.2 提交并推送代码

```bash
# 配置 git 用户信息（如果还没配置）
git config user.email "your-email@example.com"
git config user.name "Your Name"

# 提交更改
git add config/initializers/mailer.rb .github/workflows/build-smtp-fix.yml
git commit -m "fix: Force SMTP delivery method in production environment"
git push origin develop
```

#### 1.3 触发构建

- 推送代码后，GitHub Actions 会自动触发构建
- 或者手动触发：前往 Actions → "Build and Push SMTP Fix Docker Image" → Run workflow

#### 1.4 等待构建完成

- 在 GitHub Actions 页面查看构建进度
- 构建完成后，镜像会自动推送到：`wemkt168/chatwoot-zeabur:smtp-fix`

---

### 选项 2：本地手动构建

如果你本地有 Docker 环境，可以手动构建：

```bash
# 1. 确保在项目根目录
cd chatwoot-zeabur

# 2. 登录 Docker Hub
docker login

# 3. 构建镜像
docker build -f docker/Dockerfile -t wemkt168/chatwoot-zeabur:smtp-fix .

# 4. 推送镜像
docker push wemkt168/chatwoot-zeabur:smtp-fix
```

---

## ✅ 在 Zeabur 中验证

你已经将 Zeabur 中的 `rails` 和 `sidekiq` 服务镜像设置为 `wemkt168/chatwoot-zeabur:smtp-fix`。

### 验证步骤：

1. **确认镜像已更新**
   - 在 Zeabur 控制台检查服务状态
   - 确认使用的是新镜像

2. **检查环境变量**
   确保以下环境变量已正确设置：
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

3. **测试邮件发送**
   - 在 Chatwoot 中触发密码重置邮件
   - 检查 Rails 日志，确认使用 SMTP 而非 sendmail
   - 验证邮件是否成功发送

4. **查看日志确认**
   在 Zeabur 的 rails 服务日志中，应该看到：
   - 不再出现 `Mail::Sendmail::DeliveryError`
   - 不再调用 `/usr/sbin/sendmail`
   - SMTP 连接成功的信息

---

## 🔍 故障排除

如果邮件仍然发送失败：

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
if Rails.env.production?
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = smtp_settings
elsif Rails.env.test?
  config.action_mailer.delivery_method = :test
else
  config.action_mailer.delivery_method = :smtp unless ENV['SMTP_ADDRESS'].blank?
  config.action_mailer.smtp_settings = smtp_settings
  config.action_mailer.delivery_method = :sendmail if ENV['SMTP_ADDRESS'].blank?
end
```

### 工作原理

- **Production 环境**：强制使用 SMTP，不再回退到 sendmail
- **Test 环境**：使用 `:test` 模式
- **其他环境**：有 SMTP 配置时使用 SMTP，否则使用 sendmail

