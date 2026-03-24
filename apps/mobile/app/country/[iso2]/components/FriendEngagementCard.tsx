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
  totalFriends: number;
  visited: EngagementProfile[];
  bucketList: EngagementProfile[];
  fromHere: EngagementProfile[];
  loading?: boolean;
  onSelectProfile: (userId: string) => void;
};

function FriendRow({
  icon,
  title,
  profiles,
  onSelectProfile,
  colors,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  profiles: EngagementProfile[];
  onSelectProfile: (userId: string) => void;
  colors: ReturnType<typeof useTheme>;
}) {
  return (
    <View style={styles.group}>
      <View style={styles.groupHeader}>
        <View style={styles.groupTitleRow}>
          <Ionicons name={icon} size={16} color={colors.textSecondary} />
          <Text style={[styles.groupTitle, { color: colors.textPrimary }]}>{title}</Text>
        </View>
        <Text style={[styles.groupCount, { color: colors.textMuted }]}>{profiles.length}</Text>
      </View>

      {profiles.length === 0 ? (
        <Text style={[styles.emptyText, { color: colors.textMuted }]}>Nobody yet.</Text>
      ) : (
        <View style={styles.list}>
          {profiles.map(profile => (
            <Pressable
              key={profile.id}
              onPress={() => onSelectProfile(profile.id)}
              style={[styles.profileRow, { backgroundColor: colors.surface, borderColor: colors.border }]}
            >
              {profile.avatar_url ? (
                <Image source={profile.avatar_url} style={styles.avatar} contentFit="cover" />
              ) : (
                <View style={[styles.avatarFallback, { backgroundColor: colors.border }]}>
                  <Ionicons name="person" size={16} color={colors.textMuted} />
                </View>
              )}

              <View style={{ flex: 1 }}>
                <Text style={[styles.name, { color: colors.textPrimary }]}>
                  {profile.full_name?.trim() || profile.username}
                </Text>
                <Text style={[styles.username, { color: colors.textMuted }]}>
                  @{profile.username}
                </Text>
              </View>

              <Ionicons name="chevron-forward" size={16} color={colors.textMuted} />
            </Pressable>
          ))}
        </View>
      )}
    </View>
  );
}

export default function FriendEngagementCard({
  totalFriends,
  visited,
  bucketList,
  fromHere,
  loading = false,
  onSelectProfile,
}: Props) {
  const colors = useTheme();

  const summaryParts = [
    visited.length ? `${visited.length} visited` : null,
    bucketList.length ? `${bucketList.length} want to go` : null,
    fromHere.length ? `${fromHere.length} from here` : null,
  ].filter(Boolean);

  return (
    <View style={[styles.card, { backgroundColor: colors.card }]}>
      <Text style={[styles.title, { color: colors.textPrimary }]}>Friends</Text>
      <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
        {loading
          ? 'Loading friend travel signals...'
          : totalFriends === 0
            ? 'Add friends to unlock social travel signals here.'
            : summaryParts.length
              ? summaryParts.join(' • ')
              : `No friend signals yet across ${totalFriends} friends.`}
      </Text>

      {!loading ? (
        <View style={styles.stack}>
          <FriendRow
            icon="checkmark-circle"
            title="Visited"
            profiles={visited}
            onSelectProfile={onSelectProfile}
            colors={colors}
          />
          <FriendRow
            icon="bookmark"
            title="Bucket List"
            profiles={bucketList}
            onSelectProfile={onSelectProfile}
            colors={colors}
          />
          <FriendRow
            icon="home"
            title="From Here"
            profiles={fromHere}
            onSelectProfile={onSelectProfile}
            colors={colors}
          />
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 22,
    padding: 18,
    marginBottom: 18,
  },
  title: {
    fontSize: 18,
    fontWeight: '800',
  },
  subtitle: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 6,
  },
  stack: {
    marginTop: 16,
    gap: 14,
  },
  group: {
    gap: 10,
  },
  groupHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  groupTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  groupTitle: {
    fontSize: 15,
    fontWeight: '700',
  },
  groupCount: {
    fontSize: 13,
    fontWeight: '700',
  },
  emptyText: {
    fontSize: 13,
    lineHeight: 18,
  },
  list: {
    gap: 8,
  },
  profileRow: {
    borderWidth: 1,
    borderRadius: 16,
    padding: 10,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  avatar: {
    width: 42,
    height: 42,
    borderRadius: 21,
  },
  avatarFallback: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  name: {
    fontSize: 14,
    fontWeight: '700',
  },
  username: {
    fontSize: 12,
    marginTop: 2,
  },
});
