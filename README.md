# SSL ACME 自动化证书管理脚本

这是一个基于 acme.sh 的免费 SSL 证书自动生成和维护脚本，支持多种 DNS 服务商和 Web 服务器的自动化证书管理。

## 功能特性

- 🎯 **配置向导** - 交互式配置向导，快速完成初始设置
- 🚀 **一键安装** - 自动安装和配置 acme.sh
- 🔐 **多种验证方式** - 支持 DNS 验证和文件验证
- 🌐 **多DNS服务商** - 支持腾讯云、阿里云、DNSPod、AWS Route53、Cloudflare 等
- 🔄 **自动续期** - 自动检测和续期即将过期的证书
- 📦 **证书管理** - 完整的证书生命周期管理
- 🛡️ **安全配置** - 提供安全的 SSL 配置模板
- 📊 **状态监控** - 实时监控证书状态和到期时间
- 💾 **备份恢复** - 支持证书备份和恢复功能
- 🖥️ **Web服务器集成** - 自动配置 Nginx 和 Apache
- 📢 **通知系统** - 支持邮件和钉钉通知

## 系统要求

- Linux 或 macOS 系统
- Bash 4.0+
- curl 或 wget
- git
- openssl (可选，用于证书信息查看)

## 快速开始

### 方式一：使用配置向导（推荐）

```bash
# 1. 下载脚本和配置文件
git clone https://github.com/your-repo/ssl-acme-manager.git
cd ssl-acme-manager

# 2. 添加执行权限
chmod +x ssl_acme.sh setup_config.sh

# 3. 运行配置向导
./setup_config.sh
```

配置向导将引导您完成以下设置：
- 📧 邮箱地址配置
- 🌐 ACME 服务器选择（CertCloud、Let's Encrypt、ZeroSSL）
- 🔧 DNS 服务商配置（DNSPod、腾讯云、阿里云、AWS、Cloudflare）
- 📁 证书存储路径设置
- 🔄 自动续期配置
- 🖥️ Web 服务器配置（Nginx、Apache）
- 📢 通知配置（邮件、钉钉）

### 方式二：手动配置

```bash
# 1. 下载脚本和配置文件
git clone https://github.com/your-repo/ssl-acme-manager.git
cd ssl-acme-manager

# 2. 添加执行权限
chmod +x ssl_acme.sh

# 3. 复制配置文件模板
sudo cp ssl_acme.conf.example /etc/ssl_acme.conf

# 4. 编辑配置文件，设置默认邮箱和DNS服务商
sudo nano /etc/ssl_acme.conf
```

#### 在配置文件中设置：

```bash
# 基本配置
DEFAULT_SERVER="https://acme.trustasia.com/v2/DV90/directory"
DEFAULT_EMAIL="admin@example.com"
DEFAULT_DNS_PROVIDER="dns_dp"

# 路径配置
CERT_BASE_PATH="/etc/ssl/certs"
KEY_BASE_PATH="/etc/ssl/private"
BACKUP_DIR="/var/backups/ssl_certificates"
ACME_HOME="$HOME/.acme.sh"

# 自动续期配置
AUTO_RENEW_DAYS=30
RENEW_CRON="0 2 * * *"

# DNS 服务商配置
DNSPOD_ID="your_dnspod_id"
DNSPOD_KEY="your_dnspod_key"
```

### 后续步骤

#### 1. 安装 acme.sh

```bash
# 使用配置向导后，直接运行（会使用配置文件中的默认邮箱）
./ssl_acme.sh install

# 或者手动指定邮箱
./ssl_acme.sh install -e your-email@example.com
```

#### 2. 注册 ACME 账户

```bash
# 使用默认配置注册（推荐）
./ssl_acme.sh register

# 或者手动指定参数
./ssl_acme.sh register -e your-email@example.com
```

#### 3. 申请 SSL 证书

```bash
# 使用默认 DNS 服务商申请证书
./ssl_acme.sh issue -d example.com

# 指定 DNS 服务商
./ssl_acme.sh issue -d example.com -p dns_dp
./ssl_acme.sh issue -d example.com -p dns_tencent
./ssl_acme.sh issue -d example.com -p dns_ali

# 使用文件验证申请证书
./ssl_acme.sh issue -d example.com -w /var/www/html
```

