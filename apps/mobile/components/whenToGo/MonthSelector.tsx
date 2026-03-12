import React from "react";
import { ScrollView, TouchableOpacity, Text, StyleSheet, View } from "react-native";
import { useTheme } from "../../hooks/useTheme";

const months = [
  "JAN","FEB","MAR","APR","MAY","JUN",
  "JUL","AUG","SEP","OCT","NOV","DEC"
];

type Props = {
  selected: number;
  onSelect: (index: number) => void;
};

export default function MonthSelector({ selected, onSelect }: Props) {
  const colors = useTheme();
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false}>
      <View style={styles.row}>
        {months.map((m, i) => {
          const isSelected = i === selected;
          return (
            <TouchableOpacity
              key={m}
              style={[
                styles.pill,
                {
                  backgroundColor: isSelected
                    ? colors.primary
                    : colors.segmentBg,
                  borderColor: colors.border,
                },
              ]}
              onPress={() => onSelect(i)}
            >
              <Text
                style={[
                  styles.text,
                  {
                    color: isSelected
                      ? colors.primaryText
                      : colors.textPrimary,
                  },
                ]}
              >
                {m}
              </Text>
              <Text
                style={[
                  styles.sub,
                  {
                    color: isSelected
                      ? colors.primaryText
                      : colors.textSecondary,
                  },
                ]}
              >
                {String(i+1).padStart(2,"0")}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
  },
  pill: {
    width: 60,
    height: 60,
    borderRadius: 30,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 8,
  },
  text: {
    fontWeight: "600",
  },
  sub: {
    fontSize: 12,
  },
});