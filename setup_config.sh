#!/bin/bash

# SSL ACME 配置向导
# 帮助用户快速创建和配置 ssl_acme.conf 文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置文件路径
CONFIG_FILE="/etc/ssl_acme.conf"
USER_CONFIG_FILE="$HOME/.ssl_acme.conf"

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    echo -e "${BLUE}=== SSL ACME 配置向导 ===${NC}"
    echo
    echo "🎉 欢迎使用 SSL ACME 配置向导！"
    echo
    echo "此向导将帮助您："
    echo "  📧 配置邮箱和 ACME 服务器"
    echo "  🔧 设置 DNS 服务商 API 密钥"
    echo "  📁 配置证书存储路径"
    echo "  🖥️  设置 Web 服务器集成"
    echo "  📢 配置通知系统"
    echo "  🔄 设置自动续期"
    echo
    echo "配置完成后，您可以使用简化的命令管理 SSL 证书"
    echo
}

# 选择配置文件位置
choose_config_location() {
    echo "请选择配置文件位置:"
    echo "1) 系统级配置 (/etc/ssl_acme.conf) - 推荐"
    echo "2) 用户级配置 (~/.ssl_acme.conf)"
    echo
    
    while true; do
        read -p "请选择 (1-2): " choice
        case $choice in
            1)
                CONFIG_FILE="/etc/ssl_acme.conf"
                if [ "$EUID" -ne 0 ]; then
                    warn "系统级配置需要 root 权限，将使用 sudo"
                    NEED_SUDO=true
                else
                    NEED_SUDO=false
                fi
                break
                ;;
            2)
                CONFIG_FILE="$USER_CONFIG_FILE"
                NEED_SUDO=false
                break
                ;;
            *)
                error "无效选择，请输入 1 或 2"
                ;;
        esac
    done
    
    info "配置文件将创建在: $CONFIG_FILE"
}

# 收集基本配置
collect_basic_config() {
    echo
    echo -e "${BLUE}=== 基本配置 ===${NC}"
    
    # 邮箱地址
    while true; do
        read -p "请输入邮箱地址 (用于接收证书通知): " email
        if echo "$email" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
            DEFAULT_EMAIL="$email"
            break
        else
            error "邮箱格式不正确，请重新输入"
        fi
    done
    
    # ACME 服务器
    echo
    echo "请选择 ACME 服务器:"
    echo "1) CertCloud (推荐，国内访问快)"
    echo "2) Let's Encrypt (免费，全球通用)"
    echo "3) ZeroSSL (免费，商业支持)"
    echo "4) 自定义"
    
    while true; do
        read -p "请选择 (1-4): " choice
        case $choice in
            1)
                DEFAULT_SERVER="https://acme.trustasia.com/v2/DV90/directory"
                break
                ;;
            2)
                DEFAULT_SERVER="https://acme-v02.api.letsencrypt.org/directory"
                break
                ;;
            3)
                DEFAULT_SERVER="https://acme.zerossl.com/v2/DV90"
                break
                ;;
            4)
                read -p "请输入自定义 ACME 服务器地址: " custom_server
                DEFAULT_SERVER="$custom_server"
                break
                ;;
            *)
                error "无效选择，请输入 1-4"
                ;;
        esac
    done
}

