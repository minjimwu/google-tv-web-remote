"""
禾聯 (HERAN) Google TV 實機連線與即時控制整合測試 (Live Integration Test)
測試目標: 192.168.1.5 (Google TV v2 TLS 通訊埠 6466/6467)
"""

import os
import sys
import unittest
import urllib.request
import json

BASE_URL = "http://127.0.0.1:5000"

class TestLiveTVRemote(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # 測試伺服器是否就緒
        try:
            req = urllib.request.Request(f"{BASE_URL}/api/status")
            with urllib.request.urlopen(req, timeout=2.0) as resp:
                cls.server_ready = (resp.status == 200)
        except Exception:
            cls.server_ready = False

    def test_01_server_is_online(self):
        """測試 Kali Linux 後端伺服器在線上運作中"""
        self.assertTrue(self.server_ready, "Web 遙控器伺服器應正常在 port 5000 運行")

    def test_02_tv_paired_status(self):
        """測試電視目前處於已配對且已連線狀態"""
        req = urllib.request.Request(f"{BASE_URL}/api/status")
        with urllib.request.urlopen(req, timeout=2.0) as resp:
            data = json.loads(resp.read().decode())
            self.assertTrue(data.get("is_connected"), "電視應處於已連線狀態 (is_connected=true)")
            self.assertEqual(data.get("tv_ip"), "192.168.1.5")

    def test_03_send_live_key_commands(self):
        """實機測試向電視發送按鍵指令"""
        for test_key in ["VOLUME_UP", "VOLUME_DOWN", "DPAD_CENTER", "HOME"]:
            payload = json.dumps({"key": test_key}).encode("utf-8")
            req = urllib.request.Request(
                f"{BASE_URL}/api/send_key",
                data=payload,
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                self.assertEqual(resp.status, 200)
                data = json.loads(resp.read().decode())
                self.assertEqual(data.get("status"), "success", f"按鍵 {test_key} 應成功發送")

if __name__ == "__main__":
    unittest.main(verbosity=2)
