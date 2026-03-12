import { useColorScheme } from 'react-native'
import { lightColors, darkColors } from '../theme/colors'

export function useTheme() {
  const scheme = useColorScheme()
  return scheme === 'dark' ? darkColors : lightColors
}