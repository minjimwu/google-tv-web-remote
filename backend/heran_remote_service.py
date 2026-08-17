"""
禾聯 (HERAN) Google TV Remote Protocol v2 連線與控制模組 (多網卡多網段支援)
支援自動搜尋 (跨 YOUR_SUBNET 與 YOUR_HOTSPOT_SUBNET 等所有網段)、TLS 憑證生成、6 位數 PIN 碼配對與 Protobuf 遙控按鍵傳輸
"""

import os
import json
import socket
import asyncio
import logging
import threading
import urllib.request
import concurrent.futures
from typing import Optional, Dict, Any, List

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("HeranGoogleTV")

try:
    from androidtvremote2 import AndroidTVRemote
    from androidtvremote2.certificate_generator import generate_selfsigned_cert
    HAS_NATIVE_LIB = True
except ImportError:
    HAS_NATIVE_LIB = False
    logger.warning("未偵測到 androidtvremote2 庫")

CONFIG_FILE = os.path.expanduser("~/.heran_tv_remote.json")

class PersistentAsyncWorker:
    """持久化背景非同步執行緒，保證 TLS Socket 與 Event Loop 永不中斷"""
    def __init__(self):
        self.loop = asyncio.new_event_loop()
        self.thread = threading.Thread(target=self._run_loop, daemon=True)
        self.thread.start()

    def _run_loop(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()

    def run_coroutine(self, coro, timeout=12):
        future = asyncio.run_coroutine_threadsafe(coro, self.loop)
        return future.result(timeout=timeout)

worker = PersistentAsyncWorker()

class HeranGoogleTVController:
    def __init__(self):
        self.cert_path = os.path.expanduser("~/.heran_tv_cert.pem")
        self.key_path = os.path.expanduser("~/.heran_tv_key.pem")
        self.is_connected = False
        self.is_pairing = False
        self.client: Optional[Any] = None
        self.config = self._load_config()
        self.tv_ip = self.config.get("tv_ip", "")

        self._ensure_certificates()
        if self.config.get("is_paired"):
            self.connect(self.tv_ip)

    def _ensure_certificates(self):
        if not os.path.exists(self.cert_path) or not os.path.exists(self.key_path):
            if HAS_NATIVE_LIB:
                try:
                    logger.info("🔐 正在生成 Google TV TLS 認證憑證...")
                    cert_bytes, key_bytes = generate_selfsigned_cert("HERAN-Web-Remote")
                    with open(self.cert_path, "wb") as f: f.write(cert_bytes)
                    with open(self.key_path, "wb") as f: f.write(key_bytes)
                    logger.info("✅ 憑證生成完成")
                except Exception as e:
                    logger.error(f"生成憑證失敗: {e}")

    def _load_config(self) -> Dict[str, Any]:
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as e:
                logger.error(f"讀取設定檔失敗: {e}")
        return {}

    def _save_config(self):
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump({
                    "tv_ip": self.tv_ip,
                    "is_paired": True
                }, f, indent=2)
        except Exception as e:
            logger.error(f"儲存設定檔失敗: {e}")

    def _get_local_subnets(self) -> List[str]:
        """自動偵測本機所有網卡 (wlan0, wlan1 等) 之子網段，包含備援掃描"""
        subnets = set()
        
        # 1. 透過 Linux ip 指令讀取所有 IPv4 網卡
        try:
            import subprocess
            res = subprocess.run(["ip", "-o", "-4", "addr", "show"], capture_output=True, text=True, timeout=2)
            for line in res.stdout.splitlines():
                parts = line.strip().split()
                if len(parts) >= 4:
                    ip_cidr = parts[3]
                    ip = ip_cidr.split("/")[0]
                    if not ip.startswith("127."):
                        subnets.add(".".join(ip.split(".")[:3]))
        except Exception:
            pass

        # 2. 透過 UDP socket 探索預設閘道網段
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            if not ip.startswith("127."):
                subnets.add(".".join(ip.split(".")[:3]))
            s.close()
        except Exception:
            pass

        # 3. 透過已記錄的 tv_ip 推導網段
        if self.tv_ip and "." in self.tv_ip:
            subnets.add(".".join(self.tv_ip.split(".")[:3]))

        return sorted(list(subnets)) if subnets else ["192.168.1", "192.168.0"]

    def discover_devices(self) -> List[Dict[str, Any]]:
        """全自動跨網段搜尋區域網路 (LAN) 中的 Google TV / 禾聯電視設備"""
        logger.info("🔍 開始掃描本機所有網段內的 Google TV 設備...")
        found_devices = []
        subnets = self._get_local_subnets()

        def probe_ip(ip_str: str) -> Optional[Dict[str, Any]]:
            target_ports = [6467, 6466, 8008, 8009, 5555]
            matched_port = None
            for p in target_ports:
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(0.25)
                    if sock.connect_ex((ip_str, p)) == 0:
                        matched_port = p
                        sock.close()
                        break
                    sock.close()
                except Exception:
                    pass

            if not matched_port:
                return None

            name = f"禾聯 Google TV ({ip_str})"
            try:
                url = f"http://{ip_str}:8008/setup/eureka_info"
                req = urllib.request.Request(url, headers={"User-Agent": "curl/7.0"})
                with urllib.request.urlopen(req, timeout=0.8) as resp:
                    data = json.loads(resp.read().decode())
                    tv_name = data.get("name") or data.get("device_info", {}).get("name")
                    if tv_name:
                        name = f"{tv_name} ({ip_str})"
            except Exception:
                pass

            return {
                "ip": ip_str,
                "name": name,
                "port": matched_port,
                "protocol": "Google TV Remote v2" if matched_port in [6466, 6467] else "Cast/SmartTV"
            }

        all_ips = []
        for sn in subnets:
            all_ips.extend([f"{sn}.{i}" for i in range(1, 255)])

        with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
            for res in executor.map(probe_ip, all_ips):
                if res:
                    found_devices.append(res)
                    logger.info(f"✅ 發現電視: {res['name']} (IP: {res['ip']})")

        return found_devices

    def _auto_find_paired_tv(self) -> Optional[str]:
        """當原 IP 無法連線時，自動掃描區網尋找已配對的 Google TV (DHCP IP 漂移自癒)"""
        logger.info("🔄 原電視 IP 未響應，啟動智慧區網掃描與 DHCP 漂移自癒程序...")
        devices = self.discover_devices()
        tv_devices = [d for d in devices if d.get("port") in [6466, 6467]]

        for dev in tv_devices:
            candidate_ip = dev["ip"]
            logger.info(f"🧪 嘗試測試已配對憑證至新發現電視: {candidate_ip}...")
            try:
                test_client = AndroidTVRemote(
                    client_name="HERAN-Web-Remote",
                    certfile=self.cert_path,
                    keyfile=self.key_path,
                    host=candidate_ip,
                    loop=worker.loop
                )
                async def _try_connect():
                    await test_client.async_connect()
                    test_client.keep_reconnecting()
                    return True

                worker.run_coroutine(_try_connect(), timeout=4)
                # 連線成功！更新為新的電視 IP
                self.client = test_client
                self.tv_ip = candidate_ip
                self.is_connected = True
                self._save_config()
                logger.info(f"🎉 成功自癒重連！電視已無縫漫遊至新 IP: {self.tv_ip}")
                return candidate_ip
            except Exception as e:
                logger.debug(f"候選 IP {candidate_ip} 驗證非原電視: {e}")

        return None

    def start_pairing(self, tv_ip: str) -> Dict[str, Any]:
        self.tv_ip = tv_ip.strip()
        self._ensure_certificates()
        logger.info(f"📡 正在向禾聯電視 {self.tv_ip} 發起持久化 PIN 配對請求...")
        self.is_pairing = True

        if HAS_NATIVE_LIB:
            try:
                self.client = AndroidTVRemote(
                    client_name="HERAN-Web-Remote",
                    certfile=self.cert_path,
                    keyfile=self.key_path,
                    host=self.tv_ip,
                    loop=worker.loop
                )
                asyncio.run_coroutine_threadsafe(self.client.async_start_pairing(), worker.loop)
                self._save_config()
                return {
                    "status": "pairing_started",
                    "message": f"配對請求已發送至電視 ({self.tv_ip})，請查看電視螢幕中央的 6 位數 PIN 碼！",
                    "tv_ip": self.tv_ip
                }
            except Exception as e:
                logger.error(f"配對啟動失敗: {e}")
                return {"status": "error", "message": f"配對啟動失敗: {str(e)}"}
        else:
            return {"status": "pairing_started", "message": f"已發送配對請求至 {self.tv_ip}", "tv_ip": self.tv_ip}

    def finish_pairing(self, pin: str) -> Dict[str, Any]:
        pin = pin.strip().upper()
        logger.info(f"🔑 提交 PIN 碼: {pin} 至持久化配對工作程序...")

        if HAS_NATIVE_LIB and self.client:
            try:
                async def _do_finish():
                    await self.client.async_finish_pairing(pin)
                    await self.client.async_connect()
                    self.client.keep_reconnecting()
                    return True

                worker.run_coroutine(_do_finish(), timeout=10)
                self.is_connected = True
                self.is_pairing = False
                self._save_config()
                logger.info("🎉 ✅ PIN 碼驗證成功！電視已永久連線！")
                return {"status": "success", "message": "電視配對成功，已連線！"}
            except Exception as e:
                logger.error(f"PIN 碼驗證失敗: {e}")
                return {"status": "error", "message": f"PIN 碼驗證失敗: {str(e)}"}
        else:
            self.is_connected = True
            self.is_pairing = False
            self._save_config()
            return {"status": "success", "message": f"PIN 碼 [{pin}] 驗證成功 (模擬模式)"}

    def connect(self, tv_ip: Optional[str] = None) -> Dict[str, Any]:
        target_ip = (tv_ip or self.tv_ip).strip()
        if not target_ip:
            # 嘗試自動搜尋電視
            found_ip = self._auto_find_paired_tv()
            if found_ip:
                return {"status": "success", "message": f"已自動連線至電視 ({self.tv_ip})"}
            return {"status": "error", "message": "請先選擇電視 IP"}

        self.tv_ip = target_ip
        logger.info(f"連線至禾聯電視: {self.tv_ip}...")

        if HAS_NATIVE_LIB:
            try:
                if not self.client or self.client._host != self.tv_ip:
                    self.client = AndroidTVRemote(
                        client_name="HERAN-Web-Remote",
                        certfile=self.cert_path,
                        keyfile=self.key_path,
                        host=self.tv_ip,
                        loop=worker.loop
                    )

                async def _do_connect():
                    await self.client.async_connect()
                    self.client.keep_reconnecting()
                    return True

                worker.run_coroutine(_do_connect(), timeout=5)
                self.is_connected = True
                self._save_config()
                return {"status": "success", "message": f"已連線至電視 ({self.tv_ip})"}
            except Exception as e:
                logger.warning(f"連線 {self.tv_ip} 失敗 ({e})，嘗試自動掃描與 IP 漫遊自癒...")
                new_ip = self._auto_find_paired_tv()
                if new_ip:
                    return {"status": "success", "message": f"已自動漫遊並連線至電視 ({self.tv_ip})"}
                
                # 仍找不到則發起新配對
                self.start_pairing(self.tv_ip)
                return {
                    "status": "needs_pairing",
                    "message": f"電視螢幕 ({self.tv_ip}) 正顯示 6 位數 PIN 碼，請在設定中輸入完成配對！",
                    "tv_ip": self.tv_ip
                }
        else:
            self.is_connected = True
            return {"status": "success", "message": f"已連線至 {self.tv_ip}"}

    def send_key(self, key_name: str) -> Dict[str, Any]:
        logger.info(f"🎮 發送按鍵: {key_name} -> {self.tv_ip}")

        KEY_MAP = {
            "POWER": "POWER", "HOME": "HOME", "BACK": "BACK", "MENU": "MENU",
            "SETTINGS": "SETTINGS", "INPUT": "TV_INPUT", "DPAD_UP": "DPAD_UP",
            "DPAD_DOWN": "DPAD_DOWN", "DPAD_LEFT": "DPAD_LEFT", "DPAD_RIGHT": "DPAD_RIGHT",
            "DPAD_CENTER": "DPAD_CENTER", "VOLUME_UP": "VOLUME_UP", "VOLUME_DOWN": "VOLUME_DOWN",
            "MUTE": "VOLUME_MUTE", "CHANNEL_UP": "CHANNEL_UP", "CHANNEL_DOWN": "CHANNEL_DOWN",
            "NUM_1": "1", "NUM_2": "2", "NUM_3": "3", "NUM_4": "4", "NUM_5": "5",
            "NUM_6": "6", "NUM_7": "7", "NUM_8": "8", "NUM_9": "9", "NUM_0": "0",
            "NUM_DEL": "DEL", "NUM_INFO": "INFO"
        }

        APP_MAP = {
            "APP_YOUTUBE": "https://www.youtube.com",
            "APP_NETFLIX": "netflix://",
            "APP_PRIME": "https://www.primevideo.com",
            "APP_HERAN": "android.intent.action.VIEW"
        }

        if HAS_NATIVE_LIB:
            if not self.client and self.tv_ip:
                self.client = AndroidTVRemote(
                    client_name="HERAN-Web-Remote",
                    certfile=self.cert_path,
                    keyfile=self.key_path,
                    host=self.tv_ip,
                    loop=worker.loop
                )

            if self.client:
                async def _send_with_retry():
                    # 若尚未連線或連線已中斷，自動連線
                    if not getattr(self.client, "_remote_message_protocol", None):
                        logger.info("⚡ 正在重新建立與電視的 TLS 連線...")
                        await self.client.async_connect()
                        self.client.keep_reconnecting()

                    if key_name in APP_MAP:
                        app_link = APP_MAP[key_name]
                        self.client.send_launch_app_command(app_link)
                        return {"status": "success", "key": key_name, "type": "app_launch"}
                    else:
                        remote_key = KEY_MAP.get(key_name, key_name)
                        self.client.send_key_command(remote_key, "SHORT")
                        return {"status": "success", "key": key_name, "command": remote_key}

                try:
                    res = worker.run_coroutine(_send_with_retry(), timeout=4)
                    self.is_connected = True
                    return res
                except Exception as e:
                    logger.warning(f"發送失敗 ({e})，嘗試 IP 漂移自癒與重試...")
                    new_ip = self._auto_find_paired_tv()
                    if new_ip and self.client:
                        try:
                            if key_name in APP_MAP:
                                self.client.send_launch_app_command(APP_MAP[key_name])
                                return {"status": "success", "key": key_name, "type": "app_launch", "tv_ip": self.tv_ip}
                            else:
                                remote_key = KEY_MAP.get(key_name, key_name)
                                self.client.send_key_command(remote_key, "SHORT")
                                return {"status": "success", "key": key_name, "command": remote_key, "tv_ip": self.tv_ip}
                        except Exception as err2:
                            logger.error(f"自癒後發送仍失敗: {err2}")
                    
                    self.is_connected = False
                    return {"status": "error", "message": str(e)}

        return {"status": "error", "message": "尚未連線至電視"}

    def get_status(self) -> Dict[str, Any]:
        is_conn = False
        if HAS_NATIVE_LIB and self.client:
            is_conn = bool(getattr(self.client, "_remote_message_protocol", None)) or self.is_connected
        return {
            "is_connected": is_conn,
            "is_pairing": self.is_pairing,
            "tv_ip": self.tv_ip,
            "has_native_lib": HAS_NATIVE_LIB
        }
