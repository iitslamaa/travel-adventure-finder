import { useEffect } from 'react';
import { View, ActivityIndicator, Text, StyleSheet } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { supabase } from '../../lib/supabase';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import { useTheme } from '../../hooks/useTheme';

export default function AuthCallback() {
  const { code } = useLocalSearchParams();
  const router = useRouter();
  const colors = useTheme();

  useEffect(() => {
    const exchange = async () => {
      if (!code) return;

      const { error } = await supabase.auth.exchangeCodeForSession(
        code as string
      );

      if (!error) {
        router.replace('/');
      } else {
        console.log('Exchange error:', error);
      }
    };

    exchange();
  }, [code, router]);

  return (
    <ScrapbookBackground>
      <View style={styles.container}>
        <ScrapbookCard innerStyle={styles.card}>
          <Text style={[styles.eyebrow, { color: colors.textSecondary }]}>
            Secure handoff
          </Text>
          <ActivityIndicator size="large" color={colors.textPrimary} />
          <Text style={[styles.title, { color: colors.textPrimary }]}>
            Finishing your sign-in
          </Text>
          <Text style={[styles.body, { color: colors.textSecondary }]}>
            We&apos;re securely connecting your account and bringing you back into the app.
          </Text>
        </ScrapbookCard>
      </View>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 20,
  },
  card: {
    alignItems: 'center',
    paddingHorizontal: 22,
    paddingVertical: 26,
  },
  eyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.9,
    textTransform: 'uppercase',
    marginBottom: 12,
  },
  title: {
    marginTop: 16,
    fontSize: 20,
    fontWeight: '700',
    textAlign: 'center',
  },
  body: {
    marginTop: 10,
    fontSize: 15,
    lineHeight: 22,
    textAlign: 'center',
  },
});