# 收集 DNS 服务商配置
collect_dns_config() {
    echo
    echo -e "${BLUE}=== DNS 服务商配置 ===${NC}"
    
    echo "请选择主要使用的 DNS 服务商:"
    echo "1) DNSPod"
    echo "2) 腾讯云 DNS"
    echo "3) 阿里云 DNS"
    echo "4) AWS Route53"
    echo "5) Cloudflare"
    echo "6) 跳过 DNS 配置"
    
    while true; do
        read -p "请选择 (1-6): " choice
        case $choice in
            1)
                DEFAULT_DNS_PROVIDER="dns_dp"
                collect_dnspod_config
                break
                ;;
            2)
                DEFAULT_DNS_PROVIDER="dns_tencent"
                collect_tencent_config
                break
                ;;
            3)
                DEFAULT_DNS_PROVIDER="dns_ali"
                collect_aliyun_config
                break
                ;;
            4)
                DEFAULT_DNS_PROVIDER="dns_aws"
                collect_aws_config
                break
                ;;
            5)
                DEFAULT_DNS_PROVIDER="dns_cf"
                collect_cloudflare_config
                break
                ;;
            6)
                DEFAULT_DNS_PROVIDER=""
                info "跳过 DNS 配置，您可以稍后手动配置"
                break
                ;;
            *)
                error "无效选择，请输入 1-6"
                ;;
        esac
    done
}

# DNSPod 配置
collect_dnspod_config() {
    echo
    echo "DNSPod 配置:"
    echo "请登录 DNSPod 控制台 (https://www.dnspod.cn/) 获取 API 密钥"
    echo
    read -p "请输入 DNSPod ID: " dnspod_id
    read -p "请输入 DNSPod Key: " dnspod_key
    
    DNSPOD_ID="$dnspod_id"
    DNSPOD_KEY="$dnspod_key"
}

# 腾讯云配置
collect_tencent_config() {
    echo
    echo "腾讯云配置:"
    echo "请登录腾讯云控制台获取 API 密钥"
    echo
    read -p "请输入 SecretId: " secret_id
    read -p "请输入 SecretKey: " secret_key
    
    TENCENT_SECRET_ID="$secret_id"
    TENCENT_SECRET_KEY="$secret_key"
}

# 阿里云配置
collect_aliyun_config() {
    echo
    echo "阿里云配置:"
    echo "请登录阿里云 RAM 控制台获取 AccessKey"
    echo
    read -p "请输入 AccessKey ID: " access_key_id
    read -p "请输入 AccessKey Secret: " access_key_secret
    
    ALIYUN_ACCESS_KEY_ID="$access_key_id"
    ALIYUN_ACCESS_KEY_SECRET="$access_key_secret"
}

# AWS 配置
collect_aws_config() {
    echo
    echo "AWS 配置:"
    echo "请登录 AWS IAM 控制台获取访问密钥"
    echo
    read -p "请输入 Access Key ID: " access_key_id
    read -p "请输入 Secret Access Key: " secret_access_key
    read -p "请输入 AWS Region (默认: us-east-1): " aws_region
    
    AWS_ACCESS_KEY_ID="$access_key_id"
    AWS_SECRET_ACCESS_KEY="$secret_access_key"
    AWS_REGION="${aws_region:-us-east-1}"
}

# Cloudflare 配置
collect_cloudflare_config() {
    echo
    echo "Cloudflare 配置:"
    echo "请登录 Cloudflare 控制台获取 API 密钥"
    echo
    read -p "请输入 Cloudflare 邮箱: " cf_email
    read -p "请输入 API Key: " cf_api_key
    
    CLOUDFLARE_EMAIL="$cf_email"
    CLOUDFLARE_API_KEY="$cf_api_key"
}

# 收集路径配置
collect_path_config() {
    echo
    echo -e "${BLUE}=== 路径配置 ===${NC}"
    
    read -p "证书存储路径 (默认: /etc/ssl/certs): " cert_path
    read -p "私钥存储路径 (默认: /etc/ssl/private): " key_path
    read -p "备份目录 (默认: /var/backups/ssl_certificates): " backup_path
    
    CERT_BASE_PATH="${cert_path:-/etc/ssl/certs}"
    KEY_BASE_PATH="${key_path:-/etc/ssl/private}"
    BACKUP_DIR="${backup_path:-/var/backups/ssl_certificates}"
}

