"""Entry point for the ACEest Fitness & Gym Flask application.

``ACEest_Fitness.py`` is the name used throughout the assignment; ``app.py``
is kept as a thin alias so existing tooling continues to work.

Run locally with:
    python ACEest_Fitness.py
"""

import os

from aceest import create_app

app = create_app(os.environ.get("FLASK_CONFIG", "config.DevelopmentConfig"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
