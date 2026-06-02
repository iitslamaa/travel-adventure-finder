import { StyleSheet, Text, View } from 'react-native';

function scoreColors(score?: number) {
  if (typeof score !== 'number') {
    return {
      bg: 'rgba(0, 0, 0, 0.06)',
      border: 'rgba(0, 0, 0, 0.18)',
      text: '#6F6256',
    };
  }
  if (score >= 80) {
    return { bg: 'rgba(86, 131, 93, 0.14)', border: '#92AC91', text: '#436347' };
  }
  if (score >= 50) {
    return { bg: 'rgba(211, 177, 104, 0.18)', border: '#D2B17B', text: '#805B2F' };
  }
  return { bg: 'rgba(184, 112, 95, 0.16)', border: '#C79A90', text: '#7C4B43' };
}

type Props = {
  score?: number;
};

export default function MetricPill({ score }: Props) {
  const colors = scoreColors(score);
  const label = typeof score === 'number' ? Math.round(score).toString() : '—';

  return (
    <View
      style={[
        styles.pill,
        {
          backgroundColor: colors.bg,
          borderColor: colors.border,
        },
      ]}
    >
      <Text style={[styles.text, { color: colors.text }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    alignSelf: 'flex-start',
    minWidth: 54,
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 7,
    alignItems: 'center',
  },
  text: {
    fontSize: 22,
    fontWeight: '800',
  },
});
