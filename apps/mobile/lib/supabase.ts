import 'react-native-url-polyfill/auto';
import 'react-native-get-random-values';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import * as Crypto from 'expo-crypto';

import Constants from 'expo-constants';

const extra = Constants.expoConfig?.extra ?? {};

const SUPABASE_URL = extra.supabaseUrl;
const SUPABASE_ANON_KEY = extra.supabaseAnonKey;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('Supabase config missing:', extra);
  throw new Error('Supabase config missing');
}

// Ensure WebCrypto subtle.digest exists for PKCE (S256)
if (!global.crypto) {
  // @ts-ignore
  global.crypto = {};
}

if (!global.crypto.getRandomValues) {
  require('react-native-get-random-values');
}

if (!global.crypto.subtle) {
  // @ts-ignore
  global.crypto.subtle = {
    async digest(algorithm: string, data: ArrayBuffer) {
      if (algorithm !== 'SHA-256') {
        throw new Error('Only SHA-256 supported');
      }

      const bytes = new Uint8Array(data);

      const str = Array.from(bytes)
        .map(b => String.fromCharCode(b))
        .join('');

      const hashBase64 = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        str,
        { encoding: Crypto.CryptoEncoding.BASE64 }
      );

      const binary = global.atob(hashBase64);
      const buffer = new Uint8Array(binary.length);

      for (let i = 0; i < binary.length; i++) {
        buffer[i] = binary.charCodeAt(i);
      }

      return buffer.buffer;
    },
  };
}

export const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  {
    auth: {
      storage: AsyncStorage,
      storageKey: 'travelaf-auth',
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
      flowType: 'pkce',
    },
  }
);