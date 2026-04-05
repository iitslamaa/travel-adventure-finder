import { ReactNode } from 'react';
import { StyleProp, StyleSheet, View, ViewStyle } from 'react-native';
import { useTheme } from '../../hooks/useTheme';

type Props = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
  innerStyle?: StyleProp<ViewStyle>;
};

export default function ScrapbookCard({ children, style, innerStyle }: Props) {
  const colors = useTheme();

  return (
    <View style={[styles.stack, style]}>
      <View
        style={[
          styles.backLayerA,
          { backgroundColor: colors.paperAlt, borderColor: colors.border },
        ]}
      />
      <View
        style={[
          styles.backLayerB,
          { backgroundColor: colors.paper, borderColor: colors.border },
        ]}
      />
      <View
        style={[
          styles.frontCard,
          {
            backgroundColor: colors.card,
            borderColor: colors.cardBorderStrong,
            shadowColor: colors.shadow,
          },
          innerStyle,
        ]}
      >
        {children}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  stack: {
    position: 'relative',
  },
  backLayerA: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: 26,
    borderWidth: 1,
    transform: [{ rotate: '-1.4deg' }, { translateX: 6 }, { translateY: -5 }],
  },
  backLayerB: {
    ...StyleSheet.absoluteFillObject,
    borderRadius: 26,
    borderWidth: 1,
    transform: [{ rotate: '0.9deg' }, { translateX: -4 }, { translateY: 5 }],
  },
  frontCard: {
    borderRadius: 24,
    borderWidth: 1,
    shadowOpacity: 0.16,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 5,
  },
});
