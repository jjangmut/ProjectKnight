# Legacy Production System Removal

Removed on isolated branch studio/production-v3-cleanroom, with Git history retained:
- Old AGENTS.md and PROJECT_RULES.md (replaced by clean root entry + STUDIO_V3 roles).
- Old STATE.md (replaced by clean restart state).
- Previous WORK/, ART_REVIEW/, QA_REVIEW/, REVIEW/, QA/, PERF/ reports and screenshots.
- Previous daily_reports and self-reported quality numbers.
- Old batch-based continuous/daily runner and scheduling helper files.
- Old daily_dev_process_runner.gd and studio_auto_pipeline_suite.gd pseudo-agent runners.

Not removed: playable game source, game art assets, 3D side-quarter-view scenes, other gameplay/regression tests, Git history, main branch.
No automated task scheduler was unregistered on any user's Windows machine; source removal does not remove locally installed Windows scheduled tasks.
