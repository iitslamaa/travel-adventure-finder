import React, { useState } from "react";
import { View, Text, StyleSheet } from "react-native";
import { useTheme } from "../../hooks/useTheme";
import CountryChip from "./CountryChip";
import CountryDetailPreviewDrawer from "./CountryDetailPreviewDrawer";
import { WhenToGoItem } from "../../utils/whenToGoLogic";

export default function SeasonSection({
  title,
  description,
  countries,
  selectedMonth,
}: {
  title: string;
  description: string;
  countries: WhenToGoItem[];
  selectedMonth: number;
}) {
  const colors = useTheme();
  const [selectedCountry, setSelectedCountry] = useState<WhenToGoItem | null>(null);
  const [drawerVisible, setDrawerVisible] = useState(false);

  const handleOpen = (item: WhenToGoItem) => {
    setSelectedCountry(item);
    setDrawerVisible(true);
  };

  const handleClose = () => {
    setDrawerVisible(false);
    setSelectedCountry(null);
  };

  return (
    <View
      style={[
        styles.container,
        {
          borderBottomColor: colors.border,
        },
      ]}
    >
      <Text style={[styles.title, { color: colors.textPrimary }]}>{title}</Text>
      <Text style={[styles.description, { color: colors.textSecondary }]}>
        {description}
      </Text>

      {countries.length ? (
        <View style={styles.chips}>
          {countries.map((c) => (
            <CountryChip
              key={c.id}
              item={c}
              onPress={() => handleOpen(c)}
            />
          ))}
        </View>
      ) : (
        <Text style={[styles.empty, { color: colors.textMuted }]}>
          No destinations are surfacing in this bucket for the selected month yet.
        </Text>
      )}

      <CountryDetailPreviewDrawer
        visible={drawerVisible}
        onClose={handleClose}
        country={selectedCountry}
        selectedMonth={selectedMonth}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingVertical: 16,
    borderBottomWidth: 1,
  },
  title: {
    fontSize: 15,
    fontWeight: "700",
  },
  description: {
    marginTop: 6,
    marginBottom: 10,
    fontSize: 12,
    lineHeight: 17,
  },
  chips: {
    flexDirection: "row",
    flexWrap: "wrap",
    justifyContent: "space-between",
    rowGap: 2,
  },
  empty: {
    fontSize: 13,
    lineHeight: 18,
  },
});
