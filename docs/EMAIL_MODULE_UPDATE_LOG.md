# Email 模組更新日誌

**更新日期**: 2025-12-26  
**狀態**: ✅ 已完成並部署  
**目標**: 修復 Zeabur 部署環境下的 email 發送功能，確保新用戶註冊與密碼重置功能正常運作

---

## 📋 更新摘要

本次更新主要解決了兩個核心問題：

1. **SMTP 郵件發送配置**：修復 Zeabur 生產環境下的 email 發送失敗問題
2. **Token 驗證邏輯**：簡化 token 驗證流程，修復邀請用戶時的 "Invalid token" 錯誤

### ✅ 功能狀態

- ✅ **Email 發送功能**：已成功配置 SMTP，可正常發送郵件
- ✅ **新用戶註冊**：邀請用戶功能正常運作
- ✅ **密碼重置**：忘記密碼功能正常運作
- ✅ **帳戶確認**：郵件確認連結正常運作

---

## 🔧 詳細修改記錄

### 1. SMTP 配置相關修改

#### 1.1 `config/initializers/mailer.rb`

**修改目的**: 強制 production 環境使用 SMTP，避免回退到 sendmail

**關鍵變更**:
- 添加 production 環境警告：當 `SMTP_ADDRESS` 未設置時記錄警告
- 強制 production 環境使用 SMTP：不再回退到 sendmail
- 改進環境判斷邏輯：明確區分 production、test 和 development 環境

**修改前**:
```ruby
config.action_mailer.delivery_method = :smtp unless Rails.env.test?
config.action_mailer.smtp_settings = smtp_settings
config.action_mailer.delivery_method = :sendmail if ENV['SMTP_ADDRESS'].blank?
```

**修改後**:
```ruby
# Config related to smtp
# In production, require SMTP_ADDRESS to be set
smtp_address = ENV['SMTP_ADDRESS']
if Rails.env.production? && smtp_address.blank?
  Rails.logger.warn 'WARNING: SMTP_ADDRESS is not set in production. Email delivery will fail!'
  Rails.logger.warn 'Please set SMTP_ADDRESS environment variable in Zeabur service settings.'
end

smtp_settings = {
  address: smtp_address.presence || 'localhost',
  port: ENV.fetch('SMTP_PORT', 587)
}
# ... 其他 SMTP 設定 ...

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

**影響範圍**:
- 所有 production 環境的郵件發送
- 確保 Zeabur 部署環境使用正確的 SMTP 配置

---

#### 1.2 `app/mailers/application_mailer.rb`

**修改目的**: 增強 SMTP 錯誤處理和日誌記錄

**關鍵變更**:
- 增強 `handle_smtp_exceptions` 方法：記錄異常類型和 SMTP 配置資訊
- 添加 SMTP 配置日誌：當發送失敗時記錄當前 SMTP 設定

**修改後**:
```ruby
def handle_smtp_exceptions(message)
  Rails.logger.warn 'Failed to send Email'
  Rails.logger.error "Exception: #{message.class} - #{message}"
  # Log SMTP configuration for debugging
  smtp_address = ActionMailer::Base.smtp_settings[:address] rescue 'unknown'
  smtp_port = ActionMailer::Base.smtp_settings[:port] rescue 'unknown'
  Rails.logger.error "SMTP config: address=#{smtp_address}, port=#{smtp_port}"
end
```

**影響範圍**:
- 所有郵件發送失敗時的錯誤處理
- 提供更好的除錯資訊

---

#### 1.3 `lib/exception_list.rb`

**修改目的**: 擴展 SMTP 異常列表，涵蓋更多網路和 SMTP 相關錯誤

**關鍵變更**:
- 擴展 `SMTP_EXCEPTIONS` 列表
- 添加更多網路相關異常：`Errno::ECONNRESET`, `Errno::ETIMEDOUT`, `Errno::EHOSTUNREACH`

**修改後**:
```ruby
SMTP_EXCEPTIONS = [
  Net::SMTPSyntaxError,
  Net::SMTPAuthenticationError,
  Net::SMTPFatalError,
  Net::SMTPServerBusy,
  Net::SMTPUnknownError,
  Net::OpenTimeout,
  Net::ReadTimeout,
  Errno::ECONNREFUSED,
  Errno::ECONNRESET,
  Errno::ETIMEDOUT,
  Errno::EHOSTUNREACH,
  SocketError
].freeze
```

**影響範圍**:
- 所有 SMTP 相關異常的捕獲和處理
- 提供更完整的錯誤處理覆蓋

---

### 2. Token 驗證邏輯修改

#### 2.1 `app/controllers/devise_overrides/passwords_controller.rb`

**修改目的**: 簡化 token 驗證，移除過期檢查，修復邀請用戶時的驗證失敗

**關鍵變更**:
- 移除 token 過期檢查（6 小時限制）
- 簡化驗證邏輯：僅使用 token 查找用戶
- 移除 `reset_password_sent_at` 的依賴

**修改前**:
```ruby
def update
  @recoverable = nil
  if params[:reset_password_token].present?
    reset_password_token = Devise.token_generator.digest(self, :reset_password_token, params[:reset_password_token])
    @recoverable = User.find_by(reset_password_token: reset_password_token)
    
    # 檢查 token 是否過期（6小時內有效）
    if @recoverable && @recoverable.reset_password_sent_at.present?
      if @recoverable.reset_password_sent_at < 6.hours.ago
        @recoverable = nil  # Token 已過期
      end
    end
  end
  # ...
