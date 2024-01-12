# gnosissh-deb
Clear text OpenSSH login attempt tools for Debian-based Linux distributions. 

## Features

- **Root Check**: Ensures the script is run with root privileges.
- **Installs Necessary Packages**: Modifies `sources.list` for `main src-deb` repos. Installs `dpkg-dev` and OpenSSH build dependencies.
- **Modifies OpenSSH Source**: Downloads and modifies the OpenSSH server source for additional logging capabilities.
- **Builds and Installs OpenSSH**: Compiles and installs the modified OpenSSH server package.
- **Reverts Respo File**: After install, `sources.list` is reverted to previous version.

## Usage and Examples

Examples from Ubuntu 22.04.3 LTS

Make sure the script is executable:

```shell
$ chmod +x build_clear_text_openssh.sh
```

Run the script using sudo:

```shell
$ sudo ./build_clear_text_openssh.sh
```

Example usage:

```shell
$ sudo ./build_clear_text_openssh.sh
[sudo] password for user: 
[19:34:29] Enable main src-deb repo
[19:34:29] Update package information
[19:34:41] Install deb package development files
[19:34:52] Install OpenSSH build dependencies
[19:36:56] Download OpenSSH source files
[19:36:57] Modify auth-passwd.c file
[19:36:57] Build OpenSSH deb packages (takes a while)
[19:47:59] Install OpenSSH client
[19:48:01] Install OpenSSH sftp server
[19:48:02] Install OpenSSH server
[19:48:05] Change MaxAuthTries setting
[19:48:05] Restart OpenSSH daemon
[19:48:06] Add rsyslog.d conf for clear-text-pass
[19:48:06] Create /var/log/clear_text_pass
[19:48:06] Restart rsyslog daemon
[19:48:06] Done!
[00:13:37] Total run time
```

Log example with redacted ip addresses:

```shell
==> /var/log/clear_text_pass <==
Jan 11 20:00:50 linux sshd[46122]: clear_text_pass: Username: root Password: !QAZxsw2 IP: 180.xxx.xxx.xxx
Jan 11 20:00:55 linux sshd[46122]: clear_text_pass: Username: root Password: 123456aa IP: 180.xxx.xxx.xxx
Jan 11 20:00:57 linux sshd[46124]: clear_text_pass: Username: root Password: huawei@2018 IP: 54.xxx.xxx.xxx
Jan 11 20:01:00 linux sshd[46122]: clear_text_pass: Username: root Password: passwd IP: 180.xxx.xxx.xxx
Jan 11 20:01:19 linux sshd[46126]: clear_text_pass: Username: root Password: p@55word123456789 IP: 60.xxx.xxx.xxx
```
