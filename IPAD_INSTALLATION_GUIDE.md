# 📱 禾聯 (HERAN) Google TV 藍芽搖控器 - iPad 安裝與配對指南

本指南將手把手教您如何將 **禾聯 Google TV 藍芽搖控器 App** 安裝到您的 iPad 上，並完成與禾聯電視的藍芽離線配對。

---

## 🛠️ 第一部分：將 App 安裝到 iPad ( Xcode 步驟)

因為本 App 使用 iPad 的 iOS **藍芽周邊廣播 (BLE HID Peripheral)** 功能，最穩定且支援完全離線控制的方式是透過 Xcode 將 Native App 寫入 iPad：

### 需求準備
1. **Mac 電腦**（已安裝 Xcode，可於 App Store 免費下載）。
2. **iPad 設備** 與 **USB 連接線**。
3. **免費的 Apple ID 帳號**（不需付費購買開發者帳號）。

---

### 步驟 1：在 Xcode 中開啟專案
1. 打開 **Xcode**，選擇 **"Create a new Xcode project"**。
2. 選擇 **iOS ➔ App**，點選 **Next**。
3. 填寫專案資訊：
   - **Product Name**: `HeranRemote`
   - **Team**: 選擇您的個人 Apple ID (Personal Team)
   - **Organization Identifier**: `com.heran`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
4. 專案儲存位置選擇本資料夾 `/Users/jw/mygit/tvremotecontrol/ios`。

### 步驟 2：匯入與替換程式碼檔案
將 `ios` 資料夾內的以下 4 個檔案拖入 Xcode 專案總管中：
- `HeranRemoteApp.swift` (App 入口)
- `Services/BluetoothHIDRemoteManager.swift` (藍芽 BLE HID 引擎)
- `Views/RemoteControlView.swift` (iPad UI 介面)
- `Info.plist` (藍芽權限設定)

### 步驟 3：安裝至 iPad
1. 使用 USB 線將 iPad 連接到 Mac。
2. 在 Xcode 頂部選單的目標設備中，將預設的 Simulator 改選為您的 **iPad 實體裝置**。
3. 點擊左上角的 **「▶️ 執行 (Run)」** 按鈕。
4. Xcode 將會編譯並自動將 App 部署安裝至您的 iPad。

> 💡 **第一次安裝注意事項 (簽名信任)**：  
> 若 iPad 畫面上顯示「未受信任的開發者」，請在 iPad 上進入 **「設定」➔「一般」➔「裝置管理」/「VPN 與裝置管理」**，點選您的 Apple ID 並點擊 **「信任」** 即可正常開啟 App！

---

## 📺 第二部分：與禾聯 (HERAN) Google TV 藍芽配對

安裝完成後，請依照以下步驟讓電視與 iPad 建立藍芽連線：

```
+------------------+                    +-----------------------+
|  iPad Remote App | -- 藍芽 BLE 廣播 --> |  禾聯 (HERAN) Google  |
|  (HERAN Remote)  | <--- 藍芽 HID ---- |     TV 電視主機       |
+------------------+                    +-----------------------+
```

### 步驟 1：啟動 iPad 廣播
1. 在 iPad 上打開剛安裝好的 **「禾聯遙控器」App**。
2. 點擊右上角的 **「啟動藍芽廣播」** 按鈕。
3. 狀態燈將會變為 **綠色 🟢 (廣播中: HERAN TV Remote)**。

### 步驟 2：在禾聯電視開啟「新增配件」
1. 拿起禾聯電視原本的遙控器（或按下電視機身上的設定鈕）。
2. 進入電視畫面右上角的 **「設定 (Settings ⚙️)」**。
3. 選擇 **「遙控器與配件 (Remotes & Accessories)」**。
4. 點選 **「新增配件 (Pair remote or accessory)」**，電視會開始搜尋周邊藍芽設備。

### 步驟 3：完成配對
1. 電視搜尋列表中將會出現 **`HERAN TV Remote (iPad)`**。
2. 點擊選擇該設備並確認 **「配對 (Pair)」**。
3. 配對成功後，iPad App 的狀態欄會顯示 **🟢 已連線配對 (電視)**！

---

## 🎮 常用功能按鍵說明

* **D-Pad 導航區**：上下左右與中間大 OK 確定鈕，用於瀏覽與選擇電視 App選單。
* **Power (電源鈕 🔴)**：切換電視電源/待機。
* **Home (主頁鈕 🏠)**：一鍵返回 Google TV 主畫面。
* **Back (返回鈕 ⬅️)**：回到上一層選單。
* **VOL +/- & MUTE**：調整音量與一鍵靜音。
* **快捷鍵**：YouTube、Netflix、Prime Video 一鍵啟動。

---

## 🌐 額外功能：網頁模擬器 (Web Simulator)

如果您想先在電腦或 iPad Safari 瀏覽器預覽 UI 介面，可以直接開啟本專案根目錄的 `index.html`：
```bash
# 在本專案目錄執行簡易 HTTP 伺服器
npx http-server -p 8080
```
然後用瀏覽器訪問 `http://localhost:8080` 即可預覽互動式遙控器介面！
