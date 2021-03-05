-- Translate Oracle regexp modifier into PostgreSQl ones
-- Append the global modifier if $2 is true. Used internally
-- by regexp_*() functions bellow.
CREATE OR REPLACE FUNCTION oracle.translate_oracle_modifiers(text, bool)
RETURNS text
AS $$
DECLARE
    modifiers text;
    multiline text;
BEGIN
    -- Oracle 'n' modifier correspond to 's' POSIX modifier
    -- Oracle 'm' modifier correspond to 'n' POSIX modifier
    SELECT translate($1, 'nm', 'sn') INTO modifiers;
    SELECT regexp_match(modifiers, 's') INTO multiline;
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    IF multiline = NULL THEN
        modifiers := modifiers || 'p';
    END IF;
    IF $2 THEN
        modifiers := modifiers || 'g';
    END IF;
    RETURN modifiers;
END;
$$
LANGUAGE plpgsql;

-- REGEXP_LIKE( string text, pattern text) -> boolean
CREATE OR REPLACE FUNCTION oracle.regexp_like(text, text)
RETURNS boolean
AS $$
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT regexp_match($1, $2, 'p') IS NOT NULL;
$$
LANGUAGE 'sql';

-- REGEXP_LIKE( string text, pattern text, flags text ) -> boolean
CREATE OR REPLACE FUNCTION oracle.regexp_like(text, text, text)
RETURNS boolean
AS $$
DECLARE
    modifiers text;
BEGIN
    SELECT oracle.translate_oracle_modifiers($3, false) INTO modifiers;
    IF (SELECT regexp_match($1, $2, modifiers) IS NOT NULL) THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$
LANGUAGE plpgsql;

