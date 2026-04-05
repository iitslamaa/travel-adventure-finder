import React, { useMemo } from 'react';
import { View, StyleSheet } from 'react-native';
import { Stack } from 'expo-router';
import { Video, ResizeMode } from 'expo-av';
import { AuthProvider, useAuth } from '../context/AuthContext';
import { ScorePreferencesProvider } from '../context/ScorePreferencesContext';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { useTheme } from '../hooks/useTheme';
import * as WebBrowser from 'expo-web-browser';

WebBrowser.maybeCompleteAuthSession();

function RootLayoutInner() {
  const colors = useTheme();

  const { session, isGuest, loading } = useAuth();

  const showAuthBackground = useMemo(() => {
    // Do NOT decide auth UI until initial session check finishes
    if (loading) return false;
    if (isGuest) return false;
    return session === null;
  }, [session, isGuest, loading]);

  return (
    <SafeAreaView
      style={[styles.root, { backgroundColor: colors.background }]}
      edges={['top', 'left', 'right']}
    >
      <StatusBar
        style="dark"
        backgroundColor={colors.background}
      />

      {showAuthBackground && (
        <View pointerEvents="none" style={StyleSheet.absoluteFill}>
          <Video
            source={require('../assets/intro-video.mp4')}
            style={StyleSheet.absoluteFill}
            resizeMode={ResizeMode.COVER}
            shouldPlay
            isLooping
            isMuted
          />
          <View style={styles.overlay} />
        </View>
      )}

      <Stack
        screenOptions={{
          headerShown: false,
          animation: 'fade',
          animationDuration: 220,
          contentStyle: {
            backgroundColor: showAuthBackground
              ? 'transparent'
              : colors.background,
          },
        }}
      >
        <Stack.Screen name="login/index" options={{ animation: 'fade' }} />
        <Stack.Screen name="login/email" options={{ animation: 'slide_from_right', animationDuration: 260 }} />
        <Stack.Screen name="verify" options={{ animation: 'slide_from_right', animationDuration: 260 }} />
      </Stack>
    </SafeAreaView>
  );
}

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <AuthProvider>
        <ScorePreferencesProvider>
          <RootLayoutInner />
        </ScorePreferencesProvider>
      </AuthProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(23,15,10,0.24)',
  },
});
