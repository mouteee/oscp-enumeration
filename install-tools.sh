#!/bin/bash

################################################################################
#                                                                              #
#           OSCP ENUMERATION TOOLS - INSTALLATION SCRIPT v2.0                  #
#                                                                              #
#   This script installs all tools required by oscp-network-enum-v2.sh         #
#   Supports: Kali Linux, Parrot OS, Ubuntu, Debian                            #
#                                                                              #
#   New in v2.0:                                                               #
#   - Web enumeration tools (whatweb, nikto, gobuster, feroxbuster, wpscan)    #
#   - ADCS tools (certipy)                                                     #
#   - SCCM tools (sccmhunter)                                                  #
#   - AD tools (adidnsdump, ldeep, NetExec/nxc)                                #
#   - Coercion tools (PetitPotam, Coercer)                                     #
#   - Additional database tools (MongoDB)                                      #
#                                                                              #
################################################################################

VERSION="2.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
INSTALLED=0
FAILED=0
SKIPPED=0

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
+===========================================================================+
|                                                                           |
|     ████████╗ ██████╗  ██████╗ ██╗         ██╗███╗   ██╗███████╗████████╗ |
|     ╚══██╔══╝██╔═══██╗██╔═══██╗██║         ██║████╗  ██║██╔════╝╚══██╔══╝ |
|        ██║   ██║   ██║██║   ██║██║         ██║██╔██╗ ██║███████╗   ██║    |
|        ██║   ██║   ██║██║   ██║██║         ██║██║╚██╗██║╚════██║   ██║    |
|        ██║   ╚██████╔╝╚██████╔╝███████╗    ██║██║ ╚████║███████║   ██║    |
|        ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝    ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝    |
|                                                                           |
|              OSCP Network Enumeration Tools Installer v2.0                |
|                  For oscp-network-enum-v2.sh (v5.0)                       |
|                                                                           |
+===========================================================================+
EOF
    echo -e "${NC}"
}

log() {
    local level=$1
    shift
    local message="$@"

    case $level in
        "INFO")
            echo -e "${BLUE}[*]${NC} ${message}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[+]${NC} ${message}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[!]${NC} ${message}"
            ;;
        "ERROR")
            echo -e "${RED}[-]${NC} ${message}"
            ;;
        "SECTION")
            echo ""
            echo -e "${CYAN}=======================================================================${NC}"
            echo -e "${CYAN}${message}${NC}"
            echo -e "${CYAN}=======================================================================${NC}"
            echo ""
            ;;
    esac
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "This script must be run as root"
        log "INFO" "Run: sudo $0"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log "ERROR" "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    log "INFO" "Detected OS: $OS $VERSION"

    case $OS in
        kali|parrot|ubuntu|debian|linuxmint)
            PACKAGE_MANAGER="apt"
            ;;
        fedora|centos|rhel)
            PACKAGE_MANAGER="dnf"
            log "WARNING" "Fedora/CentOS support is limited. Some tools may not be available."
            ;;
        arch|manjaro)
            PACKAGE_MANAGER="pacman"
            log "WARNING" "Arch support is limited. Some tools may need AUR."
            ;;
        *)
            log "ERROR" "Unsupported OS: $OS"
            log "INFO" "Supported: Kali, Parrot, Ubuntu, Debian"
            exit 1
            ;;
    esac
}

install_apt_package() {
    local package=$1
    local name=${2:-$1}

    if dpkg -l | grep -q "^ii  $package "; then
        log "INFO" "$name already installed"
        ((SKIPPED++))
        return 0
    fi

    log "INFO" "Installing $name..."
    if apt-get install -y "$package" > /dev/null 2>&1; then
        log "SUCCESS" "$name installed successfully"
        ((INSTALLED++))
        return 0
    else
        log "ERROR" "Failed to install $name"
        ((FAILED++))
        return 1
    fi
}

install_pip_package() {
    local package=$1
    local name=${2:-$1}

    if pip3 show "$package" > /dev/null 2>&1; then
        log "INFO" "$name already installed (pip)"
        ((SKIPPED++))
        return 0
    fi

    log "INFO" "Installing $name via pip..."
    if pip3 install "$package" --break-system-packages > /dev/null 2>&1 || \
       pip3 install "$package" > /dev/null 2>&1; then
        log "SUCCESS" "$name installed successfully"
        ((INSTALLED++))
        return 0
    else
        log "ERROR" "Failed to install $name"
        ((FAILED++))
        return 1
    fi
}

