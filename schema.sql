-- Relational schema for class_dataset.csv (PostgreSQL).
--
-- One survey row becomes one students row, including the four skill ratings.
-- Tools and availability are lookup tables. Each student links to them through
-- student_tools and student_availability.
-- working_style, interests, and semester_goal stay on students: they are free
-- text, and interests is not a consistent list.

CREATE TABLE students (
    student_id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    netid                   TEXT NOT NULL UNIQUE,
    name                    TEXT NOT NULL,
    school_year             TEXT NOT NULL CHECK (school_year IN ('Sophomore', 'Junior', 'Senior')),
    intro_programming       TEXT NOT NULL CHECK (intro_programming IN ('took_it', 'equivalent', 'neither')),
    skill_programming       INTEGER NOT NULL CHECK (skill_programming BETWEEN 1 AND 5),
    skill_data_stats        INTEGER NOT NULL CHECK (skill_data_stats BETWEEN 1 AND 5),
    skill_frontend_design   INTEGER NOT NULL CHECK (skill_frontend_design BETWEEN 1 AND 5),
    skill_business_pitch    INTEGER NOT NULL CHECK (skill_business_pitch BETWEEN 1 AND 5),
    working_style           TEXT,
    interests               TEXT,
    semester_goal           TEXT,
    submitted_at            TIMESTAMPTZ
);

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
