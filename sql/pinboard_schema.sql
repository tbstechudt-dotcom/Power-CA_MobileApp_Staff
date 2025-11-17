-- Pinboard Feature Database Schema
-- Run this SQL file in Supabase SQL Editor to create the required tables

-- 1. Create pinboard_items table
CREATE TABLE IF NOT EXISTS pinboard_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  author_name VARCHAR(255) NOT NULL,
  title VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  image_url TEXT,
  location VARCHAR(500),
  event_date TIMESTAMP WITH TIME ZONE NOT NULL,
  category VARCHAR(50) NOT NULL CHECK (category IN ('due_date', 'meetings', 'greetings')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create pinboard_comments table
CREATE TABLE IF NOT EXISTS pinboard_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pinboard_item_id UUID NOT NULL REFERENCES pinboard_items(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  author_name VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create pinboard_likes table (many-to-many relationship)
CREATE TABLE IF NOT EXISTS pinboard_likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pinboard_item_id UUID NOT NULL REFERENCES pinboard_items(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(pinboard_item_id, user_id)
);

-- 4. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_pinboard_items_category ON pinboard_items(category);
CREATE INDEX IF NOT EXISTS idx_pinboard_items_event_date ON pinboard_items(event_date);
CREATE INDEX IF NOT EXISTS idx_pinboard_items_created_at ON pinboard_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pinboard_comments_item_id ON pinboard_comments(pinboard_item_id);
CREATE INDEX IF NOT EXISTS idx_pinboard_comments_created_at ON pinboard_comments(created_at ASC);
CREATE INDEX IF NOT EXISTS idx_pinboard_likes_item_id ON pinboard_likes(pinboard_item_id);
CREATE INDEX IF NOT EXISTS idx_pinboard_likes_user_id ON pinboard_likes(user_id);

-- 5. Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create triggers to automatically update updated_at
CREATE TRIGGER update_pinboard_items_updated_at
  BEFORE UPDATE ON pinboard_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pinboard_comments_updated_at
  BEFORE UPDATE ON pinboard_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 7. Enable Row Level Security (RLS)
ALTER TABLE pinboard_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pinboard_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE pinboard_likes ENABLE ROW LEVEL SECURITY;

-- 8. Create RLS Policies

-- Pinboard Items: Everyone can read, authenticated users can create
CREATE POLICY "Allow anyone to read pinboard items"
  ON pinboard_items
  FOR SELECT
  USING (true);

CREATE POLICY "Allow authenticated users to create pinboard items"
  ON pinboard_items
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow users to update their own pinboard items"
  ON pinboard_items
  FOR UPDATE
  USING (auth.uid() = author_id);

CREATE POLICY "Allow users to delete their own pinboard items"
  ON pinboard_items
  FOR DELETE
  USING (auth.uid() = author_id);

-- Pinboard Comments: Everyone can read, authenticated users can create
CREATE POLICY "Allow anyone to read comments"
  ON pinboard_comments
  FOR SELECT
  USING (true);

CREATE POLICY "Allow authenticated users to create comments"
  ON pinboard_comments
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow users to update their own comments"
  ON pinboard_comments
  FOR UPDATE
  USING (auth.uid() = author_id);

CREATE POLICY "Allow users to delete their own comments"
  ON pinboard_comments
  FOR DELETE
  USING (auth.uid() = author_id);

-- Pinboard Likes: Everyone can read, authenticated users can manage their likes
CREATE POLICY "Allow anyone to read likes"
  ON pinboard_likes
  FOR SELECT
  USING (true);

CREATE POLICY "Allow authenticated users to create likes"
  ON pinboard_likes
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

CREATE POLICY "Allow users to delete their own likes"
  ON pinboard_likes
  FOR DELETE
  USING (auth.uid() = user_id);

-- 9. Insert sample data (optional, for testing)
-- Comment out this section if you don't want sample data

/*
INSERT INTO pinboard_items (author_id, author_name, title, description, category, event_date, location) VALUES
(
  (SELECT id FROM auth.users LIMIT 1),
  'Admin User',
  'Project Deadline - Q4 Report',
  'Please ensure all Q4 reports are submitted by the end of this month. This includes financial summaries, project progress updates, and team performance reviews.',
  'due_date',
  NOW() + INTERVAL '7 days',
  'Main Office'
),
(
  (SELECT id FROM auth.users LIMIT 1),
  'Admin User',
  'Monthly Team Meeting',
  'Monthly team meeting to discuss project progress, upcoming milestones, and team collaboration. All team members are expected to attend.',
  'meetings',
  NOW() + INTERVAL '3 days',
  'Conference Room A'
),
(
  (SELECT id FROM auth.users LIMIT 1),
  'Admin User',
  'Happy Birthday John!',
  'Join us in celebrating John''s birthday! Cake and refreshments will be served in the break room.',
  'greetings',
  NOW() + INTERVAL '2 days',
  'Break Room'
);
*/

-- 10. Grant necessary permissions
GRANT ALL ON pinboard_items TO authenticated;
GRANT ALL ON pinboard_comments TO authenticated;
GRANT ALL ON pinboard_likes TO authenticated;

-- Done! Your pinboard tables are now ready to use.
