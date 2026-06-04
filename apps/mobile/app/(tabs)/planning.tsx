import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { ImageBackground, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import TitleBanner from '../../components/theme/TitleBanner';

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
      style={({ pressed }) => [styles.cardPressable, { opacity: pressed ? 0.9 : 1 }]}
    >
      <ScrapbookCard innerStyle={styles.card}>
        <View style={styles.cardTopRow}>
          <View style={styles.cardTitleBlock}>
            <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
              {title}
            </Text>
          </View>

          <View
            style={[
              styles.cardIconWrap,
              { backgroundColor: colors.paperAlt, borderColor: colors.border },
            ]}
          >
            <Ionicons name={icon} size={18} color={colors.textPrimary} />
          </View>

          <View style={[styles.chevronWrap, { backgroundColor: colors.paperAlt }]}>
            <Ionicons name="chevron-forward" size={18} color={colors.textPrimary} />
          </View>
        </View>

        <View style={styles.cardBody}>
          <Text style={[styles.cardSubtitle, { color: colors.textSecondary }]}>
            {subtitle}
          </Text>
        </View>
      </ScrapbookCard>
    </Pressable>
  );
}

export default function PlanningScreen() {
  const insets = useSafeAreaInsets();

  return (
    <ScrapbookBackground overlay={0}>
      <ImageBackground
        source={require('../../assets/scrapbook/travel2.png')}
        style={styles.pageBackground}
        imageStyle={styles.pageBackgroundImage}
      >
      <View style={styles.pageWash} />
      <ScrollView
        style={{ flex: 1, backgroundColor: 'transparent' }}
        contentContainerStyle={{
          paddingTop: insets.top + 18,
          paddingHorizontal: 20,
          paddingBottom: 120,
        }}
        showsVerticalScrollIndicator={false}
      >
        <TitleBanner title="Planning" />

        <View style={styles.stack}>
          <PlanningCard
            title="Bucket List"
            subtitle="Places you want to visit"
            icon="bookmark"
            onPress={() => router.push('/lists/bucket')}
          />

          <PlanningCard
            title="Visited Countries"
            subtitle="Track places you've been"
            icon="checkmark-circle"
            onPress={() => router.push('/lists/visited')}
          />

          <PlanningCard
            title="Trip Planner"
            subtitle="Build a trip with dates, countries, and friends"
            icon="airplane"
            onPress={() => router.push('/trip-planner' as any)}
          />
        </View>
      </ScrollView>
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
  stack: {
    gap: 24,
    marginTop: 18,
  },
  cardPressable: {
    marginHorizontal: 2,
  },
  card: {
    padding: 18,
    minHeight: 118,
  },
  cardTitleBlock: {
    flex: 1,
    minWidth: 0,
    marginRight: 12,
  },
  cardTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 14,
  },
  cardIconWrap: {
    width: 38,
    height: 38,
    borderRadius: 14,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  chevronWrap: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardBody: {
    gap: 6,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '700',
  },
  cardSubtitle: {
    fontSize: 15,
    lineHeight: 22,
  },
});
