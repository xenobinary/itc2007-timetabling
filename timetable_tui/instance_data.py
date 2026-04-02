from __future__ import annotations

from pathlib import Path

from .models import Course, Curriculum, InstanceData, Room, Unavailability

SECTION_LABELS = (
    "COURSES:",
    "ROOMS:",
    "CURRICULA:",
    "UNAVAILABILITY_CONSTRAINTS:",
)


def discover_instance_paths(repo_root: Path) -> list[Path]:
    candidates: list[Path] = []
    for relative_dir in (Path("data/itc2007"), Path("tests/fixtures")):
        directory = repo_root / relative_dir
        if directory.exists():
            candidates.extend(sorted(directory.glob("*.ctt")))
    return candidates


def parse_ctt(path: Path) -> InstanceData:
    raw_lines = path.read_text(encoding="utf-8").splitlines()
    lines = [line.strip() for line in raw_lines if line.strip()]

    header: dict[str, str] = {}
    index = 0
    while index < len(lines) and lines[index] not in SECTION_LABELS:
        key, _, value = lines[index].partition(":")
        if not value:
            raise ValueError(f"Invalid header line: {lines[index]}")
        header[key.strip()] = value.strip()
        index += 1

    def require_header(name: str) -> str:
        if name not in header:
            raise ValueError(f"Missing header field: {name}")
        return header[name]

    courses_count = int(require_header("Courses"))
    rooms_count = int(require_header("Rooms"))
    days = int(require_header("Days"))
    periods_per_day = int(require_header("Periods_per_day"))
    curricula_count = int(require_header("Curricula"))
    constraints_count = int(require_header("Constraints"))

    index = _expect_label(lines, index, "COURSES:")
    course_lines, index = _take_exact(lines, index, courses_count)
    courses = tuple(_parse_course(line) for line in course_lines)

    index = _expect_label(lines, index, "ROOMS:")
    room_lines, index = _take_exact(lines, index, rooms_count)
    rooms = tuple(_parse_room(line) for line in room_lines)

    index = _expect_label(lines, index, "CURRICULA:")
    curriculum_lines, index = _take_exact(lines, index, curricula_count)
    curricula = tuple(_parse_curriculum(line) for line in curriculum_lines)

    index = _expect_label(lines, index, "UNAVAILABILITY_CONSTRAINTS:")
    unavailability_lines, index = _take_exact(lines, index, constraints_count)
    unavailability = tuple(_parse_unavailability(line) for line in unavailability_lines)

    if index < len(lines) and lines[index] != "END.":
        raise ValueError(f"Expected END. but found: {lines[index]}")

    return InstanceData(
        source_path=path,
        name=require_header("Name"),
        courses_count=courses_count,
        rooms_count=rooms_count,
        days=days,
        periods_per_day=periods_per_day,
        curricula_count=curricula_count,
        constraints_count=constraints_count,
        courses=courses,
        rooms=rooms,
        curricula=curricula,
        unavailability=unavailability,
    )


def _expect_label(lines: list[str], index: int, label: str) -> int:
    if index >= len(lines) or lines[index] != label:
        found = lines[index] if index < len(lines) else "<EOF>"
        raise ValueError(f"Expected {label} but found {found}")
    return index + 1


def _take_exact(lines: list[str], index: int, count: int) -> tuple[list[str], int]:
    end_index = index + count
    if end_index > len(lines):
        raise ValueError(f"Expected {count} lines but file ended early")
    return lines[index:end_index], end_index


def _parse_course(line: str) -> Course:
    course_id, teacher_id, lectures, min_days, students = line.split()
    return Course(course_id, teacher_id, int(lectures), int(min_days), int(students))


def _parse_room(line: str) -> Room:
    room_id, capacity = line.split()
    return Room(room_id, int(capacity))


def _parse_curriculum(line: str) -> Curriculum:
    parts = line.split()
    curriculum_id = parts[0]
    count = int(parts[1])
    courses = tuple(parts[2:])
    if len(courses) != count:
        raise ValueError(f"Curriculum {curriculum_id} expected {count} courses")
    return Curriculum(curriculum_id, courses)


def _parse_unavailability(line: str) -> Unavailability:
    course_id, day, period = line.split()
    return Unavailability(course_id, int(day), int(period))