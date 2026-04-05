import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  ActivityIndicator,
  ImageBackground,
} from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import AuthGate from '../../../components/AuthGate';
import { useFriends } from '../../../hooks/useFriends';
import { useAuth } from '../../../context/AuthContext';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Image } from 'expo-image';
import { useTheme } from '../../../hooks/useTheme';
import ScrapbookBackground from '../../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../../components/theme/ScrapbookCard';
import TitleBanner from '../../../components/theme/TitleBanner';

export default function FriendsScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { userId } = useLocalSearchParams();
  const targetUserId = typeof userId === 'string' ? userId : undefined;

  const colors = useTheme();

  const { isGuest } = useAuth();
  const { friends, loading } = useFriends(targetUserId);

  if (!targetUserId) {
    return null;
  }

  if (isGuest) {
    return (
      <ScrapbookBackground overlay={0}>
        <ImageBackground
          source={require('../../../assets/scrapbook/travel4.png')}
          style={styles.pageBackground}
          imageStyle={styles.pageBackgroundImage}
        >
        <View style={styles.pageWash} />
        <View style={styles.container}>
          <View style={styles.headerRow}>
            <View style={styles.backButtonPlaceholder} />
          </View>

          <TitleBanner title="Friends" />

          <View style={styles.guestCenter}>
            <ScrapbookCard innerStyle={styles.guestFeatureCard}>
              <View style={styles.guestFeatureHeader}>
                <View
                  style={[
                    styles.guestFeatureIcon,
                    { backgroundColor: colors.paperAlt, borderColor: colors.border },
                  ]}
                >
                  <Ionicons name="people-outline" size={26} color={colors.textPrimary} />
                </View>
              </View>
              <Text style={[styles.emptyHeadline, { color: colors.textPrimary }]}>
                Create an account to explore travel circles
              </Text>
              <Text style={[styles.emptyBody, { color: colors.textSecondary }]}>
                Sign in to see friends, shared profiles, and social travel connections.
              </Text>
            </ScrapbookCard>

            <Pressable
              onPress={() => router.push('/login')}
              style={[
                styles.ctaButton,
                { backgroundColor: colors.paperAlt, borderColor: colors.cardBorderStrong },
              ]}
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

  const renderItem = ({ item }: { item: any }) => (
    <Pressable
      onPress={() =>
        router.push({
          pathname: '/profile/[userId]',
          params: { userId: item.id },
        })
      }
      style={[
        styles.row,
        {
          backgroundColor: colors.card,
          borderColor: colors.cardBorderStrong,
          shadowColor: colors.shadow,
        },
      ]}
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
        <Text style={[styles.rowEyebrow, { color: colors.textSecondary }]}>
          Travel friend
        </Text>
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
      <ScrapbookBackground overlay={0}>
        <ImageBackground
          source={require('../../../assets/scrapbook/travel4.png')}
          style={styles.pageBackground}
          imageStyle={styles.pageBackgroundImage}
        >
        <View style={styles.pageWash} />
        <View
          style={[
            styles.container,
            {
              paddingTop: insets.top + 12,
              paddingBottom: insets.bottom + 24,
            },
          ]}
        >
          <View style={styles.headerRow}>
            <Pressable
              onPress={() => router.back()}
              style={[styles.backButton, { backgroundColor: colors.paperAlt, borderColor: colors.border }]}
            >
              <Ionicons name="chevron-back" size={20} color={colors.textPrimary} />
            </Pressable>
          </View>

          <TitleBanner title="Friends" />

          {loading ? (
            <ScrapbookCard style={styles.card} innerStyle={styles.loadingShell}>
              <ActivityIndicator size="large" color={colors.textPrimary} />
              <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
                Loading social notebook...
              </Text>
            </ScrapbookCard>
          ) : (
            <ScrapbookCard style={styles.card} innerStyle={{ paddingVertical: 14, paddingHorizontal: 12 }}>
              <Text style={[styles.listEyebrow, { color: colors.textSecondary }]}>
                Social notebook
              </Text>
              <FlatList
                data={friends}
                renderItem={renderItem}
                keyExtractor={item => item.id}
                contentContainerStyle={{ paddingBottom: 8 }}
                ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
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
            </ScrapbookCard>
          )}
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
    paddingHorizontal: 20,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
    marginBottom: 4,
  },
  backButtonPlaceholder: {
    width: 42,
    height: 42,
  },
  backButton: {
    width: 42,
    height: 42,
    borderRadius: 21,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  card: {
    flex: 1,
    marginTop: 8,
  },
  loadingShell: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 14,
  },
  loadingText: {
    fontSize: 15,
    textAlign: 'center',
  },
  listEyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 0.9,
    textTransform: 'uppercase',
    marginBottom: 12,
    paddingHorizontal: 4,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 14,
    borderRadius: 20,
    borderWidth: 1,
    shadowOpacity: 0.1,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 3,
  },
  rowEyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 4,
  },
  avatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
    backgroundColor: 'rgba(228, 214, 193, 0.96)',
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
});