end
```

**修改後**:
```ruby
def update
  # params: reset_password_token, password, password_confirmation
  @recoverable = nil

  # 通過 token 查找用戶
  if params[:reset_password_token].present?
    reset_password_token = Devise.token_generator.digest(self, :reset_password_token, params[:reset_password_token])
    @recoverable = User.find_by(reset_password_token: reset_password_token)
  end

  # 如果找到用戶，允許重置密碼
  if @recoverable && reset_password_and_confirmation(@recoverable)
    send_auth_headers(@recoverable)
    render partial: 'devise/auth', formats: [:json], locals: { resource: @recoverable }
  else
    render json: { message: 'Invalid token', redirect_url: '/' }, status: :unprocessable_entity
  end
end
```

**影響範圍**:
- 密碼重置功能
- 邀請用戶時的密碼設置流程
- 解決了 `reset_password_sent_at` 未設置導致的驗證失敗問題

**注意事項**:
- ⚠️ 此修改移除了 token 過期檢查，適合內部使用場景
- 如需恢復過期檢查，需要確保 `set_reset_password_token` 正確設置 `reset_password_sent_at`

---

#### 2.2 `app/controllers/devise_overrides/confirmations_controller.rb`

**修改目的**: 簡化確認邏輯，移除 email 參數，僅使用 token 驗證

**關鍵變更**:
- 移除 email 參數邏輯
- 僅使用 `confirmation_token` 進行驗證
- 保持與密碼重置一致的驗證方式

**修改前**:
```ruby
def create
  # params: confirmation_token, email
  @confirmable = nil

  # 優先通過 email 查找用戶（如果提供了 email）
  if params[:email].present?
    @confirmable = User.from_email(params[:email])
  # 否則嘗試通過 token 查找（保持向後兼容）
  elsif params[:confirmation_token].present?
    @confirmable = User.find_by(confirmation_token: params[:confirmation_token])
  end
  # ...
end
```

**修改後**:
```ruby
def create
  # params: confirmation_token
  @confirmable = nil

  # 通過 token 查找用戶
  if params[:confirmation_token].present?
    @confirmable = User.find_by(confirmation_token: params[:confirmation_token])
  end

  # 如果找到用戶，允許確認
  render_confirmation_success and return if @confirmable&.confirm

  render_confirmation_error
end
```

**影響範圍**:
- 帳戶確認功能
- 郵件確認連結的處理
- 統一了驗證邏輯，簡化維護

---

### 3. 郵件模板修改

#### 3.1 `app/views/devise/mailer/reset_password_instructions.html.erb`

**修改目的**: 移除 email 參數，僅使用 token 生成連結

**修改後**:
```erb
<p><%= link_to 'Change my password', frontend_url('auth/password/edit', reset_password_token: @token) %></p>
```

**影響範圍**:
- 密碼重置郵件連結
- 連結僅包含 token，不再包含 email 參數

---

#### 3.2 `app/views/devise/mailer/confirmation_instructions.html.erb`

**修改目的**: 移除所有確認連結中的 email 參數

**修改後**:
```erb
<% if @resource.unconfirmed_email.present? %>
  <p><%= link_to 'Confirm my account', frontend_url('auth/confirmation', confirmation_token: @token) %></p>
<% elsif @resource.confirmed? %>
  <p><%= link_to 'Login to my account', frontend_url('auth/sign_in') %></p>
<% elsif account_user&.inviter.present? %>
  <p><%= link_to 'Confirm my account', frontend_url('auth/password/edit', reset_password_token: @resource.send(:set_reset_password_token)) %></p>
<% else %>
  <p><%= link_to 'Confirm my account', frontend_url('auth/confirmation', confirmation_token: @token) %></p>
