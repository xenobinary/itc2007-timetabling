from __future__ import annotations  # Enable postponed annotation evaluation (PEP 563).

from pathlib import Path  # Path provides OS-agnostic filesystem path manipulation.

from .models import (
    Course,
    Curriculum,
    InstanceData,
    Room,
    Unavailability,
)  # Import domain model types.

# Section header labels as they appear verbatim in ITC2007 .ctt files.
SECTION_LABELS = (
    "COURSES:",  # Marks the start of the COURSES section.
    "ROOMS:",  # Marks the start of the ROOMS section.
    "CURRICULA:",  # Marks the start of the CURRICULA section.
    "UNAVAILABILITY_CONSTRAINTS:",  # Marks the start of the UNAVAILABILITY_CONSTRAINTS section.
)


def discover_instance_paths(repo_root: Path) -> list[Path]:
    """Return sorted .ctt file paths found in the known instance directories."""
    candidates: list[Path] = []  # Accumulate discovered paths here.
    for relative_dir in (
        Path("data/itc2007"),
        Path("tests/fixtures"),
    ):  # Check both data dirs.
        directory = repo_root / relative_dir  # Resolve to an absolute path.
        if (
            directory.exists()
        ):  # Skip dirs that do not exist (e.g. data/ not yet downloaded).
            candidates.extend(
                sorted(directory.glob("*.ctt"))
            )  # Add sorted .ctt files from this dir.
    return candidates  # Return the combined list of discovered instances.


def parse_ctt(path: Path) -> InstanceData:
    """Parse an ITC2007 Track 2 .ctt file and return a fully populated InstanceData."""
    raw_lines = path.read_text(
        encoding="utf-8"
    ).splitlines()  # Read the file and split into lines.
    lines = [
        line.strip() for line in raw_lines if line.strip()
    ]  # Strip whitespace; skip blank lines.

    header: dict[str, str] = {}  # Collect "Key: Value" pairs from the file header.
    index = 0  # Current line index into the stripped lines list.
    while (
        index < len(lines) and lines[index] not in SECTION_LABELS
    ):  # Consume header until first section.
        key, _, value = lines[index].partition(
            ":"
        )  # Split on first colon into key and value.
        if not value:  # A line without a colon value is malformed.
            raise ValueError(f"Invalid header line: {lines[index]}")
        header[key.strip()] = value.strip()  # Store the trimmed key/value pair.
        index += 1  # Advance to the next line.

    def require_header(name: str) -> str:
        """Retrieve a mandatory header field, raising ValueError if absent."""
        if name not in header:  # Check the key exists in the parsed header dict.
            raise ValueError(f"Missing header field: {name}")
        return header[name]  # Return the string value.

    # Parse integer header fields.
    courses_count = int(require_header("Courses"))  # Number of courses declared.
    rooms_count = int(require_header("Rooms"))  # Number of rooms declared.
    days = int(require_header("Days"))  # Number of scheduling days.
    periods_per_day = int(
        require_header("Periods_per_day")
    )  # Periods per scheduling day.
    curricula_count = int(require_header("Curricula"))  # Number of curricula declared.
    constraints_count = int(
        require_header("Constraints")
    )  # Number of unavailability constraints.

    # Parse COURSES section.
    index = _expect_label(lines, index, "COURSES:")  # Advance past the COURSES: label.
    course_lines, index = _take_exact(
        lines, index, courses_count
    )  # Read exactly courses_count lines.
    courses = tuple(
        _parse_course(line) for line in course_lines
    )  # Convert each line to a Course.

    # Parse ROOMS section.
    index = _expect_label(lines, index, "ROOMS:")  # Advance past the ROOMS: label.
    room_lines, index = _take_exact(
        lines, index, rooms_count
    )  # Read exactly rooms_count lines.
    rooms = tuple(
        _parse_room(line) for line in room_lines
    )  # Convert each line to a Room.

    # Parse CURRICULA section.
    index = _expect_label(
        lines, index, "CURRICULA:"
    )  # Advance past the CURRICULA: label.
    curriculum_lines, index = _take_exact(
        lines, index, curricula_count
    )  # Read exactly curricula_count lines.
    curricula = tuple(
        _parse_curriculum(line) for line in curriculum_lines
    )  # Convert each line to a Curriculum.

    # Parse UNAVAILABILITY_CONSTRAINTS section.
    index = _expect_label(
        lines, index, "UNAVAILABILITY_CONSTRAINTS:"
    )  # Advance past label.
    unavailability_lines, index = _take_exact(
        lines, index, constraints_count
    )  # Read constraint lines.
    unavailability = tuple(
        _parse_unavailability(line) for line in unavailability_lines
    )  # Convert each line.

    if (
        index < len(lines) and lines[index] != "END."
    ):  # Optional validation of the END. sentinel.
        raise ValueError(f"Expected END. but found: {lines[index]}")

    # Construct and return the fully populated InstanceData.
    return InstanceData(
        source_path=path,  # Store the original file path.
        name=require_header("Name"),  # Instance name string.
        courses_count=courses_count,  # Header-declared course count.
        rooms_count=rooms_count,  # Header-declared room count.
        days=days,  # Header-declared day count.
        periods_per_day=periods_per_day,  # Header-declared periods-per-day.
        curricula_count=curricula_count,  # Header-declared curriculum count.
        constraints_count=constraints_count,  # Header-declared constraint count.
        courses=courses,  # Parsed Course tuple.
        rooms=rooms,  # Parsed Room tuple.
        curricula=curricula,  # Parsed Curriculum tuple.
        unavailability=unavailability,  # Parsed Unavailability tuple.
    )


