FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# 切换到阿里云镜像以加速 apt 与 pip
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list \
    && sed -i 's|security.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends inotify-tools \
    && rm -rf /var/lib/apt/lists/*

RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple

WORKDIR /workspace

RUN mkdir -p /opt/template

COPY assets /opt/template/assets
COPY index.html styles.css generate.py /opt/template/
RUN cp /opt/template/styles.css /opt/template/style.css

COPY regen-watcher.sh /usr/local/bin/regen-watcher.sh
RUN chmod +x /usr/local/bin/regen-watcher.sh
ENV TEMPLATE_DIR=/opt/template

ENTRYPOINT ["/usr/local/bin/regen-watcher.sh"]
