import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
  FlatList,
  ActivityIndicator,
  RefreshControl,
  ImageBackground,
} from 'react-native';
import { Image } from 'expo-image';
import { useRouter } from 'expo-router';
import { useMemo, useState, useCallback, useEffect } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { useIsFocused } from '@react-navigation/native';
import { supabase } from '../../lib/supabase';
import { Ionicons } from '@expo/vector-icons';
import AuthGate from '../../components/AuthGate';
import { useFriends } from '../../hooks/useFriends';
import { useAuth } from '../../context/AuthContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useBottomTabBarHeight } from '@react-navigation/bottom-tabs';
import { getResizedAvatarUrl } from '../../utils/avatar';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import TitleBanner from '../../components/theme/TitleBanner';
import { useTheme } from '../../hooks/useTheme';

export default function FriendsScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const tabBarHeight = useBottomTabBarHeight();

  const colors = useTheme();

  const { isGuest, session } = useAuth();

  const { friends, loading, refresh } = useFriends();

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
    await refresh();

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
      style={styles.rowPressable}
    >
      <View style={[styles.row, { borderBottomColor: colors.border }]}>
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

        <View style={[styles.chevronWrap, { backgroundColor: colors.paperAlt }]}>
          <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
        </View>
      </View>
    </Pressable>
  );

  if (isGuest) {
    return (
      <ScrapbookBackground overlay={0}>
        <ImageBackground
          source={require('../../assets/scrapbook/travel3.png')}
          style={styles.pageBackground}
          imageStyle={styles.pageBackgroundImage}
        >
        <View style={styles.pageWash} />
        <View
          style={[
            styles.container,
            {
              paddingTop: insets.top + 16,
              paddingBottom: insets.bottom + 24,
            },
          ]}
        >
          <View style={styles.headerRow}>
            <View style={styles.titleWrap}>
              <TitleBanner title="Friends" />
            </View>
          </View>

          <View style={styles.guestCenter}>
            <ScrapbookCard innerStyle={styles.guestFeatureCard}>
              <View style={styles.guestFeatureHeader}>
                <View
                  style={[
                    styles.guestFeatureIcon,
                    { backgroundColor: colors.paperAlt, borderColor: colors.border },
                  ]}
                >
                  <Ionicons
                    name="people-outline"
                    size={26}
                    color={colors.textPrimary}
                  />
                </View>
              </View>

              <Text style={[styles.emptyHeadline, { color: colors.textPrimary }]}>
                Create an account to build your travel circle
              </Text>
              <Text style={[styles.emptyBody, { color: colors.textSecondary }]}>
                Add friends, send requests, and explore shared travel profiles once you sign in.
              </Text>
            </ScrapbookCard>

            <Pressable
              onPress={() => router.push('/login')}
              style={[styles.ctaButton, { backgroundColor: colors.paperAlt, borderColor: colors.cardBorderStrong }]}
            >
              <Ionicons name="paper-plane" size={16} color={colors.textPrimary} />
              <Text style={[styles.ctaText, { color: colors.textPrimary }]}>
                Create Account or Log In
              </Text>
            </Pressable>
          </View>
        </View>
        </ImageBackground>
      </ScrapbookBackground>
    );
  }

  return (
    <AuthGate>
      <ScrapbookBackground overlay={0}>
        <ImageBackground
          source={require('../../assets/scrapbook/travel3.png')}
          style={styles.pageBackground}
          imageStyle={styles.pageBackgroundImage}
        >
        <View style={styles.pageWash} />
        <View
          style={[
            styles.container,
            {
              backgroundColor: 'transparent',
              paddingTop: insets.top + 16,
            },
          ]}
        >
          <>
            <View style={styles.headerRow}>
              <View style={styles.titleWrap}>
                <TitleBanner title="Friends" />
              </View>
              <Pressable
                onPress={() => router.push('/friend-requests')}
                style={[
                  styles.requestButton,
                  {
                    backgroundColor: colors.paper,
                    borderColor: colors.border,
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

            <ScrapbookCard
              style={styles.listShell}
              innerStyle={[styles.listInner, { backgroundColor: `${colors.card}F2` }]}
            >
              {loading ? (
                <View style={styles.loadingState}>
                  <Text style={[styles.listEyebrow, { color: colors.textSecondary }]}>
                    Social notebook
                  </Text>
                  <ActivityIndicator size="large" color={colors.textPrimary} />
                  <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
                    Loading your social notebook...
                  </Text>
                </View>
              ) : (
                <>
                  <Text style={[styles.listEyebrow, { color: colors.textSecondary }]}>
                    Social notebook
                  </Text>
                  <View style={[styles.searchBar, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}>
                    <Ionicons name="search" size={16} color={colors.textMuted} />
                    <TextInput
                      placeholder="Search by username"
                      placeholderTextColor={colors.textMuted}
                      style={[styles.searchInput, { color: colors.textPrimary }]}
                      value={searchQuery}
                      onChangeText={setSearchQuery}
                    />
                  </View>

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
                    ListFooterComponent={<View style={{ height: tabBarHeight + 16 }} />}
                    contentContainerStyle={styles.listContent}
                    showsVerticalScrollIndicator={false}
                    ListEmptyComponent={
                      searchLoading ? (
                        <ActivityIndicator size="small" color={colors.textPrimary} style={{ marginTop: 24 }} />
                      ) : (
                        <View style={styles.emptyState}>
                          <Ionicons
                            name={searchQuery.trim() ? 'search' : 'people-outline'}
                            size={38}
                            color={colors.textMuted}
                          />
                          <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}>
                            {searchQuery.trim() ? 'No users found' : 'No friends yet'}
                          </Text>
                          <Text style={[styles.emptySubtitle, { color: colors.textSecondary }]}>
                            {searchQuery.trim()
                              ? 'Try another name or username.'
                              : 'Once you add friends, they will show up here in your social notebook.'}
                          </Text>
                        </View>
                      )
                    }
                  />
                </>
              )}
            </ScrapbookCard>
          </>
        </View>
        </ImageBackground>
      </ScrapbookBackground>
    </AuthGate>
  );
}

const styles = StyleSheet.create({
  pageBackground: {
    flex: 1,
  },
  pageBackgroundImage: {
    resizeMode: 'cover',
  },
  pageWash: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(250,245,237,0.18)',
  },
  container: {
    flex: 1,
  },
  rowPressable: {
    marginBottom: 2,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
    marginBottom: 14,
  },
  titleWrap: {
    flex: 1,
    marginLeft: -20,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
  },
  requestButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  listShell: {
    flex: 1,
    marginHorizontal: 20,
    marginBottom: 10,
  },
  listInner: {
    flex: 1,
    paddingTop: 14,
    paddingHorizontal: 12,
  },
  listContent: {
    paddingTop: 8,
    paddingBottom: 10,
  },
  loadingState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    paddingBottom: 28,
  },
  loadingText: {
    marginTop: 14,
    fontSize: 15,
    textAlign: 'center',
  },
  listEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.7,
    textTransform: 'uppercase',
    marginBottom: 10,
    paddingHorizontal: 4,
  },
  searchBar: {
    borderRadius: 20,
    paddingHorizontal: 14,
    height: 44,
    borderWidth: 1,
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
    paddingHorizontal: 8,
    borderBottomWidth: 1,
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
  chevronWrap: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badge: {
    position: 'absolute',
    top: -4,
    right: -4,
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    backgroundColor: '#B07A6C',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  badgeText: {
    color: '#FFF8F0',
    fontSize: 10,
    fontWeight: '700',
  },
  emptyHeadline: {
    fontSize: 28,
    fontWeight: '700',
  },
  emptyBody: {
    marginTop: 12,
    fontSize: 16,
    lineHeight: 22,
  },
  guestCenter: {
    flex: 1,
    justifyContent: 'center',
    gap: 24,
    paddingHorizontal: 20,
  },
  guestFeatureCard: {
    padding: 22,
    minHeight: 168,
  },
  guestFeatureHeader: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginBottom: 12,
  },
  guestFeatureIcon: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ctaButton: {
    borderWidth: 1,
    borderRadius: 24,
    minHeight: 60,
    paddingHorizontal: 20,
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'center',
    flexDirection: 'row',
    gap: 10,
  },
  ctaText: {
    fontSize: 18,
    fontWeight: '700',
  },
  emptyState: {
    alignItems: 'center',
    paddingHorizontal: 18,
    paddingTop: 30,
    paddingBottom: 16,
  },
  emptyTitle: {
    marginTop: 12,
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
  },
  emptySubtitle: {
    marginTop: 8,
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
  },
});
