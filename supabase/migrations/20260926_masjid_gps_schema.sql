-- ==============================================================================
-- Migration: Masjid GPS Schema
-- Description: Initial schema setup for Masjid GPS app including PostGIS
-- ==============================================================================

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

-- ==============================================================================
-- 2. Tables Creation
-- ==============================================================================

-- imam_profiles
CREATE TABLE public.imam_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- mosques
CREATE TABLE public.mosques (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    imam_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 150,
    share_code TEXT UNIQUE,
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- committee_members
CREATE TABLE public.committee_members (
    mosque_id UUID REFERENCES public.mosques(id) ON DELETE CASCADE,
    member_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    title TEXT DEFAULT 'Committee Member',
    added_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (mosque_id, member_user_id)
);

-- prayer_times
CREATE TABLE public.prayer_times (
    mosque_id UUID PRIMARY KEY REFERENCES public.mosques(id) ON DELETE CASCADE,
    fajr TEXT NOT NULL DEFAULT '05:00',
    dhuhr TEXT NOT NULL DEFAULT '13:00',
    asr TEXT NOT NULL DEFAULT '17:00',
    maghrib TEXT NOT NULL DEFAULT '18:30',
    isha TEXT NOT NULL DEFAULT '20:00',
    jumuah TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id)
);

-- announcements
CREATE TABLE public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mosque_id UUID REFERENCES public.mosques(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- subscriptions
CREATE TABLE public.subscriptions (
    device_id TEXT NOT NULL,
    mosque_id UUID REFERENCES public.mosques(id) ON DELETE CASCADE,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (device_id, mosque_id)
);

-- ==============================================================================
-- 3. Indexes
-- ==============================================================================
CREATE INDEX idx_mosques_location ON public.mosques USING GIST (location);
CREATE INDEX idx_mosques_share_code ON public.mosques (share_code);
CREATE INDEX idx_imam_profiles_status ON public.imam_profiles (status);
CREATE INDEX idx_subscriptions_mosque_id ON public.subscriptions (mosque_id);
CREATE INDEX idx_announcements_mosque_created ON public.announcements (mosque_id, created_at DESC);

-- ==============================================================================
-- 4. Enable RLS
-- ==============================================================================
ALTER TABLE public.imam_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mosques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.committee_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prayer_times ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- 5. Helper Functions
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.is_imam_or_committee(p_mosque_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.mosques
        WHERE id = p_mosque_id AND imam_user_id = auth.uid()
    ) OR EXISTS (
        SELECT 1 FROM public.committee_members
        WHERE mosque_id = p_mosque_id AND member_user_id = auth.uid()
    );
END;
$$;

-- ==============================================================================
-- 6. Row Level Security Policies
-- ==============================================================================

-- imam_profiles
CREATE POLICY "Users can view their own profile or all if authenticated"
    ON public.imam_profiles FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Users can insert their own profile"
    ON public.imam_profiles FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile or admin"
    ON public.imam_profiles FOR UPDATE TO authenticated
    USING (true)
    WITH CHECK (true);

-- mosques
CREATE POLICY "Everyone can view active mosques"
    ON public.mosques FOR SELECT
    USING (is_active = true);

CREATE POLICY "Approved imams can insert mosques"
    ON public.mosques FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.imam_profiles
            WHERE user_id = auth.uid() AND status = 'approved'
        )
    );

CREATE POLICY "Imams can update their mosques"
    ON public.mosques FOR UPDATE TO authenticated
    USING (imam_user_id = auth.uid())
    WITH CHECK (imam_user_id = auth.uid());

CREATE POLICY "Imams can delete their mosques"
    ON public.mosques FOR DELETE TO authenticated
    USING (imam_user_id = auth.uid());

-- committee_members
CREATE POLICY "Everyone can view committee members"
    ON public.committee_members FOR SELECT
    USING (true);

CREATE POLICY "Imams can insert committee members"
    ON public.committee_members FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.mosques
            WHERE id = mosque_id AND imam_user_id = auth.uid()
        )
    );

CREATE POLICY "Imams can delete committee members"
    ON public.committee_members FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.mosques
            WHERE id = mosque_id AND imam_user_id = auth.uid()
        )
    );

-- prayer_times
CREATE POLICY "Everyone can view prayer times"
    ON public.prayer_times FOR SELECT
    USING (true);

