import { View, Pressable, Text, StyleSheet, ImageBackground, ScrollView } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import TitleBanner from '../../components/theme/TitleBanner';

type DiscoveryCardProps = {
  title: string;
  subtitle: string;
  icon: keyof typeof Ionicons.glyphMap;
  onPress: () => void;
};

function DiscoveryCard({ title, subtitle, icon, onPress }: DiscoveryCardProps) {
  const colors = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.cardPressable, pressed && styles.cardPressed]}
    >
      <ImageBackground
        source={require('../../assets/scrapbook/button-image.png')}
        imageStyle={styles.cardImage}
        style={styles.cardImageWrap}
      >
        <View style={styles.cardTint} />
        <View
          style={[
            styles.card,
            {
              borderColor: colors.cardBorderStrong,
            },
          ]}
        >
          <View
            style={[
              styles.cardIconWrap,
              { backgroundColor: 'rgba(255,250,244,0.8)', borderColor: colors.border },
            ]}
          >
            <Ionicons name={icon} size={20} color={colors.textPrimary} />
          </View>

          <View style={styles.cardBody}>
            <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
              {title}
            </Text>
            <Text style={[styles.cardSubtitle, { color: colors.textSecondary }]}>
              {subtitle}
            </Text>
          </View>

          <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
        </View>
      </ImageBackground>
    </Pressable>
  );
}

export default function DiscoveryScreen() {
  const insets = useSafeAreaInsets();
  const colors = useTheme();

  return (
    <ScrapbookBackground>
      <View style={styles.screen}>
        <View
          style={[
            styles.weightsButtonWrap,
            {
              top: insets.top + 12,
            },
          ]}
        >
          <Pressable
            onPress={() => router.push('/weights' as any)}
            style={[
              styles.settingsButton,
              {
                backgroundColor: colors.card,
                borderColor: colors.border,
              },
            ]}
          >
            <Ionicons
              name="options-outline"
              size={20}
              color={colors.textPrimary}
            />
          </Pressable>
        </View>

        <ScrollView
          style={[
            styles.container,
            {
              paddingTop: insets.top + 10,
              paddingBottom: insets.bottom + 24,
            },
          ]}
          contentContainerStyle={styles.content}
        >
          <View style={styles.headerWrap}>
            <TitleBanner title="Discover" />
          </View>

          <View style={styles.stack}>
            <DiscoveryCard
              title="Countries"
              subtitle="Browse and rank every destination."
              icon="globe-outline"
              onPress={() => router.push('/(tabs)/countries')}
            />

            <DiscoveryCard
              title="When to Go"
              subtitle="Explore peak and shoulder seasons by month."
              icon="calendar-outline"
              onPress={() => router.push('/(tabs)/when-to-go')}
            />

            <DiscoveryCard
              title="Score Map"
              subtitle="Compare destinations on the world map."
              icon="map-outline"
              onPress={() => router.push('/score-map')}
            />
          </View>
        </ScrollView>
      </View>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  container: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  content: {
    paddingHorizontal: 20,
  },
  weightsButtonWrap: {
    position: 'absolute',
    left: 16,
    zIndex: 3,
  },
  headerWrap: {
    marginBottom: 20,
  },
  subtitle: {
    display: 'none',
  },
  settingsButton: {
    width: 44,
    height: 44,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stack: {
    gap: 20,
  },
  cardPressable: {
    borderRadius: 26,
  },
  cardPressed: {
    opacity: 0.94,
    transform: [{ scale: 0.995 }],
  },
  cardImageWrap: {
    minHeight: 102,
    justifyContent: 'center',
  },
  cardImage: {
    borderRadius: 26,
  },
  cardTint: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(250, 244, 235, 0.18)',
    borderRadius: 26,
  },
  card: {
    borderWidth: 1,
    borderRadius: 26,
    padding: 18,
    flexDirection: 'row',
    alignItems: 'center',
    minHeight: 102,
  },
  cardIconWrap: {
    width: 46,
    height: 46,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 14,
  },
  cardBody: {
    flex: 1,
    marginRight: 12,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '700',
    marginBottom: 4,
  },
  cardSubtitle: {
    fontSize: 14,
    lineHeight: 20,
  },
});
