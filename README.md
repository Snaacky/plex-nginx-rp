# plex-nginx-rp

Build script and patches for nginx reverse proxy for use with production-grade Plex CDNs.

## Features
* [nginx-quic (1.23.4)](https://hg.nginx.org/nginx-quic)
* [OpenSSL-quic (3.1.0)](https://github.com/quictls/openssl)
* [kTLS support](https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls)
* [QUIC transport protocol and HTTP/3](https://www.nginx.com/blog/introducing-technology-preview-nginx-support-for-quic-http-3/)
* [HTTP2 HPACK encoding support](https://blog.cloudflare.com/hpack-the-silent-killer-feature-of-http-2/)
* [Dynamic TLS Record support](https://blog.cloudflare.com/optimizing-tls-over-tcp-to-reduce-latency/)
* [ngx_security_headers](https://github.com/GetPageSpeed/ngx_security_headers)
* [Cloudflare zlib](https://github.com/cloudflare/zlib)
* [tmpfs](https://en.wikipedia.org/wiki/Tmpfs) cache for Plex images & metadata

## Requirements
* [Debian 11+](https://www.debian.org/) or [Ubuntu 20+](https://ubuntu.com/)
* [Kernel with TLS module enabled (CONFIG_TLS=y)](https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls)
* [gcc (12.2.0)](https://gcc.gnu.org/)
* [mold linker (1.11.0)](https://github.com/rui314/mold)

## Install
```
$ git clone https://github.com/Snaacky/plex-nginx-rp
$ cd plex-nginx-rp
$ chmod +x build-nginx.sh
$ sudo ./build-nginx.sh
```

## Plex Configuration
* Remote Access - Disable
* Network - Relay - Disable
* Network - Custom server access URLs = `https://cdn.plex.your-domain.tld:443`
* Network - Secure connections = Preferred

## /etc/sysctl.conf
Improves congestion and buffer bloat algorithms used and adjusts buffer sizes to allow for consistent 1gbps throughput.
```
# congestion and buffer bloat
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control=bbr

# increasing the default max buffer sizes for 1gbps
net.core.rmem_default=87380
net.core.rmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.core.wmem_default=65536
net.core.wmem_max=16777216
net.ipv4.tcp_wmem=4096 65536 16777216
```
`sysctl -p`

## Credits:
 * Originally based on https://github.com/toomuchio/plex-nginx-reverseproxy
 * Build script based on https://github.com/MatthewVance/nginx-build
 * Current fork based on https://codeberg.org/0x0f/plex-nginx-reverseproxy-cf
