from pathlib import Path
from unittest import TestCase

from timetable_tui.instance_data import discover_instance_paths, parse_ctt


class InstanceDataTests(TestCase):
    def setUp(self) -> None:
        self.repo_root = Path(__file__).resolve().parents[1]

    def test_discover_instance_paths_finds_fixtures(self) -> None:
        instance_paths = discover_instance_paths(self.repo_root)
        self.assertTrue(any(path.name == "mini.ctt" for path in instance_paths))

    def test_parse_ctt_reads_expected_fields(self) -> None:
        instance = parse_ctt(self.repo_root / "tests" / "fixtures" / "mini.ctt")
        self.assertEqual(instance.name, "MINI")
        self.assertEqual(instance.courses_count, 2)
        self.assertEqual(instance.rooms_count, 2)
        self.assertEqual(instance.days, 2)
        self.assertEqual(instance.periods_per_day, 2)
        self.assertEqual(len(instance.courses), 2)
        self.assertEqual(len(instance.rooms), 2)
        self.assertEqual(len(instance.curricula), 1)
        self.assertEqual(len(instance.unavailability), 1)