import { Linking } from 'react-native';

export function normalizeExternalUrl(url?: string | null) {
  const trimmed = url?.trim();
  if (!trimmed) return undefined;

  try {
    const parsed = new URL(trimmed);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:'
      ? parsed.toString()
      : undefined;
  } catch {
    return undefined;
  }
}

export async function openExternalUrl(url: string) {
  const normalizedUrl = normalizeExternalUrl(url);
  if (!normalizedUrl) return;

  try {
    await Linking.openURL(normalizedUrl);
  } catch (error) {
    console.warn('[external-links] failed to open URL', normalizedUrl, error);
  }
}
