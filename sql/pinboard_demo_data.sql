-- =====================================================
-- PINBOARD DEMO/TEST DATA
-- =====================================================
-- Run this SQL in your Supabase SQL Editor to populate
-- the pinboard with sample data for testing
-- =====================================================

-- Clear existing demo data (optional - comment out if you want to keep existing data)
-- DELETE FROM pinboard_comments;
-- DELETE FROM pinboard_likes;
-- DELETE FROM pinboard_items;

-- =====================================================
-- PINBOARD ITEMS
-- =====================================================

-- DUE DATE CATEGORY (5 items)
-- =====================================================

INSERT INTO pinboard_items (
  title,
  description,
  image_url,
  location,
  event_date,
  category,
  author_id,
  author_name,
  created_at
) VALUES
(
  'Tax Return Filing Deadline',
  'Reminder: Annual tax return filing deadline is approaching. Please ensure all financial documents are prepared and submitted on time to avoid penalties.',
  'https://images.unsplash.com/photo-1554224311-beee460ae6fb?w=800',
  'Online Submission',
  '2025-03-31 17:00:00',
  'due_date',
  'demo-user-1',
  'Admin',
  NOW() - INTERVAL '2 days'
),
(
  'Client Report Submission',
  'Monthly client reports are due next week. Please complete all pending client documentation and submit to the review team.',
  'https://images.unsplash.com/photo-1554224311-beee460ae6fb?w=800',
  'Head Office',
  '2025-11-25 18:00:00',
  'due_date',
  'demo-user-2',
  'John Manager',
  NOW() - INTERVAL '1 day'
),
(
  'Project Proposal Deadline',
  'Final day to submit project proposals for Q1 2026. Ensure your proposal includes budget estimates and timeline.',
  'https://images.unsplash.com/photo-1606326608606-aa0b62935f2b?w=800',
  'Project Management Office',
  '2025-11-30 23:59:00',
  'due_date',
  'demo-user-3',
  'Sarah Director',
  NOW() - INTERVAL '3 hours'
),
(
  'Annual Compliance Training',
  'All staff must complete the annual compliance training module by end of this month. Access the training portal using your employee credentials.',
  'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800',
  'Online Training Portal',
  '2025-11-28 23:59:00',
  'due_date',
  'demo-user-1',
  'Admin',
  NOW() - INTERVAL '5 hours'
),
(
  'Timesheet Submission',
  'Weekly timesheet submission deadline. Please submit your hours worked for the week ending November 15, 2025.',
  'https://images.unsplash.com/photo-1586281380349-632531db7ed4?w=800',
  'HR Department',
  '2025-11-22 17:00:00',
  'due_date',
  'demo-user-4',
  'HR Team',
  NOW() - INTERVAL '1 hour'
);

-- MEETINGS CATEGORY (5 items)
-- =====================================================

INSERT INTO pinboard_items (
  title,
  description,
  image_url,
  location,
  event_date,
  category,
  author_id,
  author_name,
  created_at
) VALUES
(
  'All-Hands Company Meeting',
  'Join us for our quarterly all-hands meeting where we''ll discuss company performance, upcoming projects, and Q&A with the leadership team.',
  'https://images.unsplash.com/photo-1560439514-4e9645039924?w=800',
  'Main Conference Room',
  '2025-11-20 10:00:00',
  'meetings',
  'demo-user-2',
  'John Manager',
  NOW() - INTERVAL '6 hours'
),
(
  'Project Kickoff Meeting',
  'Kickoff meeting for the new client onboarding system project. All project team members are required to attend.',
  'https://images.unsplash.com/photo-1552664730-d307ca884978?w=800',
  'Meeting Room B - 3rd Floor',
  '2025-11-21 14:00:00',
  'meetings',
  'demo-user-3',
  'Sarah Director',
  NOW() - INTERVAL '2 days'
),
(
  'Department Team Sync',
  'Weekly team sync to discuss ongoing projects, blockers, and upcoming priorities. Please come prepared with your updates.',
  'https://images.unsplash.com/photo-1600880292203-757bb62b4baf?w=800',
  'Zoom Meeting - Link in calendar',
  '2025-11-22 09:30:00',
  'meetings',
  'demo-user-5',
  'Team Lead',
  NOW() - INTERVAL '4 hours'
),
(
  'Client Strategy Workshop',
  'Strategy workshop with ABC Corporation to discuss their digital transformation roadmap. Prepare presentation materials.',
  'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=800',
  'Client Office - Downtown',
  '2025-11-23 13:00:00',
  'meetings',
  'demo-user-2',
  'John Manager',
  NOW() - INTERVAL '1 day'
),
(
  'Monthly Performance Review',
  'Individual performance review sessions with team members. Schedule will be shared separately via email.',
  'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=800',
  'Manager Office',
  '2025-11-25 09:00:00',
  'meetings',
  'demo-user-1',
  'Admin',
  NOW() - INTERVAL '8 hours'
);

