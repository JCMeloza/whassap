"""Tests for models.py — data model dataclasses (RED phase)."""
import unittest


class TestDeviceInfo(unittest.TestCase):
    """DeviceInfo model — classification and fields."""

    def test_legacy_classification_api_29(self):
        """API 29 is classified as legacy."""
        from backend.models import DeviceInfo

        d = DeviceInfo(serial="abc", model="Pixel 5", apiLevel=29,
                       packages=["com.whatsapp"])
        self.assertEqual(d.classification, "legacy")

    def test_scoped_classification_api_30(self):
        """API 30 is classified as scoped."""
        from backend.models import DeviceInfo

        d = DeviceInfo(serial="def", model="Pixel 8", apiLevel=30,
                       packages=["com.whatsapp"])
        self.assertEqual(d.classification, "scoped")

    def test_scoped_classification_api_33(self):
        """API 33 is classified as scoped."""
        from backend.models import DeviceInfo

        d = DeviceInfo(serial="ghi", model="S24", apiLevel=33,
                       packages=["com.whatsapp"])
        self.assertEqual(d.classification, "scoped")

    def test_no_packages(self):
        """DeviceInfo with empty packages list."""
        from backend.models import DeviceInfo

        d = DeviceInfo(serial="abc", model="Pixel 5", apiLevel=29,
                       packages=[])
        self.assertEqual(d.packages, [])
        self.assertEqual(d.classification, "legacy")


class TestDatabaseInfo(unittest.TestCase):
    """DatabaseInfo model."""

    def test_database_info_fields(self):
        """DatabaseInfo holds all fields."""
        from backend.models import DatabaseInfo

        db = DatabaseInfo(
            path="/sdcard/WhatsApp/Databases/msgstore.db.crypt14",
            name="msgstore.db.crypt14",
            sizeBytes=50_000_000,
            package="com.whatsapp",
        )
        self.assertEqual(db.name, "msgstore.db.crypt14")
        self.assertEqual(db.sizeBytes, 50_000_000)
        self.assertEqual(db.package, "com.whatsapp")


class TestMediaInfo(unittest.TestCase):
    """MediaInfo model."""

    def test_media_info_fields(self):
        """MediaInfo holds all fields."""
        from backend.models import MediaInfo

        m = MediaInfo(
            category="Images",
            path="/sdcard/WhatsApp/Media/Images",
            sizeBytes=2_100_000_000,
            package="com.whatsapp",
        )
        self.assertEqual(m.category, "Images")
        self.assertEqual(m.sizeBytes, 2_100_000_000)


class TestWhatsAppData(unittest.TestCase):
    """WhatsAppData aggregates databases and media."""

    def test_total_bytes_sum(self):
        """totalBytes sums databases + media sizes."""
        from backend.models import WhatsAppData, DatabaseInfo, MediaInfo

        data = WhatsAppData(
            databases=[
                DatabaseInfo("a", "a", 100, "com.whatsapp"),
                DatabaseInfo("b", "b", 200, "com.whatsapp"),
            ],
            media=[
                MediaInfo("Images", "img", 300, "com.whatsapp"),
            ],
            package="com.whatsapp",
        )
        self.assertEqual(data.totalBytes, 600)

    def test_empty_data(self):
        """totalBytes is 0 when no databases or media."""
        from backend.models import WhatsAppData

        data = WhatsAppData(databases=[], media=[], package="com.whatsapp")
        self.assertEqual(data.totalBytes, 0)


class TestTransferConfig(unittest.TestCase):
    """TransferConfig holds transfer parameters."""

    def test_transfer_config_fields(self):
        """TransferConfig stores source, dest, packages, items."""
        from backend.models import TransferConfig

        cfg = TransferConfig(
            sourceSerial="abc",
            destSerial="def",
            packages=["com.whatsapp"],
            items=["Databases/msgstore.db.crypt14", "Media/Images"],
        )
        self.assertEqual(cfg.sourceSerial, "abc")
        self.assertEqual(cfg.destSerial, "def")
        self.assertEqual(len(cfg.items), 2)


class TestTransferProgress(unittest.TestCase):
    """TransferProgress tracks transfer state."""

    def test_progress_defaults(self):
        """TransferProgress starts with zero defaults."""
        from backend.models import TransferProgress

        p = TransferProgress(transferId="t1", phase="pull")
        self.assertEqual(p.bytesTransferred, 0)
        self.assertEqual(p.bytesTotal, 0)

    def test_progress_with_values(self):
        """TransferProgress holds non-zero values."""
        from backend.models import TransferProgress

        p = TransferProgress(
            transferId="t1", phase="push",
            itemsTotal=10, itemsCompleted=4,
            bytesTotal=5000, bytesTransferred=2000,
        )
        self.assertEqual(p.itemsCompleted, 4)
        self.assertEqual(p.percentage, 40.0)


if __name__ == "__main__":
    unittest.main()
