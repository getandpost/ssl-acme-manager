#!/bin/bash

# SSL ACME 使用示例脚本
# 演示如何使用 ssl_acme.sh 脚本管理 SSL 证书

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 脚本路径
SCRIPT_PATH="./ssl_acme.sh"

echo -e "${BLUE}=== SSL ACME 使用示例 ===${NC}"
echo

# 检查脚本是否存在
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo -e "${RED}错误: 找不到 ssl_acme.sh 脚本${NC}"
    echo "请确保脚本在当前目录中"
    exit 1
fi

# 示例1: 安装 acme.sh
example_install() {
    echo -e "${GREEN}示例1: 安装 acme.sh${NC}"
    echo "命令: $SCRIPT_PATH install -e admin@example.com"
    echo "说明: 安装 acme.sh 并设置邮箱地址"
    echo
}

# 示例2: 注册 ACME 账户
example_register() {
    echo -e "${GREEN}示例2: 注册 ACME 账户${NC}"
    echo "命令: $SCRIPT_PATH register -e admin@example.com"
    echo "说明: 注册 ACME 账户，用于申请证书"
    echo
}

# 示例3: 使用 DNSPod 申请证书
example_dnspod() {
    echo -e "${GREEN}示例3: 使用 DNSPod 申请证书${NC}"
    echo "前置条件: 设置环境变量"
    echo "export DP_Id=\"your_dnspod_id\""
    echo "export DP_Key=\"your_dnspod_key\""
    echo
    echo "命令: $SCRIPT_PATH issue -d example.com -p dns_dp"
    echo "说明: 使用 DNSPod DNS 验证申请 example.com 的证书"
    echo
}

# 示例4: 使用腾讯云申请证书
example_tencent() {
    echo -e "${GREEN}示例4: 使用腾讯云申请证书${NC}"
    echo "前置条件: 设置环境变量"
    echo "export Tencent_SecretId=\"your_secret_id\""
    echo "export Tencent_SecretKey=\"your_secret_key\""
    echo
    echo "命令: $SCRIPT_PATH issue -d example.com -p dns_tencent"
    echo "说明: 使用腾讯云 DNS 验证申请证书"
    echo
}

# 示例5: 使用阿里云申请证书
example_aliyun() {
    echo -e "${GREEN}示例5: 使用阿里云申请证书${NC}"
    echo "前置条件: 设置环境变量"
    echo "export Ali_Key=\"your_access_key_id\""
    echo "export Ali_Secret=\"your_access_key_secret\""
    echo
    echo "命令: $SCRIPT_PATH issue -d example.com -p dns_ali"
    echo "说明: 使用阿里云 DNS 验证申请证书"
    echo
}

# 示例6: 使用文件验证申请证书
example_webroot() {
    echo -e "${GREEN}示例6: 使用文件验证申请证书${NC}"
    echo "前置条件: 确保域名指向服务器，Web服务器正常运行"
    echo
    echo "命令: $SCRIPT_PATH issue -d example.com -w /var/www/html"
    echo "说明: 使用文件验证方式申请证书"
    echo
}

# 示例7: 申请通配符证书
example_wildcard() {
    echo -e "${GREEN}示例7: 申请通配符证书${NC}"
    echo "注意: 通配符证书只能使用 DNS 验证"
    echo
    echo "命令: $SCRIPT_PATH issue -d \"*.example.com\" -d example.com -p dns_dp"
    echo "说明: 申请 *.example.com 和 example.com 的通配符证书"
    echo
}

# 示例8: 安装证书到 Nginx
example_nginx() {
    echo -e "${GREEN}示例8: 安装证书到 Nginx${NC}"
    echo "命令: $SCRIPT_PATH install-cert -d example.com -t nginx"
    echo "说明: 自动安装证书到 Nginx 默认路径并重载配置"
    echo
    echo "自定义路径:"
    echo "$SCRIPT_PATH install-cert -d example.com \\"
    echo "  --cert-path /etc/nginx/ssl/example.com.cer \\"
    echo "  --key-path /etc/nginx/ssl/example.com.key \\"
    echo "  --reload-cmd \"nginx -s reload\""
    echo
}

