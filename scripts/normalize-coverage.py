#!/usr/bin/env python3
"""Rewrite absolute coverage sources to project-relative paths for SonarQube."""

import re
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "reports/coverage.xml")
text = path.read_text(encoding="utf-8")
text = re.sub(r"<source>.*?</source>", "<source>aceest</source>", text, count=1)
path.write_text(text, encoding="utf-8")
print(f"Normalised coverage source paths in {path}")
