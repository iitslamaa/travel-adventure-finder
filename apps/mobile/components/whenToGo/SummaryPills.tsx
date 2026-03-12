import React from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../../hooks/useTheme";

export default function SummaryPills({ peak, shoulder }: { peak: number; shoulder: number }) {
  const colors = useTheme();

  return (
    <View style={styles.container}>
      <View
        style={[
          styles.pill,
          { backgroundColor: colors.greenBg, borderColor: colors.greenBorder },
        ]}
      >
        <Text style={{ color: colors.greenText, fontWeight: '600' }}>
          Peak: {peak}
        </Text>
      </View>

      <View
        style={[
          styles.pill,
          { backgroundColor: colors.yellowBg, borderColor: colors.yellowBorder },
        ]}
      >
        <Text style={{ color: colors.yellowText, fontWeight: '600' }}>
          Shoulder: {shoulder}
        </Text>
      </View>

      <View
        style={[
          styles.pill,
          { backgroundColor: colors.card, borderColor: colors.border },
        ]}
      >
        <Text style={{ color: colors.textPrimary, fontWeight: '600' }}>
          Total: {peak + shoulder}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: "flex-end",
    marginVertical: 12,
  },
  pill: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 999,
    marginVertical: 4,
    borderWidth: 1,
  },
});