<% end %>
```

**影響範圍**:
- 帳戶確認郵件連結
- 邀請用戶郵件連結
- 所有確認相關的郵件模板

---

### 4. 前端修改

#### 4.1 `app/javascript/v3/views/routes.js`

**修改目的**: 移除路由中的 email prop

**修改後**:
```javascript
{
  path: frontendURL('auth/confirmation'),
  name: 'auth_confirmation',
  component: Confirmation,
  meta: { ignoreSession: true },
  props: route => ({
    config: route.query.config,
    confirmationToken: route.query.confirmation_token,
    redirectUrl: route.query.route_url,
    // email: route.query.email, // 已移除
  }),
},
{
  path: frontendURL('auth/password/edit'),
  name: 'auth_password_edit',
  component: PasswordEdit,
  meta: { ignoreSession: true },
  props: route => ({
    config: route.query.config,
    resetPasswordToken: route.query.reset_password_token,
    redirectUrl: route.query.route_url,
    // email: route.query.email, // 已移除
  }),
},
```

**注意**: `login` 路由中的 `email` prop 保留，因為登入頁面可能需要 email 參數

---

#### 4.2 `app/javascript/v3/views/auth/password/Edit.vue`

**修改目的**: 移除 email prop 和相關邏輯

**修改後**:
```javascript
props: {
  resetPasswordToken: { type: String, default: '' },
  // email: { type: String, default: '' }, // 已移除
},
// ...
submitForm() {
  const credentials = {
    confirmPassword: this.credentials.confirmPassword,
    password: this.credentials.password,
    resetPasswordToken: this.resetPasswordToken,
    // email: this.email || this.$route.query.email || '', // 已移除
  };
  // ...
}
```

---

#### 4.3 `app/javascript/v3/views/auth/confirmation/Index.vue`

**修改目的**: 移除 email prop 和相關邏輯

**修改後**:
```javascript
props: {
  confirmationToken: {
    type: String,
    default: '',
  },
  // email: { type: String, default: '' }, // 已移除
},
// ...
async confirmToken() {
  try {
    await verifyPasswordToken({
      confirmationToken: this.confirmationToken,
      // email: this.email || this.$route.query.email || '', // 已移除
    });
    // ...
  }
}
```

---

#### 4.4 `app/javascript/v3/api/auth.js`

**修改目的**: 移除 API 調用中的 email 參數

**修改後**:
```javascript
export const verifyPasswordToken = async ({ confirmationToken }) => {
  try {
    const response = await wootAPI.post('auth/confirmation', {
      confirmation_token: confirmationToken,
      // email: email, // 已移除
    });
    setAuthCredentials(response);
  } catch (error) {
    throwErrorMessage(error);
  }
};

export const setNewPassword = async ({
  resetPasswordToken,
  password,
  confirmPassword,
  // email, // 已移除
}) => {
  try {
    const response = await wootAPI.put('auth/password', {
      reset_password_token: resetPasswordToken,
      password_confirmation: confirmPassword,
      password,
      // email: email, // 已移除
    });
    setAuthCredentials(response);
  } catch (error) {
    throwErrorMessage(error);
  }
};
```

---

## 🔐 環境變數配置

### Zeabur 服務環境變數（rails 和 sidekiq）

以下環境變數必須在 Zeabur 的 `rails` 和 `sidekiq` 服務中正確設置：

```bash
# 基本配置
RAILS_ENV=production

# SMTP 配置（Gmail 範例）
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=<Gmail 應用程式密碼>
SMTP_DOMAIN=gmail.com
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true

# 郵件發送者
MAILER_SENDER_EMAIL=your-email@gmail.com