#### 4. 安装证书到服务器
```bash
# 安装到 Nginx（使用配置文件中的路径）
./ssl_acme.sh install-cert -d example.com -t nginx

# 安装到 Apache
./ssl_acme.sh install-cert -d example.com -t apache

# 自定义路径安装（注意：现在使用 .crt 后缀）
./ssl_acme.sh install-cert -d example.com \
  --cert-path /etc/ssl/certs/example.com.crt \
  --key-path /etc/ssl/private/example.com.key \
  --reload-cmd "systemctl reload nginx"
```

#### 5. 设置自动续期
```bash
# 手动测试自动续期
./ssl_acme.sh auto-renew

# 添加到 crontab（配置向导会提示具体命令）
echo "0 2 * * * /path/to/ssl_acme.sh auto-renew" | sudo crontab -
```

## 详细使用说明

### 命令列表

| 命令 | 说明 | 示例 |
|------|------|------|
| `install` | 安装 acme.sh | `./ssl_acme.sh install -e user@example.com` |
| `register` | 注册 ACME 账户 | `./ssl_acme.sh register -e user@example.com` |
| `issue` | 申请 SSL 证书 | `./ssl_acme.sh issue -d example.com -p dns_dp` |
| `install-cert` | 安装证书到服务器 | `./ssl_acme.sh install-cert -d example.com -t nginx` |
| `renew` | 手动续期证书 | `./ssl_acme.sh renew -d example.com` |
| `list` | 列出所有证书 | `./ssl_acme.sh list` |
| `remove` | 删除证书 | `./ssl_acme.sh remove -d example.com` |
| `status` | 查看证书状态 | `./ssl_acme.sh status -d example.com` |
| `backup` | 备份证书 | `./ssl_acme.sh backup` |
| `restore` | 恢复证书 | `./ssl_acme.sh restore --backup-file /path/to/backup.tar.gz` |
| `check-expiry` | 检查证书到期时间 | `./ssl_acme.sh check-expiry --days 30` |
| `auto-renew` | 自动续期即将过期的证书 | `./ssl_acme.sh auto-renew --days 30` |
| `nginx-config` | 生成 Nginx 配置 | `./ssl_acme.sh nginx-config -d example.com` |
| `apache-config` | 生成 Apache 配置 | `./ssl_acme.sh apache-config -d example.com` |

### 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `-d, --domain` | 指定域名 | `-d example.com` |
| `-w, --webroot` | 网站根目录(文件验证) | `-w /var/www/html` |
| `-s, --server` | ACME 服务器地址 | `-s https://acme.trustasia.com/v2/DV90/directory` |
| `-e, --email` | 邮箱地址 | `-e user@example.com` |
| `-p, --provider` | DNS 服务商 | `-p dns_dp` |
| `-t, --type` | Web 服务器类型 | `-t nginx` |
| `--cert-path` | 证书文件路径 | `--cert-path /etc/ssl/certs/example.com.crt` |
| `--key-path` | 私钥文件路径 | `--key-path /etc/ssl/private/example.com.key` |
| `--reload-cmd` | 重载命令 | `--reload-cmd "nginx -s reload"` |
| `--days` | 天数阈值 | `--days 30` |
| `-f, --force` | 强制执行 | `-f` |
| `-v, --verbose` | 详细输出 | `-v` |

## 支持的 DNS 服务商

| 服务商 | 参数值 | 环境变量 |
|--------|--------|----------|
| DNSPod | `dns_dp` | `DP_Id`, `DP_Key` |
| 腾讯云 | `dns_tencent` | `Tencent_SecretId`, `Tencent_SecretKey` |
| 阿里云 | `dns_ali` | `Ali_Key`, `Ali_Secret` |
| AWS Route53 | `dns_aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |

### DNSPod 配置

1. 登录 [DNSPod 控制台](https://www.dnspod.cn/)
2. 进入 API 密钥管理
3. 创建 DNSPod Token
4. 获取 ID 和 Token

```bash
export DP_Id="your_dnspod_id"
export DP_Key="your_dnspod_key"
```

### 腾讯云配置

1. 登录 [腾讯云控制台](https://console.cloud.tencent.com/)
2. 进入访问管理 → API 密钥管理
3. 创建密钥或使用子账号密钥
4. 获取 SecretId 和 SecretKey

```bash
export Tencent_SecretId="your_secret_id"
export Tencent_SecretKey="your_secret_key"
```

### 阿里云配置

1. 登录 [阿里云 RAM 控制台](https://ram.console.aliyun.com/)
2. 创建用户并生成 AccessKey
3. 授予 `AliyunDNSFullAccess` 权限
4. 获取 AccessKey ID 和 Secret

```bash
export Ali_Key="your_access_key_id"
export Ali_Secret="your_access_key_secret"
```

### AWS Route53 配置

1. 登录 [AWS IAM 控制台](https://console.aws.amazon.com/iam/)
2. 创建用户并生成访问密钥
3. 授予 Route53 相关权限
4. 获取 Access Key ID 和 Secret

```bash
export AWS_ACCESS_KEY_ID="your_access_key_id"
export AWS_SECRET_ACCESS_KEY="your_secret_access_key"
```

## 使用示例

### 完整的证书申请和部署流程

#### 方法一：使用配置文件（推荐）

```bash
# 1. 创建配置文件
sudo cp ssl_acme.conf.example /etc/ssl_acme.conf

