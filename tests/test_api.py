"""
禾聯 (HERAN) Google TV 網頁遙控器 - REST API 單元與整合測試
涵蓋: 狀態查詢、自動搜尋、配對流程、按鍵發送與例外處理
"""

import os
import sys
import unittest
import json
from unittest.mock import patch, MagicMock

# 將 backend 路徑加入 import 搜尋路徑
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../backend")))

from server import app

class TestTVRemoteAPI(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_01_index_page(self):
        """測試首頁靜態資源讀取"""
        response = self.app.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"HERAN", response.data)

    def test_02_status_api(self):
        """測試 /api/status 狀態查詢 API"""
        response = self.app.get("/api/status")
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn("is_connected", data)
        self.assertIn("tv_ip", data)
        self.assertIn("has_native_lib", data)

    @patch("heran_remote_service.HeranGoogleTVController.discover_devices")
    def test_03_discover_api(self, mock_discover):
        """測試 /api/discover 自動搜尋設備 API"""
        mock_discover.return_value = [
            {"ip": "192.168.1.5", "name": "禾聯 Google TV (192.168.1.5)", "port": 6467, "protocol": "Google TV Remote v2"}
        ]
        response = self.app.get("/api/discover")
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "success")
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["devices"][0]["ip"], "192.168.1.5")

    def test_04_pair_start_missing_ip(self):
        """測試 /api/pair/start 缺少 IP 參數之錯誤處理"""
        response = self.app.post("/api/pair/start", json={})
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "error")

    @patch("heran_remote_service.HeranGoogleTVController.start_pairing")
    def test_05_pair_start_success(self, mock_start):
        """測試 /api/pair/start 發起配對流程"""
        mock_start.return_value = {
            "status": "pairing_started",
            "message": "已向電視 192.168.1.5 發起配對請求",
            "tv_ip": "192.168.1.5"
        }
        response = self.app.post("/api/pair/start", json={"tv_ip": "192.168.1.5"})
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "pairing_started")
        self.assertEqual(data["tv_ip"], "192.168.1.5")

    def test_06_pair_finish_missing_pin(self):
        """測試 /api/pair/finish 缺少 PIN 參數之錯誤處理"""
        response = self.app.post("/api/pair/finish", json={})
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "error")

    @patch("heran_remote_service.HeranGoogleTVController.finish_pairing")
    def test_07_pair_finish_success(self, mock_finish):
        """測試 /api/pair/finish PIN 碼驗證流程"""
        mock_finish.return_value = {
            "status": "success",
            "message": "電視配對成功，已連線！"
        }
        response = self.app.post("/api/pair/finish", json={"pin": "C2C4EB"})
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "success")

    def test_08_send_key_missing_key(self):
        """測試 /api/send_key 缺少 key 參數之錯誤處理"""
        response = self.app.post("/api/send_key", json={})
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "error")

    @patch("heran_remote_service.HeranGoogleTVController.send_key")
    def test_09_send_key_dpad_and_volume(self, mock_send_key):
        """測試 /api/send_key 發送方向鍵與音量控制"""
        for test_key in ["DPAD_UP", "DPAD_CENTER", "VOLUME_UP", "POWER", "HOME", "APP_YOUTUBE"]:
            mock_send_key.return_value = {"status": "success", "key": test_key}
            response = self.app.post("/api/send_key", json={"key": test_key})
            self.assertEqual(response.status_code, 200)
            data = json.loads(response.data)
            self.assertEqual(data["status"], "success")
            self.assertEqual(data["key"], test_key)

if __name__ == "__main__":
    unittest.main(verbosity=2)
