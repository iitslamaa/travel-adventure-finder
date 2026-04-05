import Constants from 'expo-constants';
import { router } from 'expo-router';
import { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Image } from 'expo-image';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../hooks/useTheme';
import { supabase } from '../lib/supabase';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import ScrapbookCard from '../components/theme/ScrapbookCard';
import TitleBanner from '../components/theme/TitleBanner';

export default function FeedbackScreen() {
  const colors = useTheme();
  const insets = useSafeAreaInsets();
  const { session } = useAuth();
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const trimmedMessage = message.trim();
  const canSubmit = trimmedMessage.length > 0 && !submitting && !!session?.user?.id;

  const handleSubmit = async () => {
    if (!session?.user?.id || !trimmedMessage) {
      return;
    }

    setSubmitting(true);

    const { error } = await supabase.functions.invoke('send-feedback-email', {
      body: {
        message: trimmedMessage,
        user_id: session.user.id,
        device: Platform.OS,
        app_version: Constants.expoConfig?.version ?? 'dev',
        created_at: new Date().toISOString(),
      },
    });

    setSubmitting(false);

    if (error) {
      Alert.alert('Unable to send', error.message || 'Please try again.');
      return;
    }

    Alert.alert('Sent', 'Thanks. Your feedback was sent successfully.', [
      {
        text: 'OK',
        onPress: () => router.back(),
      },
    ]);
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={{ flex: 1, backgroundColor: 'transparent' }}
    >
      <ScrapbookBackground>
      <ScrollView
        contentContainerStyle={{
          paddingTop: insets.top + 12,
          paddingHorizontal: 20,
          paddingBottom: insets.bottom + 120,
        }}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <TitleBanner title="Feedback" />

        <ScrapbookCard innerStyle={styles.introCard}>
          <View style={styles.introRow}>
            <Image
              source={require('../assets/scrapbook/profile-header.png')}
              style={styles.introImage}
              contentFit="cover"
            />
            <Text style={[styles.introHeadline, { color: colors.textPrimary }]}>
              I read every note and use them to keep shaping the app.
            </Text>
          </View>

          <View style={styles.introCopy}>
            <Text style={[styles.introBody, { color: colors.textSecondary }]}>
              If something feels off, clunky, or unfinished, I want to hear it.
            </Text>
            <Text style={[styles.introBody, { color: colors.textSecondary }]}>
              Bugs, wishlist ideas, confusing flows, and design feedback are all useful.
            </Text>
            <Text style={[styles.introBodyStrong, { color: colors.textPrimary }]}>
              The more specific you are, the faster I can improve it.
            </Text>
          </View>
        </ScrapbookCard>

        <ScrapbookCard innerStyle={styles.card}>
          <TextInput
            multiline
            value={message}
            onChangeText={setMessage}
            placeholder="What should we improve?"
            placeholderTextColor={colors.textMuted}
            style={[
              styles.input,
              {
                color: colors.textPrimary,
                backgroundColor: colors.surface,
                borderColor: colors.border,
              },
            ]}
            textAlignVertical="top"
          />

          {!session?.user?.id ? (
            <Text style={[styles.helper, { color: colors.textSecondary }]}>
              Sign in to send feedback from the app.
            </Text>
          ) : null}

          <Pressable
            disabled={!canSubmit}
            onPress={handleSubmit}
            style={[
              styles.submitButton,
              {
                backgroundColor: canSubmit ? colors.primary : 'rgba(128, 128, 128, 0.3)',
                borderColor: canSubmit ? colors.primary : 'rgba(128, 128, 128, 0.3)',
              },
            ]}
          >
            {submitting ? (
              <ActivityIndicator color={colors.primaryText} />
            ) : (
              <Text
                style={[styles.submitText, { color: colors.primaryText }]}
              >
                Send Feedback
              </Text>
            )}
          </Pressable>
        </ScrapbookCard>
      </ScrollView>
      </ScrapbookBackground>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  backButton: {
    display: 'none',
  },
  backText: {
    display: 'none',
  },
  introCard: {
    borderRadius: 22,
    padding: 18,
    marginBottom: 20,
  },
  introRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginBottom: 14,
  },
  introImage: {
    width: 92,
    height: 92,
    borderRadius: 22,
  },
  introHeadline: {
    flex: 1,
    fontSize: 21,
    lineHeight: 28,
    fontWeight: '600',
  },
  introCopy: {
    gap: 10,
  },
  introBody: {
    fontSize: 15,
    lineHeight: 22,
  },
  introBodyStrong: {
    fontSize: 15,
    lineHeight: 22,
    fontWeight: '700',
  },
  card: {
    borderRadius: 22,
    padding: 18,
  },
  input: {
    minHeight: 180,
    borderWidth: 1,
    borderRadius: 16,
    padding: 14,
    fontSize: 15,
    lineHeight: 22,
  },
  helper: {
    marginTop: 12,
    fontSize: 13,
    lineHeight: 18,
  },
  submitButton: {
    minHeight: 52,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 16,
    paddingHorizontal: 16,
    borderWidth: 1,
  },
  submitText: {
    fontSize: 15,
    fontWeight: '700',
  },
});