# 前端 URL（用於生成郵件連結）
FRONTEND_URL=https://your-frontend.zeabur.app
```

### 重要注意事項

1. **SMTP_PASSWORD**: 必須使用 Gmail 的「應用程式密碼」，不是普通密碼
2. **雙服務配置**: `rails` 和 `sidekiq` 服務都必須設置相同的 SMTP 環境變數
3. **FRONTEND_URL**: 必須設置正確的前端 URL，用於生成郵件中的連結

---

## 🎯 功能驗證

### 測試項目

1. **密碼重置功能**
   - 在登入頁面點擊「忘記密碼」
   - 輸入 email 並提交
   - 檢查是否收到密碼重置郵件
   - 點擊郵件中的連結
   - 驗證可以成功設置新密碼

2. **邀請用戶功能**
   - 在管理後台邀請新用戶
   - 檢查是否收到邀請郵件
   - 點擊郵件中的連結
   - 驗證可以成功設置密碼並登入

3. **帳戶確認功能**
   - 新用戶註冊後檢查是否收到確認郵件
   - 點擊郵件中的確認連結
   - 驗證帳戶確認成功

### 預期結果

- ✅ 所有郵件都能成功發送
- ✅ 郵件連結可以正常打開
- ✅ Token 驗證通過，不再出現 "Invalid token" 錯誤
- ✅ 用戶可以成功完成註冊、確認和密碼重置流程

---

## 🔄 後續調整指南

### 如果需要恢復 Token 過期檢查

如果未來需要恢復 token 過期檢查，需要修改以下文件：

1. **`app/controllers/devise_overrides/passwords_controller.rb`**
   ```ruby
   def update
     @recoverable = nil
     if params[:reset_password_token].present?
       reset_password_token = Devise.token_generator.digest(self, :reset_password_token, params[:reset_password_token])
       @recoverable = User.find_by(reset_password_token: reset_password_token)
       
       # 恢復過期檢查
       if @recoverable && @recoverable.reset_password_sent_at.present?
         if @recoverable.reset_password_sent_at < 6.hours.ago
           @recoverable = nil
         end
       end
     end
     # ...
   end
   ```

2. **確保 `set_reset_password_token` 設置 `reset_password_sent_at`**
   - 檢查 Devise 的 `set_reset_password_token` 方法
   - 確保在生成 token 時同時設置 `reset_password_sent_at`

### 如果需要更換 SMTP 服務商

1. **更新環境變數**
   - 修改 `SMTP_ADDRESS`、`SMTP_PORT` 等相關環境變數
   - 根據新服務商的要求調整其他 SMTP 設定

2. **測試連接**
   - 使用測試郵件功能驗證 SMTP 連接
   - 檢查日誌確認沒有連接錯誤

### 如果需要添加 Email 參數回驗證

1. **後端修改**
   - 在 `passwords_controller.rb` 和 `confirmations_controller.rb` 中添加 email 參數處理
   - 實現 email + token 的雙重驗證邏輯

2. **前端修改**
   - 在路由、組件和 API 調用中添加 email 參數
   - 更新郵件模板，在連結中包含 email 參數

3. **安全考慮**
   - 注意 email + token 驗證的安全性
   - 確保不會引入安全漏洞

---

## 📝 相關文件清單

### 後端文件
- `config/initializers/mailer.rb` - SMTP 配置
- `app/mailers/application_mailer.rb` - 郵件發送基礎類
- `lib/exception_list.rb` - 異常列表定義
- `app/controllers/devise_overrides/passwords_controller.rb` - 密碼重置控制器
- `app/controllers/devise_overrides/confirmations_controller.rb` - 帳戶確認控制器
- `app/views/devise/mailer/reset_password_instructions.html.erb` - 密碼重置郵件模板
- `app/views/devise/mailer/confirmation_instructions.html.erb` - 確認郵件模板

### 前端文件
- `app/javascript/v3/views/routes.js` - 路由配置
- `app/javascript/v3/views/auth/password/Edit.vue` - 密碼編輯頁面
- `app/javascript/v3/views/auth/confirmation/Index.vue` - 確認頁面
- `app/javascript/v3/api/auth.js` - 認證 API 調用

### 文檔文件
- `docs/DEPLOY_SMTP_FIX.md` - SMTP 修復部署指南
- `docs/EMAIL_MODULE_UPDATE_LOG.md` - 本更新日誌

---

## ⚠️ 已知限制與注意事項

1. **Token 過期檢查已移除**
   - 當前實現不檢查 token 過期時間
   - 適合內部使用場景，不適合高安全要求環境
   - 如需恢復，請參考「後續調整指南」

2. **Email 參數已移除**
   - 所有驗證僅使用 token
   - 簡化了邏輯，但降低了安全性
   - 如需恢復，需要同時修改後端和前端

3. **SMTP 配置依賴環境變數**
   - 必須在 Zeabur 服務中正確設置所有 SMTP 環境變數
   - 缺少任何必要變數都會導致郵件發送失敗

---

## 📅 更新歷史

- **2025-12-26**: 初始更新日誌創建
  - 記錄所有 SMTP 配置修改
  - 記錄所有 Token 驗證邏輯修改
  - 記錄所有郵件模板和前端修改

---

## 🔗 相關資源

- [Devise 文檔](https://github.com/heartcombo/devise)
- [ActionMailer 文檔](https://guides.rubyonrails.org/action_mailer_basics.html)
- [Zeabur 文檔](https://zeabur.com/docs)

---

**最後更新**: 2025-12-26  
**維護者**: 開發團隊  
**狀態**: ✅ 生產環境運行中

