# 禾聯 (HERAN) Google TV 智慧網頁遙控器 - 雙網段與全功能指南

本系統已配置為 **全網卡綁定 (0.0.0.0:5000)**，同時支援 Kali Linux 上的所有網路介面：

---

## 🌐 支援連線網址 (Dual Network Access)

| 網段介面 | 網址 | 適用設備 |
| :--- | :--- | :--- |
| **Wi-Fi 介面 (wlan0)** | 👉 **`http://YOUR_SERVER_IP:5000`** | iPad、iPhone、家用 Wi-Fi 設備 |
| **熱點 / 子介面 (wlan1)** | 👉 **`http://YOUR_HOTSPOT_IP:5000`** | 專屬熱點、內網獨立網段設備 |
| **本機端 (Localhost)** | 👉 **`http://127.0.0.1:5000`** | Kali Linux 桌面瀏覽器 |

---

## 📐 雙網段控制架構 (Dual-Subnet Routing)

```
        [ iPad / 手機 (YOUR_SUBNET) ]           [ 獨立網段設備 (YOUR_HOTSPOT_SUBNET) ]
                       │                                         │
        http://YOUR_SERVER_IP:5000               http://YOUR_HOTSPOT_IP:5000
                       └──────────────────┬──────────────────────┘
                                          v
                   +-----------------------------------------------+
                   |       Kali Linux 智慧中繼伺服器 (Port 5000)      |
                   |  - 0.0.0.0:5000 多網卡同時監聽 (wlan0 & wlan1)   |
                   |  - 跨網段自動搜尋 (掃描 18.x 與 44.x 全網段)    |
                   |  - 持久化 TLS Socket (Port 6466/6467)         |
                   +----------------------+------------------------+
                                          │ (Google TV v2 TLS Encrypted)
                                          v
                   +-----------------------------------------------+
                   |       禾聯 Google TV (YOUR_TV_IP)            |
                   |  - 接收 Protobuf Keycode (D-Pad, Vol, Apps)   |
                   +-----------------------------------------------+
```

---

## 🧪 雙網段實機測試結果

* `http://YOUR_SERVER_IP:5000/api/status` ➔ **`HTTP 200 OK (is_connected: true)`**
* `http://YOUR_HOTSPOT_IP:5000/api/status` ➔ **`HTTP 200 OK (is_connected: true)`**
* `POST http://YOUR_HOTSPOT_IP:5000/api/send_key` ➔ **`{"command":"VOLUME_UP","status":"success"}`**