install_pipx_package() {
    local package=$1
    local name=${2:-$1}

    # Check if pipx is available
    if ! command -v pipx &> /dev/null; then
        log "INFO" "Installing pipx first..."
        apt-get install -y pipx > /dev/null 2>&1 || pip3 install pipx > /dev/null 2>&1
        pipx ensurepath > /dev/null 2>&1
    fi

    if pipx list 2>/dev/null | grep -q "$package"; then
        log "INFO" "$name already installed (pipx)"
        ((SKIPPED++))
        return 0
    fi

    log "INFO" "Installing $name via pipx..."
    if pipx install "$package" > /dev/null 2>&1; then
        log "SUCCESS" "$name installed successfully"
        ((INSTALLED++))
        return 0
    else
        log "ERROR" "Failed to install $name via pipx"
        ((FAILED++))
        return 1
    fi
}

install_go_package() {
    local package=$1
    local binary=$2
    local name=${3:-$2}

    if command -v "$binary" &> /dev/null; then
        log "INFO" "$name already installed"
        ((SKIPPED++))
        return 0
    fi

    if ! command -v go &> /dev/null; then
        log "WARNING" "Go not installed, skipping $name"
        ((SKIPPED++))
        return 1
    fi

    log "INFO" "Installing $name via go..."
    export GOPATH=${GOPATH:-$HOME/go}
    export PATH=$PATH:$GOPATH/bin

    if go install "$package" > /dev/null 2>&1; then
        if [ -f "$GOPATH/bin/$binary" ]; then
            ln -sf "$GOPATH/bin/$binary" /usr/local/bin/ 2>/dev/null
        fi
        log "SUCCESS" "$name installed successfully"
        ((INSTALLED++))
        return 0
    else
        log "ERROR" "Failed to install $name"
        ((FAILED++))
        return 1
    fi
}

################################################################################
# INSTALLATION FUNCTIONS
################################################################################

install_core_tools() {
    log "SECTION" "Installing Core Tools"

    log "INFO" "Updating package lists..."
    apt-get update > /dev/null 2>&1

    install_apt_package "nmap" "Nmap"
    install_apt_package "netcat-openbsd" "Netcat"
    install_apt_package "dnsutils" "DNS Utils (dig)"
    install_apt_package "curl" "cURL"
    install_apt_package "wget" "Wget"
    install_apt_package "git" "Git"
    install_apt_package "tree" "Tree"
    install_apt_package "jq" "jq (JSON processor)"
    install_apt_package "xmlstarlet" "XMLStarlet"
}

install_smb_tools() {
    log "SECTION" "Installing SMB/Windows Tools"

    install_apt_package "smbclient" "SMB Client"
    install_apt_package "smbmap" "SMBMap"
    install_apt_package "enum4linux" "Enum4linux"
    install_apt_package "nbtscan" "NBTScan"
    install_apt_package "cifs-utils" "CIFS Utils"
    install_apt_package "samba-common-bin" "RPC Client"

    # enum4linux-ng (Python version)
    if ! command -v enum4linux-ng &> /dev/null; then
        install_pip_package "enum4linux-ng" "enum4linux-ng"
    else
        log "INFO" "enum4linux-ng already installed"
        ((SKIPPED++))
    fi

    # NetExec (nxc) - successor to CrackMapExec
    if ! command -v nxc &> /dev/null; then
        log "INFO" "Installing NetExec (nxc)..."
        if apt-get install -y netexec > /dev/null 2>&1; then
            log "SUCCESS" "NetExec installed via apt"
            ((INSTALLED++))
        elif pipx install netexec > /dev/null 2>&1; then
            log "SUCCESS" "NetExec installed via pipx"
            ((INSTALLED++))
        else
            log "WARNING" "NetExec installation failed - try: pipx install netexec"
            ((FAILED++))
        fi
    else
        log "INFO" "NetExec (nxc) already installed"
        ((SKIPPED++))
    fi

    # CrackMapExec (fallback)
    if ! command -v nxc &> /dev/null && ! command -v crackmapexec &> /dev/null; then
        log "INFO" "Installing CrackMapExec as fallback..."
        if apt-get install -y crackmapexec > /dev/null 2>&1; then
            log "SUCCESS" "CrackMapExec installed"
            ((INSTALLED++))
        fi
    fi
}