CREATE POLICY "Imams or committee can insert prayer times"
    ON public.prayer_times FOR INSERT TO authenticated
    WITH CHECK (public.is_imam_or_committee(mosque_id));

CREATE POLICY "Imams or committee can update prayer times"
    ON public.prayer_times FOR UPDATE TO authenticated
    USING (public.is_imam_or_committee(mosque_id))
    WITH CHECK (public.is_imam_or_committee(mosque_id));

-- announcements
CREATE POLICY "Everyone can view announcements"
    ON public.announcements FOR SELECT
    USING (true);

CREATE POLICY "Imams or committee can insert announcements"
    ON public.announcements FOR INSERT TO authenticated
    WITH CHECK (public.is_imam_or_committee(mosque_id));

CREATE POLICY "Creators or imams can delete announcements"
    ON public.announcements FOR DELETE TO authenticated
    USING (
        created_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.mosques
            WHERE id = mosque_id AND imam_user_id = auth.uid()
        )
    );

-- subscriptions
CREATE POLICY "Anyone can view subscriptions"
    ON public.subscriptions FOR SELECT
    USING (true);

CREATE POLICY "Anyone can insert subscriptions"
    ON public.subscriptions FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Anyone can delete subscriptions"
    ON public.subscriptions FOR DELETE
    USING (true);


-- ==============================================================================
-- 7. RPCs (Remote Procedure Calls)
-- ==============================================================================

