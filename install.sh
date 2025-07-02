#!/bin/bash

# SSL ACME 脚本安装器
# 自动安装和配置 SSL ACME 管理脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
SCRIPT_NAME="ssl_acme.sh"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc"
LOG_DIR="/var/log"
BACKUP_DIR="/var/backups/ssl_certificates"

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

# 检查权限
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要 root 权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统
check_system() {
    info "检查系统环境..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        error "无法识别操作系统"
        exit 1
    fi
    
    source /etc/os-release
    log "检测到操作系统: $PRETTY_NAME"
    
    # 检查必要命令
    local missing_commands=()
    for cmd in curl wget git tar gzip; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "缺少必要命令: ${missing_commands[*]}"
        info "请先安装这些命令，然后重新运行安装脚本"
        
        # 提供安装建议
        case "$ID" in
            ubuntu|debian)
                echo "运行: apt update && apt install -y ${missing_commands[*]}"
                ;;
            centos|rhel|fedora)
                echo "运行: yum install -y ${missing_commands[*]} 或 dnf install -y ${missing_commands[*]}"
                ;;
            *)
                echo "请使用系统包管理器安装: ${missing_commands[*]}"
                ;;
        esac
        exit 1
    fi
    
    log "系统环境检查完成"
}

# 创建目录
create_directories() {
    info "创建必要目录..."
    
    local directories=(
        "$LOG_DIR"
        "$BACKUP_DIR"
        "/etc/ssl/certs"
        "/etc/ssl/private"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "创建目录: $dir"
        fi
    done
    
    # 设置权限
    chmod 755 "$LOG_DIR"
    chmod 700 "$BACKUP_DIR"
    chmod 755 "/etc/ssl/certs"
    chmod 700 "/etc/ssl/private"
}

# 安装脚本
install_script() {
    info "安装 SSL ACME 脚本..."
    
    # 检查脚本文件是否存在
    if [[ ! -f "$SCRIPT_NAME" ]]; then
        error "找不到脚本文件: $SCRIPT_NAME"
        exit 1
    fi
    
    # 复制脚本到安装目录
    cp "$SCRIPT_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    
    log "脚本已安装到: $INSTALL_DIR/$SCRIPT_NAME"
    
    # 创建符号链接
    if [[ ! -L "/usr/bin/ssl-acme" ]]; then
        ln -s "$INSTALL_DIR/$SCRIPT_NAME" "/usr/bin/ssl-acme"
        log "创建符号链接: /usr/bin/ssl-acme"
    fi
}

# 安装配置文件
install_config() {
    info "安装配置文件..."
    
    local config_file="$CONFIG_DIR/ssl_acme.conf"
    
    if [[ -f "ssl_acme.conf.example" ]]; then
        if [[ ! -f "$config_file" ]]; then
            cp "ssl_acme.conf.example" "$config_file"
            log "配置文件已安装到: $config_file"
        else
            warn "配置文件已存在，跳过安装"
        fi
    else
        warn "未找到示例配置文件"
    fi
}

# 设置 cron 任务
setup_cron() {
    info "设置自动续期任务..."
    
    local cron_job="0 2 * * * $INSTALL_DIR/$SCRIPT_NAME auto-renew --days 30 >/dev/null 2>&1"
    
    # 检查是否已存在相同的 cron 任务
    if crontab -l 2>/dev/null | grep -q "$INSTALL_DIR/$SCRIPT_NAME auto-renew"; then
        warn "自动续期任务已存在，跳过设置"
        return 0
    fi
    
    # 添加 cron 任务
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    log "已设置自动续期任务: 每天凌晨2点检查并续期即将过期的证书"
}

# 创建日志轮转配置
setup_logrotate() {
    info "设置日志轮转..."
    
    local logrotate_config="/etc/logrotate.d/ssl_acme"
    
    cat > "$logrotate_config" << 'EOF'
/var/log/ssl_acme.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
    
    log "日志轮转配置已创建: $logrotate_config"
}

# 创建 systemd 服务（可选）
create_systemd_service() {
    info "创建 systemd 服务..."
    
    local service_file="/etc/systemd/system/ssl-acme-renew.service"
    local timer_file="/etc/systemd/system/ssl-acme-renew.timer"
    
    # 创建服务文件
    cat > "$service_file" << EOF
[Unit]
Description=SSL ACME Certificate Auto Renewal
After=network.target

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/$SCRIPT_NAME auto-renew --days 30
User=root
StandardOutput=journal
StandardError=journal
EOF
    
    # 创建定时器文件
    cat > "$timer_file" << 'EOF'
[Unit]
Description=SSL ACME Certificate Auto Renewal Timer
Requires=ssl-acme-renew.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # 重新加载 systemd 并启用定时器
    systemctl daemon-reload
    systemctl enable ssl-acme-renew.timer
    systemctl start ssl-acme-renew.timer
    
    log "systemd 服务和定时器已创建并启用"
}

# 显示安装后信息
show_post_install_info() {
    echo
    log "SSL ACME 脚本安装完成！"
    echo
    echo "使用方法:"
    echo "  ssl-acme help                    # 查看帮助信息"
    echo "  ssl-acme install -e your@email  # 安装 acme.sh"
    echo "  ssl-acme issue -d example.com    # 申请证书"
    echo
    echo "配置文件: $CONFIG_DIR/ssl_acme.conf"
    echo "日志文件: $LOG_DIR/ssl_acme.log"
    echo "备份目录: $BACKUP_DIR"
    echo
    echo "自动续期已设置，每天凌晨2点自动检查并续期即将过期的证书"
    echo
    echo "更多信息请查看: SSL_ACME_README.md"
}

# 卸载函数
uninstall() {
    warn "开始卸载 SSL ACME 脚本..."
    
    read -p "确认卸载? 这将删除所有相关文件 (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "取消卸载"
        exit 0
    fi
    
    # 停止并禁用 systemd 服务
    if systemctl is-active --quiet ssl-acme-renew.timer; then
        systemctl stop ssl-acme-renew.timer
        systemctl disable ssl-acme-renew.timer
    fi
    
    # 删除文件
    local files_to_remove=(
        "$INSTALL_DIR/$SCRIPT_NAME"
        "/usr/bin/ssl-acme"
        "/etc/ssl_acme.conf"
        "/etc/logrotate.d/ssl_acme"
        "/etc/systemd/system/ssl-acme-renew.service"
        "/etc/systemd/system/ssl-acme-renew.timer"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" || -L "$file" ]]; then
            rm -f "$file"
            log "删除文件: $file"
        fi
    done
    
    # 删除 cron 任务
    if crontab -l 2>/dev/null | grep -q "$INSTALL_DIR/$SCRIPT_NAME"; then
        crontab -l 2>/dev/null | grep -v "$INSTALL_DIR/$SCRIPT_NAME" | crontab -
        log "删除 cron 任务"
    fi
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    log "SSL ACME 脚本卸载完成"
}

# 主函数
main() {
    case "${1:-install}" in
        "install")
            check_permissions
            check_system
            create_directories
            install_script
            install_config
            setup_cron
            setup_logrotate
            
            # 可选：创建 systemd 服务
            if command -v systemctl &> /dev/null; then
                read -p "是否创建 systemd 服务? (推荐) (Y/n): " create_service
                if [[ "$create_service" != "n" && "$create_service" != "N" ]]; then
                    create_systemd_service
                fi
            fi
            
            show_post_install_info
            ;;
        "uninstall")
            check_permissions
            uninstall
            ;;
        "help"|"-h"|"--help")
            echo "SSL ACME 脚本安装器"
            echo
            echo "用法: $0 [命令]"
            echo
            echo "命令:"
            echo "  install    安装 SSL ACME 脚本 (默认)"
            echo "  uninstall  卸载 SSL ACME 脚本"
            echo "  help       显示此帮助信息"
            ;;
        *)
            error "未知命令: $1"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@"
