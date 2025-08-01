#!/bin/bash

# SSL证书自动生成和维护脚本
# 基于acme.sh实现免费SSL证书的申请、安装和自动续期
# 支持多种DNS服务商和Web服务器

set -e

# 脚本配置
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="SSL ACME Auto Manager"
LOG_FILE="/var/log/ssl_acme.log"
CONFIG_FILE="/etc/ssl_acme.conf"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# 显示帮助信息
show_help() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

用法: $0 [选项] [命令]

命令:
    install         安装acme.sh
    register        注册ACME账户
    issue           申请SSL证书
    install-cert    安装证书到服务器
    renew           手动续期证书
    list            列出所有证书
    remove          删除证书
    config          配置脚本参数
    status          查看证书状态
    diagnose        诊断acme.sh安装状态
    help            显示此帮助信息

选项:
    -d, --domain DOMAIN     指定域名（可多次使用）
    -w, --webroot PATH      指定网站根目录(文件验证)
    -s, --server URL        指定ACME服务器
    -e, --email EMAIL       指定邮箱地址
    -p, --provider PROVIDER 指定DNS服务商
    -t, --type TYPE         指定Web服务器类型(nginx/apache)
    -f, --force             强制执行
    -v, --verbose           详细输出
    -h, --help              显示帮助信息

示例:
    $0 install                                    # 安装acme.sh
    $0 register -e user@example.com               # 注册账户
    $0 issue -d example.com -p dns_dp             # 使用DNSPod申请证书
    $0 issue -d example.com -d "*.example.com" -p dns_dp  # 申请通配符证书
    $0 issue -d example.com -d www.example.com -d api.example.com -p dns_dp  # 多域名证书
    $0 install-cert -d example.com -t nginx       # 安装证书到Nginx
    $0 renew -d example.com                       # 续期证书

支持的DNS服务商:
    dns_dp      - DNSPod
    dns_tencent - 腾讯云
    dns_ali     - 阿里云
    dns_aws     - Amazon Route53
    dns_cf      - Cloudflare

EOF
}

# 检查系统环境
check_system() {
    info "检查系统环境..."
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        OS="freebsd"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        warn "检测到 Windows 环境，某些功能可能不可用"
    else
        warn "未知操作系统: $OSTYPE，尝试继续执行"
        OS="unknown"
    fi

    log "检测到操作系统: $OS"
    
    # 检查必要命令
    local required_commands=("curl")

    # 根据操作系统调整必要命令
    if [[ "$OS" != "windows" ]]; then
        required_commands+=("wget" "git")
    fi

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            if [[ "$OS" == "windows" ]]; then
                warn "缺少命令: $cmd (Windows环境下可能不影响基本功能)"
            else
                error "缺少必要命令: $cmd"
                exit 1
            fi
        fi
    done
    
    log "系统环境检查完成"
}

