#!/usr/bin/env bash
set -e

# -----------------------------------------
# Auto-initialize a Python project using Poetry
# Author: kolikaran
# -----------------------------------------

# STEP 0 — Get project name from current folder
PROJECT_NAME=$(basename "$PWD")
ENV_PREFIX=$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]')
echo "Initializing project: $PROJECT_NAME (ENV prefix: $ENV_PREFIX)"

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
import logging
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

# Automatically detect .toml config files (excluding settings.toml)
settings_files = [
    path.as_posix() for path in _BASE_DIR.glob("*.toml") if path.stem != "settings"
]

config = Dynaconf(
    preload=[_BASE_DIR.joinpath("settings_file", "settings.toml").as_posix()],
    settings_files=settings_files,
    secrets=[] if not secrets_dir else list(Path(secrets_dir).glob("*.toml")),
    environments=True,
    envvar_prefix="${ENV_PREFIX}",
    load_dotenv=True,
    _get_now_ts=_get_now_ts,
    _get_now_iso=_get_now_iso,
    _get_start_ts=_get_start_ts,
    now=_NOW,
    partition_date=_NOW.strftime("%Y/%m/%d"),
    root_dir=_BASE_DIR.as_posix(),
    home_dir=Path.home().as_posix(),
    merge_enabled=True,
)

#########################
# Logger Initialization #
#########################
class DefaultFormatter(logging.Formatter):
    def __init__(self, fmt=None, datefmt=None):
        super().__init__(fmt=fmt, datefmt=datefmt)

    def formatTime(self, record, datefmt=None):
        dt = datetime.fromtimestamp(record.created, pytz.timezone(config.get("tz")))
        if datefmt:
            return dt.strftime(datefmt)
        return dt.isoformat()

    def format(self, record):
        record.full_path = record.pathname
        return super().format(record)


logger = logging.getLogger(config.logger_name)
logger.setLevel(logging.INFO)

fmt = "[%(asctime)s] %(levelname)s [%(full_path)s]: %(message)s"
formatter = DefaultFormatter(fmt=fmt)

stream_handler = logging.StreamHandler()
stream_handler.setLevel(logger.level)
stream_handler.setFormatter(formatter)
logger.addHandler(stream_handler)
EOF

# STEP 6 — Create settings_file inside project directory
echo "Creating $PROJECT_NAME/settings_file/settings.toml..."
mkdir -p "$PROJECT_NAME/settings_file"
cat <<EOF > "$PROJECT_NAME/settings_file/settings.toml"
[default]
now_iso = "@jinja {{this._get_now_iso(this.tz)}}"
start_ts = "@jinja {{this._get_start_ts(this.tz)}}"
tz = "Asia/Kolkata"
logger_name = "$PROJECT_NAME"
EOF


# STEP 7 — Create agent.md in project root
echo "Creating agent.md..."
cat <<EOF > agent.md
# Project Overview

This project is an auto-initialized Python template managed by Poetry.
It provides a clean structure for configuration management using Dynaconf, along with support libraries like Jinja2 and pytz.

## 📁 Project Structure

\`\`\`
project_root/
│
├── pyproject.toml # Poetry configuration & dependencies
├── README.md # Documentation for humans & LLM agents
├── omniconf.py # Base configuration loader using Dynaconf
├── settings_file/ # Directory holding main Dynaconf settings
│ └── settings.toml # Default settings loaded by omniconf
│
├── $PROJECT_NAME/ # Main Python package
│ └── __init__.py
│
└── tests/ # Pytest test directory
\`\`\`

## ✅ What Each File Does

### \`omniconf.py\`
- Central config loader for the entire project
- Loads \`settings.toml\`
- Injects useful Jinja variables (\`now\`, timezone helpers)
- Sets base paths and timestamp values
- ✅ Initializes a global logger available across the project

To log messages:

\`\`\`python
from $PROJECT_NAME.omniconf import logger
logger.info("This is a log message")
\`\`\`

### \`settings_file/settings.toml\`
- Contains default configuration values
- Uses Jinja2 templating inside Dynaconf
- Includes logger_name which is set to the project root name

Example:
\`\`\`
[default]
now_iso = "@jinja {{this._get_now_iso(this.tz)}}"
start_ts = "@jinja {{this._get_start_ts(this.tz)}}"
tz = "Asia/Kolkata"
logger_name = "$PROJECT_NAME"
\`\`\`

If an AI agent needs to modify configuration behavior, it should edit:
- \`omniconf.py\` for logic or environment variable handling
- \`settings.toml\` for changing configuration defaults

## 🔧 Extending the Project
- Add new settings in \`settings_file/settings.toml\`
- Add new Python modules inside \`$PROJECT_NAME/\`
- Add tests inside \`tests/\`
EOF


echo
echo "✅ Project initialized successfully!"
echo "Files generated:"
echo "- pyproject.toml"
echo "- README.md"
echo "- $PROJECT_NAME/__init__.py"
echo "- $PROJECT_NAME/omniconf.py"
echo "- $PROJECT_NAME/settings_file/settings.toml"
echo "- agent.md"
