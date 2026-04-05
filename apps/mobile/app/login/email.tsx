import { Redirect, useLocalSearchParams } from 'expo-router';

export default function LoginEmailRedirect() {
  const params = useLocalSearchParams<{ email?: string }>();

  return (
    <Redirect
      href={{
        pathname: '/login',
        params: {
          step: 'email',
          ...(typeof params.email === 'string' && params.email.length
            ? { email: params.email }
            : {}),
        },
      }}
    />
  );
}
