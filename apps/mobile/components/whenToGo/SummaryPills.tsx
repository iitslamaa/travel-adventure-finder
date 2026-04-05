import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../../hooks/useTheme";

export default function SummaryPills({
  peak,
  good,
  shoulder,
  rough,
}: {
  peak: number;
  good: number;
  shoulder: number;
  rough: number;
}) {
  const colors = useTheme();

  return (
    <View style={styles.container}>
      <Pill label="Peak" value={peak} backgroundColor={colors.greenBg} borderColor={colors.greenBorder} textColor={colors.greenText} />
      <Pill label="Good" value={good} backgroundColor={colors.greenBg} borderColor={colors.greenBorder} textColor={colors.greenText} />
      <Pill label="Shoulder" value={shoulder} backgroundColor={colors.yellowBg} borderColor={colors.yellowBorder} textColor={colors.yellowText} />
      <Pill label="Rough" value={rough} backgroundColor={colors.redBg} borderColor={colors.redBorder} textColor={colors.redText} />
      <Pill label="Total" value={peak + good + shoulder + rough} backgroundColor={colors.card} borderColor={colors.border} textColor={colors.textPrimary} />
    </View>
  );
}

function Pill({
  label,
  value,
  backgroundColor,
  borderColor,
  textColor,
}: {
  label: string;
  value: number;
  backgroundColor: string;
  borderColor: string;
  textColor: string;
}) {
  return (
    <View style={[styles.pill, { backgroundColor, borderColor }]}>
      <Text style={[styles.label, { color: textColor }]}>{label}</Text>
      <Text style={[styles.value, { color: textColor }]}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "flex-end",
    gap: 8,
  },
  pill: {
    minWidth: 76,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: "center",
  },
  label: {
    fontSize: 11,
    fontWeight: "700",
    textTransform: "uppercase",
    letterSpacing: 0.3,
  },
  value: {
    marginTop: 2,
    fontSize: 14,
    fontWeight: "700",
  },
});
