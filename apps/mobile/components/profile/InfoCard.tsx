import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../hooks/useTheme';

type Props = {
  title: string;
  value: React.ReactNode;
  hideValuePadding?: boolean;
};

export default function InfoCard({ title, value, hideValuePadding }: Props) {
  const colors = useTheme();

  return (
    <View
      style={[
        styles.card,
        {
          backgroundColor: colors.card,
          borderColor: colors.border,
        },
      ]}
    >
      <Text style={[styles.title, { color: colors.textSecondary }]}>
        {title}
      </Text>

      {!!value && (
        <Text
          style={[
            styles.value,
            { color: colors.textPrimary },
            hideValuePadding && { marginTop: 0 },
          ]}
        >
          {value}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 28,
    paddingVertical: 24,
    paddingHorizontal: 22,
    marginBottom: 22,
    borderWidth: 1,
  },

  title: {
    fontSize: 15,
    fontWeight: '600',
    letterSpacing: 0.3,
  },

  value: {
    marginTop: 10,
    fontSize: 18,
    fontWeight: '600',
  },
});