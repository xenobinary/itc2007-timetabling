from __future__ import annotations

from pathlib import Path
from typing import Callable, Sequence

from rich.console import Console

from .instance_data import discover_instance_paths, parse_ctt
from .models import RunResult, SessionState
from .rendering import (
    render_assignment_views,
    render_constraints,
    render_instance_choices,
    render_instance_summary,
    render_main_menu,
    render_run_summary,
)
from .solver_runner import run_solver

InputFn = Callable[[str], str]
SolverRunner = Callable[[Path, Path, str], RunResult]
InstanceProvider = Callable[[Path], Sequence[Path]]


class TerminalApp:
    def __init__(
        self,
        repo_root: Path,
        *,
        console: Console | None = None,
        input_fn: InputFn = input,
        solver_runner: SolverRunner | None = None,
        instance_provider: InstanceProvider = discover_instance_paths,
    ) -> None:
        self.repo_root = repo_root
        self.console = console or Console()
        self.input_fn = input_fn
        self.instance_provider = instance_provider
        self.solver_runner = solver_runner or self._default_solver_runner
        self.state = SessionState()

    def run(self) -> None:
        while True:
            self.state.active_screen = "main_menu"
            self.console.clear()
            selected_label = (
                self.state.selected_instance.source_path.name
                if self.state.selected_instance is not None
                else "None"
            )
            last_run_label = (
                f"{self.state.last_run.instance_path.name} ({self.state.last_run.solver_name})"
                if self.state.last_run is not None
                else "None"
            )
            render_main_menu(self.console, selected_label, last_run_label)
            choice = self.input_fn("Choose an option: ").strip()

            if choice == "1":
                self.select_instance()
            elif choice == "2":
                self.view_instance_summary()
            elif choice == "3":
                self.view_constraints()
            elif choice == "4":
                self.run_solver_screen()
            elif choice == "5":
                self.review_last_result()
            elif choice == "6":
                self.console.print("Goodbye.")
                return
            else:
                self.console.print("Invalid option. Choose 1-6.", style="bold red")
                self._pause()

    def select_instance(self) -> None:
        self.state.active_screen = "instance_selection"
        instance_paths = list(self.instance_provider(self.repo_root))
        self.state.available_instances = tuple(instance_paths)
        if not instance_paths:
            self.console.print("No .ctt files were found in the known instance directories.", style="bold red")
            self._pause()
            return

        self.console.clear()
        render_instance_choices(self.console, [str(path.relative_to(self.repo_root)) for path in instance_paths])
        raw_choice = self.input_fn("Select an instance number: ").strip()
        if not raw_choice.isdigit():
            self.console.print("Instance selection cancelled.", style="yellow")
            self._pause()
            return

        index = int(raw_choice) - 1
        if index < 0 or index >= len(instance_paths):
            self.console.print("Selected instance is out of range.", style="bold red")
            self._pause()
            return

        self.state.selected_instance = parse_ctt(instance_paths[index])
        self.console.print(
            f"Selected {self.state.selected_instance.name} from {self.state.selected_instance.source_path.relative_to(self.repo_root)}.",
            style="green",
        )
        self._pause()

    def view_instance_summary(self) -> None:
        if not self._require_selected_instance():
            return
        instance = self.state.selected_instance
        self.state.active_screen = "instance_summary"
        self.console.clear()
        render_instance_summary(self.console, instance)
        self._pause()

    def view_constraints(self) -> None:
        self.state.active_screen = "constraints"
        self.console.clear()
        render_constraints(self.console)
        self._pause()

    def run_solver_screen(self) -> None:
        if not self._require_selected_instance():
            return
        instance = self.state.selected_instance

        self.state.active_screen = "solver_run"
        self.console.clear()
        self.console.print("Select solver mode:")
        self.console.print("1. Greedy constructive")
        self.console.print("2. CLPFD")
        choice = self.input_fn("Solver choice: ").strip()
        solver_map = {"1": "constructive", "2": "clpfd"}
        solver_name = solver_map.get(choice)
        if solver_name is None:
            self.console.print("Solver selection cancelled.", style="yellow")
            self._pause()
            return

        self.console.print("Preparing solver run...", style="cyan")
        self.console.print(f"Selected solver: {solver_name}")
        self.console.print(f"Instance: {instance.source_path.relative_to(self.repo_root)}")
        try:
            with self.console.status("Running SWI-Prolog solver...", spinner="dots"):
                result = self.solver_runner(self.repo_root, instance.source_path, solver_name)
        except FileNotFoundError:
            self.console.print("SWI-Prolog executable 'swipl' was not found in PATH.", style="bold red")
            self._pause()
            return

        self.state.last_run = result
        self.console.print("Solver run finished.", style="green")
        render_run_summary(self.console, result)
        self._pause()

    def review_last_result(self) -> None:
        if self.state.last_run is None:
            self.console.print("No solver run has been completed yet.", style="yellow")
            self._pause()
            return

        self.state.active_screen = "result_review"
        self.console.clear()
        render_run_summary(self.console, self.state.last_run)
        instance = self.state.selected_instance or parse_ctt(self.state.last_run.instance_path)
        render_assignment_views(self.console, instance, self.state.last_run)
        self._pause()

    def _default_solver_runner(self, repo_root: Path, instance_path: Path, solver_name: str) -> RunResult:
        return run_solver(repo_root, instance_path, solver_name)

    def _require_selected_instance(self) -> bool:
        if self.state.selected_instance is not None:
            return True
        self.console.print("Select an instance first from the main menu.", style="yellow")
        self._pause()
        return False

    def _pause(self) -> None:
        self.input_fn("Press Enter to continue...")