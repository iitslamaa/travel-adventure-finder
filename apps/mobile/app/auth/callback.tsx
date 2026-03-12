import { useEffect } from 'react'
import { View, ActivityIndicator } from 'react-native'
import { useLocalSearchParams, useRouter } from 'expo-router'
import { supabase } from '../../lib/supabase'

export default function AuthCallback() {
  const { code } = useLocalSearchParams()
  const router = useRouter()

  useEffect(() => {
    const exchange = async () => {
      if (!code) return

      const { error } = await supabase.auth.exchangeCodeForSession(
        code as string
      )

      if (!error) {
        router.replace('/')
      } else {
        console.log('Exchange error:', error)
      }
    }

    exchange()
  }, [code])

  return (
    <View
      style={{
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
      }}
    >
      <ActivityIndicator size="large" />
    </View>
  )
}