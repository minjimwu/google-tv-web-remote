import Foundation
import CoreBluetooth
import Combine

/// 禾聯 (HERAN) Google TV 藍芽 HID 遙控器服務核心
/// 在 iPad 上透過 CoreBluetooth 模擬 BLE HID Peripheral (周邊) 廣播
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
        log("HERAN BLE Remote Engine 初始化完成")
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
    /// 發送 Consumer Control 與 D-Pad 按鍵至電視
    func sendKeyCommand(_ keyName: String, reportValue: UInt16) {
        guard isAdvertising else {
            log("⚠️ 廣播未開啟，無法發送: \(keyName)")
            return
        }
        
        lastSentKey = keyName
        log("🔘 發送按鍵: \(keyName) (Code: 0x\(String(format:"%04X", reportValue)))")
        
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
        
        if !subscribedCentrals.isEmpty {
            peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        } else {
            // 無 Central 訂閱時嘗試直接更新
            peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        }
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
        
        // HID Info: Country Code 0, Flags 0x01 (RemoteWake)
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
        
        // Protocol Mode (Boot Protocol = 1, Report Protocol = 1)
        let protocolModeChar = CBMutableCharacteristic(
            type: protocolModeUUID,
            properties: [.read, .writeWithoutResponse],
            value: Data([0x01]),
            permissions: [.readable, .writeable]
        )
        
        // Control Point
        let controlPointChar = CBMutableCharacteristic(
            type: controlPointUUID,
            properties: .writeWithoutResponse,
            value: nil,
            permissions: .writeable
        )
        
        // Input Report Characteristic (Notifications to TV)
        let reportChar = CBMutableCharacteristic(
            type: hidReportUUID,
            properties: [.read, .notify, .indicate],
            value: nil,
            permissions: .readable
        )
        self.inputReportCharacteristic = reportChar
        
        hidService.characteristics = [hidInfoChar, reportMapChar, protocolModeChar, controlPointChar, reportChar]

        // Add all services
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
        log("✅ 電視 Central 已成功與 iPad 藍芽配對連線 (ID: \(central.identifier.uuidString))")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll { $0 == central }
        if subscribedCentrals.isEmpty {
            isConnected = false
            statusMessage = "廣播中 (無連線)"
            log("ℹ️ 電視已中斷藍芽連線")
        }
    }

    // MARK: - Logger Helper
    private func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logs.append("[\(timestamp)] \(message)")
            if self.logs.count > 50 {
                self.logs.removeFirst()
            }
        }
    }
}
