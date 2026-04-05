import { ReactNode } from 'react';
import { ImageBackground, StyleSheet, View } from 'react-native';

type Props = {
  children: ReactNode;
  padded?: boolean;
  overlay?: number;
};

export default function ScrapbookBackground({
  children,
  padded = false,
  overlay = 0.12,
}: Props) {
  return (
    <ImageBackground
      source={require('../../assets/scrapbook/travel1.png')}
      style={styles.background}
      imageStyle={styles.image}
    >
      <View
        style={[
          styles.overlay,
          {
            backgroundColor: `rgba(33, 21, 13, ${overlay})`,
            paddingHorizontal: padded ? 18 : 0,
          },
        ]}
      >
        {children}
      </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
  },
  image: {
    resizeMode: 'cover',
  },
  overlay: {
    flex: 1,
  },
});
