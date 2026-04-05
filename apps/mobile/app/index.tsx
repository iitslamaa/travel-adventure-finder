import { Redirect } from 'expo-router';
import { useAuth } from '../context/AuthContext';

export default function RootIndex() {
  const { session, loading, isGuest } = useAuth();

  // While auth is booting, render nothing
  if (loading) {
    return null;
  }

  // Once auth is ready, synchronously return the correct route
  if (session || isGuest) {
    return <Redirect href="/(tabs)/discovery" />;
  }

  return <Redirect href="/login" />;
}
