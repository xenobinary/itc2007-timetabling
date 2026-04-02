from __future__ import annotations

from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from .models import InstanceData, RunResult

HARD_CONSTRAINTS = (
    "All lectures for every course must be scheduled.",
    "A room cannot host two lectures in the same day and period.",
    "A course cannot be scheduled twice in the same day and period.",
    "Courses taught by the same teacher cannot overlap.",
    "Courses in the same curriculum cannot overlap.",
    "A course cannot be placed in an unavailable slot.",
)

SOFT_CONSTRAINTS = (
    "Room capacity: students above room capacity add penalty.",
    "Minimum working days: courses should be spread across enough days.",
    "Curriculum compactness: isolated lectures in a curriculum add penalty.",
    "Room stability: using extra rooms for one course adds penalty.",
)


def render_main_menu(console: Console, selected_label: str, last_run_label: str) -> None:
    menu = Table(title="Course Timetabling TUI", show_header=False, box=None)
    menu.add_column("Option", style="cyan")
    menu.add_column("Action")
    menu.add_row("1", "Select timetable instance")
    menu.add_row("2", "View selected instance summary")
    menu.add_row("3", "View hard and soft constraints")
    menu.add_row("4", "Run solver")
    menu.add_row("5", "Review last result")
    menu.add_row("6", "Exit")
    console.print(Panel.fit(f"Selected instance: {selected_label}\nLast run: {last_run_label}"))
    console.print(menu)


def render_instance_choices(console: Console, instance_paths: list[str]) -> None:
    table = Table(title="Available Timetable Instances")
    table.add_column("#", style="cyan")
    table.add_column("Path")
    for index, path in enumerate(instance_paths, start=1):
        table.add_row(str(index), path)
    console.print(table)


def render_instance_summary(console: Console, instance: InstanceData) -> None:
    overview = Table(title=f"Instance Overview: {instance.name}")
    overview.add_column("Field", style="cyan")
    overview.add_column("Value")
    overview.add_row("Source", str(instance.source_path))
    overview.add_row("Courses", str(instance.courses_count))
    overview.add_row("Rooms", str(instance.rooms_count))
    overview.add_row("Days", str(instance.days))
    overview.add_row("Periods / Day", str(instance.periods_per_day))
    overview.add_row("Curricula", str(instance.curricula_count))
    overview.add_row("Unavailable Slots", str(instance.constraints_count))
    console.print(overview)

    courses = Table(title="Courses")
    for column in ("Course", "Teacher", "Lectures", "Min Days", "Students"):
        courses.add_column(column)
    for course in instance.courses:
        courses.add_row(
            course.course_id,
            course.teacher_id,
            str(course.lectures),
            str(course.min_days),
            str(course.students),
        )
    console.print(courses)

    rooms = Table(title="Rooms")
    rooms.add_column("Room")
    rooms.add_column("Capacity")
    for room in instance.rooms:
        rooms.add_row(room.room_id, str(room.capacity))
    console.print(rooms)

    curricula = Table(title="Curricula")
    curricula.add_column("Curriculum")
    curricula.add_column("Courses")
    for curriculum in instance.curricula:
        curricula.add_row(curriculum.curriculum_id, ", ".join(curriculum.courses))
    console.print(curricula)

    unavailable = Table(title="Unavailable Slots")
    unavailable.add_column("Course")
    unavailable.add_column("Day")
    unavailable.add_column("Period")
    for slot in instance.unavailability:
        unavailable.add_row(slot.course_id, str(slot.day), str(slot.period))
    console.print(unavailable)


def render_constraints(console: Console) -> None:
    hard = Table(title="Hard Constraints")
    hard.add_column("Constraint")
    for description in HARD_CONSTRAINTS:
        hard.add_row(description)
    console.print(hard)

    soft = Table(title="Soft Constraints")
    soft.add_column("Constraint")
    for description in SOFT_CONSTRAINTS:
        soft.add_row(description)
    console.print(soft)


def render_run_summary(console: Console, result: RunResult) -> None:
    status = "Feasible" if result.feasible else "Infeasible"
    summary = Table(title="Run Summary")
    summary.add_column("Field", style="cyan")
    summary.add_column("Value")
    summary.add_row("Instance", str(result.instance_path))
    summary.add_row("Solver", result.solver_name)
    summary.add_row("Status", status)
    summary.add_row("Penalty", str(result.penalty))
    summary.add_row("Exit Code", str(result.exit_code))
    summary.add_row("Solution File", str(result.solution_path))
    summary.add_row("Stats File", str(result.stats_path))
    console.print(summary)


def render_assignment_views(console: Console, instance: InstanceData, result: RunResult) -> None:
    assignments = Table(title="Assignments")
    assignments.add_column("Course")
    assignments.add_column("Room")
    assignments.add_column("Day")
    assignments.add_column("Period")
    for assignment in sorted(result.assignments, key=lambda item: (item.day, item.period, item.room_id, item.course_id)):
        assignments.add_row(
            assignment.course_id,
            assignment.room_id,
            str(assignment.day),
            str(assignment.period),
        )
    console.print(assignments)

    grid = Table(title="Timetable Grid")
    grid.add_column("Period", style="cyan")
    for day in range(instance.days):
        grid.add_column(f"Day {day}")

    for period in range(instance.periods_per_day):
        row = [str(period)]
        for day in range(instance.days):
            matches = [
                f"{assignment.course_id}@{assignment.room_id}"
                for assignment in result.assignments
                if assignment.day == day and assignment.period == period
            ]
            row.append("\n".join(matches) if matches else "-")
        grid.add_row(*row)
    console.print(grid)