import React, { useMemo } from "react";
import { ScrollView, View, Text, StyleSheet, ActivityIndicator, ImageBackground } from "react-native";
import { useTheme } from "../../hooks/useTheme";
import MonthSelector from "../../components/whenToGo/MonthSelector";
import SeasonSection from "../../components/whenToGo/SeasonSection";
import { useCountries } from "../../hooks/useCountries";
import { getWhenToGoBuckets } from "../../utils/whenToGoLogic";
import { useScorePreferences } from "../../context/ScorePreferencesContext";
import TitleBanner from "../../components/theme/TitleBanner";
import ScrapbookCard from "../../components/theme/ScrapbookCard";

export default function WhenToGoScreen() {
  const { countries, loading } = useCountries();
  const { selectedMonth, setSelectedMonth } = useScorePreferences();

  const colors = useTheme();

  const { peak, good, shoulder, rough } = useMemo(() => {
    return getWhenToGoBuckets(countries, selectedMonth);
  }, [countries, selectedMonth]);

  if (loading) {
    return (
      <ImageBackground
        source={require('../../assets/scrapbook/whentogo.png')}
        style={styles.background}
        imageStyle={styles.backgroundImage}
      >
        <View style={styles.loadingShell}>
          <TitleBanner title="When to Go" />
          <ImageBackground
            source={require('../../assets/scrapbook/title-background.png')}
            style={styles.monthShell}
            imageStyle={styles.monthShellImage}
          >
            <MonthSelector
              selected={selectedMonth}
              onSelect={setSelectedMonth}
            />
          </ImageBackground>
          <ScrapbookCard innerStyle={styles.loadingCard}>
            <ActivityIndicator size="large" color={colors.primary} />
            <Text style={[styles.loadingText, { color: colors.textSecondary }]}>
              Loading monthly seasonality...
            </Text>
          </ScrapbookCard>
        </View>
      </ImageBackground>
    );
  }

  const sections = [
    {
      title: "Peak season",
      description: "Best weather and overall conditions. Expect the busiest stretch, higher prices, and the strongest all-around travel scores.",
      countries: peak,
    },
    {
      title: "Good season",
      description: "Strong month to go with reliable conditions, but usually a little less perfect than the absolute best window.",
      countries: good,
    },
    {
      title: "Shoulder season",
      description: "A balanced middle ground. You may trade some ideal weather for lighter crowds, lower prices, or a more flexible trip.",
      countries: shoulder,
    },
    {
      title: "Rough season",
      description: "This month is usually harder for travel here. Weather, crowds, closures, or value may all work against the trip.",
      countries: rough,
    },
  ].filter((section) => section.countries.length > 0);

  return (
    <ImageBackground
      source={require('../../assets/scrapbook/whentogo.png')}
      style={styles.background}
      imageStyle={styles.backgroundImage}
    >
      <View style={styles.screen}>
        <TitleBanner title="When to Go" />

        <ImageBackground
          source={require('../../assets/scrapbook/title-background.png')}
          style={styles.monthShell}
          imageStyle={styles.monthShellImage}
        >
          <MonthSelector
            selected={selectedMonth}
            onSelect={setSelectedMonth}
          />
        </ImageBackground>

        <View style={styles.contentPanel}>
          <ScrollView
            style={styles.container}
            contentContainerStyle={styles.content}
            showsVerticalScrollIndicator={false}
          >
            {sections.map((section) => (
              <SeasonSection
                key={section.title}
                title={section.title}
                description={section.description}
                countries={section.countries}
                selectedMonth={selectedMonth}
              />
            ))}
          </ScrollView>
        </View>
      </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
  },
  backgroundImage: {
    resizeMode: "cover",
  },
  screen: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 12,
  },
  container: {
    flex: 1,
    backgroundColor: "transparent",
  },
  content: {
    paddingVertical: 8,
    paddingBottom: 110,
  },
  loadingShell: {
    flex: 1,
    paddingTop: 8,
    paddingHorizontal: 20,
  },
  loadingCard: {
    alignItems: "center",
    justifyContent: "center",
    minHeight: 240,
    paddingHorizontal: 24,
    paddingVertical: 28,
  },
  loadingText: {
    marginTop: 14,
    fontSize: 15,
    textAlign: "center",
  },
  monthShell: {
    height: 90,
    justifyContent: "center",
    marginBottom: 8,
    overflow: "hidden",
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "rgba(0,0,0,0.04)",
  },
  monthShellImage: {
    resizeMode: "cover",
    borderRadius: 20,
  },
  contentPanel: {
    flex: 1,
    borderRadius: 24,
    backgroundColor: "rgba(242, 235, 222, 0.82)",
    borderWidth: 1,
    borderColor: "rgba(0,0,0,0.06)",
    shadowColor: "#000000",
    shadowOpacity: 0.12,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 8 },
    elevation: 8,
    overflow: "hidden",
  },
});
