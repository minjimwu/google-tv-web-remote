#!/usr/bin/env python3
"""
禾聯 (HERAN) Google TV 網頁版遙控器後端伺服器 (Kali Linux / Ubuntu / Raspberry Pi)
提供 Web UI 靜態資源、自動搜尋電視 (mDNS/IP Scan) 與 Google TV PIN 碼配對 / 鍵碼傳輸 REST API
"""

import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from heran_remote_service import HeranGoogleTVController

app = Flask(__name__, static_folder="../frontend", static_url_path="")
CORS(app)

controller = HeranGoogleTVController()

# MARK: - 靜態首頁
@app.route("/")
def index():
    return send_from_directory(app.static_folder, "index.html")

# MARK: - REST API
@app.route("/api/status", methods=["GET"])
def get_status():
    """獲取目前與電視連線狀態"""
    return jsonify(controller.get_status())

@app.route("/api/discover", methods=["GET", "POST"])
def discover_tvs():
    """自動搜尋區域網路內的禾聯 / Google TV 電視"""
    devices = controller.discover_devices()
    return jsonify({"status": "success", "count": len(devices), "devices": devices})

@app.route("/api/pair/start", methods=["POST"])
def start_pair():
    """發起持久化 PIN 配對，電視將顯示 6 位數驗證碼"""
    data = request.json or {}
    tv_ip = data.get("tv_ip", "").strip()
    if not tv_ip:
        return jsonify({"status": "error", "message": "請提供電視的 IP 位址"}), 400

    result = controller.start_pairing(tv_ip)
    return jsonify(result)

@app.route("/api/pair/finish", methods=["POST"])
def finish_pair():
    """提交電視螢幕上顯示的 PIN 碼完成配對"""
    data = request.json or {}
    pin = data.get("pin", "").strip()
    if not pin:
        return jsonify({"status": "error", "message": "請輸入電視螢幕上顯示的 PIN 碼"}), 400

    result = controller.finish_pairing(pin)
    return jsonify(result)

@app.route("/api/connect", methods=["POST"])
def connect_tv():
    """已配對過的電視直接連線"""
    data = request.json or {}
    tv_ip = data.get("tv_ip")
    result = controller.connect(tv_ip)
    return jsonify(result)

@app.route("/api/send_key", methods=["POST"])
def send_key():
    """發送遙控器按鍵指令"""
    data = request.json or {}
    key_name = data.get("key", "").strip()
    if not key_name:
        return jsonify({"status": "error", "message": "缺少按鍵名稱"}), 400

    result = controller.send_key(key_name)
    return jsonify(result)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"==================================================")
    print(f" 📺 禾聯 (HERAN) Google TV 網頁遙控器伺服器已啟動")
    print(f" 🌐 本地網址: http://127.0.0.1:{port}")
    print(f" 📱 請用 iPad / 手機瀏覽器開啟: http://YOUR_SERVER_IP:{port}")
    print(f"==================================================")
    app.run(host="0.0.0.0", port=port, debug=False)
