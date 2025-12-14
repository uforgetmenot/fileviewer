# 文件索引自动更新容器

该项目通过 Docker 容器 + `inotify` 持续监听当前目录中的文件变化，只要检测到指定格式的文件被新增或删除，容器就会自动调用 `generate.py`，重新生成最新的 `index.json` 数据。

## 监控范围

- 监听的根目录：以 `docker compose` 启动时挂载的当前工作目录（默认 `/workspace`）。
- 受支持的扩展名：`.png`、`.jpg`、`.jpeg`、`.gif`、`.webp`、`.md`、`.drawio`、`.pdf`、`.xlsx`、`.docx`、`.txt`、`.pptx`、`.mp4`、`.mp3`（以及常见 `.webm`、`.wav`、`.m4a` 等音视频格式）。
- 忽略项：`README.md`（位于根目录时不触发）以及 `.git` 目录和自动生成的 `index.json`。
- 触发条件：文件被创建、删除、移动到/移出目录、或写入完成时，且文件扩展名命中上述列表。

## 目录结构

```
.
├── Dockerfile              # 构建带 inotify-tools 的 Python 运行环境
├── docker-compose.yml      # 定义挂载当前目录的监控服务
├── regen-watcher.sh        # 监听脚本，封装 inotify + generate.py 调用
├── generate.py             # 已有的索引生成脚本
├── index.html              # 示例静态文件
└── assets/…                # 静态资源（包含 styles.css 等依赖）
```

## 使用方式

1. **确保本机已安装** Docker 与 Docker Compose（Docker Desktop 自带 Compose）。
2. 在项目根目录执行以下命令构建并启动监听服务：

   ```bash
   docker compose up --build
   ```

   - 首次启动会立刻执行一次 `generate.py`，保证 `index.json` 存在。
   - 之后只要将指定类型的文件拷贝、创建、删除或移动到挂载目录，容器就会自动重新生成最新索引。

3. 需要在后台运行时，可以附加 `-d` 选项：`docker compose up -d --build`。停止服务使用 `docker compose down`。

## 自定义

- 如需监听其他目录，可在 `docker-compose.yml` 中调整 `volumes` 或通过环境变量 `WATCH_DIR`/`TARGET_DIR` 指定。
- 默认会调用挂载目录下的 `generate.py`，若要替换可设置 `GENERATE_SCRIPT` 指向新的脚本路径。

## 故障排查

- 若容器日志中提示 `inotifywait` 不存在，请确认镜像使用的是项目提供的 `Dockerfile` 构建版本。
- 如出现 `generate.py` 执行失败，可直接在宿主机运行 `python3 generate.py` 检查脚本本身是否报错。
- 若 `index.json` 没有变化，请确认操作的文件扩展名在支持列表内，且不叫 `README.md`。
