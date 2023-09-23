# plex-nginx-rp

Build script and patches for nginx reverse proxy for use with production-grade Plex CDNs.

## Features
* [nginx (1.25.0)](https://hg.nginx.org/nginx/rev/release-1.25.0)
* [OpenSSL-quic (3.1.0)](https://github.com/quictls/openssl)
* [kTLS support](https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls)
* [QUIC transport protocol and HTTP/3](https://www.nginx.com/blog/introducing-technology-preview-nginx-support-for-quic-http-3/)
* [HTTP2 HPACK encoding support](https://blog.cloudflare.com/hpack-the-silent-killer-feature-of-http-2/)
* [Dynamic TLS Record support](https://blog.cloudflare.com/optimizing-tls-over-tcp-to-reduce-latency/)
* [ngx_security_headers](https://github.com/GetPageSpeed/ngx_security_headers)
* [Cloudflare zlib](https://github.com/cloudflare/zlib)
* [tmpfs](https://en.wikipedia.org/wiki/Tmpfs) cache for Plex images & metadata

## Requirements
* [Ubuntu 22.04+](https://ubuntu.com/)
* [Kernel with TLS module enabled (CONFIG_TLS=y)](https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls)
* [gcc (12.2.0)](https://gcc.gnu.org/)
* [mold linker (1.11.0)](https://github.com/rui314/mold)

## Build nginx
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

## GeoDNS

You will need [AWS Route 53](https://aws.amazon.com/route53/) for GeoDNS which costs me less than $0.70 USD per month.

I have a dedicated server hosting the Plex daemon in Germany and 3x reverse proxy VPSes spread across the world in New York City, New York, Frankfurt, Germany, and Bangalore, India each running instances of this repo. My dedicated server and reverse proxy VPS hosting providers peer directly together so they get good throughput between servers. 

The idea is that your reverse proxies will have better peering to your users than the backend server so by using GeoDNS we route the user traffic to the more optimal reverse proxy server first which then proxies the request at a higher throughput to the backend server than would normally be achieved by just directly connecting to the server thereby preventing buffering.

### Steps:
* Create a NS and point it at plex.domain.tld.
* On Route53, create the following records:
  * 1x A record per reverse proxy. I have 3x reverse proxies so for me that's:
    * name: na.plex.domain.tld, value: \<New York City VPS IP>
    * name: eu.plex.domain.tld, value: \<Frankfurt VPS IP>
    * name: in.plex.domain.tld, value: \<Bangalore VPS IP>
  * 1x CNAME for each continent you wish to route. For me that looks like:
    * name: cdn, value: eu.plex.domain.tld, routing policy: Geolocation, location: Africa
    * name: cdn, value: eu.plex.domain.tld, routing policy: Geolocation, location: Europe
    * name: cdn, value: in.plex.domain.tld, routing policy: Geolocation, location: Asia
    * name: cdn, value: na.plex.domain.tld, routing policy: Geolocation, location: North America
    * name: cdn, value: in.plex.domain.tld, routing policy: Geolocation, location: Oceania
    * name: cdn, value: na.plex.domain.tld, routing policy: Geolocation, location: South America

## Credits:
 * Originally based on https://github.com/toomuchio/plex-nginx-reverseproxy
 * Build script based on https://github.com/MatthewVance/nginx-build
 * Current fork based on https://codeberg.org/0x0f/plex-nginx-reverseproxy-cf
