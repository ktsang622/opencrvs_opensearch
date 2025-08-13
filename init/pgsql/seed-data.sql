-- Seed data for relationship_role_map
INSERT INTO relationship_role_map (event_type, role_text, forward_relationship, reverse_relationship, is_anchor, creates_link, closes_links, counterpart_group) VALUES
-- Birth event mappings
('birth', 'child', 'child', 'other', true, false, false, null),
('birth', 'mother', 'mother', 'child', false, true, false, null),
('birth', 'father', 'father', 'child', false, true, false, null),
('birth', 'guardian', 'guardian', 'child', false, false, false, null),
('birth', 'grandparent', 'grandparent', 'child', false, false, false, null),
('birth', 'subject', 'child', 'other', true, false, false, null),

-- Marriage event mappings  
('marriage', 'bride', 'spouse', 'spouse', false, true, false, 'marriage_spouse_pair'),
('marriage', 'groom', 'spouse', 'spouse', false, true, false, 'marriage_spouse_pair'),

-- Death event mappings
('death', 'subject', 'other', 'other', true, false, true, null)

ON CONFLICT (event_type, role_text) DO NOTHING;

SELECT 'Relationship role mappings seeded successfully!' AS status;