import { ImageBackground, StyleSheet, Text, View } from 'react-native';
import { useTheme } from '../../hooks/useTheme';

type Props = {
  title: string;
};

export default function TitleBanner({ title }: Props) {
  const colors = useTheme();

  return (
    <View style={styles.wrap}>
      <ImageBackground
        source={require('../../assets/scrapbook/title-background.png')}
        style={styles.banner}
        imageStyle={styles.image}
      >
        <Text style={[styles.title, { color: colors.textPrimary }]}>
          {title}
        </Text>
      </ImageBackground>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    width: '100%',
    paddingHorizontal: 20,
    marginTop: 4,
    marginBottom: 6,
  },
  banner: {
    height: 110,
    alignItems: 'center',
    justifyContent: 'center',
  },
  image: {
    resizeMode: 'contain',
  },
  title: {
    width: '72%',
    textAlign: 'center',
    fontSize: 34,
    fontWeight: '600',
    lineHeight: 38,
    letterSpacing: 0,
  },
});
