import { Redirect } from 'expo-router';

export default function ListsScreen() {
  return <Redirect href={'/planning' as any} />;
}