install_snmp_tools() {
    log "SECTION" "Installing SNMP Tools"

    install_apt_package "snmp" "SNMP Tools"
    install_apt_package "snmp-mibs-downloader" "SNMP MIBs"
    install_apt_package "onesixtyone" "Onesixtyone"

    # Enable MIBs
    if [ -f /etc/snmp/snmp.conf ]; then
        sed -i 's/^mibs :$/# mibs :/' /etc/snmp/snmp.conf 2>/dev/null
    fi

    # snmp-check
    if ! command -v snmp-check &> /dev/null; then
        install_apt_package "snmpcheck" "SNMP Check"
    fi
}

install_ldap_tools() {
    log "SECTION" "Installing LDAP Tools"

    install_apt_package "ldap-utils" "LDAP Utils"

    # ldapdomaindump
    install_pip_package "ldapdomaindump" "LDAP Domain Dump"

    # ldeep - NEW
    if ! command -v ldeep &> /dev/null; then
        log "INFO" "Installing ldeep..."
        if pip3 install ldeep --break-system-packages > /dev/null 2>&1 || \
           pip3 install ldeep > /dev/null 2>&1; then
            log "SUCCESS" "ldeep installed"
            ((INSTALLED++))
        else
            log "WARNING" "ldeep installation failed"
            ((FAILED++))
        fi
    else
        log "INFO" "ldeep already installed"
        ((SKIPPED++))
    fi
}

install_database_tools() {
    log "SECTION" "Installing Database Tools"

    install_apt_package "default-mysql-client" "MySQL Client"
    install_apt_package "postgresql-client" "PostgreSQL Client"
    install_apt_package "redis-tools" "Redis Tools"

    # MongoDB client - NEW
    if ! command -v mongo &> /dev/null && ! command -v mongosh &> /dev/null; then
        log "INFO" "Installing MongoDB client..."
        if apt-get install -y mongodb-clients > /dev/null 2>&1; then
            log "SUCCESS" "MongoDB client installed"
            ((INSTALLED++))
        else
            # Try mongosh
            if apt-get install -y mongodb-mongosh > /dev/null 2>&1; then
                log "SUCCESS" "MongoDB Shell installed"
                ((INSTALLED++))
            else
                log "WARNING" "MongoDB client installation failed"
                ((FAILED++))
            fi
        fi
    else
        log "INFO" "MongoDB client already installed"
        ((SKIPPED++))
    fi

    # SQLMap
    install_apt_package "sqlmap" "SQLMap"
}