# 2. 编辑配置文件，设置默认值和API密钥
sudo nano /etc/ssl_acme.conf
# 设置：
# DEFAULT_EMAIL="admin@example.com"
# DEFAULT_DNS_PROVIDER="dns_dp"
# DNSPOD_ID="your_dnspod_id"
# DNSPOD_KEY="your_dnspod_key"

# 3. 安装 acme.sh（使用配置文件中的默认邮箱）
./ssl_acme.sh install

# 4. 注册账户
./ssl_acme.sh register

# 5. 申请证书（使用配置文件中的默认DNS服务商）
./ssl_acme.sh issue -d example.com -d www.example.com

# 6. 安装证书到 Nginx
./ssl_acme.sh install-cert -d example.com -t nginx

# 7. 生成 Nginx 配置
./ssl_acme.sh nginx-config -d example.com > /etc/nginx/sites-available/example.com

# 8. 启用站点
ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

#### 方法二：使用命令行参数

```bash
# 1. 设置环境变量
export DP_Id="your_dnspod_id"
export DP_Key="your_dnspod_key"

# 2. 安装 acme.sh
./ssl_acme.sh install -e admin@example.com

# 3. 注册账户
./ssl_acme.sh register -e admin@example.com

# 4. 申请证书
./ssl_acme.sh issue -d example.com -d www.example.com -p dns_dp

# 5. 安装证书到 Nginx
./ssl_acme.sh install-cert -d example.com -t nginx

# 6. 生成 Nginx 配置
./ssl_acme.sh nginx-config -d example.com > /etc/nginx/sites-available/example.com

# 7. 启用站点
ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### 批量管理多个域名

```bash
# 申请多个域名的证书
domains=("example1.com" "example2.com" "example3.com")

for domain in "${domains[@]}"; do
    echo "处理域名: $domain"
    ./ssl_acme.sh issue -d "$domain" -p dns_dp
    ./ssl_acme.sh install-cert -d "$domain" -t nginx
done
```

### 设置自动续期

```bash
# 添加到 crontab，每天检查并自动续期即将过期的证书
echo "0 2 * * * /path/to/ssl_acme.sh auto-renew --days 30" | crontab -
```

## 故障排除

### 常见问题

1. **DNS 验证失败**
   - 检查 DNS 服务商的 API 密钥是否正确
   - 确认域名解析服务商与配置的服务商一致
   - 检查网络连接和防火墙设置

2. **文件验证失败**
   - 确认网站根目录路径正确
   - 检查 Web 服务器是否正常运行
   - 确认域名能够正常访问

3. **证书安装失败**
   - 检查证书和私钥文件路径权限
   - 确认 Web 服务器配置语法正确
   - 查看 Web 服务器错误日志

### 日志查看

```bash
# 查看脚本日志
tail -f /var/log/ssl_acme.log

# 查看 acme.sh 日志
tail -f ~/.acme.sh/acme.sh.log
```

## 安全建议

1. **保护 API 密钥**
   - 使用子账号密钥，限制权限范围
   - 定期轮换 API 密钥
   - 不要在脚本中硬编码密钥

2. **证书文件权限**
   - 私钥文件权限设置为 600
   - 证书文件权限设置为 644
   - 使用专用用户运行 Web 服务器

3. **定期备份**
   - 定期备份证书文件
   - 测试备份恢复流程
   - 保留多个备份版本

## 许可证

本脚本基于 MIT 许可证发布，详见 LICENSE 文件。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个脚本。

## 支持

如果您在使用过程中遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查脚本日志文件
3. 提交 Issue 并提供详细的错误信息
