from __future__ import annotations

import csv
import subprocess
from datetime import datetime
from pathlib import Path

from .models import Assignment, RunResult


def run_solver(
    repo_root: Path,
    instance_path: Path,
    solver_name: str,
    *,
    seed: int = 0,
    timelimit: int = 30,
) -> RunResult:
    output_dir = repo_root / "results" / "tui"
    output_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    stem = instance_path.stem
    solution_path = output_dir / f"{stem}-{solver_name}-{timestamp}.sol"
    stats_path = output_dir / f"{stem}-{solver_name}-{timestamp}.csv"

    argv = [
        "--instance",
        _repo_relative(repo_root, instance_path),
        "--out",
        _repo_relative(repo_root, solution_path),
        "--csv",
        _repo_relative(repo_root, stats_path),
        "--solver",
        solver_name,
        "--seed",
        str(seed),
        "--timelimit",
        str(timelimit),
    ]
    goal = f"['src/main'], main([{', '.join(_quote_atom(part) for part in argv)}])"
    command = ["swipl", "-q", "-g", goal, "-t", "halt"]

    completed = subprocess.run(
        command,
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )

    feasible, penalty = _read_stats(stats_path, completed.returncode)
    assignments = _read_solution(solution_path)

    return RunResult(
        instance_path=instance_path,
        solver_name=solver_name,
        feasible=feasible,
        penalty=penalty,
        exit_code=completed.returncode,
        solution_path=solution_path,
        stats_path=stats_path,
        assignments=assignments,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )


def _repo_relative(repo_root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(repo_root))
    except ValueError:
        return str(path)


def _quote_atom(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


def _read_stats(stats_path: Path, exit_code: int) -> tuple[bool, int]:
    if not stats_path.exists():
        return exit_code == 0, 0

    with stats_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        row = next(reader, None)

    if row is None:
        return exit_code == 0, 0

    feasible = str(row.get("feasible", "")).strip().lower() == "true"
    penalty = int(row.get("penalty", "0") or 0)
    return feasible, penalty


def _read_solution(solution_path: Path) -> tuple[Assignment, ...]:
    if not solution_path.exists():
        return tuple()

    assignments: list[Assignment] = []
    for line in solution_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        course_id, room_id, day, period = line.split()
        assignments.append(Assignment(course_id, room_id, int(day), int(period)))
    return tuple(assignments)