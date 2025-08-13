-- Family Tree Database Schema
-- Proper order: Extensions → Types → Tables → Functions → Triggers

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto; -- for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS btree_gist; -- for btree_gist indexes

-- 2. Types and Enums
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='relationship_type_enum') THEN
    CREATE TYPE relationship_type_enum AS ENUM (
      'mother', 'father', 'child', 'spouse', 'sibling', 'partner', 'guardian', 'grandparent', 'other'
    );
  END IF;
END$$;

-- 3. Custom Types are provided by btree_gist extension

-- 4. Tables (in dependency order)

-- Person table
CREATE TABLE IF NOT EXISTS person (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    given_name text NOT NULL,
    family_name text NOT NULL,
    full_name text GENERATED ALWAYS AS ((given_name || ' ') || family_name) STORED,
    gender text NOT NULL,
    dob date,
    place_of_birth text,
    identifiers jsonb,
    status text DEFAULT 'active',
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
    death_date date,
    place_of_birth_uuid uuid,
    CONSTRAINT person_pkey PRIMARY KEY (id),
    CONSTRAINT person_gender_check CHECK (gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text, 'unknown'::text]))
);

CREATE INDEX IF NOT EXISTS idx_full_name ON person USING btree (full_name);
CREATE INDEX IF NOT EXISTS idx_identifiers_gin ON person USING gin (identifiers);

-- Event table
CREATE TABLE IF NOT EXISTS event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_type text NOT NULL,
    event_date date,
    location text,
    source text,
    metadata jsonb,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    crvs_event_uuid uuid NOT NULL,
    duplicates uuid[],
    status text,
    last_update_at timestamp,
    remarks text,
    CONSTRAINT event_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_event_type ON event USING btree (event_type);
CREATE UNIQUE INDEX IF NOT EXISTS unique_crvs_event_uuid ON event USING btree (crvs_event_uuid);

-- Event participant table
CREATE TABLE IF NOT EXISTS event_participant (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    person_id uuid,
    event_id uuid,
    role text NOT NULL,
    relationship_details jsonb,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    crvs_person_id uuid,
    status text DEFAULT 'active',
    ended_at timestamp,
    remarks text,
    CONSTRAINT event_participant_pkey PRIMARY KEY (id)
);

COMMENT ON COLUMN event_participant.event_id IS 'event_id → event.id';

CREATE INDEX IF NOT EXISTS idx_person_event ON event_participant USING btree (person_id, event_id);
CREATE INDEX IF NOT EXISTS idx_role ON event_participant USING btree (role);
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_participant ON event_participant USING btree (event_id, crvs_person_id) WHERE (status = 'active'::text);
CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_father_per_event ON event_participant USING btree (event_id) WHERE ((role = 'father'::text) AND (status = 'active'::text) AND (ended_at IS NULL));
CREATE INDEX IF NOT EXISTS ix_ep_event_person ON event_participant USING btree (event_id, person_id);

