#!/usr/bin/env bash
# ============================================
#  SNOWCLOUD - TACTICAL MOTD INSTALLER v3.0
#  [ ELITE SERVER DASHBOARD DEPLOYMENT ]
# ============================================

set -eo pipefail
trap 'echo -e "\n\033[1;31m[!] Installation aborted\033[0m"; exit 1' INT TERM

# ========== CONFIGURATION ==========
readonly COLOR_GREEN='\033[38;5;82m'
readonly COLOR_CYAN='\033[38;5;51m'
readonly COLOR_BLUE='\033[38;5;39m'
readonly COLOR_YELLOW='\033[38;5;220m'
readonly COLOR_RED='\033[38;5;196m'
readonly COLOR_MAGENTA='\033[38;5;165m'
readonly COLOR_GRAY='\033[38;5;245m'
readonly COLOR_RESET='\033[0m'
readonly BOLD='\033[1m'
readonly BLINK='\033[5m'

readonly LOG_FILE="/var/log/snowcloud-motd-install.log"
readonly MOTD_PATH="/etc/update-motd.d/00-snowcloud-tactical"
readonly BACKUP_DIR="/etc/update-motd.d/backup_$(date +%s)"

# ========== ANIMATION FUNCTIONS ==========
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep -w $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r[${COLOR_CYAN}%c${COLOR_RESET}]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r[${COLOR_GREEN}✓${COLOR_RESET}]"
}

print_banner() {
    clear
    echo -e "${COLOR_CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║  ███████╗███╗   ██╗ ██████╗ ██╗    ██╗ ██████╗██╗   ██╗  ║
    ║  ██╔════╝████╗  ██║██╔═══██╗██║    ██║██╔════╝██║   ██║  ║
    ║  ███████╗██╔██╗ ██║██║   ██║██║ █╗ ██║██║     ██║   ██║  ║
    ║  ╚════██║██║╚██╗██║██║   ██║██║███╗██║██║     ██║   ██║  ║
    ║  ███████║██║ ╚████║╚██████╔╝╚███╔███╔╝╚██████╗╚██████╔╝  ║
    ║  ╚══════╝╚═╝  ╚═══╝ ╚═════╝  ╚══╝╚══╝  ╚═════╝ ╚═════╝   ║
    ║                                                           ║
    ║              TACTICAL MOTD DEPLOYMENT v3.0                ║
    ║                   [ Arctic Security Suite ]               ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${COLOR_RESET}"
}

# ========== PRIVILEGE CHECK ==========
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${COLOR_RED}[!] This script must be run as root${COLOR_RESET}"
        echo -e "${COLOR_YELLOW}Use: sudo ./$(basename "$0")${COLOR_RESET}"
        exit 1
    fi
}

# ========== BACKUP EXISTING MOTD ==========
backup_existing() {
    echo -e "${COLOR_BLUE}[*] Creating backup of existing MOTD...${COLOR_RESET}"
    mkdir -p "$BACKUP_DIR"
    
    if [ -d /etc/update-motd.d ]; then
        for file in /etc/update-motd.d/*; do
            if [ -f "$file" ]; then
                cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
                echo -e "${COLOR_GRAY}  ↪ Backed up: $(basename "$file")${COLOR_RESET}"
            fi
        done
    fi
    echo -e "${COLOR_GREEN}[+] Backup created in: $BACKUP_DIR${COLOR_RESET}"
}

# ========== DISABLE DEFAULT MOTD ==========
disable_default_motd() {
    echo -e "${COLOR_BLUE}[*] Disabling default MOTD services...${COLOR_RESET}"
    
    # Disable all dynamic MOTD scripts
    if [ -d /etc/update-motd.d ]; then
        chmod -x /etc/update-motd.d/* 2>/dev/null || true
        echo -e "${COLOR_GREEN}[+] Disabled dynamic MOTD scripts${COLOR_RESET}"
    fi
    
    # Disable landscape-motd if exists
    if [ -f /etc/default/landscape-motd ]; then
        sed -i 's/^ENABLED=.*/ENABLED=0/' /etc/default/landscape-motd
        echo -e "${COLOR_GREEN}[+] Disabled landscape-motd${COLOR_RESET}"
    fi
    
    # Clean static MOTD
    > /etc/motd
    > /etc/motd-static
}

