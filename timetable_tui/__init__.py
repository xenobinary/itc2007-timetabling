from .app import (
    TerminalApp,
)  # Re-export TerminalApp so callers can import from the package root.

__all__ = [
    "TerminalApp"
]  # Declare the public API of this package; only TerminalApp is exported.
