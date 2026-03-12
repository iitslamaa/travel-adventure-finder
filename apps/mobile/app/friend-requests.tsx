import {
  View,
  Text,
  StyleSheet,
  Pressable,
  useColorScheme,
  FlatList,
  ActivityIndicator,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { lightColors, darkColors } from '../theme/colors';
import { useState, useCallback } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { getResizedAvatarUrl } from '../utils/avatar';
import { Image } from 'expo-image';

type RequestProfile = {
  request_id: string;
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
};

export default function FriendRequestsScreen() {
  const router = useRouter();
  const scheme = useColorScheme();
  const colors = scheme === 'dark' ? darkColors : lightColors;
  const { session } = useAuth();
  console.log('RN USER ID:', session?.user?.id);

  const [requests, setRequests] = useState<RequestProfile[]>([]);
  const [loading, setLoading] = useState(true);

  const handleAccept = async (requestId: string) => {
    if (!session?.user?.id) return;
    console.log('Clicked requestId:', requestId);

    try {
      // Optimistic removal
      setRequests((prev) => prev.filter((r) => r.request_id !== requestId));

      const { data, error } = await supabase
        .from('friend_requests')
        .update({ status: 'accepted' })
        .eq('id', requestId)
        .select();

      if (error) throw error;

      console.log('Accepted rows:', data);
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

        console.log('Raw friend_requests rows:', data);

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
    <View style={[styles.row, { borderBottomColor: colors.textSecondary }]}>
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

        <View style={{ flexDirection: 'row', marginTop: 8, gap: 12 }}>
          <Pressable
            onPress={() => handleAccept(item.request_id)}
            style={{
              paddingVertical: 6,
              paddingHorizontal: 14,
              borderRadius: 12,
              backgroundColor: '#22c55e',
            }}
          >
            <Text style={{ color: 'white', fontWeight: '600' }}>Accept</Text>
          </Pressable>

          <Pressable
            onPress={() => handleDecline(item.request_id)}
            style={{
              paddingVertical: 6,
              paddingHorizontal: 14,
              borderRadius: 12,
              backgroundColor: '#ef4444',
            }}
          >
            <Text style={{ color: 'white', fontWeight: '600' }}>Decline</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}> 
      <Pressable onPress={() => router.back()} style={styles.backButton}>
        <Ionicons name="arrow-back" size={24} color={colors.textPrimary} />
      </Pressable>

      <Text style={[styles.title, { color: colors.textPrimary }]}> 
        Friend Requests
      </Text>

      {loading && (
        <ActivityIndicator
          size="large"
          color={colors.textPrimary}
          style={{ marginTop: 100 }}
        />
      )}

      {!loading && requests.length === 0 && (
        <View style={styles.emptyState}>
          <Ionicons
            name="person-add-outline"
            size={60}
            color={colors.textMuted}
          />
          <Text style={[styles.emptyTitle, { color: colors.textPrimary }]}> 
            No friend requests
          </Text>
          <Text style={[styles.emptySubtitle, { color: colors.textMuted }]}> 
            When someone sends you a friend request, it’ll show up here.
          </Text>
        </View>
      )}

      {!loading && requests.length > 0 && (
        <FlatList
          data={requests}
          renderItem={renderItem}
          keyExtractor={(item) => item.request_id}
          contentContainerStyle={{ paddingTop: 24 }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 60,
    paddingHorizontal: 20,
  },
  backButton: {
    marginBottom: 20,
  },
  title: {
    fontSize: 34,
    fontWeight: '700',
  },
  emptyState: {
    marginTop: 140,
    alignItems: 'center',
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
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
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