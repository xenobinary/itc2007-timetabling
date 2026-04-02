from pathlib import Path

from .app import TerminalApp


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    app = TerminalApp(repo_root)
    app.run()


if __name__ == "__main__":
    main()