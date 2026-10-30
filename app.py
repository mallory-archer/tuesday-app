#!/usr/bin/env python3
"""Serve class names and skill averages from the students table."""

import os
import sys
from pathlib import Path

import psycopg2
from flask import Flask, jsonify, render_template

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"

SKILLS = (
    ("skill_programming", "Programming"),
    ("skill_data_stats", "Data & Stats"),
    ("skill_frontend_design", "Frontend Design"),
    ("skill_business_pitch", "Business Pitch"),
)

app = Flask(__name__)


def load_env(path: Path) -> None:
    if os.environ.get("DATABASE_URL"):
        return
    if not path.exists():
        sys.exit(f"DATABASE_URL is unset and {path} does not exist")
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


def query_class():
    skill_avgs = ", ".join(
        f"ROUND(AVG({column})::numeric, 2)" for column, _label in SKILLS
    )
    with psycopg2.connect(os.environ["DATABASE_URL"], connect_timeout=30) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT name FROM students ORDER BY name")
            names = [row[0] for row in cur.fetchall()]
            cur.execute(f"SELECT {skill_avgs} FROM students")
            row = cur.fetchone()
    averages = []
    for (_column, label), value in zip(SKILLS, row):
        averages.append({
            "label": label,
            "average": None if value is None else float(value),
        })
    return {"names": names, "averages": averages}


@app.get("/")
def index():
    return render_template("index.html")


@app.get("/api/class")
def class_summary():
    try:
        return jsonify(query_class())
    except psycopg2.Error:
        return jsonify({"error": "Could not load class data"}), 500


load_env(ENV_PATH)
if not os.environ.get("DATABASE_URL"):
    sys.exit("DATABASE_URL is unset")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5050)
