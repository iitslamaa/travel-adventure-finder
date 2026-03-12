import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
  FlatList,
  useColorScheme,
  ActivityIndicator,
  RefreshControl,
} from 'react-native';
import { Image } from 'expo-image';
import { useRouter } from 'expo-router';
import { useMemo, useState, useCallback, useEffect } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { useIsFocused } from '@react-navigation/native';
import { supabase } from '../../lib/supabase';
import { Ionicons } from '@expo/vector-icons';
import AuthGate from '../../components/AuthGate';
import { lightColors, darkColors } from '../../theme/colors';
import { useFriends } from '../../hooks/useFriends';
import { useAuth } from '../../context/AuthContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useBottomTabBarHeight } from '@react-navigation/bottom-tabs';
import { getResizedAvatarUrl } from '../../utils/avatar';

export default function FriendsScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const tabBarHeight = useBottomTabBarHeight();

  const scheme = useColorScheme();
  const colors = scheme === 'dark' ? darkColors : lightColors;

  const { isGuest, session } = useAuth();

  const { friends, loading } = useFriends();

  const [refreshing, setRefreshing] = useState(false);

  const [globalResults, setGlobalResults] = useState<any[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);

  const [pendingCount, setPendingCount] = useState(0);
  const isFocused = useIsFocused();

  useEffect(() => {
    if (!isFocused) return;
    if (!session?.user?.id) return;

    const fetchCount = async () => {
      const { count, error } = await supabase
        .from('friend_requests')
        .select('*', { count: 'exact', head: true })
        .eq('receiver_id', session.user.id)
        .eq('status', 'pending');

      if (error) {
        console.error('Pending count error:', error);
        return;
      }

      setPendingCount(count ?? 0);
    };

    fetchCount();
  }, [isFocused, session?.user?.id]);

  const handleRefresh = async () => {
    if (!session?.user?.id) return;

    setRefreshing(true);

    // Re-fetch pending requests count
    const { count } = await supabase
      .from('friend_requests')
      .select('*', { count: 'exact', head: true })
      .eq('receiver_id', session.user.id)
      .eq('status', 'pending');

    setPendingCount(count ?? 0);

    // Small delay for UX smoothness
    setTimeout(() => {
      setRefreshing(false);
    }, 400);
  };

  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    const runSearch = async () => {
      const q = searchQuery.trim();
      if (!q) {
        setGlobalResults([]);
        return;
      }
      if (!session?.user?.id) return;

      setSearchLoading(true);

      const { data, error } = await supabase
        .from('profiles')
        .select('id, full_name, username, avatar_url')
        .or(`username.ilike.%${q}%,full_name.ilike.%${q}%`)
        .neq('id', session.user.id)
        .limit(20);

      if (error) {
        console.error('Global search error:', error);
        setSearchLoading(false);
        return;
      }

      const normalized = (data ?? []).map((p: any) => ({
        ...p,
        avatar_url: getResizedAvatarUrl(p.avatar_url ?? null),
      }));

      setGlobalResults(normalized);
      setSearchLoading(false);
    };

    runSearch();
  }, [searchQuery, session?.user?.id]);

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
          key={item.id}
          source={item.avatar_url}
          style={styles.avatar}
          contentFit="cover"
          cachePolicy="memory-disk"
          onError={() => {
            console.log('Avatar failed to load for:', item.username, item.avatar_url);
          }}
        />
      ) : (
        <Ionicons
          name="person-circle"
          size={44}
          color={colors.textMuted}
          style={{ marginRight: 14 }}
        />
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

  if (isGuest) {
    return (
      <View
        style={[
          styles.container,
          {
            backgroundColor: colors.background,
            justifyContent: 'center',
            paddingTop: insets.top + 16,
            paddingBottom: insets.bottom + 24,
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

  return (
    <AuthGate>
      <View
        style={[
          styles.container,
          {
            backgroundColor: colors.background,
            paddingTop: insets.top + 16,
          },
        ]}
      >
        {loading ? (
          <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
            <ActivityIndicator size="large" color={colors.textPrimary} />
          </View>
        ) : (
          <FlatList
            data={searchQuery.trim() ? globalResults : friends}
            refreshControl={
              <RefreshControl
                refreshing={refreshing}
                onRefresh={handleRefresh}
                tintColor={colors.textPrimary}
              />
            }
            keyExtractor={(item) => item.id}
            renderItem={renderItem}
            ListHeaderComponent={
              <>
                <View style={styles.headerRow}>
                  <Text style={[styles.title, { color: colors.textPrimary }]}>Friends</Text>
                  <Pressable
                    onPress={() => router.push('/friend-requests')}
                    style={[
                      styles.requestButton,
                      {
                        backgroundColor: colors.card,
                        marginLeft: 'auto',
                      },
                    ]}
                  >
                    <Ionicons name="person-add-outline" size={20} color={colors.textPrimary} />
                    {pendingCount > 0 && (
                      <View style={styles.badge}>
                        <Text style={styles.badgeText}>{pendingCount}</Text>
                      </View>
                    )}
                  </Pressable>
                </View>

                <View style={[styles.searchBar, { backgroundColor: colors.card }]}>
                  <Ionicons name="search" size={16} color={colors.textMuted} />
                  <TextInput
                    placeholder="Search by username"
                    placeholderTextColor={colors.textMuted}
                    style={[styles.searchInput, { color: colors.textPrimary }]}
                    value={searchQuery}
                    onChangeText={setSearchQuery}
                  />
                </View>

                <View style={{ height: 24 }} />
              </>
            }
            ListFooterComponent={<View style={{ height: tabBarHeight + 16 }} />}
            contentContainerStyle={{ paddingHorizontal: 20 }}
            ListEmptyComponent={
              searchLoading ? (
                <ActivityIndicator size="small" color={colors.textPrimary} />
              ) : (
                <Text
                  style={{
                    color: colors.textMuted,
                    textAlign: 'center',
                    paddingVertical: 20,
                  }}
                >
                  {searchQuery.trim() ? 'No users found.' : 'No friends yet.'}
                </Text>
              )
            }
          />
        )}
      </View>
    </AuthGate>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
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
  requestButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
  },
  searchBar: {
    marginTop: 16,
    borderRadius: 20,
    paddingHorizontal: 14,
    height: 44,
    flexDirection: 'row',
    alignItems: 'center',
  },
  searchInput: {
    marginLeft: 8,
    flex: 1,
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
  badge: {
    position: 'absolute',
    top: -4,
    right: -4,
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    backgroundColor: '#ef4444',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  badgeText: {
    color: 'white',
    fontSize: 10,
    fontWeight: '700',
  },
});