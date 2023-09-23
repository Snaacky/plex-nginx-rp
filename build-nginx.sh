#!/usr/bin/env bash
# Run as root or with sudo

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  exit 1
fi

set -e

# Set names of latest versions of each package
VERSION_LIBATOMIC=7.8.0
VERSION_NGINX=1.25.0 # 1.25.0 is the last version with HTTP2 HPACK support
VERSION_PCRE=pcre-8.45
VERSION_SECURITY_HEADERS=0.0.11
VERSION_OPENSSL=openssl-3.1.0+quic
VERSION_MOLD=2.1.0 # must be at least 1.11.0 to build properly

# Set URLs to the source directories
SOURCE_JEMALLOC=https://github.com/jemalloc/jemalloc
SOURCE_LIBATOMIC=https://github.com/ivmai/libatomic_ops/archive/v
SOURCE_NGINX=https://hg.nginx.org/nginx
SOURCE_OPENSSL=https://github.com/quictls/openssl
SOURCE_PCRE=https://ftp.exim.org/pub/pcre/
SOURCE_SECURITY_HEADERS=https://github.com/GetPageSpeed/ngx_security_headers/archive/
SOURCE_ZLIB_CLOUDFLARE=https://github.com/cloudflare/zlib

# Set where OpenSSL and NGINX will be built
SPATH=$(pwd)
BPATH=$SPATH/build
TIME=$(date +%d%m%Y-%H%M%S-%Z)

# Clean out any files from previous runs of this script
rm -rf "$BPATH"
mkdir "$BPATH"
rm -rf "$SPATH/packages"
mkdir "$SPATH/packages"

## Move tmp within build directory
mkdir "$BPATH/tmp"
export TMPDIR="$BPATH/tmp"

# Ensure the required software to compile nginx is installed
apt-get update && apt-get -y install \
  autoconf \
  automake \
  binutils \
  build-essential \
  checkinstall \
  cmake \
  curl \
  gcc-12 \
  git \
  libtool \
  mercurial \
  wget

# Switch default gcc over to gcc-12 so we can compile.
# NOTE: You can easily undo this yourself if it bothers you.
sudo rm /usr/bin/gcc
sudo ln -rs /usr/bin/gcc-12 /usr/bin/gcc

# Install mold linker
wget https://github.com/rui314/mold/releases/download/v$VERSION_MOLD/mold-$VERSION_MOLD-$(uname -m)-linux.tar.gz -O $BPATH/mold-$VERSION_MOLD-$(uname -m)-linux.tar.gz
sudo tar -C /usr/local --strip-components=1 -xzf $BPATH/mold-$VERSION_MOLD-$(uname -m)-linux.tar.gz

# Curl the tarballs from their respective repositories.
curl -L "${SOURCE_LIBATOMIC}${VERSION_LIBATOMIC}.tar.gz" -o "${BPATH}/libatomic.tar.gz"
curl -L "${SOURCE_PCRE}${VERSION_PCRE}.tar.gz" -o "${BPATH}/pcre.tar.gz"
curl -L "${SOURCE_SECURITY_HEADERS}${VERSION_SECURITY_HEADERS}.tar.gz" -o "${BPATH}/security-headers.tar.gz"

cd "$BPATH"
git clone $SOURCE_JEMALLOC
git clone --branch develop $SOURCE_ZLIB_CLOUDFLARE zlib-cloudflare
git clone --recursive --branch openssl-3.1.0+quic $SOURCE_OPENSSL $VERSION_OPENSSL
hg clone -r release-$VERSION_NGINX $SOURCE_NGINX