# 获取 acme.sh 可执行文件路径
get_acme_path() {
    # 尝试多种方式找到 acme.sh
    local acme_paths=(
        "$HOME/.acme.sh/acme.sh"
        "/root/.acme.sh/acme.sh"
        "/usr/local/bin/acme.sh"
        "/usr/bin/acme.sh"
        "$(which acme.sh 2>/dev/null)"
        "$(command -v acme.sh 2>/dev/null)"
        "$(find /root -name "acme.sh" -type f -executable 2>/dev/null | head -1)"
        "$(find /home -name "acme.sh" -type f -executable 2>/dev/null | head -1)"
        "$(find /usr/local -name "acme.sh" -type f -executable 2>/dev/null | head -1)"
    )

    for path in "${acme_paths[@]}"; do
        if [[ -n "$path" && -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    # 如果都找不到，返回默认路径
    echo "$HOME/.acme.sh/acme.sh"
    return 1
}

# 诊断 acme.sh 安装状态
diagnose_acme_installation() {
    echo "=== acme.sh 安装诊断 ==="
    echo "当前用户: $(whoami)"
    echo "HOME 目录: $HOME"
    echo "当前工作目录: $(pwd)"
    echo

    echo "检查可能的 acme.sh 路径:"
    local paths=(
        "$HOME/.acme.sh/acme.sh"
        "/root/.acme.sh/acme.sh"
        "$(which acme.sh 2>/dev/null || echo '未找到')"
        "$(command -v acme.sh 2>/dev/null || echo '未找到')"
    )

    for path in "${paths[@]}"; do
        if [[ -n "$path" && "$path" != "未找到" ]]; then
            if [[ -f "$path" ]]; then
                if [[ -x "$path" ]]; then
                    echo "✅ $path (存在且可执行)"
                else
                    echo "⚠️  $path (存在但不可执行)"
                    ls -la "$path"
                fi
            else
                echo "❌ $path (不存在)"
            fi
        else
            echo "❌ PATH 中未找到 acme.sh"
        fi
    done

    echo
    echo "检查 .acme.sh 目录:"
    if [[ -d "$HOME/.acme.sh" ]]; then
        echo "✅ $HOME/.acme.sh 目录存在"
        echo "目录内容:"
        ls -la "$HOME/.acme.sh/" | head -10

        if [[ -f "$HOME/.acme.sh/acme.sh" ]]; then
            echo "文件权限:"
            ls -la "$HOME/.acme.sh/acme.sh"
            echo "文件类型:"
            file "$HOME/.acme.sh/acme.sh"
        fi
    else
        echo "❌ $HOME/.acme.sh 目录不存在"
    fi

    echo
    echo "检查环境变量:"
    echo "PATH: $PATH"
    if [[ -f "$HOME/.bashrc" ]]; then
        echo "检查 .bashrc 中的 acme.sh 相关配置:"
        grep -n "acme" "$HOME/.bashrc" || echo "未找到 acme.sh 相关配置"
    fi

    echo "=== 诊断完成 ==="
}

# 检查 acme.sh 是否可用
check_acme_available() {
    local acme_path=$(get_acme_path)

    if [[ ! -x "$acme_path" ]]; then
        error "acme.sh 未找到或不可执行: $acme_path"
        error "请先运行 './ssl_acme.sh install' 安装 acme.sh"
        echo
        warn "运行诊断以获取更多信息:"
        diagnose_acme_installation
        return 1
    fi

    return 0
}

# 安装acme.sh
install_acme() {
    local email="$1"

    # 如果没有提供邮箱参数，尝试使用配置文件中的默认邮箱
    if [[ -z "$email" && -n "$DEFAULT_EMAIL" ]]; then
        email="$DEFAULT_EMAIL"
        info "使用配置文件中的默认邮箱: $email"
    fi

    # 如果仍然没有邮箱，提示用户输入
    if [[ -z "$email" ]]; then
        read -p "请输入邮箱地址: " email
    fi

    if [[ -z "$email" ]]; then
        error "邮箱地址不能为空"
        exit 1
    fi
    
    info "开始安装acme.sh..."
    
    # 检查是否已安装
    local acme_path=$(get_acme_path)
    if [[ -x "$acme_path" ]]; then
        warn "acme.sh已经安装，跳过安装步骤"
        return 0
    fi
    
    # 在线安装
    if curl -s https://get.acme.sh | sh -s email="$email"; then
        log "acme.sh安装成功"

        # 等待安装完成
        sleep 2

        # 检查安装结果
        local acme_path="$HOME/.acme.sh/acme.sh"
        if [[ ! -f "$acme_path" ]]; then
            warn "标准路径未找到 acme.sh，尝试其他可能的位置..."

            # 检查其他可能的安装位置
            local alt_paths=(
                "/root/.acme.sh/acme.sh"
                "/usr/local/bin/acme.sh"
                "$(find /root -name "acme.sh" -type f 2>/dev/null | head -1)"
                "$(find /home -name "acme.sh" -type f 2>/dev/null | head -1)"
            )

            for alt_path in "${alt_paths[@]}"; do
                if [[ -n "$alt_path" && -f "$alt_path" ]]; then
                    log "找到 acme.sh: $alt_path"
                    acme_path="$alt_path"
                    break
                fi
            done
        fi

        # 确保文件可执行
        if [[ -f "$acme_path" ]]; then
            chmod +x "$acme_path"
            log "设置执行权限: $acme_path"
        fi

        # 重新加载环境
        source "$HOME/.bashrc" 2>/dev/null || true
        source "$HOME/.profile" 2>/dev/null || true

        # 创建别名
        if ! grep -q "alias acme.sh" "$HOME/.bashrc"; then
            echo "alias acme.sh='$acme_path'" >> "$HOME/.bashrc"
            log "添加别名到 .bashrc"
        fi

        # 对于 Alibaba Cloud Linux，可能需要额外的环境设置
        if grep -q "Alibaba Cloud Linux" /etc/os-release 2>/dev/null; then
            warn "检测到 Alibaba Cloud Linux，应用特殊配置..."

            # 确保 PATH 包含 acme.sh 目录
            if ! echo "$PATH" | grep -q "$HOME/.acme.sh"; then
                echo "export PATH=\"\$HOME/.acme.sh:\$PATH\"" >> "$HOME/.bashrc"
                log "添加 acme.sh 目录到 PATH"
            fi

            # 创建系统级符号链接
            if [[ -f "$acme_path" && ! -L "/usr/local/bin/acme.sh" ]]; then
                ln -sf "$acme_path" "/usr/local/bin/acme.sh" 2>/dev/null || true
                log "创建系统级符号链接"
            fi
        fi

        log "请重新打开终端或执行 'source ~/.bashrc' 使配置生效"

        # 验证安装
        echo
        info "验证安装结果..."
        diagnose_acme_installation

    else
        error "acme.sh安装失败"
        exit 1
    fi
}

# 注册ACME账户
register_account() {
    local email="$1"
    local server="$2"
    local eab_kid="$3"
    local eab_hmac="$4"

    # 如果没有提供邮箱参数，尝试使用配置文件中的默认邮箱
    if [[ -z "$email" && -n "$DEFAULT_EMAIL" ]]; then
        email="$DEFAULT_EMAIL"
        info "使用配置文件中的默认邮箱: $email"
    fi

    # 如果没有提供服务器参数，尝试使用配置文件中的默认服务器
    if [[ -z "$server" && -n "$DEFAULT_SERVER" ]]; then
        server="$DEFAULT_SERVER"
    elif [[ -z "$server" ]]; then
        server="https://acme.trustasia.com/v2/DV90/directory"
    fi

    info "注册ACME账户..."
    info "使用服务器: $server"

    # 检查 acme.sh 是否可用
    if ! check_acme_available; then
        exit 1
    fi

    # 获取 acme.sh 路径并构建注册命令
    local acme_path=$(get_acme_path)
    local cmd="$acme_path --register-account --server $server"
    
    if [[ -n "$eab_kid" && -n "$eab_hmac" ]]; then
        cmd="$cmd --eab-kid $eab_kid --eab-hmac-key $eab_hmac"
    fi
    
    if eval "$cmd"; then
        log "ACME账户注册成功"
    else
        error "ACME账户注册失败"
        exit 1
    fi
}

# 配置DNS服务商环境变量
setup_dns_provider() {
    local provider="$1"
    
    case "$provider" in
        "dns_dp")
            info "配置DNSPod环境变量..."

            # 尝试使用配置文件中的值
            local dp_id="$DNSPOD_ID"
            local dp_key="$DNSPOD_KEY"

            # 如果配置文件中没有，则提示用户输入
            if [[ -z "$dp_id" ]]; then
                read -p "请输入DNSPod ID: " dp_id
            else
                info "使用配置文件中的DNSPod ID"
            fi

            if [[ -z "$dp_key" ]]; then
                read -s -p "请输入DNSPod Key: " dp_key
                echo
            else
                info "使用配置文件中的DNSPod Key"
            fi

            export DP_Id="$dp_id"
            export DP_Key="$dp_key"
            ;;
        "dns_tencent")
            info "配置腾讯云环境变量..."

            # 尝试使用配置文件中的值
            local tencent_id="$TENCENT_SECRET_ID"
            local tencent_key="$TENCENT_SECRET_KEY"

            # 如果配置文件中没有，则提示用户输入
            if [[ -z "$tencent_id" ]]; then
                read -p "请输入腾讯云SecretId: " tencent_id
            else
                info "使用配置文件中的腾讯云SecretId"
            fi

            if [[ -z "$tencent_key" ]]; then
                read -s -p "请输入腾讯云SecretKey: " tencent_key
                echo
            else
                info "使用配置文件中的腾讯云SecretKey"
            fi

            export Tencent_SecretId="$tencent_id"
            export Tencent_SecretKey="$tencent_key"
            ;;
        "dns_ali")
            info "配置阿里云环境变量..."

            # 尝试使用配置文件中的值
            local ali_key="$ALIYUN_ACCESS_KEY_ID"
            local ali_secret="$ALIYUN_ACCESS_KEY_SECRET"

            # 如果配置文件中没有，则提示用户输入
            if [[ -z "$ali_key" ]]; then
                read -p "请输入阿里云AccessKey ID: " ali_key
            else
                info "使用配置文件中的阿里云AccessKey ID"
            fi

            if [[ -z "$ali_secret" ]]; then
                read -s -p "请输入阿里云AccessKey Secret: " ali_secret
                echo
            else
                info "使用配置文件中的阿里云AccessKey Secret"
            fi

            export Ali_Key="$ali_key"
            export Ali_Secret="$ali_secret"
            ;;
        "dns_aws")
            info "配置AWS环境变量..."
            read -p "请输入AWS Access Key ID: " aws_key
            read -s -p "请输入AWS Secret Access Key: " aws_secret
            echo
            export AWS_ACCESS_KEY_ID="$aws_key"
            export AWS_SECRET_ACCESS_KEY="$aws_secret"
            ;;
        *)
            warn "未知的DNS服务商: $provider"
            ;;
    esac
}

