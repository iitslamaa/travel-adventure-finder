export function getResizedAvatarUrl(
  avatarUrl: string | null
): string | null {
  if (!avatarUrl) return null;

  let publicUrl = avatarUrl;

  // If it's a storage path, convert to public URL
  if (!avatarUrl.startsWith('http')) {
    publicUrl = `${process.env.EXPO_PUBLIC_SUPABASE_URL}/storage/v1/object/public/${avatarUrl}`;
  }

  // No image transformation (Free plan safe)
  return publicUrl;
}