# ========== DEPLOY TACTICAL MOTD ==========
deploy_tactical_motd() {
    echo -e "${COLOR_BLUE}[*] Deploying SNOWCLOUD Tactical MOTD...${COLOR_RESET}"
    
    cat << 'EOF' > "$MOTD_PATH"
#!/usr/bin/env bash
# ============================================
#  SNOWCLOUD TACTICAL MOTD v3.0
#  [ ARCTIC SECURITY SUITE ]
# ============================================

# ===== COLOR DEFINITIONS =====
COLOR_GREEN='\033[38;5;82m'
COLOR_CYAN='\033[38;5;51m'
COLOR_BLUE='\033[38;5;39m'
COLOR_YELLOW='\033[38;5;220m'
COLOR_RED='\033[38;5;196m'
COLOR_MAGENTA='\033[38;5;165m'
COLOR_GRAY='\033[38;5;245m'
COLOR_WHITE='\033[38;5;255m'
COLOR_RESET='\033[0m'
BOLD='\033[1m'

# ===== SYSTEM METRICS =====
get_system_metrics() {
    # CPU Load with color coding
    local load1 load5 load15
    read -r load1 load5 load15 <<< $(awk '{print $1, $2, $3}' /proc/loadavg)
    local cpu_cores=$(nproc)
    local load_percent=$(echo "scale=0; $load1 * 100 / $cpu_cores" | bc)
    
    if (( $(echo "$load_percent > 80" | bc -l) )); then
        LOAD_COLOR=$COLOR_RED
    elif (( $(echo "$load_percent > 60" | bc -l) )); then
        LOAD_COLOR=$COLOR_YELLOW
    else
        LOAD_COLOR=$COLOR_GREEN
    fi
    
    # Memory with color coding
    read -r mem_total mem_used mem_free <<< $(free -m | awk '/Mem:/ {print $2, $3, $4}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    if (( mem_percent > 90 )); then
        MEM_COLOR=$COLOR_RED
    elif (( mem_percent > 70 )); then
        MEM_COLOR=$COLOR_YELLOW
    else
        MEM_COLOR=$COLOR_GREEN
    fi
    
    # Disk with color coding
    read -r disk_used disk_total disk_percent <<< $(df -h / | awk 'NR==2 {
        gsub("%","",$5); 
        print $3, $2, $5}')
    
    if (( disk_percent > 90 )); then
        DISK_COLOR=$COLOR_RED
    elif (( disk_percent > 75 )); then
        DISK_COLOR=$COLOR_YELLOW
    else
        DISK_COLOR=$COLOR_GREEN
    fi
    
    # Network
    local primary_ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    local public_ip=$(curl -s -4 ifconfig.me 2>/dev/null || echo "N/A")
    
    # Uptime
    local uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    local days=$((uptime_seconds / 86400))
    local hours=$(( (uptime_seconds % 86400) / 3600 ))
    
    # Export metrics
    export LOAD1="$load1"
    export LOAD5="$load5"
    export LOAD15="$load15"
    export LOAD_COLOR
    export MEM_TOTAL="$mem_total"
    export MEM_USED="$mem_used"
    export MEM_PERC="$mem_percent"
    export MEM_COLOR
    export DISK_USED="$disk_used"
    export DISK_TOTAL="$disk_total"
    export DISK_PERC="$disk_percent"
    export DISK_COLOR
    export IP_ADDR="$primary_ip"
    export PUBLIC_IP="$public_ip"
    export UPTIME_DAYS="$days"
    export UPTIME_HOURS="$hours"
    export HOSTNAME=$(hostname)
    export KERNEL=$(uname -r)
    export OS=$(awk -F= '/PRETTY_NAME/ {print $2}' /etc/os-release | tr -d '"')
    export USERS=$(who | wc -l)
    export PROCESSES=$(ps -e --no-headers | wc -l)
}

# ===== DISPLAY FUNCTIONS =====
display_header() {
    echo -e "${COLOR_CYAN}"
    cat << "HEADER"
    ┌─────────────────────────────────────────────────────────┐
    │  ███████╗███╗   ██╗ ██████╗ ██╗    ██╗ ██████╗██╗   ██╗  │
    │  ██╔════╝████╗  ██║██╔═══██╗██║    ██║██╔════╝██║   ██║  │
    │  ███████╗██╔██╗ ██║██║   ██║██║ █╗ ██║██║     ██║   ██║  │
    │  ╚════██║██║╚██╗██║██║   ██║██║███╗██║██║     ██║   ██║  │
    │  ███████║██║ ╚████║╚██████╔╝╚███╔███╔╝╚██████╗╚██████╔╝  │
    │  ╚══════╝╚═╝  ╚═══╝ ╚═════╝  ╚══╝╚══╝  ╚═════╝ ╚═════╝   │
    └─────────────────────────────────────────────────────────┘
HEADER
    echo -e "${COLOR_RESET}"
    
    echo -e "${COLOR_BLUE}┌─────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_WHITE}        A R C T I C   S E C U R I T Y   S U I T E         ${COLOR_BLUE}│${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_GRAY}            Enterprise Infrastructure Platform           ${COLOR_BLUE}│${COLOR_RESET}"
    echo -e "${COLOR_BLUE}└─────────────────────────────────────────────────────────┘${COLOR_RESET}"
    echo
}

display_system_status() {
    echo -e "${COLOR_CYAN}┌─────────────────────┤ ${COLOR_WHITE}SYSTEM STATUS${COLOR_CYAN} ├──────────────────────┐${COLOR_RESET}"
    
    printf "${COLOR_CYAN}│${COLOR_RESET} %-20s ${COLOR_WHITE}%-34s ${COLOR_CYAN}│${COLOR_RESET}\n" "Hostname:" "$HOSTNAME"
    printf "${COLOR_CYAN}│${COLOR_RESET} %-20s ${COLOR_WHITE}%-34s ${COLOR_CYAN}│${COLOR_RESET}\n" "OS:" "$OS"
    printf "${COLOR_CYAN}│${COLOR_RESET} %-20s ${COLOR_WHITE}%-34s ${COLOR_CYAN}│${COLOR_RESET}\n" "Kernel:" "$KERNEL"
    printf "${COLOR_CYAN}│${COLOR_RESET} %-20s ${COLOR_WHITE}%-34s ${COLOR_CYAN}│${COLOR_RESET}\n" "Uptime:" "${UPTIME_DAYS}d ${UPTIME_HOURS}h"
    
    echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────┤${COLOR_RESET}"
}

display_resource_metrics() {
    echo -e "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}Resource Metrics${COLOR_RESET}"
    
    # CPU Load
    printf "${COLOR_CYAN}│${COLOR_RESET}   CPU Load:    ${LOAD_COLOR}%-6s${COLOR_RESET} (1m) ${COLOR_GRAY}%-6s${COLOR_RESET} (5m) ${COLOR_GRAY}%-6s${COLOR_RESET} (15m)\n" \
           "$LOAD1" "$LOAD5" "$LOAD15"
    
    # Memory
    printf "${COLOR_CYAN}│${COLOR_RESET}   Memory:      ${MEM_COLOR}%4s MB${COLOR_RESET} / %4s MB ${COLOR_GRAY}[%3s%%]${COLOR_RESET}\n" \
           "$MEM_USED" "$MEM_TOTAL" "$MEM_PERC"
    
    # Disk
    printf "${COLOR_CYAN}│${COLOR_RESET}   Disk (/):    ${DISK_COLOR}%5s${COLOR_RESET} / %5s ${COLOR_GRAY}[%3s%%]${COLOR_RESET}\n" \
           "$DISK_USED" "$DISK_TOTAL" "$DISK_PERC"
    
    echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────┤${COLOR_RESET}"
}

display_network_info() {
    echo -e "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}Network Information${COLOR_RESET}"
    printf "${COLOR_CYAN}│${COLOR_RESET}   Internal IP: ${COLOR_GREEN}%-40s${COLOR_RESET}\n" "$IP_ADDR"
    printf "${COLOR_CYAN}│${COLOR_RESET}   External IP: ${COLOR_BLUE}%-40s${COLOR_RESET}\n" "$PUBLIC_IP"
    printf "${COLOR_CYAN}│${COLOR_RESET}   Connections: ${COLOR_GRAY}%-40s${COLOR_RESET}\n" "$(ss -tun | tail -n +2 | wc -l) active"
    
    echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────┤${COLOR_RESET}"
}

display_system_activity() {
    echo -e "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}System Activity${COLOR_RESET}"
    printf "${COLOR_CYAN}│${COLOR_RESET}   Users:       ${COLOR_GRAY}%-40s${COLOR_RESET}\n" "$USERS active"
    printf "${COLOR_CYAN}│${COLOR_RESET}   Processes:   ${COLOR_GRAY}%-40s${COLOR_RESET}\n" "$PROCESSES running"
    
    # Top 3 processes by CPU
    echo -e "${COLOR_CYAN}│${COLOR_RESET}   Top Processes:"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -4 | tail -3 | while read pid comm cpu; do
        printf "${COLOR_CYAN}│${COLOR_RESET}     ${COLOR_GRAY}%-30s ${COLOR_YELLOW}%5s%%${COLOR_RESET}\n" "$comm" "$cpu"
    done
    
    echo -e "${COLOR_CYAN}├─────────────────────────────────────────────────────────┤${COLOR_RESET}"
}

display_footer() {
    local current_time=$(date +"%Y-%m-%d %H:%M:%S %Z")
    echo -e "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_GRAY}Last Updated: $current_time${COLOR_RESET}"
    echo -e "${COLOR_CYAN}└─────────────────────────────────────────────────────────┘${COLOR_RESET}"
    echo
    
    echo -e "${COLOR_BLUE}┌─────────────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_CYAN} Support:${COLOR_WHITE}    support@snowcloud.io${COLOR_BLUE}                          │${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_CYAN} Website:${COLOR_WHITE}    https://snowcloud.io${COLOR_BLUE}                          │${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_CYAN} Status:${COLOR_WHITE}     https://status.snowcloud.io${COLOR_BLUE}                    │${COLOR_RESET}"
    echo -e "${COLOR_BLUE}└─────────────────────────────────────────────────────────┘${COLOR_RESET}"
    
    echo -e "${COLOR_MAGENTA}"
    cat << "FOOTER"
    ════════════════════════════════════════════════════════
      ❄️  Arctic-Grade Infrastructure • Zero Compromise  
    ════════════════════════════════════════════════════════
FOOTER
    echo -e "${COLOR_RESET}"
    echo
}

# ===== MAIN EXECUTION =====
main() {
    # Clear screen and get metrics
    clear
    get_system_metrics
    
    # Display all components
    display_header
    display_system_status
    display_resource_metrics
    display_network_info
    display_system_activity
    display_footer
}

main "$@"
EOF

    chmod +x "$MOTD_PATH"
    echo -e "${COLOR_GREEN}[+] Tactical MOTD deployed to: $MOTD_PATH${COLOR_RESET}"
}

# ========== VERIFY INSTALLATION ==========
verify_installation() {
    echo -e "${COLOR_BLUE}[*] Verifying installation...${COLOR_RESET}"
    
    local errors=0
    
    # Check if file exists and is executable
    if [ ! -f "$MOTD_PATH" ]; then
        echo -e "${COLOR_RED}[!] MOTD file not found${COLOR_RESET}"
        ((errors++))
    fi
    
    if [ ! -x "$MOTD_PATH" ]; then
        echo -e "${COLOR_RED}[!] MOTD file is not executable${COLOR_RESET}"
        ((errors++))
    fi
    
    # Test MOTD execution
    if timeout 2s bash "$MOTD_PATH" > /dev/null 2>&1; then
        echo -e "${COLOR_GREEN}[+] MOTD execution test passed${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}[!] MOTD execution test failed${COLOR_RESET}"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        echo -e "${COLOR_GREEN}[✓] Installation verified successfully${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}[!] Installation verification failed with $errors error(s)${COLOR_RESET}"
        return 1
    fi
}

# ========== DISPLAY PREVIEW ==========
display_preview() {
    echo -e "${COLOR_BLUE}[*] Generating installation preview...${COLOR_RESET}"
    echo -e "${COLOR_GRAY}────────────────────────────────────────────────────────────${COLOR_RESET}"
    
    # Simulate MOTD output
    echo -e "${COLOR_CYAN}"
    cat << "PREVIEW"
    ┌─────────────────────────────────────────────────────────┐
    │  ███████╗███╗   ██╗ ██████╗ ██╗    ██╗ ██████╗██╗   ██╗  │
    │  ██╔════╝████╗  ██║██╔═══██╗██║    ██║██╔════╝██║   ██║  │
    │  ███████╗██╔██╗ ██║██║   ██║██║ █╗ ██║██║     ██║   ██║  │
    │  ╚════██║██║╚██╗██║██║   ██║██║███╗██║██║     ██║   ██║  │
    │  ███████║██║ ╚████║╚██████╔╝╚███╔███╔╝╚██████╗╚██████╔╝  │
    │  ╚══════╝╚═╝  ╚═══╝ ╚═════╝  ╚══╝╚══╝  ╚═════╝ ╚═════╝   │
    └─────────────────────────────────────────────────────────┘
PREVIEW
    echo -e "${COLOR_RESET}"
    
    echo -e "${COLOR_BLUE}│${COLOR_WHITE}        A R C T I C   S E C U R I T Y   S U I T E         ${COLOR_BLUE}│${COLOR_RESET}"
    echo -e "${COLOR_GRAY}│            Enterprise Infrastructure Platform           │${COLOR_RESET}"
    echo -e "${COLOR_GRAY}├─────────────────────────────────────────────────────────┤${COLOR_RESET}"
    echo -e "${COLOR_GRAY}│ Hostname:           snowcloud-node-01                   │${COLOR_RESET}"
    echo -e "${COLOR_GRAY}│ Uptime:             15d 6h                              │${COLOR_RESET}"
    echo -e "${COLOR_GRAY}│ Load:               0.42 0.38 0.41                      │${COLOR_RESET}"
    echo -e "${COLOR_GRAY}│ Memory:             2.1G / 7.8G [27%]                   │${COLOR_RESET}"
    echo -e "${COLOR_GRAY}│ Disk:               45G / 200G [22%]                    │${COLOR_RESET}"
    echo -e "${COLOR_GRAY}└─────────────────────────────────────────────────────────┘${COLOR_RESET}"
    
    echo -e "${COLOR_GRAY}────────────────────────────────────────────────────────────${COLOR_RESET}"
    echo -e "${COLOR_GREEN}[✓] SNOWCLOUD Tactical MOTD will display similar output${COLOR_RESET}"
}

# ========== MAIN INSTALLATION ==========
main() {
    print_banner
    check_privileges
    
    echo -e "${COLOR_BLUE}[*] Starting SNOWCLOUD Tactical MOTD Installation${COLOR_RESET}"
    echo -e "${COLOR_GRAY}────────────────────────────────────────────────────────────${COLOR_RESET}"
    
    # Execute installation steps
    backup_existing
    echo
    
    disable_default_motd
    echo
    
    deploy_tactical_motd
    echo
    
    verify_installation
    echo
    
    display_preview
    echo
    
    # Final instructions
    echo -e "${COLOR_GREEN}════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_GREEN}[✓] SNOWCLOUD Tactical MOTD Installation Complete!${COLOR_RESET}"
    echo -e "${COLOR_GREEN}════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo
    echo -e "${COLOR_YELLOW}[*] Next Steps:${COLOR_RESET}"
    echo -e "  1. ${COLOR_WHITE}Logout and SSH back in to see the new MOTD${COLOR_RESET}"
    echo -e "  2. ${COLOR_WHITE}View the backup in: ${COLOR_CYAN}$BACKUP_DIR${COLOR_RESET}"
    echo -e "  3. ${COLOR_WHITE}Check logs at: ${COLOR_CYAN}$LOG_FILE${COLOR_RESET}"
    echo
    echo -e "${COLOR_MAGENTA}[❄] SNOWCLOUD Arctic Security Suite - Active${COLOR_RESET}"
    echo -e "${COLOR_GRAY}────────────────────────────────────────────────────────────${COLOR_RESET}"
}

# ========== EXECUTE ==========
main "$@" 2>&1 | tee "$LOG_FILE"

exit 0