def _expect_label(lines: list[str], index: int, label: str) -> int:
    """Assert the current line equals label and return the next index."""
    if (
        index >= len(lines) or lines[index] != label
    ):  # Check that the expected label is present.
        found = (
            lines[index] if index < len(lines) else "<EOF>"
        )  # Describe what was found instead.
        raise ValueError(f"Expected {label} but found {found}")
    return index + 1  # Advance past the label line.


def _take_exact(lines: list[str], index: int, count: int) -> tuple[list[str], int]:
    """Extract exactly count lines starting at index; return (slice, new_index)."""
    end_index = index + count  # Compute the exclusive end of the slice.
    if end_index > len(lines):  # Guard against reading past end of file.
        raise ValueError(f"Expected {count} lines but file ended early")
    return lines[index:end_index], end_index  # Return the slice and the advanced index.


def _parse_course(line: str) -> Course:
    """Parse a single whitespace-separated course line into a Course dataclass."""
    course_id, teacher_id, lectures, min_days, students = (
        line.split()
    )  # Unpack exactly 5 fields.
    return Course(
        course_id, teacher_id, int(lectures), int(min_days), int(students)
    )  # Construct Course.


def _parse_room(line: str) -> Room:
    """Parse a single whitespace-separated room line into a Room dataclass."""
    room_id, capacity = line.split()  # Unpack exactly 2 fields.
    return Room(room_id, int(capacity))  # Construct Room.


def _parse_curriculum(line: str) -> Curriculum:
    """Parse a curriculum line (id, count, course…) into a Curriculum dataclass."""
    parts = line.split()  # Split on whitespace.
    curriculum_id = parts[0]  # First token is the curriculum ID.
    count = int(parts[1])  # Second token is the declared number of member courses.
    courses = tuple(parts[2:])  # Remaining tokens are course IDs.
    if (
        len(courses) != count
    ):  # Validate that the declared count matches actual entries.
        raise ValueError(f"Curriculum {curriculum_id} expected {count} courses")
    return Curriculum(curriculum_id, courses)  # Construct Curriculum.


def _parse_unavailability(line: str) -> Unavailability:
    """Parse a single unavailability constraint line into an Unavailability dataclass."""
    course_id, day, period = line.split()  # Unpack exactly 3 fields.
    return Unavailability(course_id, int(day), int(period))  # Construct Unavailability.
