import unittest
import os
import sys
import tempfile
import json
import threading
import time
import urllib.request
from http.server import ThreadingHTTPServer

# Add scripts directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts")))
import manage_sites


class TestServe(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.web_dir = self.test_dir.name
        self.index_path = os.path.join(self.web_dir, "index.html")
        self.services_path = os.path.join(self.web_dir, "services.json")
        self.status_path = os.path.join(self.web_dir, "status.json")

        with open(self.index_path, "w", encoding="utf-8") as f:
            f.write("<!DOCTYPE html><html><body>Test Dashboard</body></html>")
        with open(self.services_path, "w", encoding="utf-8") as f:
            json.dump([{"id": "test-service", "name": "Test", "port": 1234}], f)
        with open(self.status_path, "w", encoding="utf-8") as f:
            json.dump({"updated_at": "2026-09-21", "statuses": {"test-service": "online"}}, f)

        self.config = {
            "web_dir": self.web_dir,
            "services_json": self.services_path,
            "status_json": self.status_path,
            "index_html": self.index_path,
            "lan_host": "127.0.0.1",
            "tailscale_host": "test.ts.net",
            "tailscale_ip": "100.64.0.1",
        }

    def tearDown(self):
        self.test_dir.cleanup()

    def test_handler_serves_files_with_cache_headers(self):
        # Verify DashboardHTTPHandler serves files
        handler_class = manage_sites.create_request_handler(self.web_dir)
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler_class)
        port = server.server_address[1]

        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()

        try:
            # 1. Test index.html
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/") as resp:
                self.assertEqual(resp.status, 200)
                body = resp.read().decode("utf-8")
                self.assertIn("Test Dashboard", body)

            # 2. Test services.json has no-cache header
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/services.json") as resp:
                self.assertEqual(resp.status, 200)
                data = json.loads(resp.read().decode("utf-8"))
                self.assertEqual(data[0]["id"], "test-service")
                cache_control = resp.headers.get("Cache-Control", "")
                self.assertIn("no-cache", cache_control)

            # 3. Test status.json has no-cache header
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/status.json") as resp:
                self.assertEqual(resp.status, 200)
                data = json.loads(resp.read().decode("utf-8"))
                self.assertEqual(data["statuses"]["test-service"], "online")
                cache_control = resp.headers.get("Cache-Control", "")
                self.assertIn("no-cache", cache_control)
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
