# gateway

Ubuntu 16.04 - Install and setup gateway

* StrongSwan (VPN IKEv2 Server)
* Dante (SOCKS Proxy)
* Squid (HTTP/S Proxy)

## Usage

Run the following to setup gateway:

```
sudo bash -c "bash <(curl -s -L https://github.com/lexxss/gateway/raw/master/setupAllFromGitHub.sh)\
user_name user_pass strongSwanIP squidPort danteInterface dantePort"
```
