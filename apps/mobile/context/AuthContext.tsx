import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { supabase } from '../lib/supabase';
import { Session } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { getResizedAvatarUrl } from '../utils/avatar';

export type Profile = {
  id: string;
  username: string | null;
  full_name?: string | null;
  onboarding_completed: boolean | null;
  avatar_url?: string | null;
  next_destination?: string | null;
  travel_mode?: string | null;
  travel_style?: string | null;
  languages?: any[] | null;
  lived_countries?: string[] | null;
};

type AuthContextType = {
  session: Session | null;
  loading: boolean;

  profile: Profile | null;
  profileLoading: boolean;

  bucketIsoCodes: string[];
  visitedIsoCodes: string[];

  toggleBucket: (iso2: string) => Promise<void>;
  toggleVisited: (iso2: string) => Promise<void>;
  isBucketed: (iso2: string) => boolean;
  isVisited: (iso2: string) => boolean;

  isGuest: boolean;
  continueAsGuest: () => void;
  exitGuest: () => void;

  refreshProfile: () => Promise<void>;
  updateProfile: (patch: Partial<Profile>) => Promise<void>;
  signOut: () => Promise<void>;
  hasSeenIntro: boolean | null;
  setHasSeenIntro: (value: boolean) => void;
};

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  const [profile, setProfile] = useState<Profile | null>(null);
  const [profileLoading, setProfileLoading] = useState(false);

  const [bucketIsoCodes, setBucketIsoCodes] = useState<string[]>([]);
  const [visitedIsoCodes, setVisitedIsoCodes] = useState<string[]>([]);

  const [isGuest, setIsGuest] = useState(false);
  const [hasSeenIntro, setHasSeenIntro] = useState<boolean | null>(null);

  const fetchProfile = async (userId: string) => {
    setProfileLoading(true);

    const [
      profileRes,
      bucketRes,
      visitedRes,
    ] = await Promise.all([
      supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single(),
      supabase
        .from('user_bucket_list')
        .select('country_id')
        .eq('user_id', userId),
      supabase
        .from('user_traveled')
        .select('country_id')
        .eq('user_id', userId),
    ]);

    if (!profileRes.error && profileRes.data) {
      const normalizedProfile = {
        ...profileRes.data,
        avatar_url: getResizedAvatarUrl(profileRes.data.avatar_url ?? null),
      } as Profile;

      setProfile(normalizedProfile);
    }

    setBucketIsoCodes(
      bucketRes.data?.map((r: any) => r.country_id) ?? []
    );

    setVisitedIsoCodes(
      visitedRes.data?.map((r: any) => r.country_id) ?? []
    );

    setProfileLoading(false);
  };

  const refreshProfile = async () => {
    const userId = session?.user?.id;
    if (!userId) return;
    await fetchProfile(userId);
  };

  const updateProfile = async (patch: Partial<Profile>) => {
    const userId = session?.user?.id;
    if (!userId) return;

    const { data, error } = await supabase
      .from('profiles')
      .update(patch)
      .eq('id', userId)
      .select('*')
      .single();

    if (!error && data) {
      const normalizedProfile = {
        ...data,
        avatar_url: getResizedAvatarUrl(data.avatar_url ?? null),
      } as Profile;

      setProfile(normalizedProfile);
    }
  };

  const isBucketed = (iso2: string) => bucketIsoCodes.includes(iso2);
  const isVisited = (iso2: string) => visitedIsoCodes.includes(iso2);

  const toggleBucket = async (iso2: string) => {
    const userId = session?.user?.id;
    if (!userId) return;

    if (bucketIsoCodes.includes(iso2)) {
      await supabase
        .from('user_bucket_list')
        .delete()
        .eq('user_id', userId)
        .eq('country_id', iso2);

      setBucketIsoCodes(prev => prev.filter(c => c !== iso2));
    } else {
      await supabase
        .from('user_bucket_list')
        .insert({ user_id: userId, country_id: iso2 });

      setBucketIsoCodes(prev => [...prev, iso2]);
    }
  };

  const toggleVisited = async (iso2: string) => {
    const userId = session?.user?.id;
    if (!userId) return;

    if (visitedIsoCodes.includes(iso2)) {
      await supabase
        .from('user_traveled')
        .delete()
        .eq('user_id', userId)
        .eq('country_id', iso2);

      setVisitedIsoCodes(prev => prev.filter(c => c !== iso2));
    } else {
      await supabase
        .from('user_traveled')
        .insert({ user_id: userId, country_id: iso2 });

      setVisitedIsoCodes(prev => [...prev, iso2]);
    }
  };

  useEffect(() => {
    const boot = async () => {
      const introFlag = await AsyncStorage.getItem('hasSeenIntro');
      setHasSeenIntro(introFlag === 'true');

      const { data } = await supabase.auth.getSession();
      console.log('[AUTHCTX] boot:getSession raw:', data);
      const s = data.session ?? null;
      console.log('[AUTHCTX] boot:setSession ->', s ? 'HAS_SESSION' : 'NULL');
      setSession(s);
      setLoading(false);

      if (s?.user?.id) {
        await fetchProfile(s.user.id);
      }
    };

    boot();

    const { data: listener } = supabase.auth.onAuthStateChange((event, newSession) => {
      console.log('[AUTHCTX] onAuthStateChange EVENT:', event);
      console.log('[AUTHCTX] onAuthStateChange newSession:', newSession ? 'HAS_SESSION' : 'NULL');

      const s = newSession ?? null;
      console.log('[AUTHCTX] setting session to', s ? 'HAS_SESSION' : 'NULL');
      setSession(s);

      if (s?.user?.id) {
        setIsGuest(false);
        fetchProfile(s.user.id);
      } else {
        setProfile(null);
        setBucketIsoCodes([]);
        setVisitedIsoCodes([]);
        setIsGuest(false);
      }
    });

    return () => {
      listener.subscription.unsubscribe();
    };
  }, []);

  const continueAsGuest = () => {
    setIsGuest(true);
    setSession(null);
    setProfile(null);
  };

  const exitGuest = () => {
    setIsGuest(false);
  };

  const signOut = async () => {
    try {
      console.log('[AUTHCTX] signOut() called');
      // Supabase sign out
      await supabase.auth.signOut();
      console.log('[AUTHCTX] signOut() completed');

      // Hard-clear any app-level cached auth/session state
      // (this prevents "stuck on auth page" loops after logout)
      await AsyncStorage.removeItem('travelaf-auth');

      // Reset in-memory state
      setSession(null);
      setProfile(null);
      setBucketIsoCodes([]);
      setVisitedIsoCodes([]);
      setIsGuest(false);
    } catch (error) {
      console.error('signOut error:', error);
      // Even if signOut fails, ensure UI state is cleared to avoid redirect loops
      setSession(null);
      setProfile(null);
      setBucketIsoCodes([]);
      setVisitedIsoCodes([]);
      setIsGuest(false);
    }
  };

  const value = useMemo<AuthContextType>(
    () => ({
      session,
      loading,
      profile,
      profileLoading,
      bucketIsoCodes,
      visitedIsoCodes,
      toggleBucket,
      toggleVisited,
      isBucketed,
      isVisited,
      isGuest,
      continueAsGuest,
      exitGuest,
      refreshProfile,
      updateProfile,
      signOut,
      hasSeenIntro,
      setHasSeenIntro,
    }),
    [session, loading, profile, profileLoading, bucketIsoCodes, visitedIsoCodes, isGuest, hasSeenIntro]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}