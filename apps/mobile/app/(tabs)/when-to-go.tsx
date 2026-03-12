import React, { useState, useMemo } from "react";
import { ScrollView, View, Text, StyleSheet, ActivityIndicator } from "react-native";
import { useTheme } from "../../hooks/useTheme";
import MonthSelector from "../../components/whenToGo/MonthSelector";
import SummaryPills from "../../components/whenToGo/SummaryPills";
import SeasonSection from "../../components/whenToGo/SeasonSection";
import { useCountries } from "../../hooks/useCountries";
import { getWhenToGoBuckets } from "../../utils/whenToGoLogic";

export default function WhenToGoScreen() {
  const [selectedMonth, setSelectedMonth] = useState(1); // 0 = Jan

  const { countries, loading } = useCountries();

  const colors = useTheme();

  const { peak, shoulder } = useMemo(() => {
    return getWhenToGoBuckets(countries, selectedMonth);
  }, [countries, selectedMonth]);

  const monthLabels = [
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
  ];

  if (loading) {
    return (
      <View style={[styles.container, styles.center]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    );
  }

  return (
    <ScrollView style={[styles.container, { backgroundColor: colors.background }]}>
      <Text style={[styles.header, { color: colors.textPrimary }]}>When to Go</Text>
      <Text style={[styles.subtitle, { color: colors.textSecondary }]}>
        Select a month to explore where it’s peak or shoulder season.
      </Text>

      <MonthSelector
        selected={selectedMonth}
        onSelect={setSelectedMonth}
      />

      <View style={styles.summaryRow}>
        <View>
          <Text style={[styles.muted, { color: colors.textSecondary }]}>Selected month</Text>
          <Text style={[styles.month, { color: colors.textPrimary }]}>
            {monthLabels[selectedMonth]}
          </Text>
        </View>

        <SummaryPills
          peak={peak.length}
          shoulder={shoulder.length}
        />
      </View>

      <SeasonSection
        title="Peak season"
        description="Best weather and overall conditions — usually the busiest and priciest."
        countries={peak}
        selectedMonth={selectedMonth}
      />

      <SeasonSection
        title="Shoulder season"
        description="Still good conditions, often fewer crowds and better value."
        countries={shoulder}
        selectedMonth={selectedMonth}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
  },
  center: {
    justifyContent: "center",
    alignItems: "center",
  },
  header: {
    fontSize: 28,
    fontWeight: "800",
  },
  subtitle: {
    marginVertical: 8,
  },
  summaryRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    marginTop: 12,
    marginBottom: 8,
  },
  muted: {
    marginBottom: 4,
  },
  month: {
    fontSize: 18,
    fontWeight: "700",
  },
});