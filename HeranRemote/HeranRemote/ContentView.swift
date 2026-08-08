import SwiftUI
import CoreBluetooth
import Combine
import UIKit

// MARK: - 禾聯 (HERAN) Google TV 藍芽 HID 遙控器服務核心 (iOS 13.4+)
final class BluetoothHIDRemoteManager: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    
    // MARK: - Published State
    @Published var isAdvertising: Bool = false
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = "藍芽系統就緒"
    @Published var lastSentKey: String = "-"
    @Published var logs: [String] = []
    
    // MARK: - CoreBluetooth Properties
    private var peripheralManager: CBPeripheralManager!
    private var inputReportCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []
    
    // MARK: - BLE GATT Service UUIDs
    private let hidServiceUUID = CBUUID(string: "1812")         // Human Interface Device
    private let deviceInfoServiceUUID = CBUUID(string: "180A")  // Device Information
    private let batteryServiceUUID = CBUUID(string: "180F")     // Battery Service
    
    // MARK: - HID Characteristics UUIDs
    private let hidInfoUUID = CBUUID(string: "2A4A")
    private let reportMapUUID = CBUUID(string: "2A4B")
    private let controlPointUUID = CBUUID(string: "2A4C")
    private let hidReportUUID = CBUUID(string: "2A4D")
    private let protocolModeUUID = CBUUID(string: "2A4E")
    
    // Device Info Characteristics
    private let manufacturerUUID = CBUUID(string: "2A29")
    private let modelUUID = CBUUID(string: "2A24")
    private let batteryLevelUUID = CBUUID(string: "2A19")

    // MARK: - Initializer
    override init() {
        super.init()
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        log("HERAN BLE Remote Engine 就緒 (iOS 13.4)")
    }

    // MARK: - User Action Methods
    func toggleAdvertising() {
        if isAdvertising {
            stopAdvertising()
        } else {
            startAdvertising()
        }
    }

    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            log("❌ 藍芽未開啟，請於 iPad 設定中啟用藍芽")
            statusMessage = "藍芽未開啟"
            return
        }

        setupGATTPeripheralServices()
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "HERAN TV Remote (iPad)",
            CBAdvertisementDataServiceUUIDsKey: [hidServiceUUID]
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        statusMessage = "廣播中 (HERAN TV Remote)"
        log("📡 已啟動藍芽廣播 (HERAN TV Remote)，請於電視設定「新增配件」中配對")
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        statusMessage = "廣播已停止"
        log("⏹ 藍芽廣播已停止")
    }

    // MARK: - Send Keycode Command
    func sendKeyCommand(_ keyName: String, reportValue: UInt16) {
        guard isAdvertising else {
            log("⚠️ 廣播未開啟，無法發送: \(keyName)")
            return
        }
        
        lastSentKey = keyName
        log("🔘 發送按鍵: \(keyName) (0x\(String(format:"%04X", reportValue)))")
        
        // 1. 發送 Key Press (按下) 封包
        var pressData = Data(count: 2)
        pressData[0] = UInt8(reportValue & 0xFF)
        pressData[1] = UInt8((reportValue >> 8) & 0xFF)
        sendReport(pressData)
        
        // 2. 延遲 50ms 後發送 Key Release (放開) 封包
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            var releaseData = Data(count: 2)
            releaseData[0] = 0x00
            releaseData[1] = 0x00
            self?.sendReport(releaseData)
        }
    }

    private func sendReport(_ data: Data) {
        guard let characteristic = inputReportCharacteristic else { return }
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }

    // MARK: - Setup GATT Services & HID Descriptor
    private func setupGATTPeripheralServices() {
        peripheralManager.removeAllServices()

        // 1. Device Information Service
        let deviceInfoService = CBMutableService(type: deviceInfoServiceUUID, primary: true)
        let manufacturerChar = CBMutableCharacteristic(
            type: manufacturerUUID,
            properties: .read,
            value: "HERAN".data(using: .utf8),
            permissions: .readable
        )
        let modelChar = CBMutableCharacteristic(
            type: modelUUID,
            properties: .read,
            value: "HERAN-GoogleTV-iPad".data(using: .utf8),
            permissions: .readable
        )
        deviceInfoService.characteristics = [manufacturerChar, modelChar]

        // 2. Battery Service (100%)
        let batteryService = CBMutableService(type: batteryServiceUUID, primary: true)
        let batteryLevelChar = CBMutableCharacteristic(
            type: batteryLevelUUID,
            properties: .read,
            value: Data([100]),
            permissions: .readable
        )
        batteryService.characteristics = [batteryLevelChar]

        // 3. HID Service
        let hidService = CBMutableService(type: hidServiceUUID, primary: true)
        
        let hidInfoData = Data([0x11, 0x01, 0x00, 0x01])
        let hidInfoChar = CBMutableCharacteristic(
            type: hidInfoUUID,
            properties: .read,
            value: hidInfoData,
            permissions: .readable
        )
        
        // HID Report Map (Consumer Control Keymap for TV Remote)
        let reportMapData = Data([
            0x05, 0x0C,        // Usage Page (Consumer)
            0x09, 0x01,        // Usage (Consumer Control)
            0xA1, 0x01,        // Collection (Application)
            0x85, 0x01,        //   Report ID (1)
            0x15, 0x00,        //   Logical Minimum (0)
            0x26, 0xFF, 0x03,  //   Logical Maximum (1023)
            0x19, 0x00,        //   Usage Minimum (0)
            0x2A, 0xFF, 0x03,  //   Usage Maximum (1023)
            0x75, 0x10,        //   Report Size (16 bits)
            0x95, 0x01,        //   Report Count (1)
            0x81, 0x00,        //   Input (Data,Array,Absolute)
            0xC0               // End Collection
        ])
        let reportMapChar = CBMutableCharacteristic(
            type: reportMapUUID,
            properties: .read,
            value: reportMapData,
            permissions: .readable
        )
        
        let protocolModeChar = CBMutableCharacteristic(
            type: protocolModeUUID,
            properties: [.read, .writeWithoutResponse],
            value: Data([0x01]),
            permissions: [.readable, .writeable]
        )
        
        let controlPointChar = CBMutableCharacteristic(
            type: controlPointUUID,
            properties: .writeWithoutResponse,
            value: nil,
            permissions: .writeable
        )
        
        let reportChar = CBMutableCharacteristic(
            type: hidReportUUID,
            properties: [.read, .notify, .indicate],
            value: nil,
            permissions: .readable
        )
        self.inputReportCharacteristic = reportChar
        
        hidService.characteristics = [hidInfoChar, reportMapChar, protocolModeChar, controlPointChar, reportChar]

        peripheralManager.add(deviceInfoService)
        peripheralManager.add(batteryService)
        peripheralManager.add(hidService)
    }

    // MARK: - CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            log("🟢 藍芽硬體已就緒")
            statusMessage = "藍芽系統就緒"
        case .poweredOff:
            log("🔴 藍芽已被關閉")
            statusMessage = "藍芽已被關閉"
            isAdvertising = false
        case .unauthorized:
            log("⚠️ 藍芽未獲授權權限")
            statusMessage = "未獲得藍芽權限"
        case .unsupported:
            log("❌ 此設備不支援 BLE 周邊模式")
            statusMessage = "設備不支援 BLE"
        default:
            log("ℹ️ 藍芽狀態更新: \(peripheral.state.rawValue)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(central) {
            subscribedCentrals.append(central)
        }
        isConnected = true
        statusMessage = "已連線配對 (電視)"
        log("✅ 電視已與 iPad 藍芽配對連線")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll { $0 == central }
        if subscribedCentrals.isEmpty {
            isConnected = false
            statusMessage = "廣播中 (無連線)"
            log("ℹ️ 電視已中斷藍芽連線")
        }
    }

    private func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logs.append("[\(timestamp)] \(message)")
            if self.logs.count > 40 {
                self.logs.removeFirst()
            }
        }
    }
}