install_web_tools() {
    log "SECTION" "Installing Web Enumeration Tools - NEW"

    # whatweb
    install_apt_package "whatweb" "WhatWeb"

    # nikto
    install_apt_package "nikto" "Nikto"

    # gobuster
    if ! command -v gobuster &> /dev/null; then
        log "INFO" "Installing Gobuster..."
        if apt-get install -y gobuster > /dev/null 2>&1; then
            log "SUCCESS" "Gobuster installed"
            ((INSTALLED++))
        else
            install_go_package "github.com/OJ/gobuster/v3@latest" "gobuster" "Gobuster"
        fi
    else
        log "INFO" "Gobuster already installed"
        ((SKIPPED++))
    fi

    # feroxbuster
    if ! command -v feroxbuster &> /dev/null; then
        log "INFO" "Installing Feroxbuster..."
        if apt-get install -y feroxbuster > /dev/null 2>&1; then
            log "SUCCESS" "Feroxbuster installed"
            ((INSTALLED++))
        else
            # Download binary
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                FEROX_URL="https://github.com/epi052/feroxbuster/releases/latest/download/x86_64-linux-feroxbuster.tar.gz"
                wget -q "$FEROX_URL" -O /tmp/feroxbuster.tar.gz 2>/dev/null
                tar -xzf /tmp/feroxbuster.tar.gz -C /usr/local/bin/ 2>/dev/null
                chmod +x /usr/local/bin/feroxbuster 2>/dev/null
                rm -f /tmp/feroxbuster.tar.gz
                log "SUCCESS" "Feroxbuster installed from GitHub"
                ((INSTALLED++))
            fi
        fi
    else
        log "INFO" "Feroxbuster already installed"
        ((SKIPPED++))
    fi

    # ffuf
    if ! command -v ffuf &> /dev/null; then
        log "INFO" "Installing ffuf..."
        if apt-get install -y ffuf > /dev/null 2>&1; then
            log "SUCCESS" "ffuf installed"
            ((INSTALLED++))
        else
            install_go_package "github.com/ffuf/ffuf/v2@latest" "ffuf" "ffuf"
        fi
    else
        log "INFO" "ffuf already installed"
        ((SKIPPED++))
    fi

    # wpscan
    if ! command -v wpscan &> /dev/null; then
        log "INFO" "Installing WPScan..."
        if apt-get install -y wpscan > /dev/null 2>&1; then
            log "SUCCESS" "WPScan installed"
            ((INSTALLED++))
        elif gem install wpscan > /dev/null 2>&1; then
            log "SUCCESS" "WPScan installed via gem"
            ((INSTALLED++))
        else
            log "WARNING" "WPScan installation failed"
            ((FAILED++))
        fi
    else
        log "INFO" "WPScan already installed"
        ((SKIPPED++))
    fi

    # dirb wordlists
    install_apt_package "dirb" "Dirb (wordlists)"
}

install_mail_tools() {
    log "SECTION" "Installing Mail Tools"

    install_apt_package "swaks" "SWAKS (SMTP)"

    # smtp-user-enum
    if ! command -v smtp-user-enum &> /dev/null; then
        log "INFO" "Installing smtp-user-enum..."
        if apt-get install -y smtp-user-enum > /dev/null 2>&1; then
            log "SUCCESS" "smtp-user-enum installed"
            ((INSTALLED++))
        fi
    else
        log "INFO" "smtp-user-enum already installed"
        ((SKIPPED++))
    fi
}

install_nfs_tools() {
    log "SECTION" "Installing NFS Tools"

    install_apt_package "nfs-common" "NFS Common"
    install_apt_package "rpcbind" "RPC Bind"
}

install_rdp_tools() {
    log "SECTION" "Installing RDP Tools"

    install_apt_package "freerdp2-x11" "FreeRDP"
    install_apt_package "rdesktop" "RDesktop"
}

install_vnc_tools() {
    log "SECTION" "Installing VNC Tools"

    install_apt_package "tigervnc-viewer" "TigerVNC Viewer"
}

install_impacket() {
    log "SECTION" "Installing Impacket Tools"

    if command -v impacket-GetNPUsers &> /dev/null; then
        log "INFO" "Impacket already installed"
        ((SKIPPED++))
        return
    fi

    # Try apt first (Kali has impacket-scripts)
    if apt-get install -y impacket-scripts > /dev/null 2>&1; then
        log "SUCCESS" "Impacket installed via apt"
        ((INSTALLED++))
    else
        log "INFO" "Installing Impacket via pip..."
        if pip3 install impacket --break-system-packages > /dev/null 2>&1 || \
           pip3 install impacket > /dev/null 2>&1; then
            log "SUCCESS" "Impacket installed via pip"
            ((INSTALLED++))
        else
            log "ERROR" "Failed to install Impacket"
            ((FAILED++))
        fi
    fi
}

