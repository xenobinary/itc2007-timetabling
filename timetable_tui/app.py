from __future__ import annotations  # Enable postponed annotation evaluation (PEP 563).

from pathlib import Path  # Path provides OS-agnostic filesystem path manipulation.
from typing import Callable, Sequence  # Type aliases for injectable dependencies.

from rich.console import (
    Console,
)  # Console is the rich output driver for all TUI output.

from .instance_data import (
    discover_instance_paths,
    parse_ctt,
)  # Instance discovery and parsing.
from .models import (
    RunResult,
    SessionState,
)  # Domain model types for results and session state.
from .rendering import (  # Import all rendering helpers for the various screens.
    render_assignment_views,
    render_constraints,
    render_instance_choices,
    render_instance_summary,
    render_main_menu,
    render_run_summary,
)
from .solver_runner import run_solver  # Default solver invocation function.

# Type aliases for injectable callables, enabling testing without real I/O.
InputFn = Callable[[str], str]  # A function that prompts for and returns a string.
SolverRunner = Callable[
    [Path, Path, str], RunResult
]  # A function that runs the solver and returns RunResult.
InstanceProvider = Callable[
    [Path], Sequence[Path]
]  # A function that discovers instance file paths.


class TerminalApp:
    """Interactive text-based UI for the ITC2007 course timetabling expert system."""

    def __init__(
        self,
        repo_root: Path,  # Absolute path to the repository root directory.
        *,
        console: Console | None = None,  # Rich Console; created if not injected.
        input_fn: InputFn = input,  # Input function; defaults to built-in input().
        solver_runner: SolverRunner
        | None = None,  # Solver callable; defaults to run_solver.
        instance_provider: InstanceProvider = discover_instance_paths,  # Instance discovery callable.
    ) -> None:
        self.repo_root = repo_root  # Store repo root for path resolution.
        self.console = console or Console()  # Use provided Console or create a new one.
        self.input_fn = input_fn  # Store input callable for prompts.
        self.instance_provider = instance_provider  # Store instance discovery callable.
        self.solver_runner = (
            solver_runner or self._default_solver_runner
        )  # Use injected or default runner.
        self.state = SessionState()  # Initialize fresh session state.

    def run(self) -> None:
        """Main event loop: display menu, dispatch on user choice, repeat until exit."""
        while True:
            self.state.active_screen = (
                "main_menu"  # Mark current screen as the main menu.
            )
            self.console.clear()  # Clear the terminal before each menu render.
            # Build the selected-instance label for the status panel.
            selected_label = (
                self.state.selected_instance.source_path.name  # Show file name if an instance is selected.
                if self.state.selected_instance is not None
                else "None"  # Show "None" when no instance has been selected yet.
            )
            # Build the last-run label for the status panel.
            last_run_label = (
                f"{self.state.last_run.instance_path.name} ({self.state.last_run.solver_name})"  # Show instance+solver.
                if self.state.last_run is not None
                else "None"  # Show "None" when no solver run has been completed yet.
            )
            render_main_menu(
                self.console, selected_label, last_run_label
            )  # Render the menu.
            choice = self.input_fn(
                "Choose an option: "
            ).strip()  # Read and strip the user's choice.

            if choice == "1":  # Option 1: select a .ctt instance file.
                self.select_instance()
            elif choice == "2":  # Option 2: view a summary of the selected instance.
                self.view_instance_summary()
            elif choice == "3":  # Option 3: view hard and soft constraint descriptions.
                self.view_constraints()
            elif choice == "4":  # Option 4: run the solver on the selected instance.
                self.run_solver_screen()
            elif choice == "5":  # Option 5: review the result of the last solver run.
                self.review_last_result()
            elif choice == "6":  # Option 6: exit the application.
                self.console.print("Goodbye.")
                return  # Return from run(); the application terminates.
            else:  # Any other input is invalid.
                self.console.print("Invalid option. Choose 1-6.", style="bold red")
                self._pause()  # Wait for the user to acknowledge the error.

    def select_instance(self) -> None:
        """Screen: discover .ctt files and let the user choose one to work with."""
        self.state.active_screen = (
            "instance_selection"  # Update active screen identifier.
        )
        instance_paths = list(
            self.instance_provider(self.repo_root)
        )  # Discover available instances.
        self.state.available_instances = tuple(
            instance_paths
        )  # Cache discovered paths in state.
        if not instance_paths:  # No instances found; inform the user and return.
            self.console.print(
                "No .ctt files were found in the known instance directories.",
                style="bold red",
            )
            self._pause()
            return

        self.console.clear()  # Clear before showing the instance list.
        render_instance_choices(
            self.console,
            [str(path.relative_to(self.repo_root)) for path in instance_paths],
        )  # Show numbered list.
        raw_choice = self.input_fn(
            "Select an instance number: "
        ).strip()  # Prompt for a number.
        if not raw_choice.isdigit():  # Non-numeric input: treat as cancellation.
            self.console.print("Instance selection cancelled.", style="yellow")
            self._pause()
            return

        index = int(raw_choice) - 1  # Convert 1-based user input to 0-based list index.
        if index < 0 or index >= len(instance_paths):  # Out-of-range check.
            self.console.print("Selected instance is out of range.", style="bold red")
            self._pause()
            return

        self.state.selected_instance = parse_ctt(
            instance_paths[index]
        )  # Parse and store the chosen instance.
        self.console.print(
            f"Selected {self.state.selected_instance.name} from {self.state.selected_instance.source_path.relative_to(self.repo_root)}.",
            style="green",  # Confirmation message in green.
        )
        self._pause()  # Wait for the user to read the confirmation.

    def view_instance_summary(self) -> None:
        """Screen: display a detailed summary of the currently selected instance."""
        if (
            not self._require_selected_instance()
        ):  # Guard: abort if no instance is selected.
            return
        instance = (
            self.state.selected_instance
        )  # Retrieve the selected instance from state.
        self.state.active_screen = (
            "instance_summary"  # Update active screen identifier.
        )
        self.console.clear()  # Clear before rendering the summary.
        render_instance_summary(
            self.console, instance
        )  # Delegate rendering to the rendering module.
        self._pause()  # Wait for the user to finish reading.

    def view_constraints(self) -> None:
        """Screen: display hard and soft constraint descriptions."""
        self.state.active_screen = "constraints"  # Update active screen identifier.
        self.console.clear()  # Clear before rendering the constraints.
        render_constraints(self.console)  # Delegate rendering to the rendering module.
        self._pause()  # Wait for the user to finish reading.

    def run_solver_screen(self) -> None:
        """Screen: select a solver, invoke it, and display the run summary."""
        if (
            not self._require_selected_instance()
        ):  # Guard: abort if no instance is selected.
            return
        instance = (
            self.state.selected_instance
        )  # Retrieve the selected instance from state.

        self.state.active_screen = "solver_run"  # Update active screen identifier.
        self.console.clear()  # Clear before showing solver options.
        self.console.print("Select solver mode:")
        self.console.print("1. Greedy constructive")  # Option 1: constructive solver.
        self.console.print("2. CLPFD")  # Option 2: CLP(FD) solver.
        choice = self.input_fn(
            "Solver choice: "
        ).strip()  # Prompt for solver selection.
        solver_map = {
            "1": "constructive",
            "2": "clpfd",
        }  # Map digit choice to solver name.
        solver_name = solver_map.get(choice)  # Look up solver name; None if invalid.
        if solver_name is None:  # Invalid or cancelled input.
            self.console.print("Solver selection cancelled.", style="yellow")
            self._pause()
            return

        self.console.print("Preparing solver run...", style="cyan")  # Status update.
        self.console.print(f"Selected solver: {solver_name}")  # Echo solver choice.
        self.console.print(
            f"Instance: {instance.source_path.relative_to(self.repo_root)}"
        )  # Echo instance.
        try:
            with self.console.status(
                "Running SWI-Prolog solver...", spinner="dots"
            ):  # Spinner while running.
                result = self.solver_runner(
                    self.repo_root, instance.source_path, solver_name
                )  # Run solver.
        except FileNotFoundError:  # swipl not found in PATH.
            self.console.print(
                "SWI-Prolog executable 'swipl' was not found in PATH.", style="bold red"
            )
            self._pause()
            return

        self.state.last_run = result  # Store the result for later review.
        self.console.print("Solver run finished.", style="green")  # Completion message.
        render_run_summary(self.console, result)  # Show the run summary table.
        self._pause()  # Wait for the user to read the results.

    def review_last_result(self) -> None:
        """Screen: display the full run summary and timetable grid for the last solver run."""
        if self.state.last_run is None:  # No run completed yet; inform the user.
            self.console.print("No solver run has been completed yet.", style="yellow")
            self._pause()
            return

        self.state.active_screen = "result_review"  # Update active screen identifier.
        self.console.clear()  # Clear before rendering results.
        render_run_summary(
            self.console, self.state.last_run
        )  # Show the run summary table.
        instance = self.state.selected_instance or parse_ctt(
            self.state.last_run.instance_path
        )  # Use cached or re-parse.
        render_assignment_views(
            self.console, instance, self.state.last_run
        )  # Show assignment list and grid.
        self._pause()  # Wait for the user to finish reading.

    def _default_solver_runner(
        self, repo_root: Path, instance_path: Path, solver_name: str
    ) -> RunResult:
        """Thin wrapper around run_solver; used as the default solver_runner callable."""
        return run_solver(
            repo_root, instance_path, solver_name
        )  # Delegate to the module-level function.

    def _require_selected_instance(self) -> bool:
        """Return True if an instance is selected; otherwise print an error and return False."""
        if (
            self.state.selected_instance is not None
        ):  # An instance has already been selected.
            return True
        self.console.print(
            "Select an instance first from the main menu.", style="yellow"
        )  # Prompt user.
        self._pause()  # Wait for acknowledgment.
        return False  # Signal that the caller should abort.

    def _pause(self) -> None:
        """Block until the user presses Enter, giving them time to read the current output."""
        self.input_fn(
            "Press Enter to continue..."
        )  # Display prompt and wait for Enter key.
