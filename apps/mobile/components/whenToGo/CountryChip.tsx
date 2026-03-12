import React from "react";
import { View, Text, StyleSheet, TouchableOpacity } from "react-native";
import { useTheme } from "../../hooks/useTheme";
import { getScoreColor } from "../../utils/seasonColor";

type Props = {
  name: string;
  region: string;
  score: number;
  iso2: string;
  onPress?: () => void;
};

export default function CountryChip({ name, region, score, onPress }: Props) {
  const theme = useTheme();
  const scoreColors = getScoreColor(score);

  const isDarkSurface = theme.background !== '#F5F5F7';

  const backgroundColor = isDarkSurface
    ? theme.surface
    : scoreColors.background;

  const borderColor = isDarkSurface
    ? scoreColors.text
    : theme.border;

  const nameColor = isDarkSurface
    ? theme.textPrimary
    : theme.textPrimary;

  const regionColor = isDarkSurface
    ? theme.textSecondary
    : theme.textSecondary;

  const scoreColor = scoreColors.text;

  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.8}
      style={[
        styles.container,
        {
          backgroundColor,
          borderColor,
        },
      ]}
    >
      <Text style={[styles.name, { color: nameColor }]}> 
        {name}
      </Text>
      <Text style={[styles.region, { color: regionColor }]}> 
        {region}
      </Text>
      <Text style={[styles.score, { color: scoreColor }]}> 
        {score}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 999,
    margin: 2,
    borderWidth: 1,
  },
  name: {
    fontWeight: "600",
    marginRight: 6,
  },
  region: {
    marginRight: 6,
    fontSize: 12,
  },
  score: {
    fontWeight: "700",
  },
});