-- GREETINGS CATEGORY (5 items)
-- =====================================================

INSERT INTO pinboard_items (
  title,
  description,
  image_url,
  location,
  event_date,
  category,
  author_id,
  author_name,
  created_at
) VALUES
(
  'Happy Birthday Michael!',
  'Wishing our amazing colleague Michael a very happy birthday! Join us in the break room at 3 PM for cake and celebrations.',
  'https://images.unsplash.com/photo-1558636508-e0db3814bd1d?w=800',
  'Office Break Room',
  '2025-11-20 15:00:00',
  'greetings',
  'demo-user-4',
  'HR Team',
  NOW() - INTERVAL '3 hours'
),
(
  'Congratulations on Your Promotion!',
  'Huge congratulations to Jennifer on her well-deserved promotion to Senior Manager! Your hard work and dedication truly inspire us all.',
  'https://images.unsplash.com/photo-1464746133101-a2c3f88e0dd9?w=800',
  null,
  '2025-11-18 00:00:00',
  'greetings',
  'demo-user-3',
  'Sarah Director',
  NOW() - INTERVAL '2 days'
),
(
  'Welcome New Team Members!',
  'Please join us in welcoming our 3 new team members: Alex (Developer), Emma (Designer), and Chris (Analyst). Welcome to the family!',
  'https://images.unsplash.com/photo-1521737711867-e3b97375f902?w=800',
  'Welcome Lunch - Cafeteria',
  '2025-11-21 12:00:00',
  'greetings',
  'demo-user-1',
  'Admin',
  NOW() - INTERVAL '1 day'
),
(
  'Work Anniversary Celebration',
  'Celebrating 5 years of excellence! Thank you David for your outstanding contributions to the company. Here''s to many more years together!',
  'https://images.unsplash.com/photo-1530103862676-de8c9debad1d?w=800',
  null,
  '2025-11-22 00:00:00',
  'greetings',
  'demo-user-2',
  'John Manager',
  NOW() - INTERVAL '5 hours'
),
(
  'Holiday Season Greetings',
  'Wishing everyone a joyful holiday season! Thank you for your hard work this year. Looking forward to a successful 2026!',
  'https://images.unsplash.com/photo-1482517967863-00e15c9b44be?w=800',
  null,
  '2025-12-25 00:00:00',
  'greetings',
  'demo-user-3',
  'Sarah Director',
  NOW() - INTERVAL '30 minutes'
);

-- =====================================================
-- COMMENTS
-- =====================================================

-- Get the IDs of the inserted items (you may need to adjust these queries based on your actual IDs)
DO $$
DECLARE
  tax_deadline_id UUID;
  client_report_id UUID;
  allhands_meeting_id UUID;
  kickoff_meeting_id UUID;
  birthday_id UUID;
  promotion_id UUID;
