#!/usr/bin/env python3
"""Apply schema.sql and load class_dataset.csv into the Postgres database in .env.

Re-running drops the app tables and reloads them from the CSV. Lookup rows in
schema.sql are inserted again as part of that reload.
"""

import csv
import os
import sys
from pathlib import Path

import psycopg2

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"
SCHEMA_PATH = ROOT / "schema.sql"
CSV_PATH = ROOT / "class_dataset.csv"

SKILL_COLUMNS = {
    "skill_programming": "programming",
    "skill_data_stats": "data_stats",
    "skill_frontend_design": "frontend_design",
    "skill_business_pitch": "business_pitch",
}


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


def sql_statements(sql: str) -> list[str]:
    statements = []
    buffer = []
    for line in sql.splitlines():
        if line.strip().startswith("--"):
            continue
        buffer.append(line)
        if line.strip().endswith(";"):
            statement = "\n".join(buffer).strip()
            if statement:
                statements.append(statement)
            buffer = []
    tail = "\n".join(buffer).strip()
    if tail:
        statements.append(tail)
    return statements


def load_csv(cur, skill_ids, tool_ids, slot_ids) -> tuple[int, int, int]:
    students = 0
    tool_links = 0
    slot_links = 0

    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            cur.execute(
                """
                INSERT INTO students (
                    netid, name, school_year, intro_programming,
                    working_style, interests, semester_goal, submitted_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING student_id
                """,
                (
                    row["netid"].strip(),
                    row["name"].strip(),
                    row["school_year"].strip(),
                    row["intro_programming"].strip(),
                    (row["working_style"] or "").strip() or None,
                    (row["interests"] or "").strip() or None,
                    (row["semester_goal"] or "").strip() or None,
                    row["submitted_at"].strip(),
                ),
            )
            student_id = cur.fetchone()[0]
            students += 1

            for column, code in SKILL_COLUMNS.items():
                cur.execute(
                    """
                    INSERT INTO student_skills (student_id, skill_id, rating)
                    VALUES (%s, %s, %s)
                    """,
                    (student_id, skill_ids[code], int(row[column])),
                )

            seen_tools = set()
            for raw in row["tools"].split(";"):
                name = raw.strip()
                if not name or name.casefold() == "none yet":
                    continue
                tool_id = tool_ids.get(name.casefold())
                if tool_id is None:
                    raise SystemExit(f"unknown tool {name!r} for {row['netid']}")
                if tool_id in seen_tools:
                    continue
                seen_tools.add(tool_id)
                cur.execute(
                    """
                    INSERT INTO student_tools (student_id, tool_id)
                    VALUES (%s, %s)
                    """,
                    (student_id, tool_id),
                )
                tool_links += 1

            for raw in row["availability"].split(";"):
                slot = raw.strip()
                if not slot:
                    continue
                availability_id = slot_ids.get(slot)
                if availability_id is None:
                    raise SystemExit(f"unknown availability slot {slot!r} for {row['netid']}")
                cur.execute(
                    """
                    INSERT INTO student_availability (student_id, availability_id)
                    VALUES (%s, %s)
                    """,
                    (student_id, availability_id),
                )
                slot_links += 1

    return students, tool_links, slot_links


def main() -> None:
    load_env(ENV_PATH)
    url = os.environ.get("DATABASE_URL")
    if not url:
        sys.exit("DATABASE_URL is unset")

    conn = psycopg2.connect(url, connect_timeout=30)
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DROP TABLE IF EXISTS
                        student_availability,
                        student_tools,
                        student_skills,
                        students,
                        skills,
                        tools,
                        availability
                    CASCADE
                    """
                )
                for statement in sql_statements(SCHEMA_PATH.read_text()):
                    cur.execute(statement)

                cur.execute("SELECT skill_code, skill_id FROM skills")
                skill_ids = dict(cur.fetchall())
                cur.execute("SELECT lower(tool_name), tool_id FROM tools")
                tool_ids = dict(cur.fetchall())
                cur.execute("SELECT slot_name, availability_id FROM availability")
                slot_ids = dict(cur.fetchall())

                missing = [code for code in SKILL_COLUMNS.values() if code not in skill_ids]
                if missing:
                    raise SystemExit(f"schema is missing skills: {', '.join(missing)}")

                students, tool_links, slot_links = load_csv(cur, skill_ids, tool_ids, slot_ids)

                cur.execute(
                    """
                    SELECT
                      (SELECT COUNT(*) FROM students),
                      (SELECT COUNT(*) FROM skills),
                      (SELECT COUNT(*) FROM student_skills),
                      (SELECT COUNT(*) FROM tools),
                      (SELECT COUNT(*) FROM student_tools),
                      (SELECT COUNT(*) FROM availability),
                      (SELECT COUNT(*) FROM student_availability)
                    """
                )
                counts = cur.fetchone()
    finally:
        conn.close()

    print(
        "students", counts[0],
        "skills", counts[1],
        "student_skills", counts[2],
        "tools", counts[3],
        "student_tools", counts[4],
        "availability", counts[5],
        "student_availability", counts[6],
    )
    print("loaded_students", students, "tool_links", tool_links, "slot_links", slot_links)


if __name__ == "__main__":
    main()