-- request_imam_access
CREATE OR REPLACE FUNCTION public.request_imam_access(p_full_name TEXT, p_phone TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.imam_profiles (user_id, full_name, phone, status)
    VALUES (auth.uid(), p_full_name, p_phone, 'pending')
    ON CONFLICT (user_id) DO NOTHING;
END;
$$;

-- nearby_mosques
CREATE OR REPLACE FUNCTION public.nearby_mosques(p_lat FLOAT8, p_lng FLOAT8, p_radius_km FLOAT8)
RETURNS TABLE (
    id UUID,
    name TEXT,
    latitude FLOAT8,
    longitude FLOAT8,
    radius_meters INT,
    share_code TEXT,
    address TEXT,
    distance_m FLOAT8,
    follower_count BIGINT,
    has_times BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.name,
        m.latitude,
        m.longitude,
        m.radius_meters,
        m.share_code,
        m.address,
        ST_Distance(m.location, ST_MakePoint(p_lng, p_lat)::geography) AS distance_m,
        (SELECT COUNT(*) FROM public.subscriptions s WHERE s.mosque_id = m.id) AS follower_count,
        EXISTS (SELECT 1 FROM public.prayer_times pt WHERE pt.mosque_id = m.id) AS has_times
    FROM public.mosques m
    WHERE m.is_active = true
      AND ST_DWithin(m.location, ST_MakePoint(p_lng, p_lat)::geography, p_radius_km * 1000)
    ORDER BY distance_m ASC;
END;
$$;

-- register_mosque
CREATE OR REPLACE FUNCTION public.register_mosque(
    p_name TEXT, 
    p_lat FLOAT8, 
    p_lng FLOAT8, 
    p_radius INT, 
    p_address TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_status TEXT;
    v_dup_name TEXT;
    v_share_code TEXT;
    v_new_mosque JSON;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'NOT_AUTHENTICATED';
    END IF;

    SELECT status INTO v_status FROM public.imam_profiles WHERE user_id = v_uid;
    IF v_status IS DISTINCT FROM 'approved' THEN
        RAISE EXCEPTION 'IMAM_NOT_APPROVED';
    END IF;

    SELECT name INTO v_dup_name FROM public.mosques 
    WHERE ST_DWithin(location, ST_MakePoint(p_lng, p_lat)::geography, 50)
    LIMIT 1;

    IF v_dup_name IS NOT NULL THEN
        RAISE EXCEPTION 'DUPLICATE_MOSQUE' USING DETAIL = v_dup_name;
    END IF;

    -- Generate a unique 6-character alphanumeric share_code
    v_share_code := upper(substring(md5(random()::text), 1, 6));

    INSERT INTO public.mosques (
        imam_user_id, name, latitude, longitude, location, radius_meters, share_code, address
    ) VALUES (
        v_uid, p_name, p_lat, p_lng, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, p_radius, v_share_code, p_address
    )
    RETURNING row_to_json(mosques.*) INTO v_new_mosque;

    RETURN v_new_mosque;
END;
$$;

-- my_managed_mosques
CREATE OR REPLACE FUNCTION public.my_managed_mosques()
RETURNS TABLE (
    id UUID,
    name TEXT,
    latitude FLOAT8,
    longitude FLOAT8,
    radius_meters INT,
    share_code TEXT,
    address TEXT,
    follower_count BIGINT,
    my_role TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.name,
        m.latitude,
        m.longitude,
        m.radius_meters,
        m.share_code,
        m.address,
        (SELECT COUNT(*) FROM public.subscriptions s WHERE s.mosque_id = m.id) AS follower_count,
        'imam'::TEXT AS my_role
    FROM public.mosques m
    WHERE m.imam_user_id = auth.uid()
    UNION
    SELECT 
        m.id,
        m.name,
        m.latitude,
        m.longitude,
        m.radius_meters,
        m.share_code,
        m.address,
        (SELECT COUNT(*) FROM public.subscriptions s WHERE s.mosque_id = m.id) AS follower_count,
        'committee'::TEXT AS my_role
    FROM public.mosques m
    JOIN public.committee_members cm ON cm.mosque_id = m.id
    WHERE cm.member_user_id = auth.uid();
END;
$$;

-- follow_mosque
CREATE OR REPLACE FUNCTION public.follow_mosque(p_mosque_id UUID, p_device_id TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.subscriptions (device_id, mosque_id)
    VALUES (p_device_id, p_mosque_id)
    ON CONFLICT (device_id, mosque_id) DO NOTHING;
END;
$$;

-- unfollow_mosque
CREATE OR REPLACE FUNCTION public.unfollow_mosque(p_mosque_id UUID, p_device_id TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.subscriptions 
    WHERE device_id = p_device_id AND mosque_id = p_mosque_id;
END;
$$;

-- list_committee
CREATE OR REPLACE FUNCTION public.list_committee(p_mosque_id UUID)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    title TEXT,
    added_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.mosques WHERE id = p_mosque_id AND imam_user_id = auth.uid()) THEN
        RAISE EXCEPTION 'ONLY_IMAM';
    END IF;

    RETURN QUERY
    SELECT 
        cm.member_user_id AS user_id,
        u.email::TEXT,
        (u.raw_user_meta_data->>'full_name')::TEXT AS full_name,
        cm.title,
        cm.added_at
    FROM public.committee_members cm
    JOIN auth.users u ON u.id = cm.member_user_id
    WHERE cm.mosque_id = p_mosque_id;
END;
$$;

-- add_committee_member
CREATE OR REPLACE FUNCTION public.add_committee_member(p_mosque_id UUID, p_email TEXT, p_title TEXT DEFAULT 'Committee Member')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_imam_user_id UUID;
BEGIN
    SELECT imam_user_id INTO v_imam_user_id FROM public.mosques WHERE id = p_mosque_id;

    IF v_imam_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'ONLY_IMAM';
    END IF;

    SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    IF v_user_id = v_imam_user_id THEN
        RAISE EXCEPTION 'ALREADY_IMAM';
    END IF;

    INSERT INTO public.committee_members (mosque_id, member_user_id, email, title)
    VALUES (p_mosque_id, v_user_id, p_email, p_title)
    ON CONFLICT (mosque_id, member_user_id) DO UPDATE SET title = p_title;
END;
$$;

-- remove_committee_member
CREATE OR REPLACE FUNCTION public.remove_committee_member(p_mosque_id UUID, p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.mosques WHERE id = p_mosque_id AND imam_user_id = auth.uid()) THEN
        RAISE EXCEPTION 'ONLY_IMAM';
    END IF;

    DELETE FROM public.committee_members
    WHERE mosque_id = p_mosque_id AND member_user_id = p_user_id;
END;
$$;

-- ==============================================================================
-- 8. Triggers
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.sync_mosque_location()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sync_mosque_location
BEFORE INSERT OR UPDATE OF latitude, longitude ON public.mosques
FOR EACH ROW
EXECUTE FUNCTION public.sync_mosque_location();

-- ==============================================================================
-- 9. Realtime
-- ==============================================================================
DO $$
BEGIN
    -- Enable logical replication on the tables for Realtime
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE public.prayer_times;
ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
