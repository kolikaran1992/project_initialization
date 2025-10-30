#!/usr/bin/env bash
set -e

# -----------------------------------------
# Auto-initialize a Python project using Poetry
# Author: kolikaran
# -----------------------------------------

# STEP 0 — Get project name from current folder
PROJECT_NAME=$(basename "$PWD")
echo "Initializing project: $PROJECT_NAME"

# STEP 1 — Initialize Poetry project
echo "Running poetry init..."
poetry init --name "$PROJECT_NAME" --author "kolikaran" --no-interaction

# STEP 2 — Create basic structure
echo "Creating $PROJECT_NAME and tests..."
mkdir -p "$PROJECT_NAME"
mkdir -p "tests"
touch "$PROJECT_NAME/__init__.py"

# STEP 3 — Create README.md
echo "Creating README.md..."
cat <<EOF > README.md
# $PROJECT_NAME

Generated Python project managed by Poetry.
EOF

# STEP 4 — Install dependencies
echo "Installing main dependencies..."
poetry add dynaconf jinja2 pytz

echo "Installing development tools (pytest, black, isort)..."
poetry add pytest
poetry add black --dev
poetry add isort --dev

# STEP 5 — Create omniconf.py inside the project folder
echo "Creating $PROJECT_NAME/omniconf.py..."
cat <<EOF > "$PROJECT_NAME/omniconf.py"
from pathlib import Path
from datetime import datetime
import os
import pytz
from dynaconf import Dynaconf


_NOW = datetime.now()
_BASE_DIR = Path(__file__).resolve().parent


def _get_start_ts(tz: str) -> datetime:
    return _NOW.astimezone(pytz.timezone(tz))


def _get_now_iso(tz: str) -> str:
    return datetime.now().astimezone(pytz.timezone(tz)).isoformat()


def _get_now_ts(tz: str) -> str:
    return datetime.now().astimezone(pytz.timezone(tz))


###################
# Create Settings #
###################
secrets_dir = os.environ.get("SECRETS_DIRECTORY") or ""
config = Dynaconf(
    preload=[_BASE_DIR.joinpath("settings_file", "settings.toml").as_posix()],
    settings_files=[],
    secrets=[] if not secrets_dir else list(Path(secrets_dir).glob("*.toml")),
    # to enable overriding of single variables at runtime
    environments=True,
    envvar_prefix="EXP_BASE",
    # to enable merging of user defined and base settings
    load_dotenv=True,
    # jinja variables
    _get_now_ts=_get_now_ts,
    _get_now_iso=_get_now_iso,
    _get_start_ts=_get_start_ts,
    now=_NOW,
    partition_date=_NOW.strftime("%Y/%m/%d"),
    root_dir=_BASE_DIR.as_posix(),
    home_dir=Path.home().as_posix(),
    merge_enabled=True,
)
EOF

# STEP 6 — Create settings_file inside project directory
echo "Creating $PROJECT_NAME/settings_file/settings.toml..."
mkdir -p "$PROJECT_NAME/settings_file"
cat <<EOF > "$PROJECT_NAME/settings_file/settings.toml"
[default]
now_iso = "@jinja {{this._get_now_iso(this.tz)}}"
start_ts = "@jinja {{this._get_start_ts(this.tz)}}"
tz = "Asia/Kolkata"
EOF

echo
echo "✅ Project initialized successfully!"
echo "Files generated:"
echo "- pyproject.toml"
echo "- README.md"
echo "- $PROJECT_NAME/__init__.py"
echo "- $PROJECT_NAME/omniconf.py"
echo "- $PROJECT_NAME/settings_file/settings.toml"
