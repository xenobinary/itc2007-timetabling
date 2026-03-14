# Data

Place ITC2007 Track 2 (Curriculum-based Course Timetabling) instance files here.

Recommended layout:

```
data/
  itc2007/
    comp01.ctt
    comp02.ctt
    ...
```

## Why the dataset is not included
ITC2007 instances may be subject to redistribution restrictions depending on where you obtained them.
Keep them out of git unless you have explicit permission.

## Official source
https://www.eeecs.qub.ac.uk/itc2007/Login/SecretPage.php

## What the code expects
- Instance path passed via `--instance` points to a single `.ctt` file.
- Output solution path passed via `--out`.

## Tip
If you have multiple instances, you can benchmark them with `scripts/benchmark.sh` (created in this repo).