// MARK: - 主畫面 ContentView (相容 iOS 13.4+)
struct ContentView: View {
    @ObservedObject var btManager = BluetoothHIDRemoteManager()
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            // 背景漸層 (iOS 13+)
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.02, green: 0.03, blue: 0.06)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 18) {
                    // 1. 頂部狀態列
                    headerView
                    
                    // 2. 電源與頂部按鍵
                    topActionsView
                    
                    // 3. 方向鍵 (D-Pad)
                    dPadView
                    
                    // 4. 返回 / 主頁 / 選單
                    navigationKeysView
                    
                    // 5. 音量與頻道推桿
                    rockerControlsView
                    
                    // 6. 快捷 App 鍵
                    appShortcutsView
                    
                    // 7. 數字鍵盤
                    numberPadView
                    
                    // 8. 藍芽 Log 視窗
                    consoleLogView
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 540)
            }
        }
        .onAppear {
            hapticImpact.prepare()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("HERAN")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Google TV Remote (BLE)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(btManager.isAdvertising ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                Text(btManager.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Button(action: {
                    hapticImpact.impactOccurred()
                    btManager.toggleAdvertising()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text(btManager.isAdvertising ? "停止廣播" : "啟動廣播")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(btManager.isAdvertising ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundColor(btManager.isAdvertising ? .red : .blue)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(btManager.isAdvertising ? Color.red : Color.blue, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.bottom, 6)
        .overlay(Divider().background(Color.white.opacity(0.1)), alignment: .bottom)
    }
    
    // MARK: - Top Power Actions
    private var topActionsView: some View {
        HStack(spacing: 28) {
            Button(action: {
                triggerKey("POWER", code: 0x0030)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.red)
                    .frame(width: 56, height: 56)
                    .background(Color(red: 0.25, green: 0.08, blue: 0.08))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.red.opacity(0.6), lineWidth: 1.5))
            }
            
            Spacer()
            
            Button(action: {
                triggerKey("INPUT", code: 0x001B)
            }) {
                Text("INPUT")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            
            Button(action: {
                triggerKey("SETTINGS", code: 0x006F)
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
        }
    }
    
    // MARK: - D-Pad
    private var dPadView: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(gradient: Gradient(colors: [Color(red: 0.15, green: 0.18, blue: 0.25), Color(red: 0.08, green: 0.10, blue: 0.14)]), center: .center, startRadius: 20, endRadius: 100)
                )
                .frame(width: 210, height: 210)
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            VStack {
                Button(action: { triggerKey("DPAD_UP", code: 0x0042) }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 46)
                }
                Spacer()
                Button(action: { triggerKey("DPAD_DOWN", code: 0x0043) }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 46)
                }
            }
            .frame(height: 190)
            
            HStack {
                Button(action: { triggerKey("DPAD_LEFT", code: 0x0044) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 56)
                }
                Spacer()
                Button(action: { triggerKey("DPAD_RIGHT", code: 0x0045) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 56)
                }
            }
            .frame(width: 190)
            
            Button(action: { triggerKey("DPAD_CENTER", code: 0x0041) }) {
                Text("OK")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 68, height: 68)
                    .background(Color(red: 0.12, green: 0.28, blue: 0.55))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.blue, lineWidth: 1.5))
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Navigation Keys
    private var navigationKeysView: some View {
        HStack(spacing: 36) {
            Button(action: { triggerKey("BACK", code: 0x0224) }) {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .bold))
                    Text("返回")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            }
            
            Button(action: { triggerKey("HOME", code: 0x0223) }) {
                VStack(spacing: 2) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("主頁")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.blue)
                .frame(width: 58, height: 58)
                .background(Color.blue.opacity(0.15))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.blue.opacity(0.4), lineWidth: 1))
            }
            
            Button(action: { triggerKey("MENU", code: 0x0040) }) {
                VStack(spacing: 2) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                    Text("選單")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Rockers
    private var rockerControlsView: some View {
        HStack(spacing: 16) {
            VStack(spacing: 10) {
                Text("VOL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                
                Button(action: { triggerKey("VOLUME_UP", code: 0x00E9) }) {
                    Text("+")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: { triggerKey("MUTE", code: 0x00E2) }) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                
                Button(action: { triggerKey("VOLUME_DOWN", code: 0x00EA) }) {
                    Text("-")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(20)
            
            VStack(spacing: 10) {
                Text("CH")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                
                Button(action: { triggerKey("CHANNEL_UP", code: 0x009C) }) {
                    Text("▲")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Text("CH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(height: 36)
                
                Button(action: { triggerKey("CHANNEL_DOWN", code: 0x009D) }) {
                    Text("▼")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(20)
        }
    }
    
    // MARK: - App Shortcuts
    private var appShortcutsView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: { triggerKey("APP_YOUTUBE", code: 0x0077) }) {
                    Text("YouTube")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
                }
                
                Button(action: { triggerKey("APP_NETFLIX", code: 0x0078) }) {
                    Text("NETFLIX")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.9, green: 0.05, blue: 0.1))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
                }
            }
            
            HStack(spacing: 8) {
                Button(action: { triggerKey("APP_PRIME", code: 0x0079) }) {
                    Text("prime video")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.4), lineWidth: 1))
                }
                
                Button(action: { triggerKey("APP_HERAN", code: 0x007A) }) {
                    Text("HERAN TV")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.4), lineWidth: 1))
                }
            }
        }
    }
    
    // MARK: - Number Pad
    private var numberPadView: some View {
        VStack(spacing: 6) {
            Text("數字鍵盤")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            HStack(spacing: 6) {
                numButton("1", code: 0x001E)
                numButton("2", code: 0x001F)
                numButton("3", code: 0x0020)
            }
            HStack(spacing: 6) {
                numButton("4", code: 0x0021)
                numButton("5", code: 0x0022)
                numButton("6", code: 0x0023)
            }
            HStack(spacing: 6) {
                numButton("7", code: 0x0024)
                numButton("8", code: 0x0025)
                numButton("9", code: 0x0026)
            }
            HStack(spacing: 6) {
                numButton("INFO", code: 0x0035)
                numButton("0", code: 0x0027)
                numButton("⌫", code: 0x002A)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
    }
    
    private func numButton(_ label: String, code: UInt16) -> some View {
        Button(action: { triggerKey(label, code: code) }) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    // MARK: - Console Log View
    private var consoleLogView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("藍芽訊號日誌 (BLE Output)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Button("清除") {
                    btManager.logs.removeAll()
                }
                .font(.system(size: 10))
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                ForEach(btManager.logs.suffix(4), id: \.self) { logText in
                    Text(logText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(logText.contains("發送") ? .green : .gray)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    // Trigger Key Action
    private func triggerKey(_ name: String, code: UInt16) {
        hapticImpact.impactOccurred()
        btManager.sendKeyCommand(name, reportValue: code)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