# 收集自动续期配置
collect_renewal_config() {
    echo
    echo -e "${BLUE}=== 自动续期配置 ===${NC}"

    read -p "自动续期天数阈值 (默认: 30): " renew_days
    read -p "续期检查时间 cron 格式 (默认: 0 2 * * *): " renew_cron
    read -p "续期失败重试次数 (默认: 3): " retry_count
    read -p "续期失败重试间隔秒数 (默认: 300): " retry_interval

    AUTO_RENEW_DAYS="${renew_days:-30}"
    RENEW_CRON="${renew_cron:-0 2 * * *}"
    RENEW_RETRY_COUNT="${retry_count:-3}"
    RENEW_RETRY_INTERVAL="${retry_interval:-300}"
}

# 收集 Web 服务器配置
collect_webserver_config() {
    echo
    echo -e "${BLUE}=== Web 服务器配置 ===${NC}"

    echo "请选择主要使用的 Web 服务器:"
    echo "1) Nginx (推荐)"
    echo "2) Apache"
    echo "3) 两者都配置"
    echo "4) 跳过 Web 服务器配置"

    while true; do
        read -p "请选择 (1-4): " choice
        case $choice in
            1)
                collect_nginx_config
                break
                ;;
            2)
                collect_apache_config
                break
                ;;
            3)
                collect_nginx_config
                collect_apache_config
                break
                ;;
            4)
                info "跳过 Web 服务器配置"
                break
                ;;
            *)
                error "无效选择，请输入 1-4"
                ;;
        esac
    done
}

# 收集 Nginx 配置
collect_nginx_config() {
    echo
    echo "Nginx 配置:"
    read -p "Nginx 配置目录 (默认: /etc/nginx): " nginx_conf_dir
    read -p "Nginx sites-available 目录 (默认: /etc/nginx/sites-available): " nginx_sites_available
    read -p "Nginx sites-enabled 目录 (默认: /etc/nginx/sites-enabled): " nginx_sites_enabled
    read -p "Nginx SSL 证书目录 (默认: /etc/nginx/ssl): " nginx_ssl_dir
    read -p "Nginx 重载命令 (默认: nginx -s reload): " nginx_reload_cmd

    NGINX_CONF_DIR="${nginx_conf_dir:-/etc/nginx}"
    NGINX_SITES_AVAILABLE="${nginx_sites_available:-/etc/nginx/sites-available}"
    NGINX_SITES_ENABLED="${nginx_sites_enabled:-/etc/nginx/sites-enabled}"
    NGINX_SSL_DIR="${nginx_ssl_dir:-/etc/nginx/ssl}"
    NGINX_RELOAD_CMD="${nginx_reload_cmd:-nginx -s reload}"
}

# 收集 Apache 配置
collect_apache_config() {
    echo
    echo "Apache 配置:"
    read -p "Apache 配置目录 (默认: /etc/apache2): " apache_conf_dir
    read -p "Apache sites-available 目录 (默认: /etc/apache2/sites-available): " apache_sites_available
    read -p "Apache sites-enabled 目录 (默认: /etc/apache2/sites-enabled): " apache_sites_enabled
    read -p "Apache SSL 证书目录 (默认: /etc/apache2/ssl): " apache_ssl_dir
    read -p "Apache 重载命令 (默认: systemctl reload apache2): " apache_reload_cmd

    APACHE_CONF_DIR="${apache_conf_dir:-/etc/apache2}"
    APACHE_SITES_AVAILABLE="${apache_sites_available:-/etc/apache2/sites-available}"
    APACHE_SITES_ENABLED="${apache_sites_enabled:-/etc/apache2/sites-enabled}"
    APACHE_SSL_DIR="${apache_ssl_dir:-/etc/apache2/ssl}"
    APACHE_RELOAD_CMD="${apache_reload_cmd:-systemctl reload apache2}"
}

