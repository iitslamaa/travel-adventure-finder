import { View, Text, StyleSheet, Pressable, FlatList, ActivityIndicator, ImageBackground } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useState, useCallback } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { getResizedAvatarUrl } from '../utils/avatar';
import { Image } from 'expo-image';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import ScrapbookCard from '../components/theme/ScrapbookCard';
import TitleBanner from '../components/theme/TitleBanner';
import { useTheme } from '../hooks/useTheme';

type RequestProfile = {
  request_id: string;
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
};

export default function FriendRequestsScreen() {
  const router = useRouter();
  const colors = useTheme();
  const { session } = useAuth();

  const [requests, setRequests] = useState<RequestProfile[]>([]);
  const [loading, setLoading] = useState(true);

  const handleAccept = async (requestId: string) => {
    if (!session?.user?.id) return;

    try {
      // Optimistic removal
      setRequests((prev) => prev.filter((r) => r.request_id !== requestId));

      const { data, error } = await supabase
        .from('friend_requests')
        .update({ status: 'accepted' })
        .eq('id', requestId)
        .select();

      if (error) throw error;
    } catch (err) {
      console.error('Accept failed:', err);
    }
  };

  const handleDecline = async (requestId: string) => {
    if (!session?.user?.id) return;

    try {
      // Optimistic removal
      setRequests((prev) => prev.filter((r) => r.request_id !== requestId));

      const { error } = await supabase
        .from('friend_requests')
        .update({ status: 'declined' })
        .eq('id', requestId);

      if (error) throw error;
    } catch (err) {
      console.error('Decline failed:', err);
    }
  };

  useFocusEffect(
    useCallback(() => {
      if (!session?.user?.id) return;

      const userId = session.user.id;

      async function fetchRequests() {
        setLoading(true);

        const { data, error } = await supabase
          .from('friend_requests')
          .select(`
            id,
            sender_id,
            profiles!friend_requests_sender_id_fkey (
              id,
              username,
              full_name,
              avatar_url
            )
          `)
          .eq('receiver_id', userId)
          .eq('status', 'pending');

        if (!error) {
          const mapped =
            data?.map((row: any) => ({
              request_id: row.id,
              ...row.profiles,
              avatar_url: getResizedAvatarUrl(row.profiles?.avatar_url ?? null),
            })) ?? [];

          setRequests(mapped);
        } else {
          console.error(error);
        }

        setLoading(false);
      }

      fetchRequests();
    }, [session])
  );

  const renderItem = ({ item }: { item: RequestProfile }) => (
    <View style={[styles.requestRow, { backgroundColor: colors.paper, borderColor: colors.cardBorderStrong }]}>
      <Pressable
        onPress={() =>
          router.push({
            pathname: '/profile/[userId]',
            params: { userId: item.id },
          })
        }
        style={styles.requestIdentity}
      >
        {item.avatar_url ? (
          <Image
            source={item.avatar_url}
            style={styles.avatar}
            contentFit="cover"
            cachePolicy="memory-disk"
          />
        ) : (
          <View style={[styles.avatarFallback, { backgroundColor: colors.paperAlt }]}>
            <Ionicons name="person-circle" size={44} color={colors.textMuted} />
          </View>
        )}

        <View style={{ flex: 1 }}>
          <Text style={[styles.name, { color: colors.textPrimary }]}>
            {item.full_name}
          </Text>
          <Text style={[styles.username, { color: colors.textMuted }]}>
            @{item.username}
          </Text>
        </View>
      </Pressable>

      <View style={styles.actionsRow}>
        <Pressable
          onPress={() => handleAccept(item.request_id)}
          style={[
            styles.actionButton,
            {
              backgroundColor: colors.primary,
              borderColor: colors.cardBorderStrong,
            },
          ]}
        >
          <Text style={styles.acceptText}>Accept</Text>
        </Pressable>

        <Pressable
          onPress={() => handleDecline(item.request_id)}
          style={[
            styles.actionButton,
            {
              backgroundColor: 'rgba(242, 237, 227, 0.96)',
              borderColor: colors.cardBorderStrong,
            },
          ]}
        >
          <Text style={[styles.declineText, { color: colors.textPrimary }]}>Decline</Text>
        </Pressable>
      </View>
    </View>
  );

  return (
    <ScrapbookBackground overlay={0}>
    <ImageBackground
      source={require('../assets/scrapbook/travel4.png')}
      style={styles.pageBackground}
      imageStyle={styles.pageBackgroundImage}
    >
    <View style={styles.pageWash} />
    <View style={[styles.container, { backgroundColor: 'transparent' }]}>
      <View style={styles.headerRow}>
        <Pressable
          onPress={() => router.back()}
          style={[styles.backButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
        >
          <Ionicons name="chevron-back" size={20} color={colors.textPrimary} />
        </Pressable>

        <View style={styles.titleWrap}>
          <TitleBanner title="Friend Requests" />
        </View>
      </View>

      <ScrapbookCard style={styles.listShell} innerStyle={[styles.listInner, { backgroundColor: `${colors.card}F0` }]}>
        {loading ? (
          <View style={styles.centerState}>
            <Text style={[styles.listEyebrow, { color: colors.textSecondary }]}>
              Social notebook
            </Text>
            <ActivityIndicator size="large" color={colors.textPrimary} />
            <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
              Loading friend requests...
            </Text>
          </View>
        ) : requests.length === 0 ? (
          <View style={[styles.emptyState, styles.emptyCard, { backgroundColor: colors.paper, borderColor: colors.border }]}>
            <Text style={[styles.listEyebrow, { color: colors.textSecondary }]}>
              Social notebook
            </Text>
            <Ionicons
              name="person-add-outline"
              size={54}
              color={colors.textMuted}
            />
            <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}> 
              No friend requests
            </Text>
            <Text style={[styles.emptySubtitle, { color: colors.textMuted }]}> 
              When someone sends you a friend request, it’ll show up here.
            </Text>
          </View>
        ) : (
          <>
            <Text style={[styles.listEyebrow, { color: colors.textSecondary }]}>
              Social notebook
            </Text>
            <FlatList
              data={requests}
              renderItem={renderItem}
              keyExtractor={(item) => item.request_id}
              contentContainerStyle={{ paddingTop: 8, paddingBottom: 28, paddingHorizontal: 12 }}
              ItemSeparatorComponent={() => <View style={{ height: 14 }} />}
              showsVerticalScrollIndicator={false}
            />
          </>
        )}
      </ScrapbookCard>
    </View>
    </ImageBackground>
    </ScrapbookBackground>
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
    paddingTop: 56,
    paddingHorizontal: 20,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 14,
  },
  titleWrap: {
    flex: 1,
    marginLeft: -8,
  },
  backButton: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  centerState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
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
    paddingHorizontal: 12,
    paddingTop: 4,
  },
  emptyState: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyCard: {
    borderWidth: 1,
    borderRadius: 22,
    paddingHorizontal: 24,
    paddingVertical: 28,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginTop: 20,
  },
  emptySubtitle: {
    fontSize: 15,
    marginTop: 8,
    textAlign: 'center',
    paddingHorizontal: 30,
  },
  listShell: {
    flex: 1,
    marginTop: 18,
  },
  listInner: {
    flex: 1,
    padding: 12,
  },
  requestRow: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 18,
    shadowColor: '#000000',
    shadowOpacity: 0.1,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 4 },
    elevation: 3,
  },
  avatar: {
    width: 54,
    height: 54,
    borderRadius: 27,
  },
  avatarFallback: {
    width: 54,
    height: 54,
    borderRadius: 27,
    alignItems: 'center',
    justifyContent: 'center',
  },
  requestIdentity: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  name: {
    fontSize: 17,
    fontWeight: '700',
  },
  username: {
    fontSize: 14,
    marginTop: 4,
  },
  actionsRow: {
    flexDirection: 'row',
    marginTop: 16,
    gap: 12,
  },
  actionButton: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 44,
    paddingHorizontal: 16,
    borderRadius: 999,
    borderWidth: 1,
  },
  acceptText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
  },
  declineText: {
    fontSize: 14,
    fontWeight: '700',
  },
});
