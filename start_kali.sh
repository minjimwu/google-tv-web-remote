#!/bin/bash
# 禾聯 (HERAN) Google TV 網頁版遙控器一鍵啟動腳本 (Kali Linux / Ubuntu)

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "=========================================================="
echo "  📺 啟動 禾聯 (HERAN) Google TV 網頁遙控器伺服器"
echo "=========================================================="

# 檢查與安裝相依套件
if [ -f "backend/requirements.txt" ]; then
    echo "📦 檢查 Python 相依套件..."
    pip3 install -q -r backend/requirements.txt 2>/dev/null || true
fi

# 取得本地 IP
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

echo ""
echo "🚀 伺服器已成功啟動！"
echo "🌐 本地訪問網址: http://127.0.0.1:5000"
echo "📱 請在 iPad / 手機 Safari 輸入: http://${LOCAL_IP}:5000"
echo "=========================================================="
echo ""

cd backend
python3 server.py