# 申请SSL证书
issue_certificate() {
    local domains="$1"
    local provider="$2"
    local webroot="$3"
    local server="$4"
    local force="$5"

    if [[ -z "$domains" ]]; then
        error "域名不能为空"
        exit 1
    fi

    # 获取主域名（第一个域名）用于日志显示
    local main_domain=$(echo "$domains" | awk '{print $1}')

    # 如果没有提供DNS服务商参数，尝试使用配置文件中的默认值
    if [[ -z "$provider" && -n "$DEFAULT_DNS_PROVIDER" ]]; then
        provider="$DEFAULT_DNS_PROVIDER"
        info "使用配置文件中的默认DNS服务商: $provider"
    fi

    # 如果没有提供服务器参数，尝试使用配置文件中的默认服务器
    if [[ -z "$server" && -n "$DEFAULT_SERVER" ]]; then
        server="$DEFAULT_SERVER"
    elif [[ -z "$server" ]]; then
        server="https://acme.trustasia.com/v2/DV90/directory"
    fi

    info "开始申请SSL证书: $domains"
    info "使用服务器: $server"

    # 检查 acme.sh 是否可用
    if ! check_acme_available; then
        exit 1
    fi

    # 获取 acme.sh 路径并构建申请命令
    local acme_path=$(get_acme_path)
    local cmd="$acme_path --issue"

    if [[ -n "$provider" ]]; then
        # DNS验证
        setup_dns_provider "$provider"
        cmd="$cmd --dns $provider"
    elif [[ -n "$webroot" ]]; then
        # 文件验证
        cmd="$cmd -w $webroot"
    else
        error "必须指定DNS服务商或网站根目录"
        exit 1
    fi

    # 添加所有域名参数
    for domain in $domains; do
        cmd="$cmd -d $domain"
    done

    cmd="$cmd --server $server --keylength 2048"
    
    if [[ "$force" == "true" ]]; then
        cmd="$cmd --force"
    fi
    
    info "执行命令: $cmd"
    
    if eval "$cmd"; then
        log "SSL证书申请成功: $domains"
    else
        error "SSL证书申请失败: $domains"
        exit 1
    fi
}

