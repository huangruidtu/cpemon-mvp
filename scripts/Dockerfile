FROM python:3.12-slim

# 1. 基础环境
WORKDIR /app

# 2. 只复制依赖列表，先安装依赖，方便 Docker 利用缓存
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3. 再复制脚本
COPY cpe_heartbeat.py .

# 4. 运行时可以用环境变量控制 URL / SN 等
ENV CPE_API_URL="https://api.local/cpe/heartbeat" \
    CPE_HEARTBEAT_SECRET="cpemon-demo-secret" \
    CPE_SN="CPE-DEMO-001" \
    CPE_WAN_IP="10.0.0.13" \
    CPE_SW_VERSION="v1.0-demo" \
    CPE_HEARTBEAT_INTERVAL="15" \
    CPE_VERIFY_SSL="false"

CMD ["python", "cpe_heartbeat.py"]
