import { ScrollView, View, Text, StyleSheet, useColorScheme } from 'react-native';
import AuthGate from '../components/AuthGate';

export default function LegalScreen() {
  const scheme = useColorScheme();
  const isDark = scheme === 'dark';

  const backgroundColor = isDark ? '#000000' : '#FFFFFF';
  const titleColor = isDark ? '#FFFFFF' : '#111827';
  const bodyColor = isDark ? '#D1D5DB' : '#374151';

  return (
    <AuthGate>
      <ScrollView
        style={{ backgroundColor }}
        contentContainerStyle={styles.content}
      >
        <View style={styles.section}>
          <Text style={[styles.title, { color: titleColor }]}>Legal, Privacy & Disclaimers</Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>Informational Use Only</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            Travel Adventure Finder provides travel insights, scores, and recommendations for informational purposes only. All content, including travelability scores, advisories, affordability indicators, and seasonality insights, is based on publicly available data and historical patterns. Information may change without notice.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>No Government Affiliation</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            Travel Adventure Finder is not affiliated with any government agency. Users should consult official government travel advisories and local authorities before making travel decisions.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>No Professional Advice</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            This app does not provide legal, medical, immigration, financial, or governmental advice. Users are responsible for verifying all information independently.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>User Accounts & Data</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            When you create an account, we may collect your email address and basic profile information for authentication and personalization. We store country preferences and saved destinations to enhance your experience. We do not sell personal data.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>Account Deletion</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            You may request deletion of your account and associated data at any time through the Profile section of the app. Account deletion permanently removes your stored preferences and profile information.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>Limitation of Liability</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            Travel Adventure Finder is not responsible for decisions made based on information presented in the app. Use of this application is at your own discretion and risk.
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>Privacy Policy</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            A full privacy policy is available at: https://iitslamaa.github.io/travel-adventure-finder/privacy.html
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={[styles.heading, { color: titleColor }]}>Contact</Text>
          <Text style={[styles.body, { color: bodyColor }]}>
            For questions regarding legal matters or privacy, contact: travelaf@gmail.com
          </Text>
        </View>

        <View style={{ height: 24 }} />
      </ScrollView>
    </AuthGate>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingHorizontal: 20,
    paddingTop: 24,
    paddingBottom: 40,
  },
  section: {
    marginBottom: 16,
  },
  title: {
    fontSize: 22,
    fontWeight: '600',
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