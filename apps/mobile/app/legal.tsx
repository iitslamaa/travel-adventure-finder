import { ScrollView, View, Text, StyleSheet } from 'react-native';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import ScrapbookCard from '../components/theme/ScrapbookCard';
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
          body: 'Travel Adventure Finder provides travel insights, scores, and recommendations for informational purposes only. Information may change without notice and should be treated as a helpful guide rather than a guaranteed source of truth.',
        },
        {
          title: 'Travel Advisories',
          body: 'Advisory information is summarized from public sources and may lag behind real-world events. Always confirm current guidance with official government or local authority sources before traveling.',
        },
        {
          title: 'No Professional Advice',
          body: 'This app does not provide legal, medical, immigration, financial, or governmental advice. You are responsible for verifying any information independently before acting on it.',
        },
        {
          title: 'Limitation of Liability',
          body: 'Travel Adventure Finder is not responsible for decisions made based on app information. Use of the application is at your own discretion and risk.',
        },
      ].map(section => (
        <ScrapbookCard key={section.title} innerStyle={styles.legalCard}>
          <View style={styles.section}>
            <Text style={[styles.eyebrow, { color: colors.textSecondary }]}>Policy</Text>
            <Text style={[styles.heading, { color: colors.textPrimary }]}>{section.title}</Text>
            <Text style={[styles.body, { color: colors.textSecondary }]}>{section.body}</Text>
          </View>
        </ScrapbookCard>
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
    padding: 18,
    marginBottom: 18,
  },
  section: {
    marginBottom: 0,
  },
  eyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 8,
  },
  heading: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 6,
  },
  body: {
    fontSize: 14,
    lineHeight: 20,
  },
});
