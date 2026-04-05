import React from "react";
import { View, Text, StyleSheet } from "react-native";

function getScoreColors(score: number) {
  if (score >= 80) {
    return { bg: "rgba(86, 131, 93, 0.14)", border: "#92AC91", text: "#436347" };
  }
  if (score >= 50) {
    return { bg: "rgba(211, 177, 104, 0.18)", border: "#D2B17B", text: "#805B2F" };
  }
  return { bg: "rgba(184, 112, 95, 0.16)", border: "#C79A90", text: "#7C4B43" };
}

type Props = {
  score: number;
  size?: "sm" | "md" | "lg";
};

export default function ScorePill({ score, size = "md" }: Props) {
  const colors = getScoreColors(score);

  const sizeStyles =
    size === "sm"
      ? { width: 44, height: 44 }
      : size === "lg"
      ? { width: 64, height: 64 }
      : { width: 54, height: 54 };

  return (
    <View
      style={[
        styles.pill,
        sizeStyles,
        {
          backgroundColor: colors.bg,
          borderColor: colors.border,
        },
      ]}
    >
      <Text style={[styles.text, { color: colors.text }]}>{score}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    borderWidth: 2,
    borderRadius: 999,
    alignItems: "center",
    justifyContent: "center",
  },
  text: {
    fontWeight: "800",
    fontSize: 18,
  },
});
