# 📺 Google TV & Android TV Web Remote

A sleek, lightweight, and low-latency **Web-based Remote Control** for **Google TV / Android TV**, engineered to run directly in any browser (iPad, iPhone, Android, Mac, Windows) via local Wi-Fi without needing native apps or ADB developer mode.

Built on Google TV Remote Protocol v2 (TLS encryption & Protobuf keycodes), supporting persistent sessions, one-time PIN pairing, haptic vibration, sound effects, and multi-network interfaces.

---

## ✨ Features

- **📱 Touch-Optimized Luxury UI**: Dark Glassmorphism interface with Apple TV / smart remote ergonomics.
- **🔒 Official Google TV v2 Protocol**: Communicates securely over TLS with self-signed X.509 certificates and 6-digit PIN challenges.
- **⚡ Persistent Asyncio Engine**: Zero-disconnect pairing session holding and instant keycode dispatch.
- **🔍 Auto Subnet Discovery**: Multi-threaded scanner detects Google TVs and Chromecast devices across all local network subnets (`192.168.x.x`).
- **🎧 Web Audio & Haptics**: Subtle click acoustics and tactile feedback on compatible mobile devices.
- **🌐 Multi-Network Interface Ready**: Binds to `0.0.0.0:5000` to serve simultaneously across multiple network adapters (e.g., Wi-Fi, hotspot, Ethernet).
- **🧪 100% Automated Test Coverage**: Comprehensive test suite covering REST APIs, controller mechanics, and live device integration.

---

## 🛠️ Architecture

```
+-------------------------------------------------------------+
|               User Client (Mobile / Tablet / PC)             |
|   Safari / Chrome Browser (http://<HOST_IP>:5000)           |
|   - Glassmorphism Touch UI                                  |
|   - Real-time Connection LED indicator                      |
+------------------------------+------------------------------+
                               | (HTTP REST API)
                               v
+-------------------------------------------------------------+
|               Relay Server (Linux / Pi / Gateway)           |
|   - Flask REST API (`server.py: 0.0.0.0:5000`)              |
|   - Persistent Asyncio Engine (`PersistentAsyncWorker`)     |
|   - Automated X.509 Certificate Generator                   |
+------------------------------+------------------------------+
                               | (TLS Socket / Protobuf: 6466, 6467)
                               v
+-------------------------------------------------------------+
|               Target Google TV / Android TV                 |
|   - Port 6467: TLS Handshake & PIN Challenge                |
|   - Port 6466: Key Command Channel (D-Pad, Volume, Apps)    |
+-------------------------------------------------------------+
```

---

## 🚀 Getting Started

### 1. Prerequisites
- Python 3.9+
- Linux (Ubuntu, Debian, Kali, Raspberry Pi OS), macOS, or Windows

### 2. Installation
```bash
# Clone the repository
git clone https://github.com/minjimwu/google-tv-web-remote.git
cd google-tv-web-remote

# Install Python dependencies
pip3 install -r backend/requirements.txt
```

### 3. Start the Server
```bash
cd backend
python3 server.py
```
By default, the server listens on `http://0.0.0.0:5000`.

### 4. Pair Your TV
1. Open `http://<SERVER_IP>:5000` on your iPad, iPhone, or browser.
2. Click **⚙️ Settings** (設定) in the top-right corner.
3. Select your detected TV from the dropdown (or enter the TV's IP address) and click **Start Pairing** (發起配對).
4. Look at your TV screen for the **6-character PIN code**.
5. Enter the PIN code in the modal and click **Verify & Save** (驗證並永久儲存).
6. The LED on the main face will turn **🟢 Green**, indicating a permanent authorized connection.

---

## 🧪 Running Automated Tests

Run the full automated test suite:
```bash
python3 -m unittest discover -s tests -p "test_*.py" -v
```

---

## ⚙️ Running as a System Service (systemd)

To automatically launch the remote server on system boot:

```bash
sudo cp systemd/heran-remote.service /etc/systemd/system/google-tv-remote.service
sudo systemctl daemon-reload
sudo systemctl enable google-tv-remote
sudo systemctl start google-tv-remote
```

---

## 📄 License
MIT License. Feel free to use and customize for your home automation needs!
