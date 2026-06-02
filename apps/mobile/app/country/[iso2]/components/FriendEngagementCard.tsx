import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../../../hooks/useTheme';

type EngagementProfile = {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string | null;
};

type Props = {
  countryName: string;
  totalFriends: number;
  visited: EngagementProfile[];
  bucketList: EngagementProfile[];
  fromHere: EngagementProfile[];
  loading?: boolean;
  onOpen?: () => void;
};

export default function FriendEngagementCard({
  countryName,
  totalFriends,
  visited,
  bucketList,
  fromHere,
  loading = false,
  onOpen,
}: Props) {
  const colors = useTheme();
  const previewProfiles = [...visited, ...fromHere, ...bucketList].filter(
    (profile, index, list) => list.findIndex(item => item.id === profile.id) === index
  ).slice(0, 3);

  const summaryParts = [
    visited.length ? `${visited.length} visited` : null,
    bucketList.length ? `${bucketList.length} want to go` : null,
    fromHere.length ? `${fromHere.length} from here` : null,
  ].filter(Boolean);

  return (
    <Pressable
      onPress={onOpen}
      style={[
        styles.card,
        {
          backgroundColor: colors.card,
          borderColor: colors.cardBorderStrong,
          shadowColor: colors.shadow,
        },
      ]}
    >
      <View style={styles.avatarStack}>
        {previewProfiles.length === 0 ? (
          <View style={[styles.avatarFallback, { backgroundColor: colors.border }]}>
            <Ionicons name="people" size={20} color={colors.textMuted} />
          </View>
        ) : (
          previewProfiles.map((profile, index) => (
            <View
              key={profile.id}
              style={[
                styles.avatarLayer,
                {
                  left: index * 22,
                  zIndex: previewProfiles.length - index,
                  borderColor: colors.card,
                },
              ]}
            >
              {profile.avatar_url ? (
                <Image source={profile.avatar_url} style={styles.avatar} contentFit="cover" />
              ) : (
                <View style={[styles.avatarFallback, { backgroundColor: colors.border }]}>
                  <Ionicons name="person" size={16} color={colors.textMuted} />
                </View>
              )}
            </View>
          ))
        )}
      </View>

      <View style={styles.previewText}>
        <Text style={[styles.eyebrow, { color: colors.textMuted }]}>Friends here</Text>
        <Text style={[styles.title, { color: colors.textPrimary }]}>{countryName}</Text>
        <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
          {loading
            ? 'Loading friend travel signals...'
            : totalFriends === 0
              ? 'Add friends to unlock social travel signals here.'
              : summaryParts.length
                ? summaryParts.join(' • ')
                : `No friend signals yet across ${totalFriends} friends.`}
        </Text>
      </View>

      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    padding: 18,
    marginBottom: 18,
    borderRadius: 14,
    borderWidth: 1,
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
    elevation: 3,
  },
  eyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  title: {
    fontSize: 16,
    fontWeight: '800',
  },
  subtitle: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 3,
  },
  avatar: {
    width: 42,
    height: 42,
    borderRadius: 21,
  },
  avatarFallback: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarStack: {
    width: 88,
    height: 48,
  },
  avatarLayer: {
    position: 'absolute',
    width: 46,
    height: 46,
    borderRadius: 23,
    borderWidth: 2,
    overflow: 'hidden',
  },
  previewText: {
    flex: 1,
  },
});
