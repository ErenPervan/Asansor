-- Migration: Remove duplicate profiles update policy
-- The policy "Profiles: Users view/update own" (cmd = ALL, roles = {authenticated})
-- already securely covers the functionality of "Users can update own profile" (cmd = UPDATE, roles = {public}).

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
