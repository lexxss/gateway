# gateway

Ubuntu 16.04 - Install and Setup 

* StrongSwan (VPN IKEv2 Server)
* Dante (SOCKS Proxy)
* Squid (HTTP\S Proxy)

## Usage

Run the following to setup gateway:

```
curl -s -L https://github.com/lexxss/gateway/raw/master/setupAllFromGitHub.sh | sudo bash -s user_name user_pass strongSwanIP squidPort danteInterface dantePort
```
