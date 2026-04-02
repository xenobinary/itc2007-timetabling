from pathlib import Path
from unittest import TestCase

from timetable_tui.solver_runner import run_solver


class SolverRunnerTests(TestCase):
    def setUp(self) -> None:
        self.repo_root = Path(__file__).resolve().parents[1]
        self.fixture = self.repo_root / "tests" / "fixtures" / "mini.ctt"

    def test_run_solver_uses_existing_prolog_engine(self) -> None:
        result = run_solver(self.repo_root, self.fixture, "constructive")
        self.assertEqual(result.exit_code, 0)
        self.assertTrue(result.feasible)
        self.assertGreaterEqual(len(result.assignments), 1)