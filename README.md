# XVPN - SSH Proxy Tunnel [![GitHub Stars](https://img.shields.io/github/stars/shohrukhkhon/xvpn.svg?style=social)](https://github.com/shohrukhkhon/xvpn)

Tags: #ssh #vpn #socks5 #redsocks #iptables #tunnel

A simple Bash script to create a secure VPN-like proxy using SSH tunnel and redsocks. Route all your system traffic through a remote server easily and securely.

## Features
- Full system traffic redirection via SSH tunnel
- Use redsocks and iptables for transparent proxying
- Easy configuration and quick start
- No root access required on the remote server

## Installation
```bash
git clone https://github.com/shohrukhkhon/xvpn.git
cd xvpn
sudo chmod +x vpn.sh
```

## Install required components
For Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install -y ssh redsocks iptables
```

## Configuration
1. Copy the example config and edit it:
   ```bash
   cp vpn.conf.example vpn.conf
   nano vpn.conf
   ```

## Usage
Start VPN tunnel:
```bash
sudo ./vpn.sh
```
To stop the VPN tunnel, simply press <kbd>Ctrl</kbd>+<kbd>C</kbd> in the terminal where the script is running.

### Alias for convenience
Add this line to your `~/.bashrc` or `~/.zshrc`:
```bash
alias xvpn='cd /path/to/xvpn && sudo ./vpn.sh'
```
Then reload your shell config:
```bash
source ~/.bashrc  # or source ~/.zshrc
```
Now you can start the VPN tunnel with:
```bash
xvpn
```

## Free SSH Server Access
You can get free SSH server access for use with XVPN at:
[https://www.vpnjantit.com/free-ssh](https://www.vpnjantit.com/free-ssh)

## Requirements
- bash | ssh | redsocks | iptables

## License
MIT

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## Star
If you find this project useful, please give it a star on GitHub!
