# 🚀 禾聯 (HERAN) Google TV 網頁遙控器 - Kali Linux 部署教學

本方案讓您在 **Kali Linux** 運行 Python Google TV 伺服器，**iPad / 手機 / 電腦** 只需要打開瀏覽器就能直接無線遙控禾聯電視！

---

## 🛠️ 第一步：在 Kali Linux 上啟動伺服器

打開 Kali Linux 的終端機 (Terminal)，執行以下指令：

```bash
# 1. 進入專案目錄
cd /path/to/tvremotecontrol

# 2. 安裝 Python 相依套件
pip3 install -r backend/requirements.txt

# 3. 啟動伺服器
chmod +x start_kali.sh
./start_kali.sh
```

終端機會顯示您的 Kali IP 位址，例如：
`📱 請在 iPad / 手機 Safari 輸入: http://192.168.1.150:5000`

---

## 📺 第二步：在電視上完成「PIN 碼配對」

1. 在 **iPad Safari 瀏覽器** 打開網址：`http://<您的Kali_IP>:5000`。
2. 點擊右上角的 **「PIN 配對」** 按鈕。
3. 輸入禾聯電視的 IP 位址（例如 `192.168.1.100`），點擊 **「發起配對」**。
4. 此時**禾聯 Google TV 螢幕上會跳出 6 位數 PIN 碼**。
5. 在 iPad 畫面上輸入這 6 位數 PIN 碼，點擊 **「驗證並完成配對」**！

> 🎉 **恭喜！配對完成後，此憑證會永久保存，以後只要打開網頁就能直接遙控！**

---

## 📱 第三步：在 iPad 上一鍵「加入主畫面」（全螢幕 App）

1. 在 iPad Safari 打開該網頁後，點擊右上角的 **「分享 (Share)」圖示**。
2. 選擇 **「加入主畫面 (Add to Home Screen)」**。
3. iPad 桌面就會出現一個 **「禾聯電視遙控器」** 圖示，點開就是全螢幕原生質感的遙控器，完全沒有網址列！
