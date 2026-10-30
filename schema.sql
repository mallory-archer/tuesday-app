-- Relational schema for class_dataset.csv (PostgreSQL).
--
-- One survey row becomes one students row. The four skill_* ratings and the
-- semicolon-separated tools and availability lists become rows in bridge tables.
-- working_style, interests, and semester_goal stay on students: they are free
-- text, and interests is not a consistent list.

CREATE TABLE students (
    student_id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    netid               TEXT NOT NULL UNIQUE,
    name                TEXT NOT NULL,
    school_year         TEXT NOT NULL CHECK (school_year IN ('Sophomore', 'Junior', 'Senior')),
    intro_programming   TEXT NOT NULL CHECK (intro_programming IN ('took_it', 'equivalent', 'neither')),
    working_style       TEXT,
    interests           TEXT,
    semester_goal       TEXT,
    submitted_at        TIMESTAMPTZ
);

-- The four self-rated areas from skill_programming, skill_data_stats,
-- skill_frontend_design, and skill_business_pitch.
CREATE TABLE skills (
    skill_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    skill_code  TEXT NOT NULL UNIQUE,
    skill_name  TEXT NOT NULL UNIQUE
);

-- Rating belongs on the relationship: each student rates each skill once.
CREATE TABLE student_skills (
    student_id  INTEGER NOT NULL REFERENCES students (student_id) ON DELETE CASCADE,
    skill_id    INTEGER NOT NULL REFERENCES skills (skill_id) ON DELETE RESTRICT,
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    PRIMARY KEY (student_id, skill_id)
);

CREATE INDEX student_skills_skill_id_idx ON student_skills (skill_id);

-- Named tools from the tools column (Python, SQL, JavaScript, Excel, R).
-- "none yet" is the absence of rows here, not a tool.
CREATE TABLE tools (
    tool_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tool_name   TEXT NOT NULL UNIQUE
);

CREATE TABLE student_tools (
    student_id  INTEGER NOT NULL REFERENCES students (student_id) ON DELETE CASCADE,
    tool_id     INTEGER NOT NULL REFERENCES tools (tool_id) ON DELETE RESTRICT,
    PRIMARY KEY (student_id, tool_id)
);

CREATE INDEX student_tools_tool_id_idx ON student_tools (tool_id);

-- The six time windows in the availability column.
CREATE TABLE availability (
    availability_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slot_code       TEXT NOT NULL UNIQUE,
    slot_name       TEXT NOT NULL UNIQUE,
    day_group       TEXT NOT NULL CHECK (day_group IN ('weekday', 'weekend')),
    time_of_day     TEXT NOT NULL CHECK (time_of_day IN ('morning', 'afternoon', 'evening')),
    UNIQUE (day_group, time_of_day)
);

CREATE TABLE student_availability (
    student_id      INTEGER NOT NULL REFERENCES students (student_id) ON DELETE CASCADE,
    availability_id INTEGER NOT NULL REFERENCES availability (availability_id) ON DELETE RESTRICT,
    PRIMARY KEY (student_id, availability_id)
);

CREATE INDEX student_availability_availability_id_idx ON student_availability (availability_id);

INSERT INTO skills (skill_code, skill_name) VALUES
    ('programming',      'Programming'),
    ('data_stats',       'Data & Stats'),
    ('frontend_design',  'Frontend Design'),
    ('business_pitch',   'Business Pitch');

INSERT INTO tools (tool_name) VALUES
    ('Python'),
    ('JavaScript'),
    ('SQL'),
    ('Excel'),
    ('R');

INSERT INTO availability (slot_code, slot_name, day_group, time_of_day) VALUES
    ('weekday_morning',   'Weekday mornings',   'weekday', 'morning'),
    ('weekday_afternoon', 'Weekday afternoons', 'weekday', 'afternoon'),
    ('weekday_evening',   'Weekday evenings',   'weekday', 'evening'),
    ('weekend_morning',   'Weekend mornings',   'weekend', 'morning'),
    ('weekend_afternoon', 'Weekend afternoons', 'weekend', 'afternoon'),
    ('weekend_evening',   'Weekend evenings',   'weekend', 'evening');
