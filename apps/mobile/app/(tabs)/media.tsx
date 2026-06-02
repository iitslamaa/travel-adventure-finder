import { Ionicons } from '@expo/vector-icons';
import { ImageBackground, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import TitleBanner from '../../components/theme/TitleBanner';

type MediaCardContent = {
  title: string;
  subtitle: string;
  icon: keyof typeof Ionicons.glyphMap;
};

type MediaSectionProps = {
  title: string;
  subtitle: string;
  cards: MediaCardContent[];
};

function MediaCard({ title, subtitle, icon }: MediaCardContent) {
  const colors = useTheme();

  return (
    <ScrapbookCard innerStyle={styles.card}>
      <View style={styles.cardRow}>
        <View
          style={[
            styles.iconShell,
            { backgroundColor: colors.paperAlt, borderColor: colors.border },
          ]}
        >
          <Ionicons name={icon} size={19} color={colors.textPrimary} />
        </View>

        <View style={styles.cardText}>
          <Text style={[styles.cardTitle, { color: colors.textPrimary }]}>
            {title}
          </Text>
          <Text style={[styles.cardSubtitle, { color: colors.textSecondary }]}>
            {subtitle}
          </Text>
        </View>

        <View style={[styles.actionShell, { backgroundColor: colors.paperAlt }]}>
          <Ionicons name="add" size={18} color={colors.textPrimary} />
        </View>
      </View>
    </ScrapbookCard>
  );
}

function MediaSection({ title, subtitle, cards }: MediaSectionProps) {
  const colors = useTheme();

  return (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
          {title}
        </Text>
        <Text style={[styles.sectionSubtitle, { color: colors.textSecondary }]}>
          {subtitle}
        </Text>
      </View>

      <View style={styles.cardStack}>
        {cards.map((card) => (
          <MediaCard key={card.title} {...card} />
        ))}
      </View>
    </View>
  );
}

export default function MediaScreen() {
  const insets = useSafeAreaInsets();

  return (
    <ScrapbookBackground overlay={0}>
      <ImageBackground
        source={require('../../assets/scrapbook/travel5.png')}
        style={styles.pageBackground}
        imageStyle={styles.pageBackgroundImage}
      >
        <View style={styles.pageWash} />
        <ScrollView
          style={styles.scroll}
          contentContainerStyle={[
            styles.content,
            {
              paddingTop: insets.top + 18,
              paddingBottom: insets.bottom + 120,
            },
          ]}
          showsVerticalScrollIndicator={false}
        >
          <TitleBanner title="Media" />

          <View style={styles.stack}>
            <MediaSection
              title="Articles"
              subtitle="Stories, guides, and inspiration for your next trip."
              cards={[
                {
                  title: 'Featured travel articles',
                  subtitle: 'Hand-picked reads from the Travel AF team.',
                  icon: 'newspaper-outline',
                },
                {
                  title: 'Destination guides',
                  subtitle: 'Practical tips for choosing where to go next.',
                  icon: 'map-outline',
                },
              ]}
            />

            <MediaSection
              title="Podcast"
              subtitle="Listen to conversations about travel planning and discovery."
              cards={[
                {
                  title: 'Podcast links',
                  subtitle: 'Find the latest episodes and listening options.',
                  icon: 'mic-outline',
                },
              ]}
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
  scroll: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  content: {
    paddingHorizontal: 20,
  },
  stack: {
    gap: 24,
    marginTop: 18,
  },
  section: {
    gap: 14,
  },
  sectionHeader: {
    paddingHorizontal: 4,
  },
  sectionTitle: {
    fontSize: 22,
    lineHeight: 28,
    fontWeight: '800',
  },
  sectionSubtitle: {
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '600',
    marginTop: 4,
  },
  cardStack: {
    gap: 14,
  },
  card: {
    padding: 18,
    minHeight: 118,
  },
  cardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  iconShell: {
    width: 46,
    height: 46,
    borderRadius: 17,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardText: {
    flex: 1,
    minWidth: 0,
  },
  cardTitle: {
    fontSize: 18,
    lineHeight: 23,
    fontWeight: '800',
  },
  cardSubtitle: {
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '600',
    marginTop: 5,
  },
  actionShell: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
