-- ============================================================
-- LuxeState CRM — Messaging Schema
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1. CONTACTS
CREATE TABLE IF NOT EXISTS public.contacts (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name            TEXT NOT NULL,
  phone           TEXT,
  email           TEXT,
  avatar_initials TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 2. CONVERSATIONS
CREATE TABLE IF NOT EXISTS public.conversations (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  contact_id       UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  lead_id          INTEGER,   -- links to Leads (Postgres integer PK)
  title            TEXT,
  status           TEXT DEFAULT 'active' CHECK (status IN ('active', 'pending', 'resolved')),
  linked_property  TEXT,
  last_message     TEXT,
  last_message_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  unread_count     INT DEFAULT 0 NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 3. MESSAGES
CREATE TABLE IF NOT EXISTS public.messages (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id       UUID REFERENCES auth.users(id) NOT NULL,
  content         TEXT NOT NULL,
  type            TEXT DEFAULT 'text' CHECK (type IN ('text', 'template', 'note')),
  status          TEXT DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 4. INDEXES
CREATE INDEX IF NOT EXISTS idx_conversations_user_id  ON public.conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_contact  ON public.conversations(contact_id);
CREATE INDEX IF NOT EXISTS idx_conversations_lead_id  ON public.conversations(lead_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation  ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at   ON public.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_contacts_user_id      ON public.contacts(user_id);

-- 5. ROW LEVEL SECURITY
ALTER TABLE public.contacts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages      ENABLE ROW LEVEL SECURITY;

-- Contacts: full access for owner
CREATE POLICY "contacts_owner" ON public.contacts FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Conversations: full access for owner
CREATE POLICY "conversations_owner" ON public.conversations FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Messages: read if conversation belongs to you
CREATE POLICY "messages_select" ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE conversations.id = messages.conversation_id
        AND conversations.user_id = auth.uid()
    )
  );

-- Messages: insert if conversation belongs to you and you are the sender
CREATE POLICY "messages_insert" ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE conversations.id = messages.conversation_id
        AND conversations.user_id = auth.uid()
    )
  );

-- Messages: update status if conversation belongs to you
CREATE POLICY "messages_update" ON public.messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations
      WHERE conversations.id = messages.conversation_id
        AND conversations.user_id = auth.uid()
    )
  );

-- 6. ENABLE REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
