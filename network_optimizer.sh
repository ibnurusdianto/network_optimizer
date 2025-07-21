RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] Script ini harus dijalankan sebagai root${NC}"
        echo -e "${YELLOW}[*] Gunakan: sudo $0${NC}"
        exit 1
    fi
}

show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║     NETWORK OPTIMIZER - KALI LINUX 2025.2    ║"
    echo "║           VMware Bridged Mode                ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

backup_config() {
    echo -e "${YELLOW}[*] Membuat backup konfigurasi...${NC}"
    BACKUP_DIR="/root/network_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $BACKUP_DIR
    cp /etc/sysctl.conf $BACKUP_DIR/ 2>/dev/null
    cp /etc/network/interfaces $BACKUP_DIR/ 2>/dev/null
    cp /etc/NetworkManager/NetworkManager.conf $BACKUP_DIR/ 2>/dev/null
    echo -e "${GREEN}[✓] Backup tersimpan di: $BACKUP_DIR${NC}"
}

get_interface() {
    echo -e "${YELLOW}[*] Mendeteksi interface jaringan...${NC}"
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}[!] Tidak dapat mendeteksi interface aktif${NC}"
        echo -e "${YELLOW}[*] Interface yang tersedia:${NC}"
        ip link show | grep -E "^[0-9]" | awk -F: '{print $2}'
        read -p "Masukkan nama interface: " INTERFACE
    fi
    echo -e "${GREEN}[✓] Interface terdeteksi: $INTERFACE${NC}"
}
optimize_tcpip() {
    echo -e "${YELLOW}[*] Mengoptimalkan TCP/IP Stack...${NC}"
    cat >> /etc/sysctl.conf << EOF
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 256960
net.core.wmem_default = 256960
net.core.optmem_max = 40960
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 8192
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.core.optmem_max = 65536
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl -p > /dev/null 2>&1
    echo -e "${GREEN}[✓] TCP/IP Stack dioptimalkan${NC}"
}
optimize_interface() {
    echo -e "${YELLOW}[*] Mengoptimalkan interface $INTERFACE...${NC}"
    ip link set dev $INTERFACE mtu 1500
    ethtool -K $INTERFACE rx on tx on sg on tso on gso on gro on lro on 2>/dev/null
    ethtool -G $INTERFACE rx 4096 tx 4096 2>/dev/null
    ethtool -C $INTERFACE adaptive-rx on adaptive-tx on 2>/dev/null
    echo -e "${GREEN}[✓] Interface dioptimalkan${NC}"
}
optimize_dns() {
    echo -e "${YELLOW}[*] Mengoptimalkan DNS...${NC}"
    cp /etc/resolv.conf /etc/resolv.conf.backup
    cat > /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
nameserver 8.8.4.4
options timeout:2 attempts:3 rotate
EOF
    chattr +i /etc/resolv.conf
    echo -e "${GREEN}[✓] DNS dioptimalkan${NC}"
}
setup_dnscrypt() {
    echo -e "${YELLOW}[*] Setup DNSCrypt untuk keamanan DNS...${NC}"
    read -p "Install DNSCrypt-proxy? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apt update > /dev/null 2>&1
        apt install -y dnscrypt-proxy > /dev/null 2>&1
        systemctl enable dnscrypt-proxy
        systemctl start dnscrypt-proxy
        echo -e "${GREEN}[✓] DNSCrypt terinstall${NC}"
    fi
}
optimize_firewall() {
    echo -e "${YELLOW}[*] Mengoptimalkan firewall...${NC}"
    modprobe nf_conntrack_ftp
    modprobe nf_conntrack_tftp
    modprobe nf_conntrack_sane
    modprobe nf_conntrack_irc
    modprobe nf_conntrack_amanda
    echo "net.netfilter.nf_conntrack_max = 1048576" >> /etc/sysctl.conf
    echo "net.netfilter.nf_conntrack_tcp_timeout_established = 3600" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
    echo -e "${GREEN}[✓] Firewall dioptimalkan${NC}"
}
install_monitoring() {
    echo -e "${YELLOW}[*] Install tools monitoring jaringan...${NC}"
    TOOLS="iftop nethogs bmon nload vnstat speedtest-cli"
    for tool in $TOOLS; do
        if ! command -v $tool &> /dev/null; then
            apt install -y $tool > /dev/null 2>&1
            echo -e "${GREEN}[✓] $tool terinstall${NC}"
        fi
    done
}
test_performance() {
    echo -e "${YELLOW}[*] Testing performa jaringan...${NC}"
    echo -e "${BLUE}[>] DNS Resolution Test:${NC}"
    time nslookup google.com > /dev/null 2>&1
    echo -e "${BLUE}[>] Connectivity Test:${NC}"
    ping -c 4 1.1.1.1
    if command -v speedtest-cli &> /dev/null; then
        echo -e "${BLUE}[>] Speed Test:${NC}"
        speedtest-cli --simple
    fi
}
create_service() {
    echo -e "${YELLOW}[*] Membuat service untuk auto-optimization...${NC}"
    cat > /etc/systemd/system/network-optimizer.service << EOF
[Unit]
Description=Network Optimizer Service
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/network-optimizer.sh --auto
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
    cp $0 /usr/local/bin/network-optimizer.sh
    chmod +x /usr/local/bin/network-optimizer.sh
    systemctl daemon-reload
    systemctl enable network-optimizer.service
    echo -e "${GREEN}[✓] Service auto-optimization dibuat${NC}"
}
restore_config() {
    echo -e "${YELLOW}[*] Restore konfigurasi...${NC}"
    echo -e "${BLUE}Backup yang tersedia:${NC}"
    ls -la /root/network_backup_* 2>/dev/null
    read -p "Masukkan path backup: " RESTORE_PATH
    if [ -d "$RESTORE_PATH" ]; then
        cp $RESTORE_PATH/sysctl.conf /etc/ 2>/dev/null
        cp $RESTORE_PATH/interfaces /etc/network/ 2>/dev/null
        cp $RESTORE_PATH/NetworkManager.conf /etc/NetworkManager/ 2>/dev/null
        chattr -i /etc/resolv.conf
        cp $RESTORE_PATH/resolv.conf.backup /etc/resolv.conf 2>/dev/null
        sysctl -p > /dev/null 2>&1
        systemctl restart NetworkManager
        echo -e "${GREEN}[✓] Konfigurasi di-restore${NC}"
    else
        echo -e "${RED}[!] Path backup tidak valid${NC}"
    fi
}
main_menu() {
    while true; do
        show_banner
        echo -e "${BLUE}Menu Utama:${NC}"
        echo "1. Full Optimization (Recommended)"
        echo "2. TCP/IP Optimization"
        echo "3. Interface Optimization"
        echo "4. DNS Optimization"
        echo "5. Install Monitoring Tools"
        echo "6. Test Network Performance"
        echo "7. Create Auto-Optimization Service"
        echo "8. Restore Configuration"
        echo "9. Exit"
        echo
        read -p "Pilih opsi [1-9]: " choice
        case $choice in
            1)
                backup_config
                get_interface
                optimize_tcpip
                optimize_interface
                optimize_dns
                optimize_firewall
                install_monitoring
                create_service
                echo -e "${GREEN}[✓] Full optimization selesai!${NC}"
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            2)
                optimize_tcpip
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            3)
                get_interface
                optimize_interface
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            4)
                optimize_dns
                setup_dnscrypt
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            5)
                install_monitoring
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            6)
                test_performance
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            7)
                create_service
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            8)
                restore_config
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
            9)
                echo -e "${GREEN}[*] Terima kasih telah menggunakan Network Optimizer${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Pilihan tidak valid${NC}"
                read -p "Tekan Enter untuk melanjutkan..."
                ;;
        esac
    done
}
if [ "$1" == "--auto" ]; then
    get_interface
    optimize_tcpip
    optimize_interface
    optimize_firewall
    exit 0
fi
check_root
main_menu