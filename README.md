# ITC2007 Course Timetabling Expert System (Prolog)

Rule-based expert system for **Course Timetabling** using **ITC2007** (Track 2: Curriculum-based Course Timetabling).

## What you’ll deliver
- **Code**: Prolog solver + rule base + parsers.
- **Tests**: unit/integration tests + reproducible runs.
- **Test results**: recorded solver runs for selected instances.
- **Proposal / Report / Research paper / Presentation**: in `docs/`.

## Quick start (SWI‑Prolog)
1. Install SWI‑Prolog:
   - Ubuntu/Debian: `sudo apt-get install swi-prolog`
2. Put ITC2007 Track 2 instances under `data/itc2007/` (see data/README.md).
3. Run a solve (example):
   - `make run INSTANCE=data/itc2007/comp01.ctt OUT=results/comp01.sol`
   - `make run-clpfd INSTANCE=data/itc2007/comp01.ctt OUT=results/comp01-clpfd.sol TIMEOUT=120`
   - `make run-all-constructive INST_DIR=data/itc2007 OUT_DIR=results/constructive-batch TIMEOUT=120`
   - `make run-all-clpfd INST_DIR=data/itc2007 OUT_DIR=results/clpfd-batch TIMEOUT=120`
   - `swipl -q -g "['src/main'], main(['--instance','data/itc2007/comp01.ctt','--out','results/comp01.sol','--solver','clpfd'])" -t halt`

## Dataset source
The ITC2007 instances were obtained from the official ITC2007 site:
https://www.eeecs.qub.ac.uk/itc2007/Login/SecretPage.php

## ITC2007 Track 2 (.ctt) file structure
Each .ctt file is a plain-text instance with:

1) Header (global metadata)
- Name: instance name
- Courses: number of course rows in COURSES:
- Rooms: number of room rows in ROOMS:
- Days: number of days in the planning horizon
- Periods_per_day: number of periods per day
- Curricula: number of curriculum rows in CURRICULA:
- Constraints: number of rows in UNAVAILABILITY_CONSTRAINTS:

2) Sections (in this order)

COURSES:
- Format per line: CourseId TeacherId Lectures MinDays Students
   - Lectures: how many lectures must be scheduled for the course
   - MinDays: minimum distinct days (soft constraint)
   - Students: enrollment (used for room capacity penalty)

ROOMS:
- Format per line: RoomId Capacity

CURRICULA:
- Format per line: CurriculumId NumCourses CourseId1 ... CourseIdN
   - Courses in the same curriculum cannot overlap (hard constraint)

UNAVAILABILITY_CONSTRAINTS:
- Format per line: CourseId Day Period
   - Day and Period are 0-based indices

END.

See data/README.md for the recommended folder layout and notes about not committing the dataset.

## Repository layout
- `src/` Prolog source code
  - `src/itc2007/` parsers + instance model
  - `src/rules/` hard/soft constraints as rules
  - `src/solver/` constructive search engine
  - `src/output/` solution writer
- `tests/` Prolog tests (plunit)
- `docs/` proposal/report/paper/presentation templates
- `results/` run outputs and summary tables

## Milestones (suggested)
- M1: Parse ITC2007 `.ctt` + build the instance model.
- M2: Implement hard constraints + feasibility checker.
- M3: Add soft constraints + objective (penalty).
- M4: Improve the constructive search strategy and compare solver runs.
- M5: Write-up + presentation.

## Notes
- Do **not** commit the ITC2007 dataset if licensing forbids redistribution. Keep instances local and document how to obtain them.
