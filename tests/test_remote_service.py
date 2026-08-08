"""
禾聯 (HERAN) Google TV Remote Protocol v2 控制器底層測試
涵蓋: 憑證存在性、按鍵映射對照、設定檔持久化儲存與連線協議
"""

import os
import sys
import unittest
import json
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../backend")))

from heran_remote_service import HeranGoogleTVController

class TestHeranRemoteService(unittest.TestCase):
    def setUp(self):
        self.controller = HeranGoogleTVController()

    def test_01_certificates_generated(self):
        """測試 TLS 認證憑證與私鑰是否已正確產生"""
        self.assertTrue(os.path.exists(self.controller.cert_path), "TLS 憑證 .pem 檔案應存在")
        self.assertTrue(os.path.exists(self.controller.key_path), "TLS 私鑰 .pem 檔案應存在")

    def test_02_config_loading_and_saving(self):
        """測試電視 IP 與配對設定儲存與讀取"""
        self.controller.tv_ip = "192.168.1.5"
        self.controller._save_config()
        loaded = self.controller._load_config()
        self.assertEqual(loaded.get("tv_ip"), "192.168.1.5")

    def test_03_key_mappings(self):
        """測試按鍵名稱映射完整度"""
        standard_keys = [
            "POWER", "HOME", "BACK", "MENU", "SETTINGS", "INPUT",
            "DPAD_UP", "DPAD_DOWN", "DPAD_LEFT", "DPAD_RIGHT", "DPAD_CENTER",
            "VOLUME_UP", "VOLUME_DOWN", "MUTE", "CHANNEL_UP", "CHANNEL_DOWN",
            "NUM_1", "NUM_2", "NUM_3", "NUM_4", "NUM_5",
            "NUM_6", "NUM_7", "NUM_8", "NUM_9", "NUM_0"
        ]
        app_keys = ["APP_YOUTUBE", "APP_NETFLIX", "APP_PRIME", "APP_HERAN"]

        # 模擬發送測試
        for k in standard_keys + app_keys:
            res = self.controller.send_key(k)
            self.assertEqual(res["status"], "success")

    def test_04_status_report(self):
        """測試控制器狀態物件完整性"""
        status = self.controller.get_status()
        self.assertIn("is_connected", status)
        self.assertIn("is_pairing", status)
        self.assertIn("tv_ip", status)
        self.assertIn("has_native_lib", status)

if __name__ == "__main__":
    unittest.main(verbosity=2)
