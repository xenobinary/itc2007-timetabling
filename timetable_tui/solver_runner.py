from __future__ import annotations  # Enable postponed annotation evaluation (PEP 563).

import csv  # Standard library CSV reader for parsing the solver stats output file.
import subprocess  # Standard library module for launching the SWI-Prolog subprocess.
from datetime import (
    datetime,
)  # Used to generate timestamp strings for unique output file names.
from pathlib import Path  # Path provides OS-agnostic filesystem path manipulation.

from .models import Assignment, RunResult  # Import output model types.


def run_solver(
    repo_root: Path,  # Absolute path to the repository root directory.
    instance_path: Path,  # Path to the .ctt instance file to be solved.
    solver_name: str,  # Solver strategy: "constructive" or "clpfd".
    *,
    seed: int = 0,  # RNG seed for the solver; 0 means use the default seed.
    timelimit: int = 30,  # Maximum wall-clock seconds allowed for the solver.
) -> RunResult:
    """Invoke the SWI-Prolog solver subprocess and return a RunResult."""
    output_dir = (
        repo_root / "results" / "tui"
    )  # Directory where TUI-generated outputs are stored.
    output_dir.mkdir(
        parents=True, exist_ok=True
    )  # Create the output directory tree if it does not exist.

    timestamp = datetime.now().strftime(
        "%Y%m%d-%H%M%S"
    )  # Human-readable timestamp for unique file names.
    stem = (
        instance_path.stem
    )  # Base name of the instance file without extension (e.g. "comp01").
    solution_path = (
        output_dir / f"{stem}-{solver_name}-{timestamp}.sol"
    )  # Path for the solution file.
    stats_path = (
        output_dir / f"{stem}-{solver_name}-{timestamp}.csv"
    )  # Path for the stats CSV file.

    # Build the SWI-Prolog --instance/--out/--csv/--solver/--seed/--timelimit argument list.
    argv = [
        "--instance",
        _repo_relative(
            repo_root, instance_path
        ),  # Pass instance path relative to repo root.
        "--out",
        _repo_relative(
            repo_root, solution_path
        ),  # Pass output path relative to repo root.
        "--csv",
        _repo_relative(repo_root, stats_path),  # Pass stats path relative to repo root.
        "--solver",
        solver_name,  # Solver strategy name.
        "--seed",
        str(seed),  # RNG seed as a string token.
        "--timelimit",
        str(timelimit),  # Time limit as a string token.
    ]
    # Construct the Prolog goal string: load main.pl then call main/1 with the argument list.
    goal = f"['src/main'], main([{', '.join(_quote_atom(part) for part in argv)}])"
    command = ["swipl", "-q", "-g", goal, "-t", "halt"]  # Full shell command to run.

    # Execute the SWI-Prolog subprocess, capturing stdout/stderr, not raising on nonzero exit.
    completed = subprocess.run(
        command,
        cwd=repo_root,  # Run from repo root so relative paths in the goal resolve correctly.
        capture_output=True,  # Capture stdout and stderr for display in the TUI.
        text=True,  # Decode stdout/stderr as text (UTF-8 by default).
        check=False,  # Do not raise CalledProcessError on non-zero exit.
    )

    feasible, penalty = _read_stats(
        stats_path, completed.returncode
    )  # Parse the CSV stats file.
    assignments = _read_solution(
        solution_path
    )  # Parse the solution file into Assignment objects.

    # Assemble and return the RunResult.
    return RunResult(
        instance_path=instance_path,  # Echo back the instance path.
        solver_name=solver_name,  # Echo back the solver name.
        feasible=feasible,  # Whether the solution is hard-constraint feasible.
        penalty=penalty,  # Total soft-constraint penalty.
        exit_code=completed.returncode,  # Process exit code (0 = success, 2 = infeasible).
        solution_path=solution_path,  # Where the .sol file was written.
        stats_path=stats_path,  # Where the .csv stats file was written.
        assignments=assignments,  # Parsed assignment list.
        stdout=completed.stdout,  # Captured standard output from the solver.
        stderr=completed.stderr,  # Captured standard error from the solver.
    )


def _repo_relative(repo_root: Path, path: Path) -> str:
    """Return path as a string relative to repo_root, or as an absolute string if outside it."""
    try:
        return str(
            path.relative_to(repo_root)
        )  # Express as a relative path when possible.
    except ValueError:
        return str(
            path
        )  # Fall back to the absolute path if it is outside the repo root.


def _quote_atom(value: str) -> str:
    """Wrap a string in single quotes for use as a Prolog atom in a goal string."""
    escaped = value.replace("\\", "\\\\").replace(
        "'", "\\'"
    )  # Escape backslashes then single quotes.
    return f"'{escaped}'"  # Wrap in single quotes to form a Prolog atom literal.


def _read_stats(stats_path: Path, exit_code: int) -> tuple[bool, int]:
    """Read feasibility and penalty from the solver CSV stats file."""
    if (
        not stats_path.exists()
    ):  # Stats file may be absent if the solver failed before writing it.
        return (
            exit_code == 0,
            0,
        )  # Infer feasibility from exit code; assume zero penalty.

    with stats_path.open(
        "r", encoding="utf-8", newline=""
    ) as handle:  # Open for reading.
        reader = csv.DictReader(handle)  # Parse as a CSV with header row.
        row = next(
            reader, None
        )  # Read the first (and only) data row; None if file is empty.

    if row is None:  # Empty stats file: fall back to exit code heuristic.
        return exit_code == 0, 0

    feasible = (
        str(row.get("feasible", "")).strip().lower() == "true"
    )  # Parse feasibility flag.
    penalty = int(
        row.get("penalty", "0") or 0
    )  # Parse penalty; default to 0 if missing.
    return feasible, penalty  # Return parsed values.


def _read_solution(solution_path: Path) -> tuple[Assignment, ...]:
    """Parse a .sol file into a tuple of Assignment objects."""
    if (
        not solution_path.exists()
    ):  # Solution file may be absent if solver did not produce one.
        return tuple()  # Return empty tuple when no solution file was written.

    assignments: list[Assignment] = []  # Accumulate parsed assignments here.
    for line in solution_path.read_text(
        encoding="utf-8"
    ).splitlines():  # Read and split into lines.
        if not line.strip():  # Skip blank lines.
            continue
        course_id, room_id, day, period = (
            line.split()
        )  # Unpack the four whitespace-separated fields.
        assignments.append(
            Assignment(course_id, room_id, int(day), int(period))
        )  # Create Assignment.
    return tuple(assignments)  # Return as an immutable tuple.