# 安装证书到服务器
install_certificate() {
    local domain="$1"
    local server_type="$2"
    local cert_path="$3"
    local key_path="$4"
    local reload_cmd="$5"
    
    if [[ -z "$domain" ]]; then
        error "域名不能为空"
        exit 1
    fi
    
    info "开始安装SSL证书: $domain"
    
    # 根据服务器类型设置默认路径和重载命令
    case "$server_type" in
        "nginx")
            if [[ -z "$cert_path" ]]; then
                # 优先使用配置文件中的路径，否则使用默认路径
                if [[ -n "$NGINX_SSL_DIR" ]]; then
                    cert_path="${NGINX_SSL_DIR}/${domain}.crt"
                else
                    cert_path="/etc/nginx/ssl/${domain}.crt"
                fi
            fi
            if [[ -z "$key_path" ]]; then
                # 优先使用配置文件中的路径，否则使用默认路径
                if [[ -n "$NGINX_SSL_DIR" ]]; then
                    key_path="${NGINX_SSL_DIR}/${domain}.key"
                else
                    key_path="/etc/nginx/ssl/${domain}.key"
                fi
            fi
            if [[ -z "$reload_cmd" ]]; then
                # 优先使用配置文件中的重载命令，否则使用默认命令
                if [[ -n "$NGINX_RELOAD_CMD" ]]; then
                    reload_cmd="$NGINX_RELOAD_CMD"
                else
                    reload_cmd="nginx -s reload"
                fi
            fi
            ;;
        "apache")
            if [[ -z "$cert_path" ]]; then
                # 优先使用配置文件中的路径，否则使用默认路径
                if [[ -n "$APACHE_SSL_DIR" ]]; then
                    cert_path="${APACHE_SSL_DIR}/${domain}.crt"
                else
                    cert_path="/etc/apache2/ssl/${domain}.crt"
                fi
            fi
            if [[ -z "$key_path" ]]; then
                # 优先使用配置文件中的路径，否则使用默认路径
                if [[ -n "$APACHE_SSL_DIR" ]]; then
                    key_path="${APACHE_SSL_DIR}/${domain}.key"
                else
                    key_path="/etc/apache2/ssl/${domain}.key"
                fi
            fi
            if [[ -z "$reload_cmd" ]]; then
                # 优先使用配置文件中的重载命令，否则使用默认命令
                if [[ -n "$APACHE_RELOAD_CMD" ]]; then
                    reload_cmd="$APACHE_RELOAD_CMD"
                else
                    reload_cmd="systemctl reload apache2"
                fi
            fi
            ;;
        *)
            if [[ -z "$cert_path" || -z "$key_path" ]]; then
                error "未指定服务器类型时，必须提供证书和私钥路径"
                exit 1
            fi
            ;;
    esac
    
    # 创建证书目录
    mkdir -p "$(dirname "$cert_path")"
    mkdir -p "$(dirname "$key_path")"

    # 检查 acme.sh 是否可用
    if ! check_acme_available; then
        exit 1
    fi

    # 获取 acme.sh 路径并构建安装命令
    local acme_path=$(get_acme_path)
    local cmd="$acme_path --installcert -d $domain"
    cmd="$cmd --key-file $key_path --fullchain-file $cert_path"
    
    if [[ -n "$reload_cmd" ]]; then
        cmd="$cmd --reloadcmd \"$reload_cmd\""
    fi
    
    info "执行命令: $cmd"
    
    if eval "$cmd"; then
        log "SSL证书安装成功: $domain"
        log "证书路径: $cert_path"
        log "私钥路径: $key_path"
    else
        error "SSL证书安装失败: $domain"
        exit 1
    fi
}

