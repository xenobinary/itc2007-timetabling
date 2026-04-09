from __future__ import annotations  # Enable postponed annotation evaluation (PEP 563).

from rich.console import (
    Console,
)  # Console is the rich output driver used to print styled content.
from rich.panel import Panel  # Panel wraps content in a box with an optional title.
from rich.table import (
    Table,
)  # Table renders columnar data with optional headers and styling.

from .models import (
    InstanceData,
    RunResult,
)  # Import domain model types needed for rendering.

# Human-readable descriptions of the six ITC2007 Track 2 hard constraints.
HARD_CONSTRAINTS = (
    "All lectures for every course must be scheduled.",  # H1: lecture coverage.
    "A room cannot host two lectures in the same day and period.",  # H2: room uniqueness.
    "A course cannot be scheduled twice in the same day and period.",  # H3: course conflict.
    "Courses taught by the same teacher cannot overlap.",  # H4: teacher conflict.
    "Courses in the same curriculum cannot overlap.",  # H5: curriculum conflict.
    "A course cannot be placed in an unavailable slot.",  # H6: unavailability.
)

# Human-readable descriptions of the four ITC2007 Track 2 soft constraints.
SOFT_CONSTRAINTS = (
    "Room capacity: students above room capacity add penalty.",  # S1: room capacity.
    "Minimum working days: courses should be spread across enough days.",  # S2: min working days.
    "Curriculum compactness: isolated lectures in a curriculum add penalty.",  # S3: compactness.
    "Room stability: using extra rooms for one course adds penalty.",  # S4: room stability.
)


def render_main_menu(
    console: Console, selected_label: str, last_run_label: str
) -> None:
    """Print the main menu table and current session status panel."""
    menu = Table(
        title="Course Timetabling TUI", show_header=False, box=None
    )  # Menu table without header/border.
    menu.add_column(
        "Option", style="cyan"
    )  # Left column for option numbers, styled cyan.
    menu.add_column("Action")  # Right column for action descriptions.
    menu.add_row("1", "Select timetable instance")  # Option 1.
    menu.add_row("2", "View selected instance summary")  # Option 2.
    menu.add_row("3", "View hard and soft constraints")  # Option 3.
    menu.add_row("4", "Run solver")  # Option 4.
    menu.add_row("5", "Review last result")  # Option 5.
    menu.add_row("6", "Exit")  # Option 6.
    console.print(
        Panel.fit(f"Selected instance: {selected_label}\nLast run: {last_run_label}")
    )  # Status panel.
    console.print(menu)  # Print the menu table below the status panel.


def render_instance_choices(console: Console, instance_paths: list[str]) -> None:
    """Print a numbered table of available .ctt instance file paths."""
    table = Table(title="Available Timetable Instances")  # Table with title.
    table.add_column("#", style="cyan")  # Index column styled cyan.
    table.add_column("Path")  # Path column.
    for index, path in enumerate(
        instance_paths, start=1
    ):  # Enumerate starting from 1 for display.
        table.add_row(str(index), path)  # Add one row per instance.
    console.print(table)  # Print the populated table.


def render_instance_summary(console: Console, instance: InstanceData) -> None:
    """Print a full summary of an instance: overview, courses, rooms, curricula, unavailability."""
    # Overview table with key/value rows.
    overview = Table(
        title=f"Instance Overview: {instance.name}"
    )  # Title includes instance name.
    overview.add_column("Field", style="cyan")  # Field name column styled cyan.
    overview.add_column("Value")  # Value column.
    overview.add_row("Source", str(instance.source_path))  # File path row.
    overview.add_row("Courses", str(instance.courses_count))  # Course count row.
    overview.add_row("Rooms", str(instance.rooms_count))  # Room count row.
    overview.add_row("Days", str(instance.days))  # Day count row.
    overview.add_row(
        "Periods / Day", str(instance.periods_per_day)
    )  # Periods-per-day row.
    overview.add_row(
        "Curricula", str(instance.curricula_count)
    )  # Curriculum count row.
    overview.add_row(
        "Unavailable Slots", str(instance.constraints_count)
    )  # Constraint count row.
    console.print(overview)  # Print the overview table.

    # Courses table listing all course entities.
    courses = Table(title="Courses")  # Table for course details.
    for column in (
        "Course",
        "Teacher",
        "Lectures",
        "Min Days",
        "Students",
    ):  # Define columns.
        courses.add_column(column)  # Add each column by name.
    for course in instance.courses:  # Iterate over all parsed courses.
        courses.add_row(
            course.course_id,  # Course identifier.
            course.teacher_id,  # Teacher identifier.
            str(course.lectures),  # Required lecture count.
            str(course.min_days),  # Minimum spread across days.
            str(course.students),  # Enrolled student count.
        )
    console.print(courses)  # Print the courses table.

    # Rooms table listing all room entities.
    rooms = Table(title="Rooms")  # Table for room details.
    rooms.add_column("Room")  # Room identifier column.
    rooms.add_column("Capacity")  # Room capacity column.
    for room in instance.rooms:  # Iterate over all parsed rooms.
        rooms.add_row(room.room_id, str(room.capacity))  # Add one row per room.
    console.print(rooms)  # Print the rooms table.

    # Curricula table listing course groups.
    curricula = Table(title="Curricula")  # Table for curriculum groups.
    curricula.add_column("Curriculum")  # Curriculum identifier column.
    curricula.add_column("Courses")  # Comma-joined course IDs column.
    for curriculum in instance.curricula:  # Iterate over all parsed curricula.
        curricula.add_row(
            curriculum.curriculum_id, ", ".join(curriculum.courses)
        )  # Join courses as CSV.
    console.print(curricula)  # Print the curricula table.

    # Unavailability constraints table.
    unavailable = Table(title="Unavailable Slots")  # Table for unavailability entries.
    unavailable.add_column("Course")  # Course identifier column.
    unavailable.add_column("Day")  # Day index column.
    unavailable.add_column("Period")  # Period index column.
    for slot in instance.unavailability:  # Iterate over all unavailability constraints.
        unavailable.add_row(
            slot.course_id, str(slot.day), str(slot.period)
        )  # Add one row per constraint.
    console.print(unavailable)  # Print the unavailability table.


