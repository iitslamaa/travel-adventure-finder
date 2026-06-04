import { ScrollView, View, Text, StyleSheet } from 'react-native';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import TitleBanner from '../components/theme/TitleBanner';
import { useTheme } from '../hooks/useTheme';

export default function LegalScreen() {
  const colors = useTheme();

  return (
    <ScrapbookBackground>
    <ScrollView
      style={{ backgroundColor: 'transparent' }}
      contentContainerStyle={styles.content}
    >
      <View style={styles.section}>
        <TitleBanner title="Legal" />
      </View>
      {[
        {
          title: 'General Information',
          body: 'Travel Adventure Finder provides informational travel insights only. All scores, advisories, and recommendations are intended for general guidance and educational purposes. Seasonality insights are based on historical climate averages and typical travel patterns.',
        },
        {
          title: 'Advisories & Safety Scores',
          body: 'Safety advisories and scores are derived from publicly available sources and third-party data. Conditions may change rapidly, and Travel Adventure Finder does not guarantee accuracy, completeness, or timeliness.',
        },
        {
          title: 'No Professional Advice',
          body: 'Travel Adventure Finder does not provide legal, medical, or governmental advice. Users should verify information with official sources before making travel decisions.',
        },
        {
          title: 'Limitation of Liability',
          body: 'Travel Adventure Finder is not responsible for decisions made based on information presented in the app. Use of this app is at your own discretion.',
        },
      ].map(section => (
        <View
          key={section.title}
          style={[
            styles.legalCard,
            {
              backgroundColor: colors.card,
              borderColor: colors.cardBorderStrong,
              shadowColor: colors.shadow,
            },
          ]}
        >
          <Text style={[styles.heading, { color: colors.textPrimary }]}>{section.title}</Text>
          <Text style={[styles.body, { color: colors.textSecondary }]}>{section.body}</Text>
        </View>
      ))}
      <View style={{ height: 24 }} />
    </ScrollView>
    </ScrapbookBackground>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingHorizontal: 20,
    paddingTop: 18,
    paddingBottom: 40,
  },
  legalCard: {
    borderRadius: 24,
    borderWidth: 1,
    padding: 20,
    marginBottom: 20,
    shadowOpacity: 0.12,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 4,
  },
  section: {
    marginBottom: 0,
  },
  heading: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
  },
  body: {
    fontSize: 14,
    lineHeight: 20,
  },
});