# 续期证书
renew_certificate() {
    local domain="$1"
    local force="$2"

    if [[ -z "$domain" ]]; then
        error "域名不能为空"
        exit 1
    fi

    info "开始续期SSL证书: $domain"

    # 检查 acme.sh 是否可用
    if ! check_acme_available; then
        exit 1
    fi

    # 获取 acme.sh 路径并构建续期命令
    local acme_path=$(get_acme_path)
    local cmd="$acme_path --renew -d $domain"

    if [[ "$force" == "true" ]]; then
        cmd="$cmd --force"
    fi

    if eval "$cmd"; then
        log "SSL证书续期成功: $domain"
    else
        error "SSL证书续期失败: $domain"
        exit 1
    fi
}

# 列出所有证书
list_certificates() {
    info "列出所有SSL证书..."

    # 检查 acme.sh 是否可用
    if ! check_acme_available; then
        exit 1
    fi

    # 获取 acme.sh 路径并执行列表命令
    local acme_path=$(get_acme_path)
    if "$acme_path" --list; then
        log "证书列表获取成功"
    else
        error "证书列表获取失败"
        exit 1
    fi
}

# 删除证书
remove_certificate() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        error "域名不能为空"
        exit 1
    fi

    warn "即将删除证书: $domain"
    read -p "确认删除? (y/N): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "取消删除操作"
        return 0
    fi

    info "开始删除SSL证书: $domain"

    # 检查 acme.sh 是否可用
    if ! check_acme_available; then
        exit 1
    fi

    # 获取 acme.sh 路径并执行删除命令
    local acme_path=$(get_acme_path)
    if "$acme_path" --remove -d "$domain"; then
        log "SSL证书删除成功: $domain"
    else
        error "SSL证书删除失败: $domain"
        exit 1
    fi
}

