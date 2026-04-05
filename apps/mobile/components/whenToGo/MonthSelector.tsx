import React, { useEffect, useRef } from "react";
import { ScrollView, Pressable, Text, StyleSheet, View } from "react-native";
import { useTheme } from "../../hooks/useTheme";

const months = [
  "JAN","FEB","MAR","APR","MAY","JUN",
  "JUL","AUG","SEP","OCT","NOV","DEC"
];

type Props = {
  selected: number;
  onSelect: (month: number) => void;
};

export default function MonthSelector({ selected, onSelect }: Props) {
  const colors = useTheme();
  const scrollRef = useRef<ScrollView>(null);

  useEffect(() => {
    const x = Math.max(0, (selected - 1) * 72 - 120);
    scrollRef.current?.scrollTo({ x, animated: true });
  }, [selected]);

  return (
    <ScrollView
      ref={scrollRef}
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.scrollContent}
    >
      <View style={styles.row}>
        {months.map((m, i) => {
          const monthNumber = i + 1;
          const isSelected = monthNumber === selected;
          return (
            <Pressable
              key={m}
              style={[
                styles.pill,
                {
                  backgroundColor: isSelected
                    ? "rgba(255,255,255,0.55)"
                    : "transparent",
                  borderColor: isSelected
                    ? "rgba(255,255,255,0.34)"
                    : "transparent",
                },
              ]}
              onPress={() => onSelect(monthNumber)}
            >
              <Text
                style={[
                  styles.text,
                  {
                    color: isSelected
                      ? colors.textPrimary
                      : colors.textPrimary,
                  },
                ]}
              >
                {m}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scrollContent: {
    paddingHorizontal: 56,
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
  },
  pill: {
    minWidth: 52,
    height: 42,
    paddingHorizontal: 14,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
    marginRight: 16,
    borderWidth: 1,
  },
  text: {
    fontSize: 17,
    fontWeight: "700",
    letterSpacing: 0.2,
  },
});
