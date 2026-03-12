import { View, Text, Pressable, StyleSheet, Alert, useColorScheme } from 'react-native';
import AuthGate from '../components/AuthGate';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { useRouter } from 'expo-router';
import { useState } from 'react';

export default function OnboardingScreen() {
  const { session, refreshProfile, isGuest } = useAuth();
  const router = useRouter();
  const [saving, setSaving] = useState(false);

  const colorScheme = useColorScheme();
  const isDark = colorScheme === 'dark';

  const completeOnboarding = async () => {
    if (isGuest) {
      Alert.alert('Guest Mode', 'Please log in to complete onboarding.');
      return;
    }
    const userId = session?.user?.id;
    if (!userId) return;

    setSaving(true);

    const { error } = await supabase
      .from('profiles')
      .update({ onboarding_completed: true })
      .eq('id', userId);

    setSaving(false);

    if (error) {
      Alert.alert('Error', error.message);
      return;
    }

    await refreshProfile();
    router.replace('/home');
  };

  return (
    <AuthGate>
      <View style={[styles.container, { backgroundColor: isDark ? '#000' : '#fff' }]}>
        <Text style={[styles.title, { color: isDark ? '#fff' : '#000' }]}>Finish Setup</Text>
        <Text style={[styles.subtitle, { color: isDark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.6)' }]}>
          This is the onboarding gate (mirrors iOS). We’ll replace this with the real flow.
        </Text>

        <Pressable style={styles.button} onPress={completeOnboarding}>
          <Text style={styles.buttonText}>{saving ? 'Saving...' : 'Complete Onboarding (dev)'}</Text>
        </Pressable>

        <Pressable
          style={styles.skipButton}
          onPress={async () => {
            if (!session?.user?.id) return;

            await supabase
              .from('profiles')
              .update({ onboarding_completed: true })
              .eq('id', session.user.id);

            await refreshProfile();
            router.replace('/(tabs)/discovery');
          }}
        >
          <Text style={[styles.skipText, { color: isDark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.6)' }]}>Skip for now</Text>
        </Pressable>
      </View>
    </AuthGate>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24 },
  title: { fontSize: 28, fontWeight: '600', marginBottom: 12, textAlign: 'center' },
  subtitle: { textAlign: 'center', marginBottom: 24, opacity: 0.7 },
  button: { backgroundColor: 'black', padding: 14, borderRadius: 8, alignItems: 'center' },
  buttonText: { color: 'white', fontWeight: '600' },
  skipButton: {
    marginTop: 16,
    alignItems: 'center',
  },
  skipText: {
    fontSize: 14,
    opacity: 0.7,
  },
});