# Extract all of the tarballs in the cwd.
cd "$BPATH"
for ARCHIVE in ./*.tar.gz; do
  tar xzf "$ARCHIVE"
done

# Clean up the no longer needed tarballs.
rm -rf "$BPATH"/*.tar.*

# Create the default nginx cache folders.
if [ ! -d "/var/cache/nginx/" ]; then
  mkdir -p \
    /var/cache/nginx/client_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/ram_cache \
    /var/cache/nginx/scgi_temp \
    /var/cache/nginx/uwsgi_temp
fi

# Create the default folders virtual host folders.
if [[ ! -d /etc/nginx/sites-available ]]; then
  mkdir -p /etc/nginx/sites-available
  cp "$SPATH/conf/plex.domain.tld" "/etc/nginx/sites-available/plex.domain.tld"
fi

if [[ ! -d /etc/nginx/sites-enabled ]]; then
  mkdir -p /etc/nginx/sites-enabled
fi

# Move the optimized config file to the nginx install directory.
if [[ ! -e /etc/nginx/nginx.conf ]]; then
  mkdir -p /etc/nginx
  cd /etc/nginx || exit 1
  cp "$SPATH/conf/nginx.conf" "/etc/nginx/nginx.conf"
fi

# Add the nginx user and group if they don't already exist.
id -g nginx &>/dev/null || addgroup --system nginx
id -u nginx &>/dev/null || adduser --disabled-password --system --home /var/cache/nginx --shell /sbin/nologin --group nginx

# Build libatomic.
cd "$BPATH/libatomic_ops-$VERSION_LIBATOMIC"
autoreconf -i
./configure
make -j "$(nproc)"
ln -s "$BPATH/libatomic_ops-$VERSION_LIBATOMIC/src/.libs/libatomic_ops.a" "$BPATH/libatomic_ops-$VERSION_LIBATOMIC/src"
make install

# Build zlib-cloudflare.
cd "$BPATH/zlib-cloudflare"
./configure --64
make -j "$(nproc)"

# Build jemalloc.
cd "$BPATH/jemalloc"
autoconf
./configure --disable-initial-exec-tls
make -j "$(nproc)"
checkinstall --install=no --pkgversion="$(cat "$BPATH/jemalloc/VERSION")" -y
cp "$BPATH/jemalloc"/*.deb "$SPATH/packages"
make install

# Build nginx, with various modules included/excluded; requires GCC 12.2; requires mold linker
ldconfig
cd "$BPATH/nginx"
patch -p1 < "$SPATH/patches/nginx.patch"

./auto/configure \
  --prefix=/etc/nginx \
  --with-cpu-opt=generic \
  --with-cc-opt='-I/usr/local/include -pipe -m64 -march=native -DTCP_FASTOPEN=23 -falign-functions=32 -O3 -Wno-error=strict-aliasing -Wno-vla-parameter -fstack-protector-strong -fuse-ld=mold --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wno-error=pointer-sign -Wimplicit-fallthrough=0 -fcode-hoisting -Wp,-D_FORTIFY_SOURCE=2 -Wno-deprecated-declarations' \
  --with-ld-opt='-Wl,-E -L/usr/local/lib -ljemalloc -Wl,-z,relro -Wl,-rpath,/usr/local/lib -fuse-ld=mold' \
  --with-openssl="../$VERSION_OPENSSL" \
  --with-openssl-opt='-pipe -O3 -fPIC -m64 -march=native -ljemalloc -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wl,-flto=16 no-weak-ssl-ciphers no-ssl3 no-idea no-err no-srp no-psk no-nextprotoneg enable-ktls enable-zlib enable-ec_nistp_64_gcc_128' \
  --with-zlib="../zlib-cloudflare" \
  --with-zlib-opt='-pipe -O3 -fPIC -m64 -march=native -ljemalloc -fstack-protector-strong -D_FORTIFY_SOURCE=2 -flto=16' \
  --with-pcre="../$VERSION_PCRE" \
  --with-pcre-opt='-pipe -O3 -fPIC -m64 -march=native -ljemalloc -fstack-protector-strong -D_FORTIFY_SOURCE=2 -flto=16' \
  --with-libatomic="../libatomic_ops-$VERSION_LIBATOMIC" \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --lock-path=/var/run/nginx.lock \
  --modules-path=/usr/lib/nginx/modules \
  --pid-path=/var/run/nginx.pid \
  --sbin-path=/usr/sbin/nginx \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --user=nginx \
  --group=nginx \
  --with-file-aio \
  --with-threads \
  --with-http_realip_module \
  --with-http_ssl_module \
  --with-http_v2_hpack_enc \
  --with-http_v2_module \
  --with-http_v3_module \
  --add-module="../ngx_security_headers-$VERSION_SECURITY_HEADERS" \
  --without-http_grpc_module \
  --without-http_memcached_module \
  --without-http_mirror_module \
  --without-http_scgi_module \
  --without-http_split_clients_module \
  --without-http_ssi_module \
  --without-http_uwsgi_module \
  --without-mail_imap_module \
  --without-mail_pop3_module \
  --without-mail_smtp_module \
  --without-poll_module \
  --without-select_module \
  --without-pcre2

make -j "$(nproc)"
make install
checkinstall --install=no --pkgname="nginx" --pkgversion="$VERSION_NGINX" -y
cp "$BPATH/nginx"/*.deb "$SPATH/packages"
make clean
strip -s /usr/sbin/nginx*

# Create NGINX systemd service file if it does not already exist
if [ ! -e "/lib/systemd/system/nginx.service" ]; then
  # Control will enter here if the NGINX service doesn't exist.
  file="/lib/systemd/system/nginx.service"

/bin/cat >$file <<'EOF'
[Unit]
Description=A high performance web server and a reverse proxy server
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecStartPost=/bin/sleep 0.1
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
fi

# Installation is done, show nginx version and elf comment.
nginx -V
readelf -p .comment /usr/sbin/nginx

# Echo out the relevant data to the script runner.
echo "All done!"
echo ""
echo "nginx bin:       /usr/sbin/nginx"
echo "nginx user/grp:  nginx:nginx"
echo "nginx pid:       /run/nginx.pid" 
echo "nginx logs:      /var/log/nginx/"
echo "nginx data:      /etc/nginx"
echo "nginx config:    /etc/nginx/nginx.conf"
echo "nginx vhosts:    /etc/nginx/sites-available (you need to symlink configs to /etc/nginx/sites-enabled)"
echo "nginx cache:     /var/cache/nginx/"
echo "nginx systemd:   /lib/systemd/system/nginx.service"
echo ""

# Clean out any files from this script
echo "Cleaning up residual files..."
sudo rm -rf "$BPATH"
sudo rm -rf "packages"

# Start nginx for the first time
echo "Starting nginx for the first time..."
sudo service nginx start