install_ad_tools() {
    log "SECTION" "Installing Active Directory Tools"

    # BloodHound Python collector
    install_pip_package "bloodhound" "BloodHound Python"

    # Kerbrute
    if ! command -v kerbrute &> /dev/null; then
        log "INFO" "Installing Kerbrute..."
        ARCH=$(uname -m)
        case $ARCH in
            x86_64)
                KERBRUTE_URL="https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_amd64"
                ;;
            aarch64)
                KERBRUTE_URL="https://github.com/ropnop/kerbrute/releases/latest/download/kerbrute_linux_arm64"
                ;;
            *)
                KERBRUTE_URL=""
                ;;
        esac

        if [ -n "$KERBRUTE_URL" ]; then
            if wget -q "$KERBRUTE_URL" -O /usr/local/bin/kerbrute 2>/dev/null; then
                chmod +x /usr/local/bin/kerbrute
                log "SUCCESS" "Kerbrute installed"
                ((INSTALLED++))
            else
                log "WARNING" "Failed to download Kerbrute"
                ((FAILED++))
            fi
        fi
    else
        log "INFO" "Kerbrute already installed"
        ((SKIPPED++))
    fi

    # Evil-WinRM
    if ! command -v evil-winrm &> /dev/null; then
        log "INFO" "Installing Evil-WinRM..."
        if apt-get install -y evil-winrm > /dev/null 2>&1; then
            log "SUCCESS" "Evil-WinRM installed via apt"
            ((INSTALLED++))
        elif gem install evil-winrm > /dev/null 2>&1; then
            log "SUCCESS" "Evil-WinRM installed via gem"
            ((INSTALLED++))
        else
            log "WARNING" "Failed to install Evil-WinRM"
            ((FAILED++))
        fi
    else
        log "INFO" "Evil-WinRM already installed"
        ((SKIPPED++))
    fi

    # adidnsdump - NEW
    if ! command -v adidnsdump &> /dev/null; then
        log "INFO" "Installing adidnsdump..."
        if pip3 install adidnsdump --break-system-packages > /dev/null 2>&1 || \
           pip3 install adidnsdump > /dev/null 2>&1; then
            log "SUCCESS" "adidnsdump installed"
            ((INSTALLED++))
        else
            log "WARNING" "adidnsdump installation failed"
            ((FAILED++))
        fi
    else
        log "INFO" "adidnsdump already installed"
        ((SKIPPED++))
    fi
}

install_adcs_tools() {
    log "SECTION" "Installing ADCS (Certificate Services) Tools - NEW"

    # certipy
    if ! command -v certipy &> /dev/null; then
        log "INFO" "Installing Certipy..."
        if pip3 install certipy-ad --break-system-packages > /dev/null 2>&1 || \
           pip3 install certipy-ad > /dev/null 2>&1; then
            log "SUCCESS" "Certipy installed"
            ((INSTALLED++))
        elif pipx install certipy-ad > /dev/null 2>&1; then
            log "SUCCESS" "Certipy installed via pipx"
            ((INSTALLED++))
        else
            log "WARNING" "Certipy installation failed - try: pipx install certipy-ad"
            ((FAILED++))
        fi
    else
        log "INFO" "Certipy already installed"
        ((SKIPPED++))
    fi

    # PKINITtools
    if ! command -v gettgtpkinit.py &> /dev/null; then
        log "INFO" "Installing PKINITtools..."
        if pip3 install PKINITtools --break-system-packages > /dev/null 2>&1 || \
           pip3 install PKINITtools > /dev/null 2>&1; then
            log "SUCCESS" "PKINITtools installed"
            ((INSTALLED++))
        else
            log "WARNING" "PKINITtools installation failed"
            ((FAILED++))
        fi
    else
        log "INFO" "PKINITtools already installed"
        ((SKIPPED++))
    fi
}

install_sccm_tools() {
    log "SECTION" "Installing SCCM Tools - NEW"

    # sccmhunter
    if ! command -v sccmhunter &> /dev/null && ! command -v sccmhunter.py &> /dev/null; then
        log "INFO" "Installing SCCMHunter..."

        # Clone and install
        if [ ! -d /opt/sccmhunter ]; then
            git clone --depth 1 https://github.com/garrettfoster13/sccmhunter.git /opt/sccmhunter > /dev/null 2>&1
        fi

        if [ -d /opt/sccmhunter ]; then
            cd /opt/sccmhunter
            pip3 install -r requirements.txt --break-system-packages > /dev/null 2>&1 || \
            pip3 install -r requirements.txt > /dev/null 2>&1
            ln -sf /opt/sccmhunter/sccmhunter.py /usr/local/bin/sccmhunter 2>/dev/null
            chmod +x /opt/sccmhunter/sccmhunter.py 2>/dev/null
            cd - > /dev/null
            log "SUCCESS" "SCCMHunter installed"
            ((INSTALLED++))
        else
            log "WARNING" "SCCMHunter installation failed"
            ((FAILED++))
        fi
    else
        log "INFO" "SCCMHunter already installed"
        ((SKIPPED++))
    fi
}