# 示例9: 安装证书到 Apache
example_apache() {
    echo -e "${GREEN}示例9: 安装证书到 Apache${NC}"
    echo "命令: $SCRIPT_PATH install-cert -d example.com -t apache"
    echo "说明: 自动安装证书到 Apache 默认路径并重载配置"
    echo
}

# 示例10: 生成 Nginx 配置
example_nginx_config() {
    echo -e "${GREEN}示例10: 生成 Nginx 配置${NC}"
    echo "命令: $SCRIPT_PATH nginx-config -d example.com"
    echo "说明: 生成 Nginx SSL 配置示例"
    echo
    echo "保存到文件:"
    echo "$SCRIPT_PATH nginx-config -d example.com > /etc/nginx/sites-available/example.com"
    echo
}

# 示例11: 列出所有证书
example_list() {
    echo -e "${GREEN}示例11: 列出所有证书${NC}"
    echo "命令: $SCRIPT_PATH list"
    echo "说明: 显示所有已申请的证书及其状态"
    echo
}

# 示例12: 查看证书状态
example_status() {
    echo -e "${GREEN}示例12: 查看证书状态${NC}"
    echo "命令: $SCRIPT_PATH status -d example.com"
    echo "说明: 查看指定域名的证书详细信息"
    echo
}

# 示例13: 手动续期证书
example_renew() {
    echo -e "${GREEN}示例13: 手动续期证书${NC}"
    echo "命令: $SCRIPT_PATH renew -d example.com"
    echo "说明: 手动续期指定域名的证书"
    echo
    echo "强制续期:"
    echo "$SCRIPT_PATH renew -d example.com -f"
    echo
}

# 示例14: 检查证书到期时间
example_check_expiry() {
    echo -e "${GREEN}示例14: 检查证书到期时间${NC}"
    echo "命令: $SCRIPT_PATH check-expiry --days 30"
    echo "说明: 检查30天内即将过期的证书"
    echo
    echo "检查指定域名:"
    echo "$SCRIPT_PATH check-expiry -d example.com"
    echo
}

# 示例15: 自动续期即将过期的证书
example_auto_renew() {
    echo -e "${GREEN}示例15: 自动续期即将过期的证书${NC}"
    echo "命令: $SCRIPT_PATH auto-renew --days 30"
    echo "说明: 自动续期30天内即将过期的所有证书"
    echo
}

# 示例16: 备份证书
example_backup() {
    echo -e "${GREEN}示例16: 备份证书${NC}"
    echo "命令: $SCRIPT_PATH backup"
    echo "说明: 备份所有证书到 /var/backups/ssl_certificates/"
    echo
}

# 示例17: 恢复证书
example_restore() {
    echo -e "${GREEN}示例17: 恢复证书${NC}"
    echo "命令: $SCRIPT_PATH restore --backup-file /path/to/backup.tar.gz"
    echo "说明: 从备份文件恢复证书"
    echo
}

# 示例18: 删除证书
example_remove() {
    echo -e "${GREEN}示例18: 删除证书${NC}"
    echo "命令: $SCRIPT_PATH remove -d example.com"
    echo "说明: 删除指定域名的证书"
    echo -e "${YELLOW}警告: 此操作不可逆，请谨慎使用${NC}"
    echo
}

# 示例19: 批量申请多个域名证书
example_batch() {
    echo -e "${GREEN}示例19: 批量申请多个域名证书${NC}"
    echo "创建批量脚本:"
    cat << 'EOF'
#!/bin/bash
domains=("example1.com" "example2.com" "example3.com")

for domain in "${domains[@]}"; do
    echo "处理域名: $domain"
    ./ssl_acme.sh issue -d "$domain" -p dns_dp
    ./ssl_acme.sh install-cert -d "$domain" -t nginx
    echo "完成: $domain"
    echo "---"
done
EOF
    echo
}