# 收集通知配置
collect_notification_config() {
    echo
    echo -e "${BLUE}=== 通知配置 ===${NC}"

    read -p "是否启用邮件通知? (y/N): " enable_email
    if [ "$enable_email" = "y" ] || [ "$enable_email" = "Y" ]; then
        ENABLE_EMAIL_NOTIFICATION="true"
        read -p "通知邮箱地址 (默认使用注册邮箱): " notification_email
        NOTIFICATION_EMAIL="${notification_email:-$DEFAULT_EMAIL}"
    else
        ENABLE_EMAIL_NOTIFICATION="false"
        NOTIFICATION_EMAIL=""
    fi

    read -p "是否启用钉钉通知? (y/N): " enable_dingtalk
    if [ "$enable_dingtalk" = "y" ] || [ "$enable_dingtalk" = "Y" ]; then
        ENABLE_DINGTALK_NOTIFICATION="true"
        read -p "钉钉机器人 Webhook URL: " dingtalk_webhook
        DINGTALK_WEBHOOK="$dingtalk_webhook"
    else
        ENABLE_DINGTALK_NOTIFICATION="false"
        DINGTALK_WEBHOOK=""
    fi
}

# 生成配置文件
generate_config() {
    echo
    info "生成配置文件..."

    local temp_config="/tmp/ssl_acme.conf.tmp"

    cat > "$temp_config" << EOF
# SSL ACME 配置文件
# 生成时间: $(date)

# =============================================================================
# 基本配置
# =============================================================================

# 默认邮箱地址
DEFAULT_EMAIL="$DEFAULT_EMAIL"

# 默认ACME服务器
DEFAULT_SERVER="$DEFAULT_SERVER"

# 默认DNS服务商
DEFAULT_DNS_PROVIDER="$DEFAULT_DNS_PROVIDER"

# =============================================================================
# 路径配置
# =============================================================================

# 证书存储基础路径
CERT_BASE_PATH="$CERT_BASE_PATH"

# 私钥存储基础路径
KEY_BASE_PATH="$KEY_BASE_PATH"

# 备份目录
BACKUP_DIR="$BACKUP_DIR"

# acme.sh 安装目录
ACME_HOME="\$HOME/.acme.sh"

# =============================================================================
# 日志配置
# =============================================================================

# 日志文件路径
LOG_FILE="/var/log/ssl_acme.log"

# 日志级别
LOG_LEVEL="INFO"

# 日志文件最大大小 (MB)
LOG_MAX_SIZE=100

# 保留的日志文件数量
LOG_BACKUP_COUNT=5

# =============================================================================
# 自动续期配置
# =============================================================================

# 自动续期天数阈值
AUTO_RENEW_DAYS=$AUTO_RENEW_DAYS

# 续期检查时间 (cron 格式)
RENEW_CRON="$RENEW_CRON"

# 续期失败重试次数
RENEW_RETRY_COUNT=$RENEW_RETRY_COUNT

# 续期失败重试间隔 (秒)
RENEW_RETRY_INTERVAL=$RENEW_RETRY_INTERVAL

# =============================================================================
# 通知配置
# =============================================================================

# 启用邮件通知
ENABLE_EMAIL_NOTIFICATION=$ENABLE_EMAIL_NOTIFICATION

# 邮件通知地址
NOTIFICATION_EMAIL="$NOTIFICATION_EMAIL"

# 启用钉钉通知
ENABLE_DINGTALK_NOTIFICATION=$ENABLE_DINGTALK_NOTIFICATION

# 钉钉机器人 Webhook URL
DINGTALK_WEBHOOK="$DINGTALK_WEBHOOK"

# 启用企业微信通知
ENABLE_WECHAT_NOTIFICATION=false

# 企业微信机器人 Webhook URL
WECHAT_WEBHOOK=""

# =============================================================================
# DNS 服务商配置
# =============================================================================

EOF

    # 添加 DNS 服务商配置
    if [ -n "$DNSPOD_ID" ]; then
        cat >> "$temp_config" << EOF
# DNSPod 配置
DNSPOD_ID="$DNSPOD_ID"
DNSPOD_KEY="$DNSPOD_KEY"

EOF
    fi

    if [ -n "$TENCENT_SECRET_ID" ]; then
        cat >> "$temp_config" << EOF
# 腾讯云配置
TENCENT_SECRET_ID="$TENCENT_SECRET_ID"
TENCENT_SECRET_KEY="$TENCENT_SECRET_KEY"

EOF
    fi

    if [ -n "$ALIYUN_ACCESS_KEY_ID" ]; then
        cat >> "$temp_config" << EOF
# 阿里云配置
ALIYUN_ACCESS_KEY_ID="$ALIYUN_ACCESS_KEY_ID"
ALIYUN_ACCESS_KEY_SECRET="$ALIYUN_ACCESS_KEY_SECRET"

EOF
    fi

    if [ -n "$AWS_ACCESS_KEY_ID" ]; then
        cat >> "$temp_config" << EOF
# AWS 配置
AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
AWS_REGION="$AWS_REGION"

EOF
    fi

    if [ -n "$CLOUDFLARE_EMAIL" ]; then
        cat >> "$temp_config" << EOF
# Cloudflare 配置
CLOUDFLARE_EMAIL="$CLOUDFLARE_EMAIL"
CLOUDFLARE_API_KEY="$CLOUDFLARE_API_KEY"

EOF
    fi

    # 添加 Web 服务器配置
    if [ -n "$NGINX_CONF_DIR" ]; then
        cat >> "$temp_config" << EOF

# =============================================================================
# Web 服务器配置
# =============================================================================

# Nginx 配置
NGINX_CONF_DIR="$NGINX_CONF_DIR"
NGINX_SITES_AVAILABLE="$NGINX_SITES_AVAILABLE"
NGINX_SITES_ENABLED="$NGINX_SITES_ENABLED"
NGINX_SSL_DIR="$NGINX_SSL_DIR"
NGINX_RELOAD_CMD="$NGINX_RELOAD_CMD"

EOF
    fi

    if [ -n "$APACHE_CONF_DIR" ]; then
        cat >> "$temp_config" << EOF
# Apache 配置
APACHE_CONF_DIR="$APACHE_CONF_DIR"
APACHE_SITES_AVAILABLE="$APACHE_SITES_AVAILABLE"
APACHE_SITES_ENABLED="$APACHE_SITES_ENABLED"
APACHE_SSL_DIR="$APACHE_SSL_DIR"
APACHE_RELOAD_CMD="$APACHE_RELOAD_CMD"

EOF
    fi

    # 添加安全和高级配置
    cat >> "$temp_config" << EOF
# =============================================================================
# 安全配置
# =============================================================================

# 证书文件权限
CERT_FILE_PERMISSION=644

# 私钥文件权限
KEY_FILE_PERMISSION=600

# 证书目录权限
CERT_DIR_PERMISSION=755

# 私钥目录权限
KEY_DIR_PERMISSION=700

# 证书文件所有者
CERT_OWNER="root:root"

# 私钥文件所有者
KEY_OWNER="root:root"

# =============================================================================
# 高级配置
# =============================================================================

# 证书密钥长度
KEY_LENGTH=2048

# 证书有效期检查间隔 (天)
VALIDITY_CHECK_INTERVAL=1

# 并发处理域名数量
CONCURRENT_DOMAINS=5

# DNS 传播等待时间 (秒)
DNS_SLEEP=20

# HTTP 验证端口
HTTP_PORT=80

# HTTPS 验证端口
HTTPS_PORT=443

# 启用 OCSP Stapling
ENABLE_OCSP_STAPLING=true

# 启用 HSTS
ENABLE_HSTS=true

# HSTS 最大年龄 (秒)
HSTS_MAX_AGE=31536000

# =============================================================================
# 备份配置
# =============================================================================

# 自动备份间隔 (天)
BACKUP_INTERVAL=7

# 保留备份文件数量
BACKUP_RETENTION=30

# 备份压缩级别 (1-9)
BACKUP_COMPRESSION_LEVEL=6

# 备份文件命名格式
BACKUP_NAME_FORMAT="ssl_backup_%Y%m%d_%H%M%S.tar.gz"

# =============================================================================
# 监控配置
# =============================================================================

# 启用证书监控
ENABLE_MONITORING=true

# 监控检查间隔 (小时)
MONITORING_INTERVAL=24

# 证书到期预警天数
EXPIRY_WARNING_DAYS=30

# 证书到期紧急预警天数
EXPIRY_CRITICAL_DAYS=7

EOF

    # 复制到目标位置
    if [ "$NEED_SUDO" = "true" ]; then
        sudo cp "$temp_config" "$CONFIG_FILE"
        sudo chmod 600 "$CONFIG_FILE"
    else
        cp "$temp_config" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
    
    rm -f "$temp_config"
    
    log "配置文件已创建: $CONFIG_FILE"
}