install_coercion_tools() {
    log "SECTION" "Installing Coercion Tools - NEW"

    # PetitPotam
    if ! command -v petitpotam.py &> /dev/null && [ ! -f /opt/PetitPotam/PetitPotam.py ]; then
        log "INFO" "Installing PetitPotam..."
        git clone --depth 1 https://github.com/topotam/PetitPotam.git /opt/PetitPotam > /dev/null 2>&1
        if [ -f /opt/PetitPotam/PetitPotam.py ]; then
            ln -sf /opt/PetitPotam/PetitPotam.py /usr/local/bin/petitpotam.py 2>/dev/null
            chmod +x /opt/PetitPotam/PetitPotam.py 2>/dev/null
            log "SUCCESS" "PetitPotam installed"
            ((INSTALLED++))
        fi
    else
        log "INFO" "PetitPotam already installed"
        ((SKIPPED++))
    fi

    # Coercer
    if ! command -v coercer &> /dev/null; then
        log "INFO" "Installing Coercer..."
        if pip3 install coercer --break-system-packages > /dev/null 2>&1 || \
           pip3 install coercer > /dev/null 2>&1; then
            log "SUCCESS" "Coercer installed"
            ((INSTALLED++))
        else
            log "WARNING" "Coercer installation failed"
            ((FAILED++))
        fi
    else
        log "INFO" "Coercer already installed"
        ((SKIPPED++))
    fi

    # PrinterBug / dementor
    if [ ! -f /opt/dementor/dementor.py ]; then
        log "INFO" "Installing dementor (PrinterBug)..."
        mkdir -p /opt/dementor
        wget -q https://raw.githubusercontent.com/NotMedic/NetNTLMtoSilverTicket/master/dementor.py \
            -O /opt/dementor/dementor.py 2>/dev/null
        if [ -f /opt/dementor/dementor.py ]; then
            ln -sf /opt/dementor/dementor.py /usr/local/bin/dementor.py 2>/dev/null
            chmod +x /opt/dementor/dementor.py 2>/dev/null
            log "SUCCESS" "dementor installed"
            ((INSTALLED++))
        fi
    else
        log "INFO" "dementor already installed"
        ((SKIPPED++))
    fi

    # Responder
    if ! command -v responder &> /dev/null; then
        log "INFO" "Installing Responder..."
        if apt-get install -y responder > /dev/null 2>&1; then
            log "SUCCESS" "Responder installed"
            ((INSTALLED++))
        else
            # Clone manually
            git clone --depth 1 https://github.com/lgandx/Responder.git /opt/Responder > /dev/null 2>&1
            if [ -f /opt/Responder/Responder.py ]; then
                ln -sf /opt/Responder/Responder.py /usr/local/bin/responder 2>/dev/null
                chmod +x /opt/Responder/Responder.py 2>/dev/null
                log "SUCCESS" "Responder installed from GitHub"
                ((INSTALLED++))
            fi
        fi
    else
        log "INFO" "Responder already installed"
        ((SKIPPED++))
    fi

    # ntlmrelayx (part of impacket)
    log "INFO" "ntlmrelayx is part of Impacket (already handled)"
}

install_password_tools() {
    log "SECTION" "Installing Password Attack Tools"

    install_apt_package "hydra" "Hydra"
    install_apt_package "medusa" "Medusa"
    install_apt_package "hashcat" "Hashcat"
    install_apt_package "john" "John the Ripper"
    install_apt_package "hashid" "HashID"
}

install_exploit_tools() {
    log "SECTION" "Installing Exploit Tools"

    # Searchsploit / ExploitDB
    if ! command -v searchsploit &> /dev/null; then
        log "INFO" "Installing ExploitDB..."
        if apt-get install -y exploitdb > /dev/null 2>&1; then
            log "SUCCESS" "ExploitDB installed"
            ((INSTALLED++))
        else
            if [ ! -d /opt/exploitdb ]; then
                git clone --depth 1 https://gitlab.com/exploit-database/exploitdb.git /opt/exploitdb > /dev/null 2>&1
                ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit
                log "SUCCESS" "ExploitDB installed manually"
                ((INSTALLED++))
            fi
        fi
    else
        log "INFO" "ExploitDB already installed"
        ((SKIPPED++))
    fi

    if command -v searchsploit &> /dev/null; then
        log "INFO" "Run 'searchsploit -u' manually to update database"
    fi
}

