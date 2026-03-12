import { View, ActivityIndicator } from 'react-native';
import { useEffect, useRef } from 'react';
import { useRouter, usePathname } from 'expo-router';
import { useAuth } from '../context/AuthContext';

export default function AuthGate({ children }: { children: React.ReactNode }) {
  const { session, loading, isGuest, profile, profileLoading } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  const hasRedirectedRef = useRef(false);

  // Not logged in and not guest -> must be on landing/login flow
  useEffect(() => {
    if (hasRedirectedRef.current) return;

    if (!loading && !session && !isGuest) {
      const isPublicRoute =
        pathname === '/' ||
        pathname === '/verify' ||
        pathname.startsWith('/login');

      if (!isPublicRoute) {
        hasRedirectedRef.current = true;
        router.replace('/');
      }
    }
  }, [loading, session, isGuest]);

  // Logged in -> enforce onboarding gate (guest bypasses)
  useEffect(() => {
    if (hasRedirectedRef.current) return;
    if (loading || profileLoading) return;
    if (!session || isGuest) return;
    if (!profile) return;

    const onboarded = profile?.onboarding_completed === true;

    if (!onboarded && pathname !== '/onboarding') {
      hasRedirectedRef.current = true;
      router.replace('/onboarding');
      return;
    }

    if (onboarded && pathname === '/onboarding') {
      hasRedirectedRef.current = true;
      router.replace('/(tabs)/discovery');
    }
  }, [loading, profileLoading, session, isGuest, profile]);

  if (loading || (session && !isGuest && profileLoading)) {
    return (
      <View style={{ flex: 1, justifyContent: 'center' }}>
        <ActivityIndicator />
      </View>
    );
  }

  // Always render children once loading checks pass.
  // Redirect logic above handles protection.
  return <>{children}</>;
}