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
* Prevents public access to PMS built-in web interface
* [tmpfs](https://en.wikipedia.org/wiki/Tmpfs) cache for Plex images & metadata

## Requirements
* [Debian 11+](https://www.debian.org/) or [Ubuntu 20+](https://ubuntu.com/)
* [Kernel with TLS module enabled (CONFIG_TLS=y)](https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls)
* [gcc (12.2.0)](https://gcc.gnu.org/)
* [mold linker (1.11.0)](https://github.com/rui314/mold)

## Plex Configuration
* Remote Access - Disable
* Network - Relay - Disable
* Network - Custom server access URLs = `https://cdn.plex.your-domain.tld:443`
* Network - Secure connections = Preferred

## Credits:
 * Originally based on https://github.com/toomuchio/plex-nginx-reverseproxy
 * Build script based on https://github.com/MatthewVance/nginx-build
 * Current fork based on https://codeberg.org/0x0f/plex-nginx-reverseproxy-cf