# 查看证书状态
check_certificate_status() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        list_certificates
        return 0
    fi

    info "检查证书状态: $domain"

    # 检查证书文件是否存在
    local cert_dir="$HOME/.acme.sh/$domain"
    if [[ ! -d "$cert_dir" ]]; then
        error "证书不存在: $domain"
        return 1
    fi

    # 显示证书信息
    local cert_file="$cert_dir/$domain.cer"
    if [[ -f "$cert_file" ]]; then
        info "证书文件: $cert_file"

        # 使用openssl查看证书详情
        if command -v openssl &> /dev/null; then
            echo "证书详情:"
            openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
        fi
    fi
}

# 生成Nginx配置示例
generate_nginx_config() {
    local domain="$1"
    local cert_path="$2"
    local key_path="$3"

    if [[ -z "$domain" ]]; then
        error "域名不能为空"
        exit 1
    fi

    if [[ -z "$cert_path" ]]; then
        # 优先使用配置文件中的路径，否则使用默认路径
        if [[ -n "$NGINX_SSL_DIR" ]]; then
            cert_path="${NGINX_SSL_DIR}/${domain}.crt"
        else
            cert_path="/etc/nginx/ssl/${domain}.crt"
        fi
    fi

    if [[ -z "$key_path" ]]; then
        # 优先使用配置文件中的路径，否则使用默认路径
        if [[ -n "$NGINX_SSL_DIR" ]]; then
            key_path="${NGINX_SSL_DIR}/${domain}.key"
        else
            key_path="/etc/nginx/ssl/${domain}.key"
        fi
    fi

    cat << EOF

# Nginx SSL配置示例 - $domain
server {
    listen 80;
    server_name $domain;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;

    # SSL证书配置
    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;

    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    # 网站根目录
    root /var/www/html;
    index index.html index.htm index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
}

EOF
}

# 生成Apache配置示例
generate_apache_config() {
    local domain="$1"
    local cert_path="$2"
    local key_path="$3"

    if [[ -z "$domain" ]]; then
        error "域名不能为空"
        exit 1
    fi

    if [[ -z "$cert_path" ]]; then
        # 优先使用配置文件中的路径，否则使用默认路径
        if [[ -n "$APACHE_SSL_DIR" ]]; then
            cert_path="${APACHE_SSL_DIR}/${domain}.crt"
        else
            cert_path="/etc/apache2/ssl/${domain}.crt"
        fi
    fi

    if [[ -z "$key_path" ]]; then
        # 优先使用配置文件中的路径，否则使用默认路径
        if [[ -n "$APACHE_SSL_DIR" ]]; then
            key_path="${APACHE_SSL_DIR}/${domain}.key"
        else
            key_path="/etc/apache2/ssl/${domain}.key"
        fi
    fi

    cat << EOF

# Apache SSL配置示例 - $domain
<VirtualHost *:80>
    ServerName $domain
    Redirect permanent / https://$domain/
</VirtualHost>

<VirtualHost *:443>
    ServerName $domain
    DocumentRoot /var/www/html

    # SSL配置
    SSLEngine on
    SSLCertificateFile $cert_path
    SSLCertificateKeyFile $key_path

    # SSL安全配置
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    SSLHonorCipherOrder off
    SSLSessionTickets off

    # 安全头
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
</VirtualHost>

EOF
}

# 备份证书
backup_certificates() {
    local backup_dir="/var/backups/ssl_certificates"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/ssl_backup_$timestamp.tar.gz"

    info "开始备份SSL证书..."

    # 创建备份目录
    mkdir -p "$backup_dir"

    # 备份acme.sh目录
    if tar -czf "$backup_file" -C "$HOME" .acme.sh; then
        log "SSL证书备份成功: $backup_file"

        # 保留最近7天的备份
        find "$backup_dir" -name "ssl_backup_*.tar.gz" -mtime +7 -delete
        log "清理旧备份文件完成"
    else
        error "SSL证书备份失败"
        exit 1
    fi
}

