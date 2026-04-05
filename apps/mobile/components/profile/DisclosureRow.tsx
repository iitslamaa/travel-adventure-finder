import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import ScrapbookCard from '../theme/ScrapbookCard';

type Props = {
  label: string;
  value: string;
  onPress?: () => void;
};

export default function DisclosureRow({ label, value, onPress }: Props) {
  const colors = useTheme();

  return (
    <TouchableOpacity onPress={onPress} activeOpacity={0.82}>
      <ScrapbookCard innerStyle={styles.row}>
        <View style={styles.left}>
          <Text style={[styles.label, { color: colors.textSecondary }]}>
            {label}
          </Text>

          {!!value && (
            <Text style={[styles.value, { color: colors.textPrimary }]}>
              {value}
            </Text>
          )}
        </View>

        <Ionicons
          name="chevron-forward"
          size={20}
          color={colors.textMuted}
        />
      </ScrapbookCard>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  row: {
    paddingVertical: 20,
    paddingHorizontal: 20,
    marginBottom: 18,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },

  left: {
    flex: 1,
  },

  label: {
    fontSize: 14,
    fontWeight: '600',
    letterSpacing: 0.3,
  },

  value: {
    marginTop: 6,
    fontSize: 18,
    fontWeight: '700',
  },
});
