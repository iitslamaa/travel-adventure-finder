import React from "react";
import { Text, StyleSheet, TouchableOpacity } from "react-native";
import { useTheme } from "../../hooks/useTheme";
import { getScoreColor } from "../../utils/seasonColor";

type Props = {
  item: {
    country: {
      name: string;
      facts?: {
        scoreTotal?: number;
      };
      scoreTotal?: number;
    };
  };
  onPress?: () => void;
};

export default function CountryChip({ item, onPress }: Props) {
  const theme = useTheme();
  const score = item.country.facts?.scoreTotal ?? item.country.scoreTotal ?? 0;
  const scoreColors = getScoreColor(score);

  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.8}
      style={[
        styles.container,
        {
          backgroundColor: scoreColors.background,
          borderColor: scoreColors.border ?? theme.border,
        },
      ]}
    >
      <Text
        numberOfLines={3}
        style={[styles.name, { color: theme.textPrimary }]}
      >
        {item.country.name}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    minHeight: 62,
    width: "31%",
    paddingHorizontal: 12,
    paddingVertical: 14,
    borderRadius: 14,
    justifyContent: "flex-start",
    alignItems: "flex-start",
    marginBottom: 10,
    borderWidth: 1,
  },
  name: {
    fontWeight: "600",
    fontSize: 12,
    lineHeight: 16,
    textAlign: "left",
  },
});
