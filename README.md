# XVPN - SSH Proxy Tunnel [![GitHub Stars](https://img.shields.io/github/stars/shohrukhkhon/xvpn.svg?style=social)](https://github.com/shohrukhkhon/xvpn)

Tags: #ssh #vpn #socks5 #redsocks #iptables #tunnel

A secure VPN-like proxy solution using SSH tunnel and redsocks. Route all system traffic through a remote server with automatic configuration.

## Features
- Full system traffic redirection via SSH tunnel
- Automatic dependency installation
- Transparent proxying with redsocks + iptables
- One-time setup with persistent alias
- Automatic cleanup on termination

## Installation
```bash
git clone https://github.com/shohrukhkhon/xvpn.git
cd xvpn
sudo chmod +x vpn.sh
```

## Quick Start
#### Initial Setup

```bash
sudo ./vpn.sh setup
```
This will:

1) Install required dependencies
2) Create config from example file
3) Add xvpn alias to your shell
4) Update current shell session

#### Configuration

Edit the generated config file:

```bash
nano vpn.conf
```

Set your SSH server details:

```ini
HOST="your.server.com"
PORT="22"
USER="username"
PASSWORD="yourpassword"
```

## Usage

Start VPN connection:

```bash
xvpn start
```

Stop VPN connection:

```bash
xvpn stop
```

## System Commands

| Command      | Description                         |
| :----------- | :---------------------------------- |
| `xvpn start` | Establish VPN connection            |
| `xvpn stop`  | Terminate VPN connection            |
| `xvpn setup` | First-time configuration (run once) |

## Recommended SSH Providers

For free SSH server access: \
https://www.vpnjantit.com/free-ssh

## License

MIT

## Contributing

Contributions welcome! Please:

1) Open an issue to discuss changes
2) Fork the repository
3) Submit a pull request

## Support

Show your support by giving a ⭐ on GitHub!