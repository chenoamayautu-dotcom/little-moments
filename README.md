# 康康 Little Moments

双人治愈风私人日记网站：Vue 3 + Vite + Supabase + GitHub Pages。

## 注意

本版本对应你已在 Supabase SQL Editor 中**逐步执行**的六张表、创建空间和邀请码函数、私有 `memories` Storage bucket。**不要再运行旧的 `supabase/schema.sql`**，那是早期版本，字段不兼容。

### 1. 补充心情表

在 SQL Editor 中运行 `supabase/next-step-moods.sql`，只运行一次。

### 2. 本地启动

安装 Node.js 22 后，在项目目录执行：

```bash
npm install
cp .env.example .env
npm run dev
```

Windows 上可直接复制 `.env.example` 并改名为 `.env`。

填写 `.env` 中的 `VITE_SUPABASE_URL` 与 `VITE_SUPABASE_ANON_KEY`（或 Supabase 新界面里的 publishable key）。两者是浏览器可使用的公开连接参数。**绝对不要把 service_role、secret key、数据库密码放进前端或 GitHub。**

### 3. GitHub Pages

创建 GitHub 仓库 `little-moments`，上传项目所有文件（包含 `.github/workflows/deploy.yml`），并在仓库 Settings → Secrets and variables → Actions → Variables 添加：

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Settings → Pages → Source 选择 **GitHub Actions**，push 到 main 后在 Actions 查看部署。

正式地址通常是 `https://<GitHub用户名>.github.io/little-moments/`。在 Supabase Authentication → URL Configuration 将该地址设为 Site URL 并加入 Redirect URLs。邮箱验证前务必完成该步骤。

### 4. 使用

两人分别注册并验证邮箱。创建者登录后在首页创建空间并生成邀请码；朋友登录后输入邀请码加入。日记、心情各自私密；留言和回忆属于共享空间。照片储存在私有 `memories` bucket。

### 5. 上线前检查

- 分别用两个真实邮箱测试注册、验证和登录；第三个账号无法读取共享空间数据。
- 分别测试私人日记、心情隔离；共同留言与回忆可互相查看。
- 测试邀请码过期、重复使用、第三人加入被拒绝。
- 测试照片上传、下载、删除，确认 Storage RLS 正常。
- GitHub Pages、Supabase 在中国大陆网络环境下的可访问性需要实测。
- Supabase 默认邮件服务可能限制收件人，必要时配置自有 SMTP。

当前为可部署的初始版本，尚未经过完整端到端安全测试。不要在测试完成前存放敏感私人内容。
