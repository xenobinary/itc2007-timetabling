from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Course:
    course_id: str
    teacher_id: str
    lectures: int
    min_days: int
    students: int


@dataclass(frozen=True)
class Room:
    room_id: str
    capacity: int


@dataclass(frozen=True)
class Curriculum:
    curriculum_id: str
    courses: tuple[str, ...]


@dataclass(frozen=True)
class Unavailability:
    course_id: str
    day: int
    period: int


@dataclass(frozen=True)
class Assignment:
    course_id: str
    room_id: str
    day: int
    period: int


@dataclass(frozen=True)
class InstanceData:
    source_path: Path
    name: str
    courses_count: int
    rooms_count: int
    days: int
    periods_per_day: int
    curricula_count: int
    constraints_count: int
    courses: tuple[Course, ...]
    rooms: tuple[Room, ...]
    curricula: tuple[Curriculum, ...]
    unavailability: tuple[Unavailability, ...]


@dataclass(frozen=True)
class RunResult:
    instance_path: Path
    solver_name: str
    feasible: bool
    penalty: int
    exit_code: int
    solution_path: Path
    stats_path: Path
    assignments: tuple[Assignment, ...]
    stdout: str = ""
    stderr: str = ""


@dataclass
class SessionState:
    selected_instance: InstanceData | None = None
    active_screen: str = "main_menu"
    last_run: RunResult | None = None
    available_instances: tuple[Path, ...] = field(default_factory=tuple)