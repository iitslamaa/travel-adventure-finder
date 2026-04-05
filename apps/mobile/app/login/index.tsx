import AsyncStorage from '@react-native-async-storage/async-storage';
import { Video, ResizeMode } from 'expo-av';
import * as Linking from 'expo-linking';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import {
  ActivityIndicator,
  Alert,
  Animated,
  Image,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  useWindowDimensions,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAuth } from '../../context/AuthContext';
import { supabase } from '../../lib/supabase';

WebBrowser.maybeCompleteAuthSession();

const GUEST_PILL_TEXT = '#45392E';
const BORDER = 'rgba(73, 58, 43, 0.12)';
const FIELD_BG = '#F7F2E8';
const PRIMARY_FILL = '#3A2A1C';
const PRIMARY_TEXT = '#FFFFFF';
const MUTED_TEXT = '#786A57';
const PANEL_BORDER = 'rgba(122, 107, 84, 0.35)';

export default function LandingScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{ step?: string; email?: string }>();
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const { session, isGuest, loading, continueAsGuest } = useAuth();

  const [authView, setAuthView] = useState<'menu' | 'email' | 'verify'>('menu');
  const [email, setEmail] = useState('');
  const [emailLoading, setEmailLoading] = useState(false);
  const [loadingGoogle, setLoadingGoogle] = useState(false);
  const [cooldownSeconds, setCooldownSeconds] = useState(0);
  const [showBypass, setShowBypass] = useState(false);
  const [bypassKey, setBypassKey] = useState('');
  const [code, setCode] = useState('');
  const [verifyLoading, setVerifyLoading] = useState(false);

  const panelOpacity = useRef(new Animated.Value(0)).current;
  const panelTranslateY = useRef(new Animated.Value(18)).current;
  const menuOpacity = useRef(new Animated.Value(1)).current;
  const menuTranslateX = useRef(new Animated.Value(0)).current;
  const emailOpacity = useRef(new Animated.Value(0)).current;
  const emailTranslateX = useRef(new Animated.Value(36)).current;
  const verifyOpacity = useRef(new Animated.Value(0)).current;
  const verifyTranslateX = useRef(new Animated.Value(36)).current;
  const videoRef = useRef<Video>(null);
  const revealTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const cooldownIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const loginInProgressRef = useRef(false);

  useEffect(() => {
    if (loading) return;

    if (session) {
      router.replace('/(tabs)/discovery');
    }
  }, [session, loading, router]);

  useFocusEffect(
    useCallback(() => {
      videoRef.current?.replayAsync().catch(() => {});
      return () => {};
    }, [])
  );

  useEffect(() => {
    revealTimeoutRef.current = setTimeout(() => {
      Animated.parallel([
        Animated.timing(panelOpacity, {
          toValue: 1,
          duration: 450,
          useNativeDriver: true,
        }),
        Animated.timing(panelTranslateY, {
          toValue: 0,
          duration: 450,
          useNativeDriver: true,
        }),
      ]).start();
    }, 2000);

    return () => {
      if (revealTimeoutRef.current) {
        clearTimeout(revealTimeoutRef.current);
      }
    };
  }, [panelOpacity, panelTranslateY]);

  useEffect(() => {
    const handleUrl = async () => {
      await supabase.auth.getSession();
    };

    const subscription = Linking.addEventListener('url', handleUrl);
    return () => {
      subscription.remove();
    };
  }, []);

  useEffect(() => {
    if (cooldownSeconds <= 0) {
      if (cooldownIntervalRef.current) {
        clearInterval(cooldownIntervalRef.current);
        cooldownIntervalRef.current = null;
      }
      return;
    }

    cooldownIntervalRef.current = setInterval(() => {
      setCooldownSeconds(current => {
        if (current <= 1) {
          if (cooldownIntervalRef.current) {
            clearInterval(cooldownIntervalRef.current);
            cooldownIntervalRef.current = null;
          }
          return 0;
        }
        return current - 1;
      });
    }, 1000);

    return () => {
      if (cooldownIntervalRef.current) {
        clearInterval(cooldownIntervalRef.current);
        cooldownIntervalRef.current = null;
      }
    };
  }, [cooldownSeconds]);

  const panelMaxHeight = useMemo(
    () => Math.min(Math.max(height * 0.4, 320), 420),
    [height]
  );
  const authButtonWidth = useMemo(
    () => Math.min(320, Math.max(248, Math.round(height * 0.18))),
    [height]
  );
  const emailCardWidth = useMemo(
    () => Math.min(288, Math.max(248, Math.round(authButtonWidth * 0.9))),
    [authButtonWidth]
  );
  const verifyCardWidth = useMemo(
    () => Math.min(268, Math.max(236, emailCardWidth - 12)),
    [emailCardWidth]
  );

  useEffect(() => {
    if (!params?.step) return;

    if (typeof params.email === 'string' && params.email.length) {
      setEmail(params.email);
    }

    if (params.step === 'email') {
      setAuthView('email');
      menuOpacity.setValue(0);
      menuTranslateX.setValue(-42);
      emailOpacity.setValue(1);
      emailTranslateX.setValue(0);
      verifyOpacity.setValue(0);
      verifyTranslateX.setValue(36);
      return;
    }

    if (params.step === 'verify') {
      setAuthView('verify');
      menuOpacity.setValue(0);
      menuTranslateX.setValue(-42);
      emailOpacity.setValue(0);
      emailTranslateX.setValue(-36);
      verifyOpacity.setValue(1);
      verifyTranslateX.setValue(0);
    }
  }, [
    params?.email,
    params?.step,
    emailOpacity,
    emailTranslateX,
    menuOpacity,
    menuTranslateX,
    verifyOpacity,
    verifyTranslateX,
  ]);

  const dumpStorage = async (label: string) => {
    try {
      const keys = await AsyncStorage.getAllKeys();
      const interesting = keys.filter(key =>
        key.includes('supabase') ||
        key.includes('sb-') ||
        key.includes('pkce') ||
        key.includes('auth') ||
        key.includes('travelaf')
      );

      if (!interesting.length) return;

      const pairs = await AsyncStorage.multiGet(interesting);
      console.log(
        `[storage.dump] ${label}`,
        pairs.map(([key, value]) => [key, value ? `len=${value.length}` : null])
      );
    } catch (error) {
      console.log('[storage.dump] error', error);
    }
  };

  const handleGoogleLogin = async () => {
    if (loginInProgressRef.current) return;

    loginInProgressRef.current = true;
    setLoadingGoogle(true);

    try {
      const redirectTo = 'travelaf://auth/callback';
      await dumpStorage('BEFORE signInWithOAuth');

      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo },
      });

      await dumpStorage('AFTER signInWithOAuth');

      if (error) {
        Alert.alert('Google Login Error', error.message);
        return;
      }

      if (!data?.url) {
        Alert.alert('Google Login Error', 'No OAuth URL returned.');
        return;
      }

      await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
    } catch (error: any) {
      Alert.alert('Google Login Error', error?.message ?? 'Unknown error');
    } finally {
      setLoadingGoogle(false);
      loginInProgressRef.current = false;
    }
  };

  const handleGuest = () => {
    continueAsGuest();
    router.replace('/(tabs)/discovery');
  };

  const transitionToEmail = useCallback(() => {
    setAuthView('email');
    Animated.parallel([
      Animated.timing(menuOpacity, {
        toValue: 0,
        duration: 260,
        useNativeDriver: true,
      }),
      Animated.timing(menuTranslateX, {
        toValue: -42,
        duration: 260,
        useNativeDriver: true,
      }),
      Animated.timing(emailOpacity, {
        toValue: 1,
        duration: 260,
        useNativeDriver: true,
      }),
      Animated.timing(emailTranslateX, {
        toValue: 0,
        duration: 260,
        useNativeDriver: true,
      }),
    ]).start();
  }, [emailOpacity, emailTranslateX, menuOpacity, menuTranslateX]);

  const transitionToMenu = useCallback(() => {
    Animated.parallel([
      Animated.timing(menuOpacity, {
        toValue: 1,
        duration: 240,
        useNativeDriver: true,
      }),
      Animated.timing(menuTranslateX, {
        toValue: 0,
        duration: 240,
        useNativeDriver: true,
      }),
      Animated.timing(emailOpacity, {
        toValue: 0,
        duration: 240,
        useNativeDriver: true,
      }),
      Animated.timing(emailTranslateX, {
        toValue: 36,
        duration: 240,
        useNativeDriver: true,
      }),
      Animated.timing(verifyOpacity, {
        toValue: 0,
        duration: 180,
        useNativeDriver: true,
      }),
      Animated.timing(verifyTranslateX, {
        toValue: 36,
        duration: 180,
        useNativeDriver: true,
      }),
    ]).start(({ finished }) => {
      if (finished) {
        setAuthView('menu');
        setShowBypass(false);
        setCode('');
      }
    });
  }, [
    emailOpacity,
    emailTranslateX,
    menuOpacity,
    menuTranslateX,
    verifyOpacity,
    verifyTranslateX,
  ]);

  const transitionToVerify = useCallback(() => {
    setAuthView('verify');
    Animated.parallel([
      Animated.timing(emailOpacity, {
        toValue: 0,
        duration: 240,
        useNativeDriver: true,
      }),
      Animated.timing(emailTranslateX, {
        toValue: -34,
        duration: 240,
        useNativeDriver: true,
      }),
      Animated.timing(verifyOpacity, {
        toValue: 1,
        duration: 240,
        useNativeDriver: true,
      }),
      Animated.timing(verifyTranslateX, {
        toValue: 0,
        duration: 240,
        useNativeDriver: true,
      }),
    ]).start();
  }, [emailOpacity, emailTranslateX, verifyOpacity, verifyTranslateX]);

  const transitionBackToEmail = useCallback(() => {
    setAuthView('email');
    Animated.parallel([
      Animated.timing(verifyOpacity, {
        toValue: 0,
        duration: 220,
        useNativeDriver: true,
      }),
      Animated.timing(verifyTranslateX, {
        toValue: 36,
        duration: 220,
        useNativeDriver: true,
      }),
      Animated.timing(emailOpacity, {
        toValue: 1,
        duration: 220,
        useNativeDriver: true,
      }),
      Animated.timing(emailTranslateX, {
        toValue: 0,
        duration: 220,
        useNativeDriver: true,
      }),
    ]).start();
  }, [emailOpacity, emailTranslateX, verifyOpacity, verifyTranslateX]);

  const handleEmailLogin = async () => {
    if (!email || cooldownSeconds > 0) return;

    try {
      setEmailLoading(true);

      const { error } = await supabase.auth.signInWithOtp({
        email,
        options: { shouldCreateUser: true },
      });

      if (error) {
        Alert.alert('Login Error', error.message);
        return;
      }

      setCooldownSeconds(30);
      setCode('');
      transitionToVerify();
    } finally {
      setEmailLoading(false);
    }
  };

  const handleBypassLogin = async () => {
    if (!email || !bypassKey) {
      Alert.alert('Enter email and bypass key');
      return;
    }

    try {
      setEmailLoading(true);

      const { error } = await supabase.auth.signInWithPassword({
        email,
        password: bypassKey,
      });

      if (error) {
        Alert.alert('Invalid bypass key', error.message);
        return;
      }

      router.replace('/(tabs)/discovery');
    } finally {
      setEmailLoading(false);
    }
  };

  const handleVerify = async () => {
    if (!email || !code) return;

    try {
      setVerifyLoading(true);

      const { error } = await supabase.auth.verifyOtp({
        email,
        token: code,
        type: 'email',
      });

      if (error) {
        Alert.alert('Verification Error', error.message);
        return;
      }

      router.replace('/(tabs)/discovery');
    } finally {
      setVerifyLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <Video
        ref={videoRef}
        source={require('../../assets/intro-video.mp4')}
        style={StyleSheet.absoluteFill}
        resizeMode={ResizeMode.COVER}
        shouldPlay
        isLooping={false}
        isMuted
      />

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{ flex: 1 }}
      >
        <Animated.View
          style={[
            styles.panelLayer,
            {
              paddingTop: insets.top + Math.max(height * 0.23, 168),
              paddingBottom: Math.max(insets.bottom, 20),
              opacity: panelOpacity,
              transform: [{ translateY: panelTranslateY }],
            },
          ]}
        >
          {!session && !isGuest && !loading && (
            <>
              <View style={[styles.keyboardWrap, { height: panelMaxHeight }]}>
                <View style={styles.authFrame}>
                  <View style={styles.authFrameSpacer} />
                  <View style={styles.authViewport}>
                    <Animated.View
                      pointerEvents={authView === 'menu' ? 'auto' : 'none'}
                      style={[
                        styles.authSlide,
                        {
                          opacity: menuOpacity,
                          transform: [{ translateX: menuTranslateX }],
                        },
                      ]}
                    >
                      <View style={styles.menuStack}>
                        <AuthGhostButton
                          label={loadingGoogle ? 'Connecting...' : 'Continue with Google'}
                          onPress={handleGoogleLogin}
                          disabled={loadingGoogle}
                          width={authButtonWidth}
                          icon={
                            <Image
                              source={require('../../assets/google_logo.png')}
                              style={styles.googleLogo}
                            />
                          }
                        />
                        <AuthGhostButton
                          label="Continue with Email"
                          onPress={transitionToEmail}
                          width={authButtonWidth}
                        />
                      </View>
                    </Animated.View>

                    <Animated.View
                      pointerEvents={authView === 'email' ? 'auto' : 'none'}
                      style={[
                        styles.authSlide,
                        styles.emailSlide,
                        {
                          opacity: emailOpacity,
                          transform: [{ translateX: emailTranslateX }],
                        },
                      ]}
                    >
                      <View style={[styles.emailCard, { width: emailCardWidth }]}>
                        <Pressable onPress={transitionToMenu} hitSlop={10} style={styles.backRow}>
                          <Text style={styles.backText}>Back</Text>
                        </Pressable>

                        <Text style={styles.panelTag}>Email sign in</Text>
                        <Text style={styles.panelTitle}>Enter your email</Text>

                        <TextInput
                          placeholder="Email address"
                          value={email}
                          onChangeText={setEmail}
                          style={styles.input}
                          autoCapitalize="none"
                          keyboardType="email-address"
                          autoCorrect={false}
                          textContentType="emailAddress"
                          placeholderTextColor={MUTED_TEXT}
                        />

                        <Pressable
                          style={[
                            styles.primaryButton,
                            (!email || cooldownSeconds > 0) && styles.primaryButtonDisabled,
                          ]}
                          onPress={handleEmailLogin}
                          disabled={emailLoading || !email || cooldownSeconds > 0}
                        >
                          {emailLoading ? (
                            <ActivityIndicator color={PRIMARY_TEXT} />
                          ) : (
                            <Text
                              style={[
                                styles.primaryButtonText,
                                (!email || cooldownSeconds > 0) && styles.primaryButtonTextDisabled,
                              ]}
                            >
                              {cooldownSeconds > 0 ? `Resend in ${cooldownSeconds}s` : 'Send Code'}
                            </Text>
                          )}
                        </Pressable>

                        <Pressable onPress={() => setShowBypass(current => !current)}>
                          <Text style={styles.secondaryLink}>
                            {showBypass ? 'Hide bypass key' : 'Use bypass code'}
                          </Text>
                        </Pressable>

                        {showBypass ? (
                          <View style={styles.bypassWrap}>
                            <TextInput
                              value={bypassKey}
                              onChangeText={setBypassKey}
                              placeholder="Enter bypass key"
                              placeholderTextColor={MUTED_TEXT}
                              secureTextEntry
                              autoCapitalize="none"
                              autoCorrect={false}
                              style={styles.input}
                            />

                            <Pressable
                              style={[
                                styles.secondaryActionButton,
                                (!email || !bypassKey) && styles.secondaryActionButtonDisabled,
                              ]}
                              onPress={handleBypassLogin}
                              disabled={emailLoading || !email || !bypassKey}
                            >
                              <Text style={styles.secondaryActionButtonText}>
                                {emailLoading ? 'Verifying...' : 'Submit'}
                              </Text>
                            </Pressable>
                          </View>
                        ) : null}
                      </View>
                    </Animated.View>

                    <Animated.View
                      pointerEvents={authView === 'verify' ? 'auto' : 'none'}
                      style={[
                        styles.authSlide,
                        styles.emailSlide,
                        {
                          opacity: verifyOpacity,
                          transform: [{ translateX: verifyTranslateX }],
                        },
                      ]}
                    >
                      <View style={[styles.emailCard, styles.verifyCard, { width: verifyCardWidth }]}>
                        <Pressable onPress={transitionBackToEmail} hitSlop={10} style={styles.backRow}>
                          <Text style={styles.backText}>Back</Text>
                        </Pressable>

                        <Text style={styles.panelTag}>Verification</Text>
                        <Text style={styles.panelEyebrow}>We sent a code to</Text>
                        <Text style={styles.emailPreview} numberOfLines={1}>
                          {email || 'your email'}
                        </Text>

                        <TextInput
                          placeholder="Enter code"
                          value={code}
                          onChangeText={setCode}
                          style={[styles.input, styles.codeInput]}
                          autoCapitalize="none"
                          autoCorrect={false}
                          keyboardType="number-pad"
                          maxLength={6}
                          textContentType="oneTimeCode"
                          placeholderTextColor={MUTED_TEXT}
                        />

                        <Pressable
                          style={[styles.primaryButton, !code && styles.primaryButtonDisabled]}
                          onPress={handleVerify}
                          disabled={verifyLoading || !code}
                        >
                          {verifyLoading ? (
                            <ActivityIndicator color={PRIMARY_TEXT} />
                          ) : (
                            <Text
                              style={[
                                styles.primaryButtonText,
                                !code && styles.primaryButtonTextDisabled,
                              ]}
                            >
                              Verify
                            </Text>
                          )}
                        </Pressable>
                      </View>
                    </Animated.View>
                  </View>
                  <View style={styles.authFrameSpacer} />
                </View>
              </View>

              {authView === 'menu' ? (
                <Pressable style={styles.guestPill} onPress={handleGuest}>
                  <Text style={styles.guestPillText}>Continue as Guest</Text>
                </Pressable>
              ) : null}
            </>
          )}
        </Animated.View>
      </KeyboardAvoidingView>
    </View>
  );
}