def render_constraints(console: Console) -> None:
    """Print the hard and soft constraint descriptions as two separate tables."""
    hard = Table(title="Hard Constraints")  # Table listing hard constraints.
    hard.add_column("Constraint")  # Single column for constraint descriptions.
    for description in HARD_CONSTRAINTS:  # Iterate over the six hard constraints.
        hard.add_row(description)  # Add one row per constraint.
    console.print(hard)  # Print the hard constraints table.

    soft = Table(title="Soft Constraints")  # Table listing soft constraints.
    soft.add_column("Constraint")  # Single column for constraint descriptions.
    for description in SOFT_CONSTRAINTS:  # Iterate over the four soft constraints.
        soft.add_row(description)  # Add one row per constraint.
    console.print(soft)  # Print the soft constraints table.


def render_run_summary(console: Console, result: RunResult) -> None:
    """Print a key/value summary table for a completed solver run."""
    status = (
        "Feasible" if result.feasible else "Infeasible"
    )  # Map boolean to display string.
    summary = Table(title="Run Summary")  # Summary table with title.
    summary.add_column("Field", style="cyan")  # Field name column styled cyan.
    summary.add_column("Value")  # Value column.
    summary.add_row("Instance", str(result.instance_path))  # Instance file path row.
    summary.add_row("Solver", result.solver_name)  # Solver name row.
    summary.add_row("Status", status)  # Feasibility status row.
    summary.add_row("Penalty", str(result.penalty))  # Soft-constraint penalty row.
    summary.add_row("Exit Code", str(result.exit_code))  # Process exit code row.
    summary.add_row(
        "Solution File", str(result.solution_path)
    )  # Solution file path row.
    summary.add_row("Stats File", str(result.stats_path))  # Stats CSV file path row.
    console.print(summary)  # Print the run summary table.


def render_assignment_views(
    console: Console, instance: InstanceData, result: RunResult
) -> None:
    """Print both a flat assignment list and a day×period timetable grid."""
    # Flat assignment table sorted by (day, period, room, course) for readability.
    assignments = Table(title="Assignments")  # Table listing individual assignments.
    assignments.add_column("Course")  # Course identifier column.
    assignments.add_column("Room")  # Room identifier column.
    assignments.add_column("Day")  # Day index column.
    assignments.add_column("Period")  # Period index column.
    for assignment in sorted(
        result.assignments,
        key=lambda item: (item.day, item.period, item.room_id, item.course_id),
    ):  # Sort for stable display order.
        assignments.add_row(
            assignment.course_id,  # Course ID for this assignment.
            assignment.room_id,  # Room ID for this assignment.
            str(assignment.day),  # Day index as string.
            str(assignment.period),  # Period index as string.
        )
    console.print(assignments)  # Print the flat assignment table.

    # Timetable grid: rows = periods, columns = days; each cell lists "CourseId@RoomId" entries.
    grid = Table(title="Timetable Grid")  # Grid table with title.
    grid.add_column(
        "Period", style="cyan"
    )  # First column is the period index, styled cyan.
    for day in range(instance.days):  # Add one column per scheduling day.
        grid.add_column(f"Day {day}")  # Header is "Day 0", "Day 1", etc.

    for period in range(instance.periods_per_day):  # Iterate over each period row.
        row = [str(period)]  # First cell is the period index.
        for day in range(instance.days):  # Iterate over each day cell in this row.
            matches = [
                f"{assignment.course_id}@{assignment.room_id}"  # Format as "Course@Room".
                for assignment in result.assignments
                if assignment.day == day
                and assignment.period == period  # Filter to this cell.
            ]
            row.append(
                "\n".join(matches) if matches else "-"
            )  # Join multiple events with newline; "-" if empty.
        grid.add_row(*row)  # Add the complete period row to the grid.
    console.print(grid)  # Print the timetable grid.