-- REGEXP_COUNT( string text, pattern text ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_count(text, text)
RETURNS integer
AS $$
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT count(*)::integer FROM regexp_matches($1, $2, 'pg');
$$
LANGUAGE 'sql';

-- REGEXP_COUNT( string text, pattern text, position int ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_count(text, text, integer)
RETURNS integer
AS $$
DECLARE
    v_cnt integer;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT count(*)::integer FROM regexp_matches(substr($1, $3), $2, 'pg') INTO v_cnt;
    RETURN v_cnt;
END;
$$
LANGUAGE plpgsql;

-- REGEXP_COUNT( string text, pattern text, position int, flags text ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_count(text, text, integer, text)
RETURNS integer
AS $$
DECLARE
    modifiers text;
    v_count   integer;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    SELECT oracle.translate_oracle_modifiers($4, true) INTO modifiers;
    SELECT count(*)::integer FROM regexp_matches(substr($1, $3), $2, modifiers) INTO v_count;
    RETURN v_count;
END;
$$
LANGUAGE plpgsql;

--  REGEXP_INSTR( string text, pattern text ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_instr(text, text)
RETURNS integer
AS $$
DECLARE
    v_pos integer;
    v_pattern text;
BEGIN
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT position((SELECT (regexp_matches($1, v_pattern, 'pg'))[1] offset 0 limit 1) IN $1) INTO v_pos;
    -- position() returns NULL when not found, we need to return 0 instead
    IF v_pos IS NOT NULL THEN
        RETURN v_pos;
    END IF;
    RETURN 0;
END;
$$
LANGUAGE plpgsql;

--  REGEXP_INSTR( string text, pattern text, position int ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_instr(text, text, integer)
RETURNS integer
AS $$
DECLARE
    v_pos integer;
    v_pattern text;
BEGIN
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT position((SELECT (regexp_matches(substr($1, $3), v_pattern, 'pg'))[1] offset 0 limit 1) IN $1) INTO v_pos;
    -- position() returns NULL when not found, we need to return 0 instead
    IF v_pos IS NOT NULL THEN
        RETURN v_pos;
    END IF;
    RETURN 0;
END;
$$
LANGUAGE plpgsql;

--  REGEXP_INSTR( string text, pattern text, position int, occurence int ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_instr(text, text, integer, integer)
RETURNS integer
AS $$
DECLARE
    v_pos integer;
    v_pattern text;
BEGIN
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    IF $4 < 1 THEN
        RAISE EXCEPTION 'argument ''occurence'' must be a number greater than 0';
    END IF;
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT position((SELECT (regexp_matches(substr($1, $3), v_pattern, 'pg'))[1] offset $4-1 limit 1) IN $1) INTO v_pos;
    -- position() returns NULL when not found, we need to return 0 instead
    IF v_pos IS NOT NULL THEN
        RETURN v_pos;
    END IF;
    RETURN 0;
END;
$$
LANGUAGE plpgsql;

--  REGEXP_INSTR( string text, pattern text, position int, occurence int, return_opt int ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_instr(text, text, integer, integer, integer)
RETURNS integer
AS $$
DECLARE
    v_pos integer;
    v_len integer;
    v_pattern text;
BEGIN
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    IF $4 < 1 THEN
        RAISE EXCEPTION 'argument ''occurence'' must be a number greater than 0';
    END IF;
    IF $5 != 0 AND $5 != 1 THEN
        RAISE EXCEPTION 'argument ''return_opt'' must be 0 or 1';
    END IF;
    -- Without subexpression specified, assume 0 which mean that the first
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT position((SELECT (regexp_matches(substr($1, $3), v_pattern, 'pg'))[1] offset $4-1 limit 1) IN $1) INTO v_pos;
    -- position() returns NULL when not found, we need to return 0 instead
    IF v_pos IS NOT NULL THEN
        IF $5 = 1 THEN
            SELECT length((SELECT (regexp_matches(substr($1, $3), v_pattern, 'pg'))[1] offset $4-1 limit 1)) INTO v_len;
        v_pos := v_pos + v_len;
        END IF;
        RETURN v_pos;
    END IF;
    RETURN 0;
END;
$$
LANGUAGE plpgsql;

--  REGEXP_INSTR( string text, pattern text, position int, occurence int, return_opt int, flags text ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_instr(text, text, integer, integer, integer, text)
RETURNS integer
AS $$
DECLARE
    v_pos integer;
    v_len integer;
    modifiers text;
    v_pattern text;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    IF $4 < 1 THEN
        RAISE EXCEPTION 'argument ''occurence'' must be a number greater than 0';
    END IF;
    IF $5 != 0 AND $5 != 1 THEN
        RAISE EXCEPTION 'argument ''return_opt'' must be 0 or 1';
    END IF;
    SELECT oracle.translate_oracle_modifiers($6, true) INTO modifiers;
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    SELECT position((SELECT (regexp_matches(substr($1, $3), v_pattern, modifiers))[1] offset $4-1 limit 1) IN $1) INTO v_pos;
    -- position() returns NULL when not found, we need to return 0 instead
    IF v_pos IS NOT NULL THEN
        IF $5 = 1 THEN
            SELECT length((SELECT (regexp_matches(substr($1, $3), v_pattern, modifiers))[1] offset $4-1 limit 1)) INTO v_len;
        v_pos := v_pos + v_len;
        END IF;
        RETURN v_pos;
    END IF;
    RETURN 0;
END;
$$
LANGUAGE plpgsql;

--  REGEXP_INSTR( string text, pattern text, position int, occurence int, return_opt int, flags text, group int ) -> integer
CREATE OR REPLACE FUNCTION oracle.regexp_instr(text, text, integer, integer, integer, text, integer)
RETURNS integer
AS $$
DECLARE
    v_pos integer := 0;
    v_pos_orig integer := $3;
    v_len integer := 0;
    modifiers text;
    occurrence integer := $4;
    idx integer := 1;
    v_curr_pos integer := 0;
    v_pattern text;
    v_subexpr integer := $7;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    IF $4 < 1 THEN
        RAISE EXCEPTION 'argument ''occurence'' must be a number greater than 0';
    END IF;
    IF $7 < 0 THEN
        RAISE EXCEPTION 'argument ''group'' must be a positive number';
    END IF;
    IF $5 != 0 AND $5 != 1 THEN
        RAISE EXCEPTION 'argument ''return_opt'' must be 0 or 1';
    END IF;
    -- Translate Oracle regexp modifier into PostgreSQl ones
    SELECT oracle.translate_oracle_modifiers($6, true) INTO modifiers;
    -- If subexpression value is 0 we need to enclose the pattern between parentheses.
    IF v_subexpr = 0 THEN
       v_pattern := '(' || $2 || ')';
       v_subexpr := 1;
    ELSE
       v_pattern := $2;
    END IF;
    -- To get position of occurrence > 1 we need a more complex code
    LOOP
	v_curr_pos := v_curr_pos + v_len;
        SELECT position((SELECT (regexp_matches(substr($1, v_pos_orig), '('||$2||')', modifiers))[1] offset 0 limit 1) IN substr($1, v_pos_orig)) INTO v_pos;
        SELECT length((SELECT (regexp_matches(substr($1, v_pos_orig), '('||$2||')', modifiers))[1] offset 0 limit 1)) INTO v_len;
        IF v_len IS NULL THEN
            EXIT;
        END IF;
        v_pos_orig := v_pos_orig + v_pos + v_len;
	v_curr_pos := v_curr_pos + v_pos;
        idx := idx + 1;
        EXIT WHEN (idx > occurrence);
    END LOOP;
    SELECT position((SELECT (regexp_matches(substr($1, v_curr_pos), v_pattern, modifiers))[v_subexpr] offset 0 limit 1) IN substr($1, v_curr_pos)) INTO v_pos;
    IF v_pos IS NOT NULL THEN
        IF $5 = 1 THEN
            SELECT length((SELECT (regexp_matches(substr($1, v_curr_pos), v_pattern, modifiers))[v_subexpr] offset 0 limit 1)) INTO v_len;
            v_pos := v_pos + v_len;
        END IF;
        RETURN v_pos + v_curr_pos - 1;
    END IF;
    RETURN 0;
END;
$$
LANGUAGE plpgsql;

-- REGEXP_SUBSTR( string text, pattern text ) -> text
CREATE OR REPLACE FUNCTION oracle.regexp_substr(text, text)
RETURNS text
AS $$
DECLARE
    v_substr text;
    v_pattern text;
BEGIN
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT (regexp_matches($1, v_pattern, 'pg'))[1] offset 0 limit 1 INTO v_substr;
    RETURN v_substr;
END;
$$
LANGUAGE plpgsql;

-- REGEXP_SUBSTR( string text, pattern text, position int ) -> text
CREATE OR REPLACE FUNCTION oracle.regexp_substr(text, text, int)
RETURNS text
AS $$
DECLARE
    v_substr text;
    v_pattern text;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT (regexp_matches(substr($1, $3), v_pattern, 'pg'))[1] offset 0 limit 1 INTO v_substr;
    RETURN v_substr;
END;
$$
LANGUAGE plpgsql;


-- REGEXP_SUBSTR( string text, pattern text, position int, occurence int ) -> text
CREATE OR REPLACE FUNCTION oracle.regexp_substr(text, text, integer, integer)
RETURNS text
AS $$
DECLARE
    v_substr text;
    v_pattern text;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    IF $4 < 1 THEN
        RAISE EXCEPTION 'argument ''occurence'' must be a number greater than 0';
    END IF;
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT (regexp_matches(substr($1, $3), v_pattern, 'pg'))[1] offset $4-1 limit 1 INTO v_substr;
    RETURN v_substr;
END;
$$
LANGUAGE plpgsql;

-- REGEXP_SUBSTR( string text, pattern text, position int, occurence int, flags text ) -> text
CREATE OR REPLACE FUNCTION oracle.regexp_substr(text, text, integer, integer, text)
RETURNS text
AS $$
DECLARE
    v_substr text;
    v_pattern text;
    modifiers text;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
        RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    IF $4 < 1 THEN
        RAISE EXCEPTION 'argument ''occurence'' must be a number greater than 0';
    END IF;
    SELECT oracle.translate_oracle_modifiers($5, true) INTO modifiers;
    -- Without subexpression specified, assume 0 which mean that the first
    -- position for the substring matching the whole pattern is returned.
    -- We need to enclose the pattern between parentheses.
    v_pattern := '(' || $2 || ')';
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT (regexp_matches(substr($1, $3), v_pattern, modifiers))[1] offset $4-1 limit 1 INTO v_substr;
    RETURN v_substr;
END;
$$
LANGUAGE plpgsql;

-- REGEXP_SUBSTR( string text, pattern text, position int, occurence int, flags text, group int ) -> text
CREATE OR REPLACE FUNCTION oracle.regexp_substr(text, text, integer, integer, text, int)
RETURNS text
AS $$
DECLARE
    v_substr text;
    v_pattern text;
    modifiers text;
    v_subexpr integer := $6;
BEGIN
    -- Check numeric arguments
    IF $3 < 1 THEN
	RAISE EXCEPTION 'argument ''position'' must be a number greater than 0';
    END IF;
    IF $4 < 1 THEN
	RAISE EXCEPTION 'argument ''occurence'' must be a number greater than 0';
    END IF;
    IF v_subexpr < 0 THEN
	RAISE EXCEPTION 'argument ''group'' must be a positive number';
    END IF;
    -- Check that with v_subexpr = 1 we have a capture group otherwise return NULL
    IF $6 = 1 AND regexp_match(v_pattern, '\(.*\)') IS NULL THEN
	RETURN NULL;
    END IF;
    SELECT oracle.translate_oracle_modifiers($5, true) INTO modifiers;
    -- If subexpression value is 0 we need to enclose the pattern between parentheses.
    IF v_subexpr = 0 THEN
       v_pattern := '(' || $2 || ')';
       v_subexpr := 1;
    ELSE
       v_pattern := $2;
    END IF;
    -- Oracle default behavior is newline-sensitive,
    -- PostgreSQL not, so force 'p' modifier to affect
    -- newline-sensitivity but not ^ and $ search.
    SELECT (regexp_matches(substr($1, $3), v_pattern, modifiers))[v_subexpr] offset $4-1 limit 1 INTO v_substr;
    RETURN v_substr;
END;
$$
LANGUAGE plpgsql;

