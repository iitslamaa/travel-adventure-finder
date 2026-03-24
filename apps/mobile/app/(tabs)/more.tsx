import { View, Text, Pressable, StyleSheet } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';

export default function MoreScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const colors = useTheme();

  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor: colors.background,
          paddingTop: insets.top + 18,
        },
      ]}
    >
      <Text style={[styles.header, { color: colors.textPrimary }]}>More</Text>
      <Text style={[styles.subheader, { color: colors.textSecondary }]}>
        Extra tools and housekeeping for the app.
      </Text>

      <Pressable
        style={[
          styles.row,
          { borderBottomColor: colors.border, backgroundColor: colors.card },
        ]}
        onPress={() => router.push('/feedback' as any)}
      >
        <View style={styles.rowLeft}>
          <Ionicons
            name="chatbubble-ellipses-outline"
            size={18}
            color={colors.textPrimary}
          />
          <View>
            <Text style={[styles.rowText, { color: colors.textPrimary }]}>
              Feedback
            </Text>
            <Text style={[styles.rowSubtext, { color: colors.textSecondary }]}>
              Send product notes directly from the app.
            </Text>
          </View>
        </View>
        <Ionicons
          name="chevron-forward"
          size={18}
          color={colors.textMuted}
        />
      </Pressable>

      <Pressable
        style={[
          styles.row,
          { borderBottomColor: colors.border, backgroundColor: colors.card },
        ]}
        onPress={() => router.push('/(tabs)/when-to-go')}
      >
        <View style={styles.rowLeft}>
          <Ionicons name="calendar-outline" size={18} color={colors.textPrimary} />
          <View>
            <Text style={[styles.rowText, { color: colors.textPrimary }]}>
              When to Go
            </Text>
            <Text style={[styles.rowSubtext, { color: colors.textSecondary }]}>
              Explore seasonality by month.
            </Text>
          </View>
        </View>
        <Ionicons
          name="chevron-forward"
          size={18}
          color={colors.textMuted}
        />
      </Pressable>

      <Pressable
        style={[
          styles.row,
          { borderBottomColor: colors.border, backgroundColor: colors.card },
        ]}
        onPress={() => router.push('/legal')}
      >
        <View style={styles.rowLeft}>
          <Ionicons
            name="document-text-outline"
            size={18}
            color={colors.textPrimary}
          />
          <View>
            <Text style={[styles.rowText, { color: colors.textPrimary }]}>
              Legal
            </Text>
            <Text style={[styles.rowSubtext, { color: colors.textSecondary }]}>
              Privacy, disclaimers, and account information.
            </Text>
          </View>
        </View>
        <Ionicons
          name="chevron-forward"
          size={18}
          color={colors.textMuted}
        />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 20,
  },
  header: {
    fontSize: 28,
    fontWeight: '800',
  },
  subheader: {
    fontSize: 15,
    lineHeight: 22,
    marginTop: 8,
    marginBottom: 24,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 18,
    borderWidth: 1,
    borderRadius: 20,
    borderBottomWidth: 1,
    marginBottom: 12,
  },
  rowLeft: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
    flex: 1,
  },
  rowText: {
    fontSize: 16,
    fontWeight: '700',
  },
  rowSubtext: {
    fontSize: 13,
    lineHeight: 18,
    marginTop: 2,
  },
});
