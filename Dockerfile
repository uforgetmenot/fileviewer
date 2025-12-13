FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# 切换到阿里云镜像以加速 apt 与 pip
RUN set -eux; \
    release="$(. /etc/os-release && echo "$VERSION_CODENAME")"; \
    : "${release:=bookworm}"; \
    cat > /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/debian ${release} main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian ${release}-updates main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian ${release}-backports main contrib non-free non-free-firmware
deb http://mirrors.aliyun.com/debian-security ${release}-security main contrib non-free non-free-firmware
EOF

RUN apt-get update \
    && apt-get install -y --no-install-recommends inotify-tools \
    && rm -rf /var/lib/apt/lists/*

RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple

WORKDIR /workspace

RUN mkdir -p /opt/template

COPY assets /opt/template/assets
COPY index.html generate.py /opt/template/

COPY regen-watcher.sh /usr/local/bin/regen-watcher.sh
RUN chmod +x /usr/local/bin/regen-watcher.sh
ENV TEMPLATE_DIR=/opt/template

ENTRYPOINT ["/usr/local/bin/regen-watcher.sh"]