BEGIN
  -- Get item IDs
  SELECT id INTO tax_deadline_id FROM pinboard_items WHERE title = 'Tax Return Filing Deadline' LIMIT 1;
  SELECT id INTO client_report_id FROM pinboard_items WHERE title = 'Client Report Submission' LIMIT 1;
  SELECT id INTO allhands_meeting_id FROM pinboard_items WHERE title = 'All-Hands Company Meeting' LIMIT 1;
  SELECT id INTO kickoff_meeting_id FROM pinboard_items WHERE title = 'Project Kickoff Meeting' LIMIT 1;
  SELECT id INTO birthday_id FROM pinboard_items WHERE title = 'Happy Birthday Michael!' LIMIT 1;
  SELECT id INTO promotion_id FROM pinboard_items WHERE title = 'Congratulations on Your Promotion!' LIMIT 1;

  -- Comments for Tax Deadline
  IF tax_deadline_id IS NOT NULL THEN
    INSERT INTO pinboard_comments (pinboard_item_id, author_id, author_name, content, created_at) VALUES
    (tax_deadline_id, 'demo-user-5', 'Emma Smith', 'Thanks for the reminder! Do we have a checklist of required documents?', NOW() - INTERVAL '1 hour'),
    (tax_deadline_id, 'demo-user-1', 'Admin', 'Yes! Check your email for the complete checklist sent yesterday.', NOW() - INTERVAL '30 minutes');
  END IF;

  -- Comments for Client Report
  IF client_report_id IS NOT NULL THEN
    INSERT INTO pinboard_comments (pinboard_item_id, author_id, author_name, content, created_at) VALUES
    (client_report_id, 'demo-user-6', 'Mike Johnson', 'Are we using the new template for this month?', NOW() - INTERVAL '3 hours'),
    (client_report_id, 'demo-user-2', 'John Manager', 'Yes, please use the updated template from the shared drive.', NOW() - INTERVAL '2 hours'),
    (client_report_id, 'demo-user-7', 'Lisa Chen', 'Got it! Will submit by Wednesday.', NOW() - INTERVAL '1 hour');
  END IF;

  -- Comments for All-Hands Meeting
  IF allhands_meeting_id IS NOT NULL THEN
    INSERT INTO pinboard_comments (pinboard_item_id, author_id, author_name, content, created_at) VALUES
    (allhands_meeting_id, 'demo-user-8', 'Tom Brown', 'Will this be recorded for remote team members?', NOW() - INTERVAL '4 hours'),
    (allhands_meeting_id, 'demo-user-2', 'John Manager', 'Yes, we''ll share the recording on the intranet after the meeting.', NOW() - INTERVAL '3 hours'),
    (allhands_meeting_id, 'demo-user-9', 'Anna White', 'Looking forward to it!', NOW() - INTERVAL '2 hours');
  END IF;

  -- Comments for Kickoff Meeting
  IF kickoff_meeting_id IS NOT NULL THEN
    INSERT INTO pinboard_comments (pinboard_item_id, author_id, author_name, content, created_at) VALUES
    (kickoff_meeting_id, 'demo-user-10', 'Chris Green', 'Do we have the project brief ready?', NOW() - INTERVAL '1 day'),
    (kickoff_meeting_id, 'demo-user-3', 'Sarah Director', 'Yes, it''s in the project folder. Please review before the meeting.', NOW() - INTERVAL '20 hours');
  END IF;

  -- Comments for Birthday
  IF birthday_id IS NOT NULL THEN
    INSERT INTO pinboard_comments (pinboard_item_id, author_id, author_name, content, created_at) VALUES
    (birthday_id, 'demo-user-5', 'Emma Smith', 'Happy Birthday Michael! 🎉', NOW() - INTERVAL '2 hours'),
    (birthday_id, 'demo-user-6', 'Mike Johnson', 'Have a great day! See you at 3 PM!', NOW() - INTERVAL '1 hour'),
    (birthday_id, 'demo-user-7', 'Lisa Chen', 'Happy Birthday! 🎂🎈', NOW() - INTERVAL '45 minutes');
  END IF;

  -- Comments for Promotion
  IF promotion_id IS NOT NULL THEN
    INSERT INTO pinboard_comments (pinboard_item_id, author_id, author_name, content, created_at) VALUES
    (promotion_id, 'demo-user-8', 'Tom Brown', 'Well deserved! Congratulations Jennifer!', NOW() - INTERVAL '1 day'),
    (promotion_id, 'demo-user-9', 'Anna White', 'So happy for you! You''ve earned it!', NOW() - INTERVAL '20 hours'),
    (promotion_id, 'demo-user-10', 'Chris Green', 'Congrats! Looking forward to working with you in your new role!', NOW() - INTERVAL '18 hours');
  END IF;
END $$;

-- =====================================================
-- LIKES
-- =====================================================

DO $$
DECLARE
  item_id UUID;
BEGIN
  -- Add likes to various items
  FOR item_id IN SELECT id FROM pinboard_items LIMIT 10
  LOOP
    -- Random number of likes (3-8 per item)
    INSERT INTO pinboard_likes (pinboard_item_id, user_id)
    SELECT item_id, 'demo-user-' || generate_series(1, floor(random() * 6 + 3)::int);
  END LOOP;
END $$;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check how many items were created
SELECT
  category,
  COUNT(*) as item_count
FROM pinboard_items
GROUP BY category
ORDER BY category;

-- Check total comments
SELECT COUNT(*) as total_comments FROM pinboard_comments;

-- Check total likes
SELECT COUNT(*) as total_likes FROM pinboard_likes;

-- Show sample items with counts
SELECT
  pi.title,
  pi.category,
  pi.author_name,
  pi.event_date,
  COUNT(DISTINCT pl.user_id) as likes_count,
  COUNT(DISTINCT pc.id) as comments_count
FROM pinboard_items pi
LEFT JOIN pinboard_likes pl ON pi.id = pl.pinboard_item_id
LEFT JOIN pinboard_comments pc ON pi.id = pc.pinboard_item_id
GROUP BY pi.id, pi.title, pi.category, pi.author_name, pi.event_date
ORDER BY pi.created_at DESC;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Demo data created successfully!';
  RAISE NOTICE '📋 Created 15 pinboard items (5 per category)';
  RAISE NOTICE '💬 Created sample comments on multiple items';
  RAISE NOTICE '❤️  Created sample likes on all items';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Your pinboard is now ready for testing!';
  RAISE NOTICE '📱 Open the app and navigate to the Pinboard page to see the data.';
END $$;
