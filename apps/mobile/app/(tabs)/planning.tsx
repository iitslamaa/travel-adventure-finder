import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';

type PlanningCardProps = {
  title: string;
  subtitle: string;
  icon: keyof typeof Ionicons.glyphMap;
  onPress: () => void;
};

function PlanningCard({ title, subtitle, icon, onPress }: PlanningCardProps) {
  const colors = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.card,
        {
          backgroundColor: colors.card,
          borderColor: colors.border,
          opacity: pressed ? 0.9 : 1,
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

export default function PlanningScreen() {
  const colors = useTheme();
  const insets = useSafeAreaInsets();

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.background }}
      contentContainerStyle={{
        paddingTop: insets.top + 18,
        paddingHorizontal: 20,
        paddingBottom: 120,
      }}
      showsVerticalScrollIndicator={false}
    >
      <Text style={[styles.title, { color: colors.textPrimary }]}>Planning</Text>
      <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
        Keep your bucket list, visited countries, and upcoming trip ideas in one
        place.
      </Text>

      <View style={styles.stack}>
        <PlanningCard
          title="Bucket List"
          subtitle="Countries you want to visit next."
          icon="bookmark-outline"
          onPress={() => router.push('/lists/bucket')}
        />

        <PlanningCard
          title="Visited"
          subtitle="The places you have already checked off."
          icon="checkmark-circle-outline"
          onPress={() => router.push('/lists/visited')}
        />

        <PlanningCard
          title="Trip Planner"
          subtitle="Save trip ideas with dates, countries, and travel buddies."
          icon="airplane-outline"
          onPress={() => router.push('/trip-planner')}
        />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  title: {
    fontSize: 28,
    fontWeight: '800',
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 8,
    marginBottom: 24,
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