# 示例20: 设置定时任务
example_cron() {
    echo -e "${GREEN}示例20: 设置定时任务${NC}"
    echo "添加到 crontab:"
    echo "# 每天凌晨2点检查并自动续期即将过期的证书"
    echo "0 2 * * * /usr/local/bin/ssl_acme.sh auto-renew --days 30 >/dev/null 2>&1"
    echo
    echo "添加命令:"
    echo "echo \"0 2 * * * /usr/local/bin/ssl_acme.sh auto-renew --days 30 >/dev/null 2>&1\" | crontab -"
    echo
}

# 示例21: 配置文件使用
example_config_file() {
    echo -e "${GREEN}示例21: 配置文件使用${NC}"
    echo "1. 复制配置文件:"
    echo "   sudo cp ssl_acme.conf.example /etc/ssl_acme.conf"
    echo
    echo "2. 编辑配置文件:"
    echo "   sudo nano /etc/ssl_acme.conf"
    echo
    echo "3. 主要配置项:"
    echo "   DEFAULT_EMAIL=\"admin@example.com\""
    echo "   DEFAULT_DNS_PROVIDER=\"dns_dp\""
    echo "   DNSPOD_ID=\"your_dnspod_id\""
    echo "   DNSPOD_KEY=\"your_dnspod_key\""
    echo
    echo "4. 使用配置文件后，命令更简洁:"
    echo "   $SCRIPT_PATH install          # 使用默认邮箱"
    echo "   $SCRIPT_PATH issue -d example.com  # 使用默认DNS服务商"
    echo
}

# 完整的部署流程示例
example_complete_workflow() {
    echo -e "${GREEN}完整的部署流程示例${NC}"
    echo
    echo -e "${BLUE}方法一：使用配置文件（推荐）${NC}"
    echo "1. 创建配置文件:"
    echo "   sudo cp ssl_acme.conf.example /etc/ssl_acme.conf"
    echo
    echo "2. 编辑配置文件，设置默认值:"
    echo "   sudo nano /etc/ssl_acme.conf"
    echo "   # 设置 DEFAULT_EMAIL、DEFAULT_DNS_PROVIDER、DNSPOD_ID、DNSPOD_KEY"
    echo
    echo "3. 安装 acme.sh (使用配置文件默认邮箱):"
    echo "   $SCRIPT_PATH install"
    echo
    echo "4. 注册账户:"
    echo "   $SCRIPT_PATH register"
    echo
    echo "5. 申请证书 (使用配置文件默认DNS服务商):"
    echo "   $SCRIPT_PATH issue -d example.com -d www.example.com"
    echo
    echo "6. 安装证书到 Nginx:"
    echo "   $SCRIPT_PATH install-cert -d example.com -t nginx"
    echo
    echo "7. 生成 Nginx 配置:"
    echo "   $SCRIPT_PATH nginx-config -d example.com > /etc/nginx/sites-available/example.com"
    echo
    echo "8. 启用站点:"
    echo "   ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/"
    echo "   nginx -t && systemctl reload nginx"
    echo
    echo "9. 设置自动续期:"
    echo "   echo \"0 2 * * * $SCRIPT_PATH auto-renew --days 30\" | crontab -"
    echo
    echo -e "${BLUE}方法二：使用命令行参数${NC}"
    echo "1. 设置环境变量:"
    echo "   export DP_Id=\"your_dnspod_id\""
    echo "   export DP_Key=\"your_dnspod_key\""
    echo
    echo "2. 安装 acme.sh:"
    echo "   $SCRIPT_PATH install -e admin@example.com"
    echo
    echo "3. 注册账户:"
    echo "   $SCRIPT_PATH register -e admin@example.com"
    echo
    echo "4. 申请证书:"
    echo "   $SCRIPT_PATH issue -d example.com -d www.example.com -p dns_dp"
    echo
    echo "5-8. 其余步骤同方法一"
    echo
}

