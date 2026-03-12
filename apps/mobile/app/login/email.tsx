import {
  View,
  Text,
  TextInput,
  StyleSheet,
  Pressable,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useState } from 'react';
import { useRouter } from 'expo-router';
import { supabase } from '../../lib/supabase';

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const [showBypass, setShowBypass] = useState(false);
  const [bypassKey, setBypassKey] = useState('');

  const handleEmailLogin = async () => {
    if (!email) return;

    setLoading(true);

    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: true },
    });

    setLoading(false);

    if (error) {
      Alert.alert('Login Error', error.message);
    } else {
      router.push({
        pathname: '/verify',
        params: { email },
      });
    }
  };

  const handleBypassLogin = async () => {
    if (!email || !bypassKey) {
      Alert.alert('Enter email and bypass key');
      return;
    }

    setLoading(true);

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password: bypassKey,
    });

    setLoading(false);

    if (error) {
      Alert.alert('Invalid bypass key', error.message);
      return;
    }

    router.replace('/discovery');
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={styles.container}
    >
      <View style={styles.inner}>
        <Text style={styles.title}>Enter your email</Text>

        <TextInput
          placeholder="Email address"
          value={email}
          onChangeText={setEmail}
          style={styles.input}
          autoCapitalize="none"
          keyboardType="email-address"
          placeholderTextColor="rgba(255,255,255,0.6)"
        />

        <Pressable
          style={[styles.button, loading && { opacity: 0.6 }]}
          onPress={handleEmailLogin}
          disabled={loading}
        >
          <Text style={styles.buttonText}>
            {loading ? 'Sending...' : 'Send Code'}
          </Text>
        </Pressable>

        <Pressable
          style={styles.bypassToggle}
          onPress={() => setShowBypass(true)}
        >
          <Text style={styles.bypassToggleText}>Bypass Key</Text>
        </Pressable>

        {showBypass && (
          <View style={styles.bypassContainer}>
            <TextInput
              value={bypassKey}
              onChangeText={setBypassKey}
              placeholder="Enter bypass key"
              placeholderTextColor="rgba(255,255,255,0.6)"
              secureTextEntry
              autoCapitalize="none"
              autoCorrect={false}
              style={styles.bypassInput}
            />

            <Pressable
              style={[styles.bypassSubmit, loading && { opacity: 0.6 }]}
              onPress={handleBypassLogin}
              disabled={loading}
            >
              <Text style={styles.bypassSubmitText}>
                {loading ? 'Verifying...' : 'Submit'}
              </Text>
            </Pressable>
          </View>
        )}

        <Pressable onPress={() => router.back()}>
          <Text style={styles.link}>Back</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
  },
  inner: {
    padding: 24,
  },
  title: {
    fontSize: 28,
    fontWeight: '600',
    marginBottom: 24,
    color: 'white',
  },
  input: {
    backgroundColor: 'rgba(255,255,255,0.15)',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    marginBottom: 16,
    color: 'white',
  },
  button: {
    backgroundColor: 'black',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  buttonText: {
    color: 'white',
    fontWeight: '600',
    fontSize: 16,
  },
  link: {
    textAlign: 'center',
    marginTop: 16,
    color: 'rgba(255,255,255,0.8)',
  },
  bypassToggle: {
    alignItems: 'center',
    marginTop: 12,
  },
  bypassToggleText: {
    color: 'rgba(255,255,255,0.85)',
    fontSize: 14,
    textDecorationLine: 'underline',
  },
  bypassContainer: {
    marginTop: 12,
  },
  bypassInput: {
    backgroundColor: 'rgba(255,255,255,0.15)',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    color: 'white',
  },
  bypassSubmit: {
    marginTop: 10,
    backgroundColor: 'white',
    padding: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  bypassSubmitText: {
    fontWeight: '600',
    fontSize: 15,
  },
});