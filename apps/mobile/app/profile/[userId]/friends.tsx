import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  useColorScheme,
  ActivityIndicator,
} from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { supabase } from '../../../lib/supabase';
import { Ionicons } from '@expo/vector-icons';
import AuthGate from '../../../components/AuthGate';
import { lightColors, darkColors } from '../../../theme/colors';
import { useFriends } from '../../../hooks/useFriends';
import { useAuth } from '../../../context/AuthContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Image } from 'expo-image';

export default function FriendsScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { userId } = useLocalSearchParams();
  if (typeof userId !== 'string') return null;

  const scheme = useColorScheme();
  const colors = scheme === 'dark' ? darkColors : lightColors;

  const { isGuest } = useAuth();

  const { friends, loading } = useFriends(userId);

  if (isGuest) {
    return (
      <View
        style={[
          styles.container,
          {
            backgroundColor: colors.background,
            justifyContent: 'center',
          },
        ]}
      >
        <Text
          style={{
            fontSize: 34,
            fontWeight: '700',
            color: colors.textPrimary,
          }}
        >
          Login to customize your friends
        </Text>

        <Text
          style={{
            marginTop: 16,
            fontSize: 16,
            color: colors.textMuted,
            lineHeight: 22,
            maxWidth: 320,
          }}
        >
          Sign in to add friends, send requests, and explore profiles.
        </Text>

        <Pressable onPress={() => router.push('/login')} style={{ marginTop: 24 }}>
          <Text
            style={{
              fontSize: 18,
              fontWeight: '600',
              color: '#3B82F6',
            }}
          >
            Go to Login →
          </Text>
        </Pressable>
      </View>
    );
  }

  const renderItem = ({ item }: { item: any }) => (
    <Pressable
      onPress={() =>
        router.push({
          pathname: '/profile/[userId]',
          params: { userId: item.id },
        })
      }
      style={[styles.row, { borderBottomColor: colors.textSecondary }]}
    >
      {item.avatar_url ? (
        <Image
          source={item.avatar_url}
          style={styles.avatar}
          contentFit="cover"
          cachePolicy="memory-disk"
        />
      ) : (
        <View style={styles.avatar} />
      )}

      <View style={{ flex: 1 }}>
        <Text style={[styles.name, { color: colors.textPrimary }]}>
          {item.full_name}
        </Text>
        <Text style={[styles.username, { color: colors.textMuted }]}>
          @{item.username}
        </Text>
      </View>

      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );

  return (
    <AuthGate>
      <View
        style={[
          styles.container,
          {
            backgroundColor: colors.background,
            paddingTop: insets.top + 16,
            paddingBottom: insets.bottom + 24,
          },
        ]}
      >
        {loading ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <ActivityIndicator size="large" color={colors.textPrimary} />
          </View>
        ) : (
          <>
            {/* Header */}
            <View style={styles.headerRow}>
              <Pressable onPress={() => router.back()}>
                <Ionicons name="arrow-back" size={22} color={colors.textPrimary} />
              </Pressable>

              <Text
                style={[
                  styles.title,
                  { color: colors.textPrimary, marginLeft: 8 },
                ]}
              >
                Friends
              </Text>
            </View>

            {/* Friends List Card */}
            <View style={[styles.card, { backgroundColor: colors.card }]}>
              <FlatList
                data={friends}
                renderItem={renderItem}
                keyExtractor={(item) => item.id}
                contentContainerStyle={{ paddingBottom: 16 }}
                ListEmptyComponent={
                  <Text
                    style={{
                      color: colors.textMuted,
                      textAlign: 'center',
                      paddingVertical: 20,
                    }}
                  >
                    No friends yet.
                  </Text>
                }
              />
            </View>
          </>
        )}
      </View>
    </AuthGate>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 20,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
  },
  card: {
    marginTop: 24,
    borderRadius: 24,
    paddingVertical: 10,
    paddingHorizontal: 8,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#444',
    marginRight: 14,
  },
  name: {
    fontSize: 16,
    fontWeight: '600',
  },
  username: {
    fontSize: 14,
    marginTop: 2,
  },
});