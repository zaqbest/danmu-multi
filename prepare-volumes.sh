#!/usr/bin/env bash
# 准备 danmu 多实例部署（全新建）：创建 volumes、生成 .env、初始化 MySQL 三库
# 用法：在服务器 /opt/apps/danmu/ 执行  bash prepare-volumes.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-rikei@1234}"
MYSQL_USER="${MYSQL_USER:-danmuapi}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-rikei@1234}"

echo "==> 检查 Docker ..."
docker info >/dev/null 2>&1 || { echo -e "${RED}Docker 未运行，请先启动 Docker${NC}"; exit 1; }

if [ ! -f "$COMPOSE_FILE" ]; then
  echo -e "${RED}未找到 $COMPOSE_FILE，请在包含 compose 文件的目录运行${NC}"; exit 1
fi

# ---------------------------------------------------------------------------
# 1. 创建 external volumes（若不存在）
# ---------------------------------------------------------------------------
echo "==> 创建 external volumes（若不存在）..."
VOLUMES=(danmu_multi_server_app_data_1 danmu_multi_server_app_data_2 danmu_multi_server_app_data_3 danmu_multi_server_db_data)
for v in "${VOLUMES[@]}"; do
  if docker volume inspect "$v" >/dev/null 2>&1; then
    echo "  [skip] $v 已存在"
  else
    docker volume create "$v" >/dev/null
    echo -e "  ${GREEN}[ok]${NC}   $v 已创建"
  fi
done

# ---------------------------------------------------------------------------
# 2. 生成 .env（端口变量）
# ---------------------------------------------------------------------------
if [ ! -f .env ]; then
  cat > .env <<EOF
# danmu 多实例端口（按需修改，避免与宿主机已占用端口冲突）
DANMU_SERVER_PORT=7768
DANMU_SERVER_PORT_2=7769
DANMU_SERVER_PORT_3=7770
EOF
  echo -e "  ${GREEN}[ok]${NC}   已生成 .env（7768 / 7769 / 7770）"
else
  echo "  [skip] .env 已存在，未修改"
fi

# ---------------------------------------------------------------------------
# 3. 启动 danmu-multi-mysql（仅 mysql，供后续建库用）
# ---------------------------------------------------------------------------
echo "==> 启动 danmu-multi-mysql ..."
docker compose -f "$COMPOSE_FILE" up -d danmu-multi-mysql

echo "  等待 MySQL 就绪 ..."
for i in $(seq 1 30); do
  if docker compose -f "$COMPOSE_FILE" exec -T danmu-multi-mysql mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" >/dev/null 2>&1; then
    echo -e "  ${GREEN}[ok]${NC}   MySQL 已就绪"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo -e "  ${RED}MySQL 启动超时${NC}"; exit 1
  fi
  sleep 2
done

# ---------------------------------------------------------------------------
# 4. 初始化数据库 danmuapi1/2/3 并授权
# ---------------------------------------------------------------------------
echo "==> 初始化数据库 danmuapi1/2/3 ..."
docker compose -f "$COMPOSE_FILE" exec -T danmu-multi-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<'SQL'
CREATE DATABASE IF NOT EXISTS danmuapi1 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS danmuapi2 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS danmuapi3 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON danmuapi1.* TO 'danmuapi'@'%';
GRANT ALL PRIVILEGES ON danmuapi2.* TO 'danmuapi'@'%';
GRANT ALL PRIVILEGES ON danmuapi3.* TO 'danmuapi'@'%';
FLUSH PRIVILEGES;
SQL

echo -e "  ${GREEN}[ok]${NC}   danmuapi1 / danmuapi2 / danmuapi3 已就绪"

# ---------------------------------------------------------------------------
# 5. 完成
# ---------------------------------------------------------------------------
echo
echo "=========================================="
echo -e "${GREEN}准备完成${NC}"
echo "=========================================="
echo "下一步：启动所有服务"
echo "  docker compose -f $COMPOSE_FILE up -d"
echo
echo "三个实例对应关系："
echo "  danmu-server   -> ${DANMU_SERVER_PORT:-7768}      -> danmuapi1"
echo "  danmu-server-2 -> ${DANMU_SERVER_PORT_2:-7769}    -> danmuapi2"
echo "  danmu-server-3 -> ${DANMU_SERVER_PORT_3:-7770}    -> danmuapi3"
echo