# 恢复证书
restore_certificates() {
    local backup_file="$1"

    if [[ -z "$backup_file" ]]; then
        error "请指定备份文件路径"
        exit 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        error "备份文件不存在: $backup_file"
        exit 1
    fi

    warn "即将恢复SSL证书备份，这将覆盖现有证书"
    read -p "确认恢复? (y/N): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "取消恢复操作"
        return 0
    fi

    info "开始恢复SSL证书..."

    # 备份当前证书
    if [[ -d "$HOME/.acme.sh" ]]; then
        mv "$HOME/.acme.sh" "$HOME/.acme.sh.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # 恢复证书
    if tar -xzf "$backup_file" -C "$HOME"; then
        log "SSL证书恢复成功"
    else
        error "SSL证书恢复失败"
        exit 1
    fi
}

# 检查证书到期时间
check_expiry() {
    local domain="$1"
    local days="$2"

    if [[ -z "$days" ]]; then
        days=30
    fi

    info "检查证书到期时间 (${days}天内)..."

    if [[ -n "$domain" ]]; then
        # 检查指定域名
        local cert_file="$HOME/.acme.sh/$domain/$domain.cer"
        if [[ -f "$cert_file" ]]; then
            check_single_cert_expiry "$cert_file" "$domain" "$days"
        else
            error "证书文件不存在: $domain"
        fi
    else
        # 检查所有证书
        for cert_dir in "$HOME/.acme.sh"/*/; do
            if [[ -d "$cert_dir" ]]; then
                local domain_name=$(basename "$cert_dir")
                local cert_file="$cert_dir/$domain_name.cer"
                if [[ -f "$cert_file" ]]; then
                    check_single_cert_expiry "$cert_file" "$domain_name" "$days"
                fi
            fi
        done
    fi
}

# 检查单个证书到期时间
check_single_cert_expiry() {
    local cert_file="$1"
    local domain="$2"
    local days="$3"

    if command -v openssl &> /dev/null; then
        local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

        if [[ $days_until_expiry -le $days ]]; then
            if [[ $days_until_expiry -le 0 ]]; then
                error "证书已过期: $domain (过期时间: $expiry_date)"
            else
                warn "证书即将过期: $domain (剩余 $days_until_expiry 天，过期时间: $expiry_date)"
            fi
        else
            log "证书正常: $domain (剩余 $days_until_expiry 天)"
        fi
    else
        warn "未安装openssl，无法检查证书到期时间"
    fi
}

# 自动续期所有即将过期的证书
auto_renew() {
    local days="$1"

    if [[ -z "$days" ]]; then
        days=30
    fi

    info "自动续期即将过期的证书 (${days}天内)..."

    for cert_dir in "$HOME/.acme.sh"/*/; do
        if [[ -d "$cert_dir" ]]; then
            local domain_name=$(basename "$cert_dir")
            local cert_file="$cert_dir/$domain_name.cer"

            if [[ -f "$cert_file" && "$domain_name" != "ca" ]]; then
                if should_renew_cert "$cert_file" "$days"; then
                    info "续期证书: $domain_name"
                    renew_certificate "$domain_name" "false"
                fi
            fi
        fi
    done
}

# 判断证书是否需要续期
should_renew_cert() {
    local cert_file="$1"
    local days="$2"

    if command -v openssl &> /dev/null; then
        local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

        if [[ $days_until_expiry -le $days ]]; then
            return 0  # 需要续期
        else
            return 1  # 不需要续期
        fi
    else
        return 1  # 无法判断，不续期
    fi
}

# 创建配置文件
create_config() {
    cat > "$CONFIG_FILE" << EOF
# SSL ACME 配置文件
# 生成时间: $(date)

# 默认ACME服务器
DEFAULT_SERVER="https://acme.trustasia.com/v2/DV90/directory"

# 默认邮箱
DEFAULT_EMAIL=""

# 默认DNS服务商
DEFAULT_DNS_PROVIDER=""

# 证书存储路径
CERT_BASE_PATH="/etc/ssl/certs"

# 私钥存储路径
KEY_BASE_PATH="/etc/ssl/private"

# 备份目录
BACKUP_DIR="/var/backups/ssl_certificates"

# 日志级别 (DEBUG, INFO, WARN, ERROR)
LOG_LEVEL="INFO"

# 自动续期天数阈值
AUTO_RENEW_DAYS=30

EOF

    log "配置文件已创建: $CONFIG_FILE"
}

