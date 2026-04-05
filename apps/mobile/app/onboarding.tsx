import { View, Text, Pressable, StyleSheet, Alert } from 'react-native';
import AuthGate from '../components/AuthGate';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import ScrapbookCard from '../components/theme/ScrapbookCard';
import TitleBanner from '../components/theme/TitleBanner';
import { useTheme } from '../hooks/useTheme';

export default function OnboardingScreen() {
  const { session, refreshProfile, isGuest } = useAuth();
  const router = useRouter();
  const [saving, setSaving] = useState(false);
  const colors = useTheme();

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
      <ScrapbookBackground>
        <View style={styles.container}>
          <TitleBanner title="Finish Setup" />

          <ScrapbookCard style={styles.card} innerStyle={styles.cardInner}>
            <Text style={[styles.eyebrow, { color: colors.textSecondary }]}>
              Final Step
            </Text>
            <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
              One last pass before you explore
            </Text>

            <Text style={[styles.cardBody, { color: colors.textSecondary }]}>
              Save your profile setup so recommendations, planning, and personal details all stay in sync.
            </Text>
            <View
              style={[
                styles.statusCard,
                { backgroundColor: colors.surface, borderColor: colors.border },
              ]}
            >
              <Text style={[styles.statusEyebrow, { color: colors.textSecondary }]}>
                Ready to unlock
              </Text>
              <Text style={[styles.statusValue, { color: colors.textPrimary }]}>
                Personalized recommendations, profile syncing, and trip planning
              </Text>
            </View>

            <Pressable
              style={[
                styles.button,
                { backgroundColor: colors.paperAlt, borderColor: colors.border },
              ]}
              onPress={completeOnboarding}
            >
              <Text style={[styles.buttonText, { color: colors.textPrimary }]}>
                {saving ? 'Saving...' : 'Complete Setup'}
              </Text>
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
              <Text style={[styles.skipText, { color: colors.textSecondary }]}>
                Skip for now
              </Text>
            </Pressable>
          </ScrapbookCard>
        </View>
      </ScrapbookBackground>
    </AuthGate>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 20,
    paddingVertical: 28,
  },
  subtitle: {
    display: 'none',
  },
  card: {
    width: '100%',
    alignSelf: 'center',
  },
  cardInner: {
    paddingHorizontal: 20,
    paddingVertical: 22,
  },
  eyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 10,
  },
  cardTitle: {
    fontSize: 22,
    fontWeight: '600',
    marginBottom: 14,
  },
  cardBody: {
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 18,
  },
  statusCard: {
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginBottom: 22,
  },
  statusEyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    marginBottom: 6,
  },
  statusValue: {
    fontSize: 14,
    fontWeight: '700',
    lineHeight: 20,
  },
  button: {
    paddingVertical: 15,
    borderRadius: 18,
    alignItems: 'center',
    borderWidth: 1,
  },
  buttonText: { fontWeight: '600', fontSize: 16 },
  skipButton: {
    marginTop: 18,
    alignItems: 'center',
  },
  skipText: {
    fontSize: 14,
  },
});
