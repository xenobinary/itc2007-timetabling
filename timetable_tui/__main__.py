from pathlib import Path  # Path provides OS-agnostic filesystem path manipulation.

from .app import TerminalApp  # Import the main application class from the app module.


def main() -> None:
    """Entry point called when the package is run with ``python -m timetable_tui``."""
    repo_root = (
        Path(__file__).resolve().parent.parent
    )  # Resolve the repo root two levels up from this file.
    app = TerminalApp(repo_root)  # Instantiate the TUI application with the repo root.
    app.run()  # Start the interactive event loop.


if __name__ == "__main__":
    main()  # Allow running this module directly as a script in addition to -m invocation.