# 加载配置文件
load_config() {
    # 配置文件查找顺序
    local config_files=(
        "/etc/ssl_acme.conf"
        "$HOME/.ssl_acme.conf"
        "./ssl_acme.conf"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            source "$config_file"
            info "已加载配置文件: $config_file"
            return 0
        fi
    done

    # 如果没有找到配置文件，给出提示
    warn "未找到配置文件，将使用默认设置"
    warn "您可以运行 './setup_config.sh' 创建配置文件"
}

# 主函数
main() {
    # 初始化
    mkdir -p "$(dirname "$LOG_FILE")"
    load_config

    # 解析参数
    local command=""
    local domains=""
    local webroot=""
    local server=""
    local email=""
    local provider=""
    local server_type=""
    local force="false"
    local verbose="false"
    local cert_path=""
    local key_path=""
    local reload_cmd=""
    local backup_file=""
    local days=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            install|register|issue|install-cert|renew|list|remove|config|status|help|backup|restore|check-expiry|auto-renew|nginx-config|apache-config|diagnose)
                command="$1"
                shift
                ;;
            -d|--domain)
                if [[ -z "$domains" ]]; then
                    domains="$2"
                else
                    domains="$domains $2"
                fi
                shift 2
                ;;
            -w|--webroot)
                webroot="$2"
                shift 2
                ;;
            -s|--server)
                server="$2"
                shift 2
                ;;
            -e|--email)
                email="$2"
                shift 2
                ;;
            -p|--provider)
                provider="$2"
                shift 2
                ;;
            -t|--type)
                server_type="$2"
                shift 2
                ;;
            --cert-path)
                cert_path="$2"
                shift 2
                ;;
            --key-path)
                key_path="$2"
                shift 2
                ;;
            --reload-cmd)
                reload_cmd="$2"
                shift 2
                ;;
            --backup-file)
                backup_file="$2"
                shift 2
                ;;
            --days)
                days="$2"
                shift 2
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 检查系统环境
    check_system

    # 执行命令
    case "$command" in
        "install")
            install_acme "$email"
            ;;
        "register")
            register_account "$email" "$server"
            ;;
        "issue")
            issue_certificate "$domains" "$provider" "$webroot" "$server" "$force"
            ;;
        "install-cert")
            # install-cert 只支持单个域名，使用第一个域名
            local main_domain=$(echo "$domains" | awk '{print $1}')
            install_certificate "$main_domain" "$server_type" "$cert_path" "$key_path" "$reload_cmd"
            ;;
        "renew")
            # renew 只支持单个域名，使用第一个域名
            local main_domain=$(echo "$domains" | awk '{print $1}')
            renew_certificate "$main_domain" "$force"
            ;;
        "list")
            list_certificates
            ;;
        "remove")
            # remove 只支持单个域名，使用第一个域名
            local main_domain=$(echo "$domains" | awk '{print $1}')
            remove_certificate "$main_domain"
            ;;
        "status")
            # status 只支持单个域名，使用第一个域名
            local main_domain=$(echo "$domains" | awk '{print $1}')
            check_certificate_status "$main_domain"
            ;;
        "backup")
            backup_certificates
            ;;
        "restore")
            restore_certificates "$backup_file"
            ;;
        "check-expiry")
            # check-expiry 支持单个域名或检查所有，使用第一个域名
            local main_domain=$(echo "$domains" | awk '{print $1}')
            check_expiry "$main_domain" "$days"
            ;;
        "auto-renew")
            auto_renew "$days"
            ;;
        "nginx-config")
            # nginx-config 只支持单个域名，使用第一个域名
            local main_domain=$(echo "$domains" | awk '{print $1}')
            generate_nginx_config "$main_domain" "$cert_path" "$key_path"
            ;;
        "apache-config")
            # apache-config 只支持单个域名，使用第一个域名
            local main_domain=$(echo "$domains" | awk '{print $1}')
            generate_apache_config "$main_domain" "$cert_path" "$key_path"
            ;;
        "config")
            create_config
            ;;
        "diagnose")
            diagnose_acme_installation
            ;;
        "help"|"")
            show_help
            ;;
        *)
            error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