install_scanning_tools() {
    log "SECTION" "Installing Additional Scanning Tools"

    # Masscan
    install_apt_package "masscan" "Masscan"

    # Rustscan
    if ! command -v rustscan &> /dev/null; then
        log "INFO" "Installing Rustscan..."
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            RUSTSCAN_URL=$(curl -s https://api.github.com/repos/RustScan/RustScan/releases/latest | \
                grep "browser_download_url.*amd64.deb" | cut -d'"' -f4 | head -1)
            if [ -n "$RUSTSCAN_URL" ]; then
                wget -q "$RUSTSCAN_URL" -O /tmp/rustscan.deb 2>/dev/null
                if dpkg -i /tmp/rustscan.deb > /dev/null 2>&1; then
                    log "SUCCESS" "Rustscan installed"
                    ((INSTALLED++))
                else
                    apt-get install -f -y > /dev/null 2>&1
                fi
                rm -f /tmp/rustscan.deb
            fi
        fi
    else
        log "INFO" "Rustscan already installed"
        ((SKIPPED++))
    fi

    # SSH Audit
    install_pip_package "ssh-audit" "SSH Audit"
}

install_misc_tools() {
    log "SECTION" "Installing Miscellaneous Tools"

    install_apt_package "ftp" "FTP Client"
    install_apt_package "tftp" "TFTP Client"
    install_apt_package "telnet" "Telnet"
    install_apt_package "whois" "Whois"
    install_apt_package "ipmitool" "IPMI Tool"
    install_apt_package "rsync" "Rsync"

    # Python dependencies
    install_apt_package "python3-pip" "Python3 Pip"
    install_apt_package "python3-venv" "Python3 Venv"
    install_apt_package "pipx" "Pipx"

    # Ensure pipx path
    if command -v pipx &> /dev/null; then
        pipx ensurepath > /dev/null 2>&1
    fi

    # Go (for some tools)
    if ! command -v go &> /dev/null; then
        log "INFO" "Installing Go..."
        if apt-get install -y golang > /dev/null 2>&1; then
            log "SUCCESS" "Go installed"
            ((INSTALLED++))
            echo 'export GOPATH=$HOME/go' >> /etc/profile.d/go.sh
            echo 'export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin' >> /etc/profile.d/go.sh
        fi
    else
        log "INFO" "Go already installed"
        ((SKIPPED++))
    fi

    # Ruby (for evil-winrm, wpscan)
    install_apt_package "ruby" "Ruby"
    install_apt_package "ruby-dev" "Ruby Dev"
}

install_wordlists() {
    log "SECTION" "Installing Wordlists"

    # SecLists
    if [ ! -d /usr/share/seclists ]; then
        log "INFO" "Installing SecLists..."
        if apt-get install -y seclists > /dev/null 2>&1; then
            log "SUCCESS" "SecLists installed"
            ((INSTALLED++))
        else
            log "INFO" "Cloning SecLists from GitHub..."
            git clone --depth 1 https://github.com/danielmiessler/SecLists.git /usr/share/seclists > /dev/null 2>&1
            log "SUCCESS" "SecLists cloned"
            ((INSTALLED++))
        fi
    else
        log "INFO" "SecLists already installed"
        ((SKIPPED++))
    fi

    # Rockyou
    if [ ! -f /usr/share/wordlists/rockyou.txt ]; then
        if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
            log "INFO" "Extracting rockyou.txt..."
            gunzip -k /usr/share/wordlists/rockyou.txt.gz 2>/dev/null
            log "SUCCESS" "rockyou.txt extracted"
        fi
    else
        log "INFO" "rockyou.txt already available"
        ((SKIPPED++))
    fi

    mkdir -p /usr/share/wordlists 2>/dev/null
}