# 故障排除示例
example_troubleshooting() {
    echo -e "${GREEN}故障排除示例${NC}"
    echo
    echo "1. 查看详细日志:"
    echo "   tail -f /var/log/ssl_acme.log"
    echo
    echo "2. 查看 acme.sh 日志:"
    echo "   tail -f ~/.acme.sh/acme.sh.log"
    echo
    echo "3. 测试 DNS 配置:"
    echo "   dig TXT _acme-challenge.example.com"
    echo
    echo "4. 测试证书:"
    echo "   openssl s_client -connect example.com:443 -servername example.com"
    echo
    echo "5. 检查证书有效期:"
    echo "   $SCRIPT_PATH status -d example.com"
    echo
}

# 主菜单
show_menu() {
    echo "请选择要查看的示例:"
    echo
    echo " 1) 安装 acme.sh"
    echo " 2) 注册 ACME 账户"
    echo " 3) DNSPod 申请证书"
    echo " 4) 腾讯云申请证书"
    echo " 5) 阿里云申请证书"
    echo " 6) 文件验证申请证书"
    echo " 7) 申请通配符证书"
    echo " 8) 安装证书到 Nginx"
    echo " 9) 安装证书到 Apache"
    echo "10) 生成 Nginx 配置"
    echo "11) 列出所有证书"
    echo "12) 查看证书状态"
    echo "13) 手动续期证书"
    echo "14) 检查证书到期时间"
    echo "15) 自动续期证书"
    echo "16) 备份证书"
    echo "17) 恢复证书"
    echo "18) 删除证书"
    echo "19) 批量申请证书"
    echo "20) 设置定时任务"
    echo "21) 配置文件使用"
    echo "22) 完整部署流程"
    echo "23) 故障排除"
    echo " 0) 显示所有示例"
    echo
    read -p "请输入选项 (0-23): " choice
    
    case $choice in
        1) example_install ;;
        2) example_register ;;
        3) example_dnspod ;;
        4) example_tencent ;;
        5) example_aliyun ;;
        6) example_webroot ;;
        7) example_wildcard ;;
        8) example_nginx ;;
        9) example_apache ;;
        10) example_nginx_config ;;
        11) example_list ;;
        12) example_status ;;
        13) example_renew ;;
        14) example_check_expiry ;;
        15) example_auto_renew ;;
        16) example_backup ;;
        17) example_restore ;;
        18) example_remove ;;
        19) example_batch ;;
        20) example_cron ;;
        21) example_config_file ;;
        22) example_complete_workflow ;;
        23) example_troubleshooting ;;
        0) show_all_examples ;;
        *) echo -e "${RED}无效选项${NC}" ;;
    esac
}

# 显示所有示例
show_all_examples() {
    example_install
    example_register
    example_dnspod
    example_tencent
    example_aliyun
    example_webroot
    example_wildcard
    example_nginx
    example_apache
    example_nginx_config
    example_list
    example_status
    example_renew
    example_check_expiry
    example_auto_renew
    example_backup
    example_restore
    example_remove
    example_batch
    example_cron
    example_config_file
    example_complete_workflow
    example_troubleshooting
}

# 主函数
main() {
    if [[ $# -eq 0 ]]; then
        show_menu
    else
        case "$1" in
            "all") show_all_examples ;;
            "workflow") example_complete_workflow ;;
            "troubleshooting") example_troubleshooting ;;
            *) 
                echo -e "${RED}未知参数: $1${NC}"
                echo "用法: $0 [all|workflow|troubleshooting]"
                exit 1
                ;;
        esac
    fi
}

# 脚本入口
main "$@"
