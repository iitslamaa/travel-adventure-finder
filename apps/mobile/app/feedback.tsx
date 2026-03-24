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
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../hooks/useTheme';
import { supabase } from '../lib/supabase';

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
      style={{ flex: 1, backgroundColor: colors.background }}
    >
      <ScrollView
        contentContainerStyle={{
          paddingTop: insets.top + 18,
          paddingHorizontal: 20,
          paddingBottom: insets.bottom + 32,
        }}
        keyboardShouldPersistTaps="handled"
      >
        <Pressable onPress={() => router.back()} style={styles.backButton}>
          <Text style={[styles.backText, { color: colors.textPrimary }]}>
            Back
          </Text>
        </Pressable>

        <Text style={[styles.title, { color: colors.textPrimary }]}>Feedback</Text>
        <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
          Share bugs, ideas, or anything that would make the mobile app feel as
          polished as the Swift version.
        </Text>

        <View
          style={[
            styles.card,
            { backgroundColor: colors.card, borderColor: colors.border },
          ]}
        >
          <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
            Message
          </Text>
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
                backgroundColor: canSubmit ? colors.primary : colors.border,
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
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  backButton: {
    alignSelf: 'flex-start',
    marginBottom: 16,
  },
  backText: {
    fontSize: 15,
    fontWeight: '600',
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 8,
    marginBottom: 24,
  },
  card: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 18,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '700',
    marginBottom: 12,
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
    minHeight: 48,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 16,
    paddingHorizontal: 16,
  },
  submitText: {
    fontSize: 15,
    fontWeight: '700',
  },
});
