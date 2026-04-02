from io import StringIO
from pathlib import Path
from unittest import TestCase

from rich.console import Console

from timetable_tui.app import TerminalApp
from timetable_tui.instance_data import parse_ctt
from timetable_tui.models import Assignment, RunResult


class TerminalAppTests(TestCase):
    def setUp(self) -> None:
        self.repo_root = Path(__file__).resolve().parents[1]
        self.fixture = self.repo_root / "tests" / "fixtures" / "mini.ctt"

    def test_full_menu_loop_updates_session_state(self) -> None:
        inputs = iter([
            "1",  # select instance
            "1",  # choose the first available instance
            "",   # pause
            "2",  # view summary
            "",   # pause
            "3",  # view constraints
            "",   # pause
            "4",  # run solver
            "1",  # choose constructive
            "",   # pause
            "5",  # review last result
            "",   # pause
            "6",  # exit
        ])
        output = StringIO()
        console = Console(file=output, force_terminal=False, width=120)

        def fake_input(_prompt: str) -> str:
            return next(inputs)

        def fake_runner(_repo_root: Path, instance_path: Path, solver_name: str) -> RunResult:
            return RunResult(
                instance_path=instance_path,
                solver_name=solver_name,
                feasible=True,
                penalty=0,
                exit_code=0,
                solution_path=self.repo_root / "results" / "fake.sol",
                stats_path=self.repo_root / "results" / "fake.csv",
                assignments=(Assignment("C1", "R1", 0, 1),),
            )

        app = TerminalApp(
            self.repo_root,
            console=console,
            input_fn=fake_input,
            solver_runner=fake_runner,
            instance_provider=lambda _repo_root: [self.fixture],
        )
        app.run()

        self.assertIsNotNone(app.state.selected_instance)
        self.assertEqual(app.state.selected_instance.name, "MINI")
        self.assertIsNotNone(app.state.last_run)
        self.assertEqual(app.state.last_run.solver_name, "constructive")
        self.assertIn("Run Summary", output.getvalue())

    def test_review_without_selected_instance_uses_last_run_path(self) -> None:
        output = StringIO()
        console = Console(file=output, force_terminal=False, width=120)
        app = TerminalApp(
            self.repo_root,
            console=console,
            input_fn=lambda _prompt: "",
            instance_provider=lambda _repo_root: [self.fixture],
        )
        app.state.last_run = RunResult(
            instance_path=self.fixture,
            solver_name="constructive",
            feasible=True,
            penalty=0,
            exit_code=0,
            solution_path=self.repo_root / "results" / "fake.sol",
            stats_path=self.repo_root / "results" / "fake.csv",
            assignments=(Assignment("C1", "R1", 0, 1),),
        )

        app.review_last_result()

        self.assertIn("Timetable Grid", output.getvalue())
        parsed = parse_ctt(self.fixture)
        self.assertEqual(parsed.name, "MINI")