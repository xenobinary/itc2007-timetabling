from __future__ import (
    annotations,
)  # Enable postponed evaluation of annotations (PEP 563).

from dataclasses import (
    dataclass,
    field,
)  # dataclass decorator for auto-generated boilerplate; field for defaults.
from pathlib import Path  # Path provides OS-agnostic filesystem path manipulation.


@dataclass(
    frozen=True
)  # Immutable dataclass: instances are hashable and cannot be mutated after creation.
class Course:
    """Represents a single course entry from an ITC2007 .ctt instance file."""

    course_id: str  # Unique string identifier for the course (e.g. "C1").
    teacher_id: str  # Identifier of the teacher responsible for this course.
    lectures: int  # Total number of lecture sessions that must be scheduled.
    min_days: int  # Minimum number of distinct days on which lectures must be spread.
    students: (
        int  # Number of enrolled students; used for room capacity soft constraint.
    )


@dataclass(frozen=True)  # Immutable dataclass.
class Room:
    """Represents a room available for scheduling."""

    room_id: str  # Unique string identifier for the room (e.g. "R1").
    capacity: int  # Maximum number of students the room can accommodate.


@dataclass(frozen=True)  # Immutable dataclass.
class Curriculum:
    """Represents a group of courses that share the same student cohort."""

    curriculum_id: str  # Unique string identifier for the curriculum (e.g. "CURR1").
    courses: tuple[
        str, ...
    ]  # Ordered tuple of course IDs belonging to this curriculum.


@dataclass(frozen=True)  # Immutable dataclass.
class Unavailability:
    """Records a single unavailability constraint: a course must not be placed at (day, period)."""

    course_id: str  # The course that is unavailable at the given slot.
    day: int  # Zero-based index of the day on which the course is unavailable.
    period: int  # Zero-based index of the period within the day on which the course is unavailable.


@dataclass(frozen=True)  # Immutable dataclass.
class Assignment:
    """Represents a single scheduled lecture: a course placed in a room at (day, period)."""

    course_id: str  # The course being scheduled.
    room_id: str  # The room in which the lecture is held.
    day: int  # Zero-based day index.
    period: int  # Zero-based period index within the day.


@dataclass(frozen=True)  # Immutable dataclass.
class InstanceData:
    """Complete in-memory representation of one ITC2007 Track 2 problem instance."""

    source_path: Path  # Filesystem path to the original .ctt file.
    name: str  # Instance name string from the file header.
    courses_count: int  # Declared number of courses (from header).
    rooms_count: int  # Declared number of rooms (from header).
    days: int  # Number of scheduling days (from header).
    periods_per_day: int  # Number of periods per day (from header).
    curricula_count: int  # Declared number of curricula (from header).
    constraints_count: (
        int  # Declared number of unavailability constraints (from header).
    )
    courses: tuple[Course, ...]  # Parsed course entities.
    rooms: tuple[Room, ...]  # Parsed room entities.
    curricula: tuple[Curriculum, ...]  # Parsed curriculum groups.
    unavailability: tuple[Unavailability, ...]  # Parsed unavailability constraints.


@dataclass(
    frozen=True
)  # Immutable dataclass: a solver run result should not be mutated.
class RunResult:
    """Captures all outputs from a single solver invocation."""

    instance_path: Path  # Path to the instance file that was solved.
    solver_name: str  # Name of the solver used (e.g. "constructive" or "clpfd").
    feasible: bool  # True if the returned solution satisfies all hard constraints.
    penalty: int  # Total soft-constraint penalty of the solution (lower is better).
    exit_code: int  # Process exit code returned by the SWI-Prolog subprocess.
    solution_path: Path  # Path where the .sol solution file was written.
    stats_path: Path  # Path where the .csv stats file was written.
    assignments: tuple[
        Assignment, ...
    ]  # Decoded assignment list from the solution file.
    stdout: str = ""  # Captured standard output from the solver subprocess.
    stderr: str = ""  # Captured standard error from the solver subprocess.


@dataclass  # Mutable dataclass: session state is updated throughout the app lifecycle.
class SessionState:
    """Holds the mutable runtime state of a single TUI session."""

    selected_instance: InstanceData | None = (
        None  # The currently selected problem instance, or None.
    )
    active_screen: str = (
        "main_menu"  # Identifier of the screen currently being displayed.
    )
    last_run: RunResult | None = None  # Result of the most recent solver run, or None.
    available_instances: tuple[Path, ...] = field(
        default_factory=tuple
    )  # Discovered .ctt file paths.