create_symlinks() {
    log "SECTION" "Creating Symlinks"

    # Ensure /usr/local/bin is in PATH
    if ! echo "$PATH" | grep -q "/usr/local/bin"; then
        export PATH=$PATH:/usr/local/bin
    fi

    log "INFO" "Symlinks created"
}

verify_installation() {
    log "SECTION" "Verifying Installation"

    local tools=(
        "nmap:Nmap"
        "nc:Netcat"
        "dig:DNS Utils"
        "smbclient:SMB Client"
        "enum4linux:Enum4linux"
        "smbmap:SMBMap"
        "snmpwalk:SNMP Walk"
        "ldapsearch:LDAP Search"
        "showmount:Showmount"
        "rpcclient:RPC Client"
        "searchsploit:SearchSploit"
        "impacket-GetNPUsers:Impacket"
        "nbtscan:NBTScan"
        "hydra:Hydra"
        "masscan:Masscan"
        "redis-cli:Redis CLI"
        "mysql:MySQL Client"
        "psql:PostgreSQL Client"
        # New tools
        "nxc:NetExec"
        "whatweb:WhatWeb"
        "nikto:Nikto"
        "gobuster:Gobuster"
        "ffuf:ffuf"
        "certipy:Certipy (ADCS)"
        "kerbrute:Kerbrute"
        "evil-winrm:Evil-WinRM"
        "bloodhound-python:BloodHound"
        "adidnsdump:adidnsdump"
        "ldeep:ldeep"
        "responder:Responder"
        "coercer:Coercer"
    )

    echo ""
    echo "Tool Verification Results:"
    echo "=========================="

    local available=0
    local missing=0

    for tool_entry in "${tools[@]}"; do
        tool="${tool_entry%%:*}"
        name="${tool_entry##*:}"

        if command -v "$tool" &> /dev/null; then
            echo -e "  ${GREEN}[OK]${NC} $name ($tool)"
            ((available++))
        else
            echo -e "  ${RED}[--]${NC} $name ($tool)"
            ((missing++))
        fi
    done

    echo ""
    echo "=========================="
    echo -e "Available: ${GREEN}$available${NC}"
    echo -e "Missing:   ${RED}$missing${NC}"
    echo ""
}

print_summary() {
    log "SECTION" "Installation Summary"

    echo ""
    echo "======================================================================="
    echo ""
    echo -e "  ${GREEN}Installed:${NC}  $INSTALLED packages"
    echo -e "  ${YELLOW}Skipped:${NC}    $SKIPPED packages (already installed)"
    echo -e "  ${RED}Failed:${NC}     $FAILED packages"
    echo ""
    echo "======================================================================="
    echo ""

    if [ $FAILED -gt 0 ]; then
        log "WARNING" "Some packages failed to install. Check the output above."
        log "INFO" "You may need to install them manually."
    else
        log "SUCCESS" "All tools installed successfully!"
    fi

    echo ""
    echo "Next Steps:"
    echo "  1. Run the enumeration script: sudo ./oscp-network-enum-v2.sh <target>"
    echo "  2. Update searchsploit: searchsploit -u"
    echo "  3. Source your profile: source /etc/profile"
    echo ""
    echo "Quick Test:"
    echo "  sudo ./oscp-network-enum-v2.sh -h"
    echo ""
}

################################################################################
# MAIN
################################################################################

main() {
    print_banner

    check_root
    detect_os

    echo ""
    log "INFO" "This script will install all tools required for OSCP enumeration v5.0."
    log "INFO" "Includes: Web tools, ADCS tools, SCCM tools, Coercion tools, and more."
    echo ""
    read -p "Continue with installation? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Installation cancelled."
        exit 0
    fi

    echo ""

    # Install tools by category
    install_core_tools
    install_smb_tools
    install_snmp_tools
    install_ldap_tools
    install_database_tools
    install_web_tools          # NEW
    install_mail_tools
    install_nfs_tools
    install_rdp_tools
    install_vnc_tools
    install_impacket
    install_ad_tools
    install_adcs_tools         # NEW
    install_sccm_tools         # NEW
    install_coercion_tools     # NEW
    install_password_tools
    install_exploit_tools
    install_scanning_tools
    install_misc_tools
    install_wordlists
    create_symlinks

    verify_installation
    print_summary
}

# Run main function
main "$@"