function AuthGhostButton({
  label,
  onPress,
  disabled = false,
  icon,
  width,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  icon?: ReactNode;
  width: number;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled}
      style={({ pressed }) => [
        styles.ghostButton,
        { width },
        disabled && styles.buttonDisabled,
        pressed && !disabled && styles.buttonPressed,
      ]}
    >
      <View style={styles.ghostButtonContent}>
        {icon ? <View style={styles.ghostIconSlot}>{icon}</View> : null}
        <Text style={styles.ghostButtonText}>{label}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  panelLayer: {
    flex: 1,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'flex-start',
    paddingHorizontal: 20,
  },
  keyboardWrap: {
    width: '100%',
    maxWidth: 360,
    alignItems: 'stretch',
  },
  authFrame: {
    flex: 1,
    justifyContent: 'center',
  },
  authViewport: {
    minHeight: 196,
    justifyContent: 'center',
    alignItems: 'center',
  },
  authFrameSpacer: {
    flex: 1,
  },
  authSlide: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
  },
  emailSlide: {
    position: 'absolute',
  },
  menuStack: {
    gap: 20,
    alignItems: 'center',
  },
  ghostButton: {
    height: 52,
    borderRadius: 18,
    backgroundColor: 'rgba(250,245,238,0.98)',
    borderWidth: 1,
    borderColor: BORDER,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#7e684e',
    shadowOpacity: 0.12,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 4,
  },
  ghostButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 18,
  },
  ghostIconSlot: {
    width: 26,
    marginRight: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ghostButtonText: {
    color: 'rgba(58,42,28,0.94)',
    fontSize: 17,
    fontWeight: '600',
  },
  googleLogo: {
    width: 20,
    height: 20,
    resizeMode: 'contain',
  },
  guestPill: {
    marginTop: -18,
    minHeight: 40,
    paddingHorizontal: 20,
    borderRadius: 999,
    backgroundColor: 'rgba(227,213,181,0.95)',
    borderWidth: 1,
    borderColor: 'rgba(73,58,43,0.08)',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#7e684e',
    shadowOpacity: 0.08,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 4 },
    elevation: 3,
  },
  guestPillText: {
    color: GUEST_PILL_TEXT,
    fontSize: 15,
    fontWeight: '600',
  },
  emailCard: {
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderRadius: 20,
    backgroundColor: 'rgba(247,242,234,0.98)',
    borderWidth: 1,
    borderColor: PANEL_BORDER,
    shadowColor: '#7e684e',
    shadowOpacity: 0.12,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
    elevation: 4,
    gap: 12,
  },
  verifyCard: {
    paddingVertical: 12,
    gap: 10,
  },
  backRow: {
    alignSelf: 'flex-start',
  },
  backText: {
    color: MUTED_TEXT,
    fontSize: 16,
    fontWeight: '600',
  },
  panelTitle: {
    color: PRIMARY_FILL,
    fontSize: 17,
    fontWeight: '700',
  },
  panelTag: {
    color: MUTED_TEXT,
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.9,
    textTransform: 'uppercase',
    marginBottom: -4,
  },
  panelEyebrow: {
    color: MUTED_TEXT,
    fontSize: 14,
    fontWeight: '600',
  },
  emailPreview: {
    color: PRIMARY_FILL,
    fontSize: 15,
    fontWeight: '700',
  },
  input: {
    height: 46,
    borderRadius: 12,
    backgroundColor: FIELD_BG,
    color: PRIMARY_FILL,
    paddingHorizontal: 12,
    fontSize: 16,
  },
  codeInput: {
    textAlign: 'center',
    letterSpacing: 4,
  },
  primaryButton: {
    alignSelf: 'center',
    width: 200,
    height: 50,
    borderRadius: 16,
    backgroundColor: '#735436',
    borderWidth: 1,
    borderColor: '#58402B',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#7e684e',
    shadowOpacity: 0.14,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 4,
  },
  primaryButtonDisabled: {
    backgroundColor: 'rgba(216,204,191,0.96)',
    borderColor: 'rgba(255,250,244,0.62)',
  },
  primaryButtonText: {
    color: PRIMARY_TEXT,
    fontSize: 16,
    fontWeight: '700',
  },
  primaryButtonTextDisabled: {
    color: MUTED_TEXT,
  },
  secondaryLink: {
    color: MUTED_TEXT,
    fontSize: 13,
    textAlign: 'center',
  },
  bypassWrap: {
    gap: 10,
  },
  secondaryActionButton: {
    height: 46,
    borderRadius: 14,
    backgroundColor: FIELD_BG,
    borderWidth: 1,
    borderColor: PANEL_BORDER,
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryActionButtonDisabled: {
    opacity: 0.6,
  },
  secondaryActionButtonText: {
    color: PRIMARY_FILL,
    fontSize: 15,
    fontWeight: '700',
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonPressed: {
    transform: [{ scale: 0.995 }],
  },
});