# 显示完成信息
show_completion() {
    echo
    log "配置完成！"
    echo
    echo "配置文件位置: $CONFIG_FILE"
    echo
    echo -e "${GREEN}现在您可以使用简化的命令:${NC}"
    echo "  ./ssl_acme.sh install                    # 安装 acme.sh"
    echo "  ./ssl_acme.sh register                   # 注册 ACME 账户"
    echo "  ./ssl_acme.sh issue -d example.com       # 申请证书"
    echo "  ./ssl_acme.sh install-cert -d example.com -t nginx  # 安装证书"
    echo "  ./ssl_acme.sh auto-renew                 # 自动续期即将过期的证书"
    echo
    echo -e "${GREEN}配置文件管理:${NC}"
    if [ "$NEED_SUDO" = "true" ]; then
        echo "  sudo cat $CONFIG_FILE                   # 查看配置"
        echo "  sudo nano $CONFIG_FILE                  # 编辑配置"
    else
        echo "  cat $CONFIG_FILE                        # 查看配置"
        echo "  nano $CONFIG_FILE                       # 编辑配置"
    fi
    echo
    echo -e "${GREEN}下一步建议:${NC}"
    echo "1. 安装 acme.sh: ./ssl_acme.sh install"
    echo "2. 注册 ACME 账户: ./ssl_acme.sh register"
    echo "3. 申请您的第一个证书: ./ssl_acme.sh issue -d yourdomain.com"
    echo "4. 设置自动续期 cron 任务:"
    echo "   echo '$RENEW_CRON /path/to/ssl_acme.sh auto-renew' | sudo crontab -"
    echo
    if [ "$ENABLE_EMAIL_NOTIFICATION" = "true" ] || [ "$ENABLE_DINGTALK_NOTIFICATION" = "true" ]; then
        echo -e "${YELLOW}通知配置已启用，证书状态变化时会收到通知${NC}"
        echo
    fi
    if [ -n "$NGINX_CONF_DIR" ]; then
        echo -e "${BLUE}Nginx 配置已设置，证书将安装到: $NGINX_SSL_DIR${NC}"
        echo
    fi
    if [ -n "$APACHE_CONF_DIR" ]; then
        echo -e "${BLUE}Apache 配置已设置，证书将安装到: $APACHE_SSL_DIR${NC}"
        echo
    fi
}

# 主函数
main() {
    show_welcome

    # 检查示例配置文件是否存在
    if [ ! -f "ssl_acme.conf.example" ]; then
        error "找不到 ssl_acme.conf.example 文件"
        echo "请确保在包含配置文件示例的目录中运行此脚本"
        exit 1
    fi

    choose_config_location
    collect_basic_config
    collect_dns_config
    collect_path_config
    collect_webserver_config
    collect_notification_config
    collect_renewal_config
    generate_config
    show_completion
}

# 脚本入口
main "$@"
