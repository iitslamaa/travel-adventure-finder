import { ImageBackground, ScrollView, View, Text, Pressable, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';
import ScrapbookBackground from '../../components/theme/ScrapbookBackground';
import ScrapbookCard from '../../components/theme/ScrapbookCard';
import TitleBanner from '../../components/theme/TitleBanner';

export default function MoreScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const colors = useTheme();

  return (
    <ScrapbookBackground overlay={0}>
      <ImageBackground
        source={require('../../assets/scrapbook/travel2.png')}
        style={styles.pageBackground}
        imageStyle={styles.pageBackgroundImage}
      >
      <View style={styles.pageWash} />
      <ScrollView
        contentContainerStyle={[
          styles.container,
          {
            backgroundColor: 'transparent',
            paddingTop: insets.top + 18,
            paddingBottom: insets.bottom + 120,
          },
        ]}
        showsVerticalScrollIndicator={false}
      >
        <TitleBanner title="More" />

        <View style={styles.stack}>
          <Pressable onPress={() => router.push('/feedback' as any)} style={styles.cardWrap}>
            <ScrapbookCard innerStyle={styles.row}>
              <Text style={[styles.rowEyebrow, { color: colors.textSecondary }]}>
                Support
              </Text>
              <View style={styles.rowTop}>
                <View
                  style={[
                    styles.iconShell,
                    { backgroundColor: colors.paperAlt, borderColor: colors.border },
                  ]}
                >
                  <Ionicons
                    name="chatbubble-ellipses-outline"
                    size={18}
                    color={colors.textPrimary}
                  />
                </View>
                <Ionicons
                  name="chevron-forward"
                  size={18}
                  color={colors.textMuted}
                />
              </View>
              <Text style={[styles.rowText, { color: colors.textPrimary }]}>
                Feedback
              </Text>
              <Text style={[styles.rowSubtext, { color: colors.textSecondary }]}>
                Send product notes directly from the app.
              </Text>
            </ScrapbookCard>
          </Pressable>

          <Pressable style={styles.cardWrap} onPress={() => router.push('/legal')}>
            <ScrapbookCard innerStyle={styles.row}>
              <Text style={[styles.rowEyebrow, { color: colors.textSecondary }]}>
                Reference
              </Text>
              <View style={styles.rowTop}>
                <View
                  style={[
                    styles.iconShell,
                    { backgroundColor: colors.paperAlt, borderColor: colors.border },
                  ]}
                >
                  <Ionicons
                    name="document-text-outline"
                    size={18}
                    color={colors.textPrimary}
                  />
                </View>
                <Ionicons
                  name="chevron-forward"
                  size={18}
                  color={colors.textMuted}
                />
              </View>
              <Text style={[styles.rowText, { color: colors.textPrimary }]}>
                Legal
              </Text>
              <Text style={[styles.rowSubtext, { color: colors.textSecondary }]}>
                Privacy, advisories, and app disclaimers.
              </Text>
            </ScrapbookCard>
          </Pressable>
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
  container: {
    paddingHorizontal: 20,
  },
  stack: {
    gap: 24,
    marginTop: 16,
  },
  subheader: {
    display: 'none',
  },
  cardWrap: {
    marginHorizontal: 2,
  },
  row: {
    paddingHorizontal: 16,
    paddingVertical: 18,
    borderRadius: 20,
    minHeight: 128,
  },
  rowEyebrow: {
    fontSize: 10,
    fontWeight: '800',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginBottom: 12,
  },
  rowTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  iconShell: {
    width: 42,
    height: 42,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rowText: {
    fontSize: 22,
    fontWeight: '700',
  },
  rowSubtext: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 8,
  },
});
