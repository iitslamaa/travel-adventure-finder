import { Redirect, useLocalSearchParams } from 'expo-router';

export default function VerifyRedirect() {
  const params = useLocalSearchParams<{ email?: string }>();

  return (
    <Redirect
      href={{
        pathname: '/login',
        params: {
          step: 'verify',
          ...(typeof params.email === 'string' && params.email.length
            ? { email: params.email }
            : {}),
        },
      }}
    />
  );
}
