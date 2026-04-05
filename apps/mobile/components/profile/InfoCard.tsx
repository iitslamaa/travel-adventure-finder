import React from 'react';
import { View, Text, StyleSheet, ImageBackground } from 'react-native';
import ScrapbookCard from '../theme/ScrapbookCard';
import { useTheme } from '../../hooks/useTheme';

type Props = {
  title: string;
  value: React.ReactNode;
  hideValuePadding?: boolean;
};

export default function InfoCard({ title, value, hideValuePadding }: Props) {
  const colors = useTheme();
  const valueIsElement = React.isValidElement(value);

  return (
    <ScrapbookCard innerStyle={styles.card}>
      <ImageBackground
        source={require('../../assets/scrapbook/profile-header.png')}
        style={styles.background}
        imageStyle={styles.backgroundImage}
      >
        <View style={[styles.wash, { backgroundColor: `${colors.paper}CC` }]}>
          <Text style={[styles.title, { color: colors.textSecondary }]}>
            {title}
          </Text>

          {!!value && (
            valueIsElement ? (
              <View style={[styles.valueWrap, hideValuePadding && { marginTop: 0 }]}>
                {value}
              </View>
            ) : (
              <Text
                style={[
                  styles.value,
                  { color: colors.textPrimary },
                  hideValuePadding && { marginTop: 0 },
                ]}
              >
                {value}
              </Text>
            )
          )}
        </View>
      </ImageBackground>
    </ScrapbookCard>
  );
}

const styles = StyleSheet.create({
  card: {
    paddingVertical: 0,
    paddingHorizontal: 0,
    marginBottom: 22,
    overflow: 'hidden',
  },
  background: {
    width: '100%',
  },
  backgroundImage: {
    resizeMode: 'cover',
  },
  wash: {
    paddingVertical: 24,
    paddingHorizontal: 22,
  },
  title: {
    fontSize: 15,
    fontWeight: '600',
    letterSpacing: 0.3,
  },

  value: {
    marginTop: 10,
    fontSize: 18,
    fontWeight: '600',
  },
  valueWrap: {
    marginTop: 10,
  },
});
