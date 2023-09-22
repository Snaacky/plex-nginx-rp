# plex-nginx-rp

Build script and patches for nginx reverse proxy for use with production-grade Plex CDNs.


## Features

```
nginx version: nginx/1.23.4 (15042023-093836-UTC-[debian_nginx-quic+quictls])
built by gcc 12.2.0 (GCC)
built with OpenSSL 3.1.0+quic 14 Mar 2023
TLS SNI support enabled
configure arguments: --build=15042023-093836-UTC-[debian_nginx-quic+quictls] --prefix=/etc/nginx --with-cpu-opt=generic --with-cc-opt='-I/usr/local/include -pipe -m64 -march=native -DTCP_FASTOPEN=23 -falign-functions=32 -O3 -Wno-error=strict-aliasing -Wno-vla-parameter -fstack-protector-strong -fuse-ld=mold --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wno-error=pointer-sign -Wimplicit-fallthrough=0 -fcode-hoisting -Wp,-D_FORTIFY_SOURCE=2 -Wno-deprecated-declarations' --with-ld-opt='-Wl,-E -L/usr/local/lib -ljemalloc -Wl,-z,relro -Wl,-rpath,/usr/local/lib -fuse-ld=mold' --with-openssl=../openssl-3.1.0+quic --with-openssl-opt='-pipe -O3 -fPIC -m64 -march=native -ljemalloc -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wl,-flto=16 no-weak-ssl-ciphers no-ssl3 no-idea no-err no-srp no-psk no-nextprotoneg enable-ktls enable-zlib enable-ec_nistp_64_gcc_128' --with-zlib=../zlib-cloudflare --with-zlib-opt='-pipe -O3 -fPIC -m64 -march=native -ljemalloc -fstack-protector-strong -D_FORTIFY_SOURCE=2 -flto=16' --with-pcre=../pcre-8.45 --with-pcre-opt='-pipe -O3 -fPIC -m64 -march=native -ljemalloc -fstack-protector-strong -D_FORTIFY_SOURCE=2 -flto=16' --with-libatomic=../libatomic_ops-7.8.0 --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --lock-path=/var/run/nginx.lock --modules-path=/usr/lib/nginx/modules --pid-path=/var/run/nginx.pid --sbin-path=/usr/sbin/nginx --http-client-body-temp-path=/var/cache/nginx/client_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --user=nginx --group=nginx --with-file-aio --with-threads --with-http_realip_module --with-http_ssl_module --with-http_v2_hpack_enc --with-http_v2_module --with-http_v3_module --add-module=../ngx_security_headers-0.0.11 --without-http_access_module --without-http_auth_basic_module --without-http_autoindex_module --without-http_browser_module --without-http_charset_module --without-http_empty_gif_module --without-http_fastcgi_module --without-http_geo_module --without-http_grpc_module --without-http_limit_conn_module --without-http_limit_req_module --without-http_memcached_module --without-http_mirror_module --without-http_referer_module --without-http_scgi_module --without-http_split_clients_module --without-http_ssi_module --without-http_upstream_hash_module --without-http_upstream_ip_hash_module --without-http_upstream_least_conn_module --without-http_upstream_random_module --without-http_upstream_zone_module --without-http_userid_module --without-http_uwsgi_module --without-mail_imap_module --without-mail_pop3_module --without-mail_smtp_module --without-poll_module --without-select_module --without-pcre2
```

* nginx-quic 1.23.4 - https://hg.nginx.org/nginx-quic
* openssl-3.1.0+quic - quictls: https://github.com/quictls/openssl
* Kernel TLS - https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls
* QUIC transport protocol and HTTP/3 - https://www.nginx.com/blog/introducing-technology-preview-nginx-support-for-quic-http-3/
* Add HTTP2 HPACK Encoding Support - https://blog.cloudflare.com/hpack-the-silent-killer-feature-of-http-2/
* Add Dynamic TLS Record support - https://blog.cloudflare.com/optimizing-tls-over-tcp-to-reduce-latency/
* ngx_security_headers - https://github.com/GetPageSpeed/ngx_security_headers
* CloudFlare ZLIB - https://github.com/cloudflare/zlib
* Prevents public access to PMS built-in web interface
* tmpfs cache for Plex images & metadata
 
## Requirements
 
Plex:
* Remote Access - Disable
* Network - Relay - Disable
* Network - Custom server access URLs = `https://<your-domain>:443,http://<your-domain>:80`
* Network - Secure connections = Preferred

System: 
* Debian Bullseye x64 (11)
* Kernel with TLS module enabled (CONFIG_TLS=y) - https://www.nginx.com/blog/improving-nginx-performance-with-kernel-tls
* gcc (12.2.0)
* mold linker (1.11.0) - https://github.com/rui314/mold

```
Using built-in specs.
COLLECT_GCC=gcc
COLLECT_LTO_WRAPPER=/usr/local/gcc-12.2.0/libexec/gcc/x86_64-linux-gnu/12.2.0/lto-wrapper
Target: x86_64-linux-gnu
Configured with: ../gcc-12.2.0/configure -v --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu --prefix=/usr/local/gcc-12.2.0 --enable-checking=release --enable-languages=c,c++ --disable-multilib --program-suffix=-12.2 --with-system-zlib --with-cc-opt='-ljemalloc -fuse-ld=mold'
Thread model: posix
Supported LTO compression algorithms: zlib
gcc version 12.2.0 (GCC)
```

Credits:
 * Originally based on https://github.com/toomuchio/plex-nginx-reverseproxy
 * Build script based on https://github.com/MatthewVance/nginx-build
 * Forked based on https://codeberg.org/0x0f/plex-nginx-reverseproxy-cf