-- Family links forward table
CREATE TABLE IF NOT EXISTS family_links_forward (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    person_id uuid NOT NULL,
    related_person_id uuid NOT NULL,
    relationship_type relationship_type_enum NOT NULL,
    relationship_subtype text,
    source_event_id uuid,
    start_date date,
    end_date date,
    source text DEFAULT 'OpenCRVS',
    notes text,
    period daterange GENERATED ALWAYS AS (daterange(start_date, end_date, '[]')) STORED,
    CONSTRAINT family_link_check CHECK (person_id <> related_person_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_flnew_pair_type_event ON family_links_forward USING btree (person_id, related_person_id, relationship_type, source_event_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_flnew_active_per_role_event ON family_links_forward USING btree (person_id, relationship_type, source_event_id) WHERE (end_date IS NULL);
CREATE INDEX IF NOT EXISTS ix_flnew_event ON family_links_forward USING btree (source_event_id);
CREATE INDEX IF NOT EXISTS ix_flnew_person ON family_links_forward USING btree (person_id);
CREATE INDEX IF NOT EXISTS ix_flnew_related ON family_links_forward USING btree (related_person_id);
CREATE INDEX IF NOT EXISTS ix_flnew_no_overlap ON family_links_forward USING gist (person_id, relationship_type, source_event_id, period);
CREATE UNIQUE INDEX IF NOT EXISTS ux_flnew_spouse_unordered ON family_links_forward USING btree (source_event_id, LEAST(person_id, related_person_id), GREATEST(person_id, related_person_id)) WHERE ((relationship_type = 'spouse'::relationship_type_enum) AND (end_date IS NULL));

-- Family link table (legacy compatibility)
CREATE TABLE IF NOT EXISTS family_link (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    person_id uuid NOT NULL,
    related_person_id uuid NOT NULL,
    relationship_type relationship_type_enum NOT NULL,
    relationship_subtype text,
    source_event_id uuid,
    start_date date,
    end_date date,
    source text DEFAULT 'OpenCRVS',
    notes text,
    CONSTRAINT family_link_pkey PRIMARY KEY (id),
    CONSTRAINT family_link_check CHECK (person_id <> related_person_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS unique_family_link ON family_link USING btree (person_id, related_person_id, relationship_type, source_event_id);
CREATE INDEX IF NOT EXISTS idx_family_link_event ON family_link USING btree (source_event_id);
CREATE INDEX IF NOT EXISTS idx_family_link_person_id ON family_link USING btree (person_id);
CREATE INDEX IF NOT EXISTS idx_family_link_related_person_id ON family_link USING btree (related_person_id);

-- Person name history table
CREATE TABLE IF NOT EXISTS person_name_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    person_id uuid NOT NULL,
    given_name text NOT NULL,
    family_name text NOT NULL,
    full_name text GENERATED ALWAYS AS ((given_name || ' ') || family_name) STORED,
    change_reason text,
    valid_from date,
    valid_to date,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT person_name_history_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_name_history_full_name ON person_name_history USING btree (full_name);
CREATE INDEX IF NOT EXISTS idx_name_history_valid_from ON person_name_history USING btree (valid_from);

-- Relationship role map table
CREATE SEQUENCE IF NOT EXISTS relationship_role_map_id_seq INCREMENT 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE TABLE IF NOT EXISTS relationship_role_map (
    id integer DEFAULT nextval('relationship_role_map_id_seq') NOT NULL,
    event_type text NOT NULL,
    role_text text NOT NULL,
    forward_relationship relationship_type_enum NOT NULL,
    reverse_relationship relationship_type_enum NOT NULL,
    is_anchor boolean DEFAULT false NOT NULL,
    creates_link boolean DEFAULT true NOT NULL,
    closes_links boolean DEFAULT false NOT NULL,
    counterpart_group text,
    CONSTRAINT relationship_role_map_pkey PRIMARY KEY (id),
    CONSTRAINT chk_event_type_lower CHECK (event_type = lower(event_type))
);

CREATE UNIQUE INDEX IF NOT EXISTS relationship_role_map_event_type_role_text_key ON relationship_role_map USING btree (event_type, role_text);

-- Sync request table
CREATE TABLE IF NOT EXISTS sync_request (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_type text NOT NULL,
    action text NOT NULL,
    crvs_event_uuid uuid NOT NULL,
    payload jsonb,
    status text DEFAULT 'pending' NOT NULL,
    error_message text,
    retry_count integer DEFAULT 0,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
    processed_at timestamp,
    CONSTRAINT sync_request_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_sync_request_status ON sync_request USING btree (status);
CREATE INDEX IF NOT EXISTS idx_sync_request_crvs_uuid ON sync_request USING btree (crvs_event_uuid);
CREATE INDEX IF NOT EXISTS idx_sync_request_created_at ON sync_request USING btree (created_at);

-- Toppan migrations table
CREATE SEQUENCE IF NOT EXISTS toppan_migrations_id_seq INCREMENT 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1;

CREATE TABLE IF NOT EXISTS toppan_migrations (
    id integer DEFAULT nextval('toppan_migrations_id_seq') NOT NULL,
    filename character varying(255) NOT NULL,
    executed_at timestamp DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT toppan_migrations_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS toppan_migrations_filename_key ON toppan_migrations USING btree (filename);

-- 5. Foreign Key Constraints
DO $$
BEGIN
    -- Event participant foreign keys
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'event_participant_event_id_fkey') THEN
        ALTER TABLE event_participant ADD CONSTRAINT event_participant_event_id_fkey FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'event_participant_person_id_fkey') THEN
        ALTER TABLE event_participant ADD CONSTRAINT event_participant_person_id_fkey FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE;
    END IF;

    -- Family link foreign keys
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'family_link_person_id_fkey') THEN
        ALTER TABLE family_link ADD CONSTRAINT family_link_person_id_fkey FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'family_link_related_person_id_fkey') THEN
        ALTER TABLE family_link ADD CONSTRAINT family_link_related_person_id_fkey FOREIGN KEY (related_person_id) REFERENCES person(id) ON DELETE CASCADE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'family_link_source_event_id_fkey') THEN
        ALTER TABLE family_link ADD CONSTRAINT family_link_source_event_id_fkey FOREIGN KEY (source_event_id) REFERENCES event(id) ON DELETE SET NULL;
    END IF;

    -- Person name history foreign key
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'person_name_history_person_id_fkey') THEN
        ALTER TABLE person_name_history ADD CONSTRAINT person_name_history_person_id_fkey FOREIGN KEY (person_id) REFERENCES person(id);
    END IF;
END$$;

-- 6. Functions (now that all tables exist)

-- Upsert family link forward shadow function
CREATE OR REPLACE FUNCTION upsert_family_link_forward_shadow(
    p_person_id uuid,
    p_related_person_id uuid,
    p_relationship relationship_type_enum,
    p_event_id uuid,
    p_start_date date,
    p_end_date date,
    p_source text
) RETURNS void AS $$
BEGIN
  -- Close any active conflicting link (same anchor/role/event pointing elsewhere)
  UPDATE family_links_forward fl
     SET end_date = COALESCE(p_start_date, CURRENT_DATE),
         notes = COALESCE(fl.notes,'') || ' [Auto-ended due to revision]'
   WHERE fl.person_id = p_person_id
     AND fl.relationship_type = p_relationship
     AND fl.source_event_id = p_event_id
     AND fl.end_date IS NULL
     AND fl.related_person_id <> p_related_person_id;

  -- Upsert the current link
  INSERT INTO family_links_forward(
    person_id, related_person_id, relationship_type,
    source_event_id, start_date, end_date, source, notes
  )
  VALUES (
    p_person_id, p_related_person_id, p_relationship,
    p_event_id, p_start_date, p_end_date, p_source, 'From EP (shadow)'
  )
  ON CONFLICT (person_id, related_person_id, relationship_type, source_event_id)
  DO UPDATE SET
    start_date = COALESCE(family_links_forward.start_date, EXCLUDED.start_date),
    end_date   = COALESCE(EXCLUDED.end_date, family_links_forward.end_date),
    source     = COALESCE(EXCLUDED.source, family_links_forward.source);
END;
$$ LANGUAGE plpgsql;

-- Apply event participant change shadow function
CREATE OR REPLACE FUNCTION apply_event_participant_change_shadow(p_event_participant_id uuid)
RETURNS void AS $$
DECLARE
  ep    event_participant%ROWTYPE;
  ev    event%ROWTYPE;
  m_row relationship_role_map%ROWTYPE;

  start_d   date;
  end_d     date;
  is_active boolean;
  is_ready  boolean;  -- NEW: active OR review

  anchor_id uuid;
  other_id  uuid;
BEGIN
  SELECT * INTO ep FROM event_participant WHERE id = p_event_participant_id;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO ev FROM event WHERE id = ep.event_id;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO m_row
  FROM relationship_role_map
  WHERE event_type = lower(ev.event_type)
    AND role_text  = ep.role;
  IF NOT FOUND THEN RETURN; END IF;

  is_active := (ep.status = 'active' AND ep.ended_at IS NULL);
  -- Treat 'review' as ready to create a link (but not to end it)
  is_ready  := (ep.status IN ('active','review') AND ep.ended_at IS NULL);

  start_d := COALESCE(ev.event_date, ep.created_at::date, CURRENT_DATE);
  -- IMPORTANT: don't synthesize an end date just because it's not active
  end_d   := NULL;

  -- ========= BIRTH =========
  IF lower(ev.event_type) = 'birth' THEN
    -- find anchor child (subject)
    SELECT ep2.person_id
      INTO anchor_id
    FROM event_participant ep2
    WHERE ep2.event_id = ep.event_id
      AND ep2.role = 'subject'
      AND ep2.status = 'active'
      AND ep2.ended_at IS NULL
    ORDER BY ep2.created_at
    LIMIT 1;

    IF anchor_id IS NULL THEN RETURN; END IF;

    -- Only create/refresh when ready (active or review)
    IF is_ready AND m_row.creates_link AND ep.person_id IS NOT NULL THEN
      PERFORM upsert_family_link_forward_shadow(
        anchor_id,                -- child
        ep.person_id,             -- parent
        m_row.forward_relationship,
        ep.event_id,
        start_d,
        NULL,                     -- open-ended
        COALESCE(ev.source,'OpenCRVS')
      );
    END IF;

    -- If EP row explicitly ended, close the link (no creation)
    IF ep.ended_at IS NOT NULL AND m_row.creates_link AND ep.person_id IS NOT NULL THEN
      UPDATE family_links_forward fl
         SET end_date = ep.ended_at::date,
             notes = COALESCE(fl.notes,'') || ' [Closed by EP ended_at]'
       WHERE fl.person_id = anchor_id
         AND fl.related_person_id = ep.person_id
         AND fl.relationship_type = m_row.forward_relationship
         AND fl.source_event_id = ep.event_id
         AND fl.end_date IS NULL;
    END IF;

    RETURN;
  END IF;

  -- ========= MARRIAGE ========= (unchanged: require active for both)
  IF lower(ev.event_type) = 'marriage' THEN
    IF NOT is_active OR NOT m_row.creates_link OR ep.person_id IS NULL THEN
      RETURN;
    END IF;

    SELECT ep2.person_id
      INTO other_id
    FROM event_participant ep2
    WHERE ep2.event_id = ep.event_id
      AND ep2.role IN (
        SELECT role_text FROM relationship_role_map
        WHERE event_type = 'marriage'
          AND counterpart_group = m_row.counterpart_group
      )
      AND ep2.id <> ep.id
      AND ep2.status = 'active'
      AND ep2.ended_at IS NULL
    LIMIT 1;

    IF other_id IS NULL THEN RETURN; END IF;

    INSERT INTO family_links_forward(
      person_id, related_person_id, relationship_type,
      source_event_id, start_date, end_date, source, notes
    )
    SELECT
      LEAST(ep.person_id, other_id),
      GREATEST(ep.person_id, other_id),
      'spouse'::relationship_type_enum,
      ep.event_id,
      start_d,
      NULL,
      COALESCE(ev.source,'OpenCRVS'),
      'From marriage event (shadow)'
    ON CONFLICT (person_id, related_person_id, relationship_type, source_event_id)
    DO NOTHING;

    RETURN;
  END IF;

  -- ========= DEATH ========= (unchanged)
  IF lower(ev.event_type) = 'death' THEN
    IF m_row.closes_links AND ep.person_id IS NOT NULL THEN
      UPDATE family_links_forward fl
         SET end_date = COALESCE(ev.event_date, CURRENT_DATE),
             notes    = COALESCE(fl.notes,'') || ' [Closed by death]'
       WHERE fl.person_id = ep.person_id
         AND fl.relationship_type IN ('spouse','partner')
         AND fl.end_date IS NULL;
    END IF;
    RETURN;
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql;

-- Backfill family links from events function
CREATE OR REPLACE FUNCTION backfill_family_links_from_events()
RETURNS void AS $$
BEGIN
  -- 👶 Birth: child → mother/father
  INSERT INTO family_link (
    person_id,
    related_person_id,
    relationship_type,
    source_event_id,
    source,
    notes
  )
  SELECT DISTINCT ON (
    child.person_id, parent.person_id, parent.role, e.id
  )
    child.person_id,
    parent.person_id,
    CASE parent.role
      WHEN 'mother' THEN 'mother'
      WHEN 'father' THEN 'father'
    END::relationship_type_enum,
    e.id,
    'OpenCRVS',
    'Backfilled from birth event'
  FROM event e
  JOIN (
    SELECT DISTINCT event_id, person_id, role
    FROM event_participant
    WHERE role = 'subject'
  ) child ON child.event_id = e.id
  JOIN (
    SELECT DISTINCT event_id, person_id, role
    FROM event_participant
    WHERE role IN ('mother', 'father')
  ) parent ON parent.event_id = e.id
  LEFT JOIN family_link existing ON
    existing.person_id = child.person_id AND
    existing.related_person_id = parent.person_id AND
    existing.relationship_type = CASE parent.role
      WHEN 'mother' THEN 'mother'
      WHEN 'father' THEN 'father'
    END::relationship_type_enum AND
    existing.source_event_id = e.id
  WHERE e.event_type = 'birth'
    AND existing.id IS NULL
    AND parent.person_id IS NOT NULL
    AND child.person_id IS NOT NULL
    AND child.person_id != parent.person_id;

  -- 💍 Marriage: spouse ↔ spouse
  INSERT INTO family_link (
    person_id,
    related_person_id,
    relationship_type,
    source_event_id,
    source,
    notes
  )
  SELECT DISTINCT ON (a.person_id, b.person_id, e.id)
    a.person_id,
    b.person_id,
    'spouse'::relationship_type_enum,
    e.id,
    'OpenCRVS',
    'Backfilled from marriage event'
  FROM event e
  JOIN (
    SELECT DISTINCT event_id, person_id FROM event_participant WHERE role = 'groom'
  ) a ON a.event_id = e.id
  JOIN (
    SELECT DISTINCT event_id, person_id FROM event_participant WHERE role = 'bride'
  ) b ON b.event_id = e.id
  LEFT JOIN family_link existing ON
    existing.person_id = a.person_id AND
    existing.related_person_id = b.person_id AND
    existing.relationship_type = 'spouse' AND
    existing.source_event_id = e.id
  WHERE e.event_type = 'marriage'
    AND existing.id IS NULL
    AND a.person_id IS NOT NULL
    AND b.person_id IS NOT NULL
    AND a.person_id != b.person_id;

  RAISE NOTICE '✅ Family link backfill complete.';
END;
$$ LANGUAGE plpgsql;

-- Create family link from event function
CREATE OR REPLACE FUNCTION create_family_link_from_event()
RETURNS trigger AS $$
DECLARE
  child_id UUID;
BEGIN
  IF NEW.role IN ('mother', 'father') THEN
    -- Look for the child (role='subject' and type='child')
    SELECT person_id INTO child_id
    FROM event_participant
    WHERE event_id = NEW.event_id
      AND relationship_details->>'type' = 'child'
    LIMIT 1;

    IF child_id IS NOT NULL THEN
      -- Insert child → parent with correct direction
      IF NOT EXISTS (
        SELECT 1 FROM family_link
        WHERE person_id = child_id
          AND related_person_id = NEW.person_id
          AND relationship_type = NEW.role::relationship_type_enum
          AND source_event_id = NEW.event_id
      ) THEN
        INSERT INTO family_link (
          person_id,               -- child
          related_person_id,       -- mother or father
          relationship_type,
          source_event_id,
          start_date,
          end_date,
          source,
          notes
        )
        VALUES (
          child_id,
          NEW.person_id,
          NEW.role::relationship_type_enum,
          NEW.event_id,
          NULL, NULL,
          'event_participant',
          'Auto-linked from event'
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create reverse family link function
CREATE OR REPLACE FUNCTION create_reverse_family_link()
RETURNS trigger AS $$
DECLARE
  reverse_type relationship_type_enum;
BEGIN
  CASE NEW.relationship_type
    WHEN 'mother' THEN reverse_type := 'child';
    WHEN 'father' THEN reverse_type := 'child';
    WHEN 'spouse' THEN reverse_type := 'spouse';
    WHEN 'sibling' THEN reverse_type := 'sibling';
    WHEN 'partner' THEN reverse_type := 'partner';
    ELSE
      -- Skip reverse creation for 'child' or undefined relationships
      RETURN NEW;
  END CASE;

  -- Check for duplicates
  IF NOT EXISTS (
    SELECT 1 FROM family_link
    WHERE person_id = NEW.related_person_id
      AND related_person_id = NEW.person_id
      AND relationship_type = reverse_type
      AND source_event_id = NEW.source_event_id
  ) THEN
    INSERT INTO family_link (
      person_id,
      related_person_id,
      relationship_type,
      relationship_subtype,
      source_event_id,
      start_date,
      end_date,
      source,
      notes
    )
    VALUES (
      NEW.related_person_id,
      NEW.person_id,
      reverse_type,
      NEW.relationship_subtype,
      NEW.source_event_id,
      NEW.start_date,
      NEW.end_date,
      NEW.source,
      'Auto-created reverse link'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger call apply ep change shadow function
CREATE OR REPLACE FUNCTION trg_call_apply_ep_change_shadow()
RETURNS trigger AS $$
BEGIN
  PERFORM apply_event_participant_change_shadow(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Views (after all tables and functions exist)

-- Family links bidirectional view
CREATE OR REPLACE VIEW family_links_bidirectional AS
WITH ep_roles AS (
  SELECT
    e.id AS event_id,
    ep.person_id AS pid,
    lower(e.event_type) AS etype,
    ep.role AS role_text
  FROM event_participant ep
  JOIN event e ON e.id = ep.event_id
  WHERE ep.status = 'active' AND ep.ended_at IS NULL
)
SELECT
  fl.person_id,
  fl.related_person_id,
  fl.relationship_type,
  CASE
    WHEN fl.relationship_type = 'spouse' THEN
      CASE lower(rf.role_text)
        WHEN 'groom' THEN 'husband'
        WHEN 'bride' THEN 'wife'
        ELSE NULL
      END
    ELSE fl.relationship_subtype
  END AS relationship_subtype,
  fl.source_event_id,
  fl.start_date,
  fl.end_date,
  fl.source,
  fl.notes
FROM family_links_forward fl
LEFT JOIN ep_roles rf
  ON rf.event_id = fl.source_event_id
 AND rf.pid = fl.person_id
 AND rf.etype = 'marriage'

UNION ALL

SELECT
  fl.related_person_id AS person_id,
  fl.person_id AS related_person_id,
  CASE fl.relationship_type
    WHEN 'mother' THEN 'child'::relationship_type_enum
    WHEN 'father' THEN 'child'::relationship_type_enum
    WHEN 'guardian' THEN 'child'::relationship_type_enum
    WHEN 'grandparent' THEN 'child'::relationship_type_enum
    WHEN 'spouse' THEN 'spouse'::relationship_type_enum
    WHEN 'sibling' THEN 'sibling'::relationship_type_enum
    WHEN 'partner' THEN 'partner'::relationship_type_enum
    WHEN 'child' THEN 'other'::relationship_type_enum
    ELSE 'other'::relationship_type_enum
  END AS relationship_type,
  CASE
    WHEN fl.relationship_type = 'spouse' THEN
      CASE lower(rr.role_text)
        WHEN 'groom' THEN 'husband'
        WHEN 'bride' THEN 'wife'
        ELSE NULL
      END
    ELSE NULL
  END AS relationship_subtype,
  fl.source_event_id,
  fl.start_date,
  fl.end_date,
  fl.source,
  'Reverse (virtual)' AS notes
FROM family_links_forward fl
LEFT JOIN ep_roles rr
  ON rr.event_id = fl.source_event_id
 AND rr.pid = fl.related_person_id
 AND rr.etype = 'marriage';

-- Get family view
CREATE OR REPLACE VIEW get_family AS
SELECT
  f.person_id,
  f.relationship_type,
  json_agg(json_build_object(
    'related_person_id', f.related_person_id,
    'subtype', f.relationship_subtype,
    'start_date', f.start_date,
    'end_date', f.end_date,
    'source_event_id', f.source_event_id
  )) AS relatives
FROM family_link f
GROUP BY f.person_id, f.relationship_type;

-- 8. Triggers (after all functions exist)

-- Drop existing triggers to avoid conflicts
DROP TRIGGER IF EXISTS trg_apply_ep_change_shadow ON event_participant;
DROP TRIGGER IF EXISTS trg_create_family_link_from_event ON event_participant;
DROP TRIGGER IF EXISTS trg_create_reverse_family_link ON family_link;

-- Create triggers
CREATE TRIGGER trg_apply_ep_change_shadow
    AFTER INSERT OR UPDATE ON event_participant
    FOR EACH ROW
    EXECUTE FUNCTION trg_call_apply_ep_change_shadow();

CREATE TRIGGER trg_create_family_link_from_event
    AFTER INSERT OR UPDATE ON event_participant
    FOR EACH ROW
    EXECUTE FUNCTION create_family_link_from_event();

CREATE TRIGGER trg_create_reverse_family_link
    AFTER INSERT ON family_link
    FOR EACH ROW
    EXECUTE FUNCTION create_reverse_family_link();

-- btree_gist extension provides all necessary functions

-- Success message
SELECT 'Database schema created successfully!' AS status;