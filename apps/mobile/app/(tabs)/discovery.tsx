import { View, Pressable, Text, StyleSheet } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';

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
      style={({ pressed }) => [
        styles.card,
        {
          backgroundColor: colors.card,
          borderColor: colors.border,
          opacity: pressed ? 0.92 : 1,
        },
      ]}
    >
      <View
        style={[
          styles.cardIconWrap,
          { backgroundColor: colors.segmentBg, borderColor: colors.border },
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
    </Pressable>
  );
}

export default function DiscoveryScreen() {
  const insets = useSafeAreaInsets();
  const colors = useTheme();

  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor: colors.background,
          paddingTop: insets.top + 18,
          paddingBottom: insets.bottom + 24,
        },
      ]}
    >
      <View style={styles.headerRow}>
        <View style={{ flex: 1, marginRight: 12 }}>
          <Text style={[styles.title, { color: colors.textPrimary }]}>
            Discovery
          </Text>
          <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
            Explore countries, seasonality, and the score map from one place.
          </Text>
        </View>

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

      <View style={styles.stack}>
        <DiscoveryCard
          title="Countries"
          subtitle="Browse and rank every destination."
          icon="globe-outline"
          onPress={() => router.push('/countries' as any)}
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
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 8,
    marginBottom: 24,
  },
  settingsButton: {
    width: 44,
    height: 44,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 4,
  },
  stack: {
    gap: 14,
  },
  card: {
    borderWidth: 1,
    borderRadius: 22,
    padding: 18,
    flexDirection: 'row',
    alignItems: 'center',
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
