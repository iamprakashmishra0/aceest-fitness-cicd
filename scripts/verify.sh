#!/usr/bin/env bash
set -euo pipefail

PYTHON="${PYTHON:-python3}"

"$PYTHON" -m compileall -q ACEest_Fitness.py app.py config.py aceest
"$PYTHON" -m flake8 ACEest_Fitness.py app.py config.py aceest tests --count
"$PYTHON" -m pytest --cov=aceest --cov-report=term-missing --cov-fail-under=90
