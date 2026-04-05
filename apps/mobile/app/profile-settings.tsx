import { useEffect, useState } from 'react';
import {
  ScrollView,
  View,
  Text,
  StyleSheet,
  Pressable,
  Alert,
  Modal,
  TextInput,
  Image,
  ActivityIndicator,
  ImageBackground,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { useCountries } from '../hooks/useCountries';
import { useTheme } from '../hooks/useTheme';
import { formatLanguageList, normalizeLanguageDraft } from '../utils/language';

import * as ImagePicker from 'expo-image-picker';
import * as ImageManipulator from 'expo-image-manipulator';
import ScrapbookBackground from '../components/theme/ScrapbookBackground';
import ScrapbookCard from '../components/theme/ScrapbookCard';
import TitleBanner from '../components/theme/TitleBanner';

type EditField = 'full_name' | 'username';
type SelectorKind =
  | 'mode'
  | 'style'
  | 'next'
  | 'current'
  | 'favorite'
  | 'languages'
  | 'lived'
  | 'passports';

const LANGUAGE_PROFICIENCY_OPTIONS = [
  { value: 'beginner', label: 'Beginner' },
  { value: 'conversational', label: 'Conversational' },
  { value: 'fluent', label: 'Fluent' },
] as const;

function flagFor(code: string) {
  const normalized = code.trim().toUpperCase();
  if (normalized.length !== 2) return normalized;
  return normalized.replace(/./g, char =>
    String.fromCodePoint(127397 + char.charCodeAt(0))
  );
}

function normalizeProficiency(value: unknown) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (normalized === 'fluent' || normalized === 'native' || normalized === 'advanced') {
    return 'fluent';
  }
  if (normalized === 'conversational' || normalized === 'intermediate') {
    return 'conversational';
  }
  return 'beginner';
}

function proficiencyLabel(value: unknown) {
  return (
    LANGUAGE_PROFICIENCY_OPTIONS.find(option => option.value === normalizeProficiency(value))?.label ??
    'Beginner'
  );
}

function joinFlagPreview(codes: string[], max = 4) {
  if (!codes.length) return '—';
  const preview = codes.slice(0, max).map(flagFor).join(' ');
  return codes.length > max ? `${preview} +${codes.length - max}` : preview;
}

export default function ProfileSettingsScreen() {
  const router = useRouter();
  const { profile, signOut, updateProfile } = useAuth();

  /* ---------------- Logout ---------------- */

  const handleLogout = async () => {
    try {
      await signOut();
      // Let AuthGate redirect to landing (/)
    } catch {
      Alert.alert('Logout failed', 'Please try again.');
    }
  };

  /* ---------------- Delete Account ---------------- */

  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const handleDeleteAccount = async () => {
    try {
      setDeleting(true);

      const { error } = await supabase.functions.invoke('delete-account', {
        body: {},
      });

      if (error) throw error;

      await signOut();
      await supabase.auth.signOut();
      // Let AuthGate redirect to landing (/)
    } catch (e: any) {
      Alert.alert('Delete failed', e?.message ?? 'Please try again.');
    } finally {
      setDeleting(false);
      setDeleteOpen(false);
    }
  };

  const colors = useTheme();
  const borderColor = colors.border;

  const [saveState, setSaveState] = useState<'idle' | 'saving' | 'saved'>('idle');
  const [isUploadingAvatar, setIsUploadingAvatar] = useState(false);
  const [avatarMenuOpen, setAvatarMenuOpen] = useState(false);

  /* ---------------- Avatar ---------------- */

  const pickAvatar = async () => {
    try {
      const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permission.granted) {
        Alert.alert('Permission required', 'Please allow photo access.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        quality: 1,
      });

      if (result.canceled) return;

      setIsUploadingAvatar(true);

      const image = result.assets[0];

      const manipulated = await ImageManipulator.manipulateAsync(
        image.uri,
        [{ resize: { width: 512 } }],
        { compress: 0.7, format: ImageManipulator.SaveFormat.JPEG }
      );

      const response = await fetch(manipulated.uri);
      const blob = await response.blob();

      const fileName = `${profile?.id}-${Date.now()}.jpg`;

      const { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(fileName, blob, {
          contentType: 'image/jpeg',
          upsert: true,
        });

      if (uploadError) throw uploadError;

      const { data } = supabase.storage.from('avatars').getPublicUrl(fileName);

      await updateProfile({ avatar_url: data.publicUrl });
    } catch (e: any) {
      Alert.alert('Upload failed', e?.message ?? 'Please try again.');
    } finally {
      setIsUploadingAvatar(false);
      setAvatarMenuOpen(false);
    }
  };

  const deleteAvatar = async () => {
    try {
      if (!profile?.avatar_url) return;

      setIsUploadingAvatar(true);

      const fileName = profile.avatar_url.split('/').pop();
      if (fileName) {
        await supabase.storage.from('avatars').remove([fileName]);
      }

      await updateProfile({ avatar_url: null });
    } catch {
      Alert.alert('Error', 'Failed to remove profile photo.');
    } finally {
      setIsUploadingAvatar(false);
      setAvatarMenuOpen(false);
    }
  };

  /* ---------------- Draft State ---------------- */

  const [selectorOpen, setSelectorOpen] = useState<null | SelectorKind>(null);
  const [draftMode, setDraftMode] = useState<string | null>(null);
  const [draftStyle, setDraftStyle] = useState<string | null>(null);
  const [draftNextDestination, setDraftNextDestination] = useState<string | null>(null);
  const [draftCurrentCountry, setDraftCurrentCountry] = useState<string | null>(null);
  const [draftFavoriteCountries, setDraftFavoriteCountries] = useState<string[]>([]);
  const [draftLivedCountries, setDraftLivedCountries] = useState<string[]>([]);
  const [draftLanguages, setDraftLanguages] = useState<any[]>([]);
  const [draftFirstName, setDraftFirstName] = useState(profile?.first_name ?? '');
  const [draftLastName, setDraftLastName] = useState(profile?.last_name ?? '');
  const [draftUsername, setDraftUsername] = useState(profile?.username ?? '');
  const [draftPassportNationalities, setDraftPassportNationalities] = useState<string[]>([]);
  const [loadedPassportNationalities, setLoadedPassportNationalities] = useState<string[]>([]);
  const [draftLanguageInput, setDraftLanguageInput] = useState('');

  const { countries } = useCountries();

  /* ---------------- Normalize Array Fields ---------------- */

  const currentMode =
    Array.isArray(profile?.travel_mode) ? profile?.travel_mode?.[0] ?? null : null;

  const currentStyle =
    Array.isArray(profile?.travel_style) ? profile?.travel_style?.[0] ?? null : null;

  useEffect(() => {
    setDraftMode(currentMode);
    setDraftStyle(currentStyle);
    setDraftNextDestination(profile?.next_destination ?? null);
    setDraftCurrentCountry(profile?.current_country ?? null);
    setDraftFavoriteCountries(
      Array.isArray(profile?.favorite_countries)
        ? profile.favorite_countries.map((code: any) => String(code).toUpperCase()).filter(Boolean)
        : []
    );

    if (Array.isArray(profile?.languages)) {
      setDraftLanguages(profile.languages);
    } else {
      setDraftLanguages([]);
    }

    if (Array.isArray(profile?.lived_countries)) {
      setDraftLivedCountries(
        profile.lived_countries
          .map((c: any) =>
            typeof c === 'string'
              ? c.toUpperCase()
              : c?.iso2?.toUpperCase()
          )
        .filter(Boolean)
      );
    } else {
      setDraftLivedCountries([]);
    }
    setDraftFirstName(profile?.first_name ?? '');
    setDraftLastName(profile?.last_name ?? '');
    setDraftUsername(profile?.username ?? '');
  }, [profile]);

  useEffect(() => {
    const loadPassportPreferences = async () => {
      if (!profile?.id) {
        setDraftPassportNationalities([]);
        return;
      }

      const { data, error } = await supabase
        .from('user_passport_preferences')
        .select('nationality_country_codes')
        .eq('user_id', profile.id)
        .maybeSingle();

      if (error) {
        console.error('Failed to load passport preferences', error);
        return;
      }

      setDraftPassportNationalities(
        Array.isArray(data?.nationality_country_codes)
          ? data.nationality_country_codes.map((code: any) => String(code).toUpperCase()).filter(Boolean)
          : []
      );
      setLoadedPassportNationalities(
        Array.isArray(data?.nationality_country_codes)
          ? data.nationality_country_codes.map((code: any) => String(code).toUpperCase()).filter(Boolean)
          : []
      );
    };

    void loadPassportPreferences();
  }, [profile?.id]);

  /* ---------------- Change Detection ---------------- */

  const normalizedProfileLived = Array.isArray(profile?.lived_countries)
    ? profile.lived_countries
        .map((c: any) =>
          typeof c === 'string'
            ? c.toUpperCase()
            : c?.iso2?.toUpperCase()
        )
        .filter(Boolean)
    : [];

  const hasChanges =
    draftFirstName !== (profile?.first_name ?? '') ||
    draftLastName !== (profile?.last_name ?? '') ||
    draftUsername !== (profile?.username ?? '') ||
    draftMode !== currentMode ||
    draftStyle !== currentStyle ||
    draftNextDestination !== profile?.next_destination ||
    draftCurrentCountry !== (profile?.current_country ?? null) ||
    JSON.stringify((draftFavoriteCountries ?? []).slice().sort()) !== JSON.stringify(((profile?.favorite_countries ?? []) as string[]).slice().sort()) ||
    JSON.stringify((draftPassportNationalities ?? []).slice().sort()) !== JSON.stringify((loadedPassportNationalities ?? []).slice().sort()) ||
    JSON.stringify(draftLanguages ?? []) !== JSON.stringify(profile?.languages ?? []) ||
    JSON.stringify(draftLivedCountries ?? []) !== JSON.stringify(normalizedProfileLived);

  useEffect(() => {
    if (hasChanges && saveState === 'saved') {
      setSaveState('idle');
    }
  }, [hasChanges, saveState]);

  /* ---------------- Save ---------------- */

  const saveAll = async () => {
    if (!hasChanges) return;

    try {
      setSaveState('saving');

      const trimmedFirstName = draftFirstName.trim();
      const trimmedLastName = draftLastName.trim();
      const fullName = [trimmedFirstName, trimmedLastName].filter(Boolean).join(' ').trim();

      await updateProfile({
        full_name: fullName || null,
        first_name: trimmedFirstName || null,
        last_name: trimmedLastName || null,
        username: draftUsername.replace(/^@/, ''),
        travel_mode: draftMode ? [draftMode] : null,
        travel_style: draftStyle ? [draftStyle] : null,
        next_destination: draftNextDestination,
        current_country: draftCurrentCountry,
        favorite_countries: draftFavoriteCountries,
        languages: normalizeLanguageDraft(draftLanguages),
        lived_countries: draftLivedCountries,
      });

      if (profile?.id) {
        const { error: passportError } = await supabase
          .from('user_passport_preferences')
          .upsert({
            user_id: profile.id,
            nationality_country_codes: draftPassportNationalities,
            passport_country_code: draftPassportNationalities[0] ?? null,
          });

        if (passportError) {
          throw passportError;
        }

        setLoadedPassportNationalities(draftPassportNationalities);
      }

      setSaveState('saved');

      // reset back to idle after visible confirmation
      setTimeout(() => {
        setSaveState('idle');
      }, 900);

    } catch {
      Alert.alert('Save failed', 'Please try again.');
      setSaveState('idle');
    }
  };

  const cancelAll = () => {
    setDraftMode(currentMode);
    setDraftStyle(currentStyle);
    setDraftNextDestination(profile?.next_destination ?? null);
    setDraftCurrentCountry(profile?.current_country ?? null);
    setDraftFavoriteCountries(
      Array.isArray(profile?.favorite_countries)
        ? profile.favorite_countries.map((code: any) => String(code).toUpperCase()).filter(Boolean)
        : []
    );
    setDraftLanguages(profile?.languages ?? []);
    setDraftLivedCountries(normalizedProfileLived);
    setDraftFirstName(profile?.first_name ?? '');
    setDraftLastName(profile?.last_name ?? '');
    setDraftPassportNationalities(loadedPassportNationalities);
    router.back();
  };


  /* ---------------- Labels ---------------- */

  const modeLabel =
    draftMode === 'solo'
      ? 'Solo'
      : draftMode === 'group'
      ? 'Group'
      : draftMode === 'both'
      ? 'Solo + Group'
      : '—';

  const styleLabel =
    draftStyle === 'budget'
      ? 'Budget'
      : draftStyle === 'comfortable'
      ? 'Comfortable'
      : draftStyle === 'luxury'
      ? 'Luxury'
      : '—';

  const localizedCountryName = (code?: string | null) =>
    code ? countries.find(c => c.iso2 === code)?.name ?? code : null;

  const currentCountryLabel =
    draftCurrentCountry
      ? `${flagFor(draftCurrentCountry)} ${localizedCountryName(draftCurrentCountry)}`
      : '—';

  const nextDestinationLabel =
    draftNextDestination
      ? `${flagFor(draftNextDestination)} ${localizedCountryName(draftNextDestination)}`
      : '—';

  const favoriteCountriesLabel = joinFlagPreview(draftFavoriteCountries);

  const passportsLabel = joinFlagPreview(draftPassportNationalities);

  const livedCountriesLabel = joinFlagPreview(draftLivedCountries);
  const languageCountLabel = draftLanguages.length ? `${draftLanguages.length} saved` : 'None';
  const defaultPassportLabel = draftPassportNationalities[0]
    ? `${flagFor(draftPassportNationalities[0])} ${localizedCountryName(draftPassportNationalities[0])}`
    : 'Not set';

  const selectorTitle =
    selectorOpen === 'mode'
      ? 'Travel mode'
      : selectorOpen === 'style'
        ? 'Travel style'
        : selectorOpen === 'next'
          ? 'Next destination'
          : selectorOpen === 'current'
            ? 'Current country'
            : selectorOpen === 'favorite'
              ? 'Favorite countries'
              : selectorOpen === 'languages'
                ? 'Languages'
                : selectorOpen === 'passports'
                  ? 'Passports'
                  : selectorOpen === 'lived'
                    ? 'My flags'
                    : '';

  const selectorEyebrow =
    selectorOpen === 'mode' || selectorOpen === 'style'
      ? 'Travel preferences'
      : selectorOpen === 'languages'
        ? 'Communication'
        : selectorOpen === 'passports'
          ? 'Border context'
          : 'Background';

  const selectorHelper =
    selectorOpen === 'mode'
      ? 'Choose how you usually travel so discovery and planning feel more personal.'
      : selectorOpen === 'style'
        ? 'Pick the comfort level that best matches the trips you usually plan.'
        : selectorOpen === 'next'
          ? 'Select the destination you are most excited to plan next.'
          : selectorOpen === 'current'
            ? 'Set the country you currently call home.'
            : selectorOpen === 'favorite'
              ? 'Save the destinations that define your travel taste.'
              : selectorOpen === 'languages'
                ? 'Add languages one by one, then choose how comfortable you are using each one.'
                : selectorOpen === 'passports'
                  ? 'Select every passport you hold. The first one becomes your default visa passport.'
                  : selectorOpen === 'lived'
                    ? 'Keep the flags that represent where you have lived.'
                    : '';

  /* ---------------- UI ---------------- */

  return (
    <ScrapbookBackground overlay={0}>
      <ImageBackground
        source={require('../assets/scrapbook/travel4.png')}
        style={styles.pageBackground}
        imageStyle={styles.pageBackgroundImage}
      >
      <View style={styles.pageWash} />
      <SafeAreaView style={{ flex: 1, backgroundColor: 'transparent' }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 60 }}>
        <View style={styles.navBar}>
          <Pressable
            onPress={cancelAll}
            style={[
              styles.navBackAction,
              { backgroundColor: colors.paperAlt, borderColor },
            ]}
          >
            <Ionicons name="chevron-back" size={18} color={colors.textPrimary} />
          </Pressable>

          <View style={styles.navTitleWrap}>
            <TitleBanner title="Profile Settings" />
          </View>

          <Pressable
            onPress={saveAll}
            disabled={saveState === 'saving' || !hasChanges}
            style={[
              styles.navAction,
              {
                opacity: !hasChanges ? 0.4 : 1,
                backgroundColor: hasChanges ? colors.primary : colors.paperAlt,
                borderColor: hasChanges ? colors.primary : borderColor,
              },
            ]}
          >
            {saveState === 'saving' ? (
              <Text style={[styles.navBtn, { color: hasChanges ? colors.primaryText : colors.textSecondary }]}> 
                Saving…
              </Text>
            ) : saveState === 'saved' ? (
              <Text style={[styles.navBtn, { color: colors.primaryText, fontWeight: '700' }]}> 
                ✓ Saved
              </Text>
            ) : (
              <Text
                style={[
                  styles.navBtn,
                  { color: hasChanges ? colors.primaryText : colors.textPrimary },
                ]}
              >
                Save
              </Text>
            )}
          </Pressable>
        </View>

        <ScrapbookCard innerStyle={styles.sectionCard}>
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            Account
          </Text>
          <View style={styles.accountShell}>
            <Pressable
              onPress={() => setAvatarMenuOpen(true)}
              style={styles.accountAvatarColumn}
            >
              <View style={{ position: 'relative' }}>
                {profile?.avatar_url ? (
                  <Image
                    source={{ uri: profile.avatar_url }}
                    style={styles.avatarImage}
                  />
                ) : (
                  <View
                    style={[
                      styles.avatarFallback,
                      { backgroundColor: colors.border },
                    ]}
                  >
                    <Ionicons name="person" size={34} color={colors.textSecondary} />
                  </View>
                )}

                {isUploadingAvatar && (
                  <View style={styles.avatarOverlay}>
                    <ActivityIndicator color="#fff" />
                  </View>
                )}

                <View style={[styles.cameraBadge, { backgroundColor: colors.card, borderColor }]}>
                  <Ionicons name="camera" size={14} color={colors.textPrimary} />
                </View>
              </View>

              <Text style={[styles.avatarActionText, { color: colors.textSecondary }]}>
                {profile?.avatar_url ? 'Edit Photo' : 'Add Photo'}
              </Text>
            </Pressable>

            <View style={styles.identityFields}>
              <View style={styles.compactFieldGroup}>
                <Text style={[styles.fieldLabel, { color: colors.textPrimary }]}>
                  First Name
                </Text>
                <TextInput
                  value={draftFirstName}
                  onChangeText={setDraftFirstName}
                  style={[styles.input, styles.compactInput, { borderColor, color: colors.textPrimary }]}
                  placeholder="First name"
                  placeholderTextColor={colors.textSecondary}
                />
              </View>

              <View style={styles.compactFieldGroup}>
                <Text style={[styles.fieldLabel, { color: colors.textPrimary }]}>
                  Last Name
                </Text>
                <TextInput
                  value={draftLastName}
                  onChangeText={setDraftLastName}
                  style={[styles.input, styles.compactInput, { borderColor, color: colors.textPrimary }]}
                  placeholder="Last name"
                  placeholderTextColor={colors.textSecondary}
                />
              </View>

              <View style={styles.compactFieldGroup}>
                <Text style={[styles.fieldLabel, { color: colors.textPrimary }]}>
                  Username
                </Text>
                <View style={[styles.usernameInputWrap, { borderColor }]}>
                  <Text style={[styles.usernamePrefix, { color: colors.textSecondary }]}>@</Text>
                  <TextInput
                    value={draftUsername}
                    onChangeText={setDraftUsername}
                    style={[styles.usernameInput, { color: colors.textPrimary }]}
                    placeholder="Username"
                    placeholderTextColor={colors.textSecondary}
                    autoCapitalize="none"
                  />
                </View>
              </View>
            </View>
          </View>
        </ScrapbookCard>

        <Modal visible={avatarMenuOpen} transparent animationType="fade">
          <Pressable
            style={{ flex: 1, backgroundColor: 'rgba(33,21,13,0.34)', justifyContent: 'flex-end' }}
            onPress={() => setAvatarMenuOpen(false)}
          >
            <ScrapbookCard
              style={styles.sheetShell}
              innerStyle={{
                backgroundColor: colors.card,
                padding: 24,
                borderTopLeftRadius: 24,
                borderTopRightRadius: 24,
              }}
            >
              <Pressable
                onPress={pickAvatar}
                style={[styles.sheetAction, { borderColor }]}
              >
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.textPrimary }}>
                  {profile?.avatar_url ? 'Change Photo' : 'Add Photo'}
                </Text>
              </Pressable>

              {profile?.avatar_url && (
                <Pressable
                  onPress={deleteAvatar}
                  style={[styles.sheetAction, { borderColor: colors.redBorder }]}
                >
                  <Text style={{ fontSize: 16, fontWeight: '600', color: colors.redText }}>
                    Remove Photo
                  </Text>
                </Pressable>
              )}

              <Pressable
                onPress={() => setAvatarMenuOpen(false)}
                style={[styles.sheetAction, { borderColor }]}
              >
                <Text style={{ fontSize: 16, fontWeight: '600', color: colors.textSecondary }}>
                  Cancel
                </Text>
              </Pressable>
            </ScrapbookCard>
          </Pressable>
        </Modal>

        <ScrapbookCard innerStyle={styles.sectionCard}>
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            Travel
          </Text>
          <Row
            label="Travel mode"
            value={modeLabel}
            onPress={() => setSelectorOpen('mode')}
          />
          <Divider color={borderColor} />
          <Row
            label="Travel style"
            value={styleLabel}
            onPress={() => setSelectorOpen('style')}
          />
        </ScrapbookCard>

        <ScrapbookCard innerStyle={styles.sectionCard}>
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            Background
          </Text>
          <Row
            label="My flags"
            value={livedCountriesLabel}
            onPress={() => setSelectorOpen('lived')}
          />
          <Divider color={borderColor} />
          <Row
            label="Current country"
            value={currentCountryLabel}
            onPress={() => setSelectorOpen('current')}
          />
          <Divider color={borderColor} />
          <Row
            label="Next destination"
            value={nextDestinationLabel}
            onPress={() => setSelectorOpen('next')}
          />
          <Divider color={borderColor} />
          <Row
            label="Favorite countries"
            value={favoriteCountriesLabel}
            onPress={() => setSelectorOpen('favorite')}
          />
        </ScrapbookCard>

        <ScrapbookCard innerStyle={styles.sectionCard}>
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            Languages
          </Text>
          {draftLanguages.length ? (
            <View style={styles.inlineSummaryStack}>
              {draftLanguages.slice(0, 3).map((entry: any, index) => {
                const languageName =
                  typeof entry === 'string'
                    ? entry
                    : entry?.name ?? entry?.code ?? '';

                return (
                  <View key={`${languageName}-${index}`} style={styles.languageSummaryRow}>
                    <Text style={[styles.languageSummaryName, { color: colors.textPrimary }]}>
                      {languageName}
                    </Text>
                    <Text style={[styles.languageSummaryLevel, { color: colors.textSecondary }]}>
                      {proficiencyLabel(typeof entry === 'string' ? 'fluent' : entry?.proficiency)}
                    </Text>
                  </View>
                );
              })}
            </View>
          ) : (
            <Text style={[styles.emptyInlineText, { color: colors.textSecondary }]}>
              No languages added yet
            </Text>
          )}
          <Divider color={borderColor} />
          <Row
            label="Languages"
            value={languageCountLabel}
            onPress={() => setSelectorOpen('languages')}
          />
        </ScrapbookCard>

        <ScrapbookCard innerStyle={styles.sectionCard}>
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            Passports
          </Text>
          <Row
            label="Passports"
            value={passportsLabel}
            onPress={() => setSelectorOpen('passports')}
          />
          <Divider color={borderColor} />
          <Row
            label="Default passport"
            value={defaultPassportLabel}
          />
        </ScrapbookCard>

        <ScrapbookCard innerStyle={styles.sectionCard}> 
          <Text style={[styles.sectionTitle, { color: colors.textPrimary }]}>
            Account Actions
          </Text>
          <Pressable
            onPress={handleLogout}
            style={[styles.actionRow, { borderColor: borderColor }]}
          >
            <View style={styles.actionRowLeft}>
              <View style={[styles.actionIconWrap, { backgroundColor: colors.surface, borderColor }]}>
                <Ionicons name="log-out-outline" size={16} color={colors.textPrimary} />
              </View>
              <Text style={{ color: colors.textPrimary, fontWeight: '700', fontSize: 15 }}>
                Log out
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} />
          </Pressable>
        </ScrapbookCard>

        <ScrapbookCard innerStyle={styles.sectionCard}> 
          <Text style={{ fontSize: 17, fontWeight: '700', color: colors.redText, marginBottom: 10 }}>
            Danger Zone
          </Text>

          <Pressable
            onPress={() => setDeleteOpen(true)}
            style={[styles.actionRow, { borderColor: colors.redBorder }]}
          >
            <View style={styles.actionRowLeft}>
              <View style={[styles.actionIconWrap, { backgroundColor: colors.redBg, borderColor: colors.redBorder }]}>
                <Ionicons name="trash-outline" size={16} color={colors.redText} />
              </View>
              <Text style={{ color: colors.redText, fontWeight: '700', fontSize: 15 }}>
                Delete account
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={16} color={colors.redText} />
          </Pressable>
        </ScrapbookCard>
      </ScrollView>
      <Modal visible={!!selectorOpen} animationType="slide" transparent>
        <Pressable style={styles.modalBackdrop} onPress={() => setSelectorOpen(null)} />
        <ScrapbookCard
          style={styles.modalSheetShell}
          innerStyle={[styles.modalSheet, { backgroundColor: colors.card, maxHeight: '70%' }]}
        >
          <Text style={[styles.modalEyebrow, { color: colors.textSecondary }]}>
            {selectorEyebrow}
          </Text>
          <Text style={[styles.modalTitle, { color: colors.textPrimary }]}>
            {selectorTitle}
          </Text>
          <Text style={[styles.modalHelperText, { color: colors.textSecondary }]}>
            {selectorHelper}
          </Text>

          {selectorOpen === 'mode' && (
            <>
              {['solo','group','both'].map(option => (
                <Pressable
                  key={option}
                  style={{ paddingVertical: 14 }}
                  onPress={() => {
                    setDraftMode(option);
                    setSelectorOpen(null);
                  }}
                >
                  <Text style={{ color: colors.textPrimary, fontWeight: '600' }}>
                    {option === 'solo' ? 'Solo' : option === 'group' ? 'Group' : 'Solo + Group'}
                  </Text>
                </Pressable>
              ))}
            </>
          )}

          {selectorOpen === 'style' && (
            <>
              {['budget','comfortable','luxury'].map(option => (
                <Pressable
                  key={option}
                  style={{ paddingVertical: 14 }}
                  onPress={() => {
                    setDraftStyle(option);
                    setSelectorOpen(null);
                  }}
                >
                  <Text style={{ color: colors.textPrimary, fontWeight: '600' }}>
                    {option.charAt(0).toUpperCase() + option.slice(1)}
                  </Text>
                </Pressable>
              ))}
            </>
          )}

          {selectorOpen === 'next' && (
            <ScrollView>
              {countries.map(c => (
                <Pressable
                  key={c.iso2}
                  style={{ paddingVertical: 12 }}
                  onPress={() => {
                    setDraftNextDestination(c.iso2);
                    setSelectorOpen(null);
                  }}
                >
                  <Text style={{ color: colors.textPrimary }}>{c.name}</Text>
                </Pressable>
              ))}
            </ScrollView>
          )}

          {selectorOpen === 'current' && (
            <ScrollView>
              {countries.map(c => (
                <Pressable
                  key={c.iso2}
                  style={{ paddingVertical: 12 }}
                  onPress={() => {
                    setDraftCurrentCountry(c.iso2);
                    setSelectorOpen(null);
                  }}
                >
                  <Text style={{ color: colors.textPrimary }}>{c.name}</Text>
                </Pressable>
              ))}
            </ScrollView>
          )}

          {selectorOpen === 'favorite' && (
            <ScrollView>
              {countries.map(c => {
                const iso = c.iso2.toUpperCase();
                const selected = draftFavoriteCountries.includes(iso);
                return (
                  <Pressable
                    key={c.iso2}
                    style={{ paddingVertical: 12 }}
                    onPress={() => {
                      setDraftFavoriteCountries(prev =>
                        selected ? prev.filter(i => i !== iso) : [...prev, iso]
                      );
                    }}
                  >
                    <Text style={{ color: colors.textPrimary }}>
                      {selected ? '✓ ' : ''}{c.name}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          )}

          {selectorOpen === 'languages' && (
            <View>
              <TextInput
                value={draftLanguageInput}
                onChangeText={setDraftLanguageInput}
                placeholder="Add a language"
                placeholderTextColor={colors.textSecondary}
                style={[styles.input, { borderColor, color: colors.textPrimary, marginBottom: 12 }]}
                onSubmitEditing={event => {
                  const value = event.nativeEvent.text.trim();
                  if (!value) return;

                  setDraftLanguages(current => {
                    const normalized = normalizeLanguageDraft([
                      ...current,
                      { name: value, proficiency: 'fluent' },
                    ]);
                    return normalized;
                  });
                  setDraftLanguageInput('');
                }}
              />

              <ScrollView showsVerticalScrollIndicator={false}>
                {draftLanguages.length === 0 ? (
                  <Text style={[styles.emptyInlineText, { color: colors.textSecondary }]}>
                    No languages added yet
                  </Text>
                ) : (
                  draftLanguages.map((entry: any, index) => {
                    const languageName =
                      typeof entry === 'string' ? entry : entry?.name ?? entry?.code ?? '';
                    const proficiency = normalizeProficiency(
                      typeof entry === 'string' ? 'fluent' : entry?.proficiency
                    );

                    return (
                      <View
                        key={`${languageName}-${index}`}
                        style={[styles.languageEditorCard, { backgroundColor: colors.surface, borderColor }]}
                      >
                        <View style={styles.languageEditorHeader}>
                          <Text style={[styles.languageSummaryName, { color: colors.textPrimary }]}>
                            {languageName}
                          </Text>
                          <Pressable
                            onPress={() =>
                              setDraftLanguages(current => current.filter((_: any, i: number) => i !== index))
                            }
                          >
                            <Ionicons name="remove-circle" size={20} color={colors.redText} />
                          </Pressable>
                        </View>

                        <View style={styles.proficiencyRow}>
                          {LANGUAGE_PROFICIENCY_OPTIONS.map(option => {
                            const selected = proficiency === option.value;
                            return (
                              <Pressable
                                key={`${languageName}-${option.value}`}
                                onPress={() =>
                                  setDraftLanguages(current =>
                                    current.map((item: any, i: number) =>
                                      i === index
                                        ? {
                                            ...(typeof item === 'string' ? { name: item } : item),
                                            name:
                                              typeof item === 'string'
                                                ? item
                                                : item?.name ?? item?.code ?? languageName,
                                            proficiency: option.value,
                                          }
                                        : item
                                    )
                                  )
                                }
                                style={[
                                  styles.proficiencyChip,
                                  {
                                    backgroundColor: selected ? colors.primary : colors.card,
                                    borderColor: selected ? colors.primary : borderColor,
                                  },
                                ]}
                              >
                                <Text
                                  style={{
                                    color: selected ? colors.primaryText : colors.textPrimary,
                                    fontWeight: '700',
                                    fontSize: 12,
                                  }}
                                >
                                  {option.label}
                                </Text>
                              </Pressable>
                            );
                          })}
                        </View>
                      </View>
                    );
                  })
                )}
              </ScrollView>
            </View>
          )}

          {selectorOpen === 'passports' && (
            <ScrollView>
              {countries.map(c => {
                const iso = c.iso2.toUpperCase();
                const selected = draftPassportNationalities.includes(iso);
                return (
                  <Pressable
                    key={c.iso2}
                    style={[styles.selectorRow, { borderBottomColor: borderColor }]}
                    onPress={() => {
                      setDraftPassportNationalities(prev =>
                        selected ? prev.filter(i => i !== iso) : [...prev, iso]
                      );
                    }}
                  >
                    <Text style={{ color: colors.textPrimary }}>
                      {flagFor(iso)} {c.name}
                    </Text>
                    <Text style={{ color: selected ? colors.primary : colors.textSecondary, fontWeight: '700' }}>
                      {selected ? (draftPassportNationalities[0] === iso ? 'Default' : 'Selected') : ''}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          )}

          {selectorOpen === 'lived' && (
            <ScrollView>
              {countries.map(c => {
                const iso = c.iso2.toUpperCase();
                const selected = draftLivedCountries.includes(iso);
                return (
                  <Pressable
                    key={c.iso2}
                    style={{ paddingVertical: 12 }}
                    onPress={() => {
                      setDraftLivedCountries(prev =>
                        selected
                          ? prev.filter(i => i !== iso)
                          : [...prev, iso]
                      );
                    }}
                  >
                    <Text style={{ color: colors.textPrimary }}>
                      {selected ? '✓ ' : ''}{c.name}
                    </Text>
                  </Pressable>
                );
              })}
            </ScrollView>
          )}
        </ScrapbookCard>
      </Modal>


      <Modal visible={deleteOpen} animationType="fade" transparent>
        <Pressable
          style={{ flex: 1, backgroundColor: 'rgba(33,21,13,0.38)', justifyContent: 'center', padding: 24 }}
          onPress={() => setDeleteOpen(false)}
        >
          <ScrapbookCard
            style={styles.deleteShell}
            innerStyle={{
              backgroundColor: colors.card,
              borderRadius: 20,
              padding: 20,
            }}
          >
            <Text style={{ fontSize: 18, fontWeight: '700', marginBottom: 8, color: colors.textPrimary }}>
              Delete account?
            </Text>

            <Text style={{ fontSize: 14, marginBottom: 20, color: colors.textSecondary }}>
              This action is permanent. Your account and all associated data will be deleted.
            </Text>

            <View style={{ flexDirection: 'row', gap: 12 }}>
              <Pressable
                onPress={() => setDeleteOpen(false)}
                style={{
                  flex: 1,
                  paddingVertical: 14,
                  borderRadius: 14,
                  alignItems: 'center',
                  borderWidth: 1,
                  borderColor: borderColor,
                }}
              >
                <Text style={{ fontWeight: '600', color: colors.textPrimary }}>
                  Cancel
                </Text>
              </Pressable>

              <Pressable
                onPress={handleDeleteAccount}
                disabled={deleting}
                style={{
                  flex: 1,
                  paddingVertical: 14,
                  borderRadius: 14,
                  alignItems: 'center',
                  borderWidth: 1,
                  borderColor: colors.redBorder,
                }}
              >
                <Text style={{ fontWeight: '700', color: colors.redText }}>
                  {deleting ? 'Deleting…' : 'Delete'}
                </Text>
              </Pressable>
            </View>
          </ScrapbookCard>
        </Pressable>
      </Modal>
      </SafeAreaView>
      </ImageBackground>
    </ScrapbookBackground>
  );
}

function Row({ label, value, onPress }: any) {
  const colors = useTheme();

  const Container: any = onPress ? Pressable : View;

  return (
    <Container
      style={styles.row}
      onPress={onPress}
    >
      <Text
        style={[
          styles.rowText,
          { color: colors.textPrimary, marginRight: 12 }
        ]}
        numberOfLines={1}
      >
        {label}
      </Text>

      <Text
        style={[
          styles.rowValue,
          { color: colors.textSecondary, flexShrink: 1, textAlign: 'right' }
        ]}
        numberOfLines={1}
      >
        {value}
      </Text>

      {onPress ? (
        <Ionicons
          name="chevron-forward"
          size={15}
          color={colors.textSecondary}
          style={styles.rowChevron}
        />
      ) : null}
    </Container>
  );
}

function Divider({ color }: { color: string }) {
  return <View style={[styles.divider, { backgroundColor: color }]} />;
}

function SummaryChip({
  label,
  value,
  colors,
  wide = false,
}: {
  label: string;
  value: string;
  colors: ReturnType<typeof useTheme>;
  wide?: boolean;
}) {
  return (
    <View
      style={[
        styles.summaryChip,
        {
          backgroundColor: colors.surface,
          borderColor: colors.border,
          flex: wide ? undefined : 1,
        },
      ]}
    >
      <Text style={[styles.summaryChipLabel, { color: colors.textSecondary }]}>
        {label}
      </Text>
      <Text style={[styles.summaryChipValue, { color: colors.textPrimary }]} numberOfLines={1}>
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pageBackground: {
    flex: 1,
  },
  pageBackgroundImage: {
    resizeMode: 'cover',
  },
  pageWash: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(250,245,237,0.18)',
  },
  navBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 22,
    paddingTop: 8,
    paddingBottom: 4,
  },
  navTitleWrap: {
    flex: 1,
    marginHorizontal: -12,
  },
  navBackAction: {
    width: 42,
    height: 42,
    borderWidth: 1,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  navAction: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 16,
    paddingVertical: 10,
    minWidth: 96,
    alignItems: 'center',
  },
  navBtn: { fontSize: 17, fontWeight: '600' },
  sectionCard: {
    borderRadius: 24,
    paddingVertical: 16,
    paddingHorizontal: 16,
    marginHorizontal: 20,
    marginTop: 12,
    backgroundColor: 'rgba(255,255,255,0.96)',
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.06)',
    shadowColor: '#000000',
    shadowOpacity: 0.08,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
    elevation: 4,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 10,
  },
  sectionSubtitle: {
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 12,
  },
  summaryPairRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginBottom: 12,
  },
  summaryChip: {
    minHeight: 58,
    borderRadius: 16,
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 10,
    justifyContent: 'center',
  },
  summaryChipLabel: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    marginBottom: 4,
  },
  summaryChipValue: {
    fontSize: 15,
    fontWeight: '700',
  },
  accountShell: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 16,
  },
  accountAvatarColumn: {
    width: 92,
    alignItems: 'center',
    paddingTop: 4,
  },
  avatarActionText: {
    marginTop: 10,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
  },
  inlineSummaryStack: {
    gap: 10,
    marginBottom: 6,
  },
  languageSummaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  languageSummaryName: {
    fontSize: 15,
    fontWeight: '700',
    flex: 1,
    marginRight: 10,
  },
  languageSummaryLevel: {
    fontSize: 13,
    fontWeight: '600',
  },
  emptyInlineText: {
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 6,
  },
  inlineFlagRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 12,
    marginBottom: 8,
  },
  flagChip: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  flagChipText: {
    fontSize: 18,
  },
  avatarCard: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
  },
  avatarImage: {
    width: 84,
    height: 84,
    borderRadius: 42,
  },
  avatarFallback: {
    width: 84,
    height: 84,
    borderRadius: 42,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    borderRadius: 48,
    backgroundColor: 'rgba(33,21,13,0.28)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraBadge: {
    position: 'absolute',
    right: -2,
    bottom: -2,
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  identityFields: {
    gap: 10,
    flex: 1,
    minWidth: 0,
  },
  compactFieldGroup: {
    gap: 6,
  },
  fieldLabel: {
    fontSize: 14,
    fontWeight: '600',
  },
  input: {
    minHeight: 46,
    borderWidth: 0,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    backgroundColor: 'rgba(245,245,245,0.9)',
  },
  usernameInputWrap: {
    minHeight: 46,
    borderWidth: 0,
    borderRadius: 10,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(245,245,245,0.9)',
  },
  usernamePrefix: {
    fontSize: 16,
    marginRight: 6,
  },
  usernameInput: {
    flex: 1,
    paddingVertical: 10,
    fontSize: 16,
  },
  row: {
    minHeight: 52,
    paddingVertical: 14,
    paddingHorizontal: 2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  rowText: { fontSize: 16, flex: 1 },
  rowValue: { fontSize: 15, maxWidth: '50%' },
  rowChevron: { marginLeft: 8 },
  divider: { height: StyleSheet.hairlineWidth },
  modalBackdrop: { flex: 1, backgroundColor: 'rgba(33,21,13,0.28)' },
  modalSheetShell: {
    position: 'absolute',
    left: 12,
    right: 12,
    bottom: 0,
  },
  modalSheet: { padding: 20 },
  modalEyebrow: {
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.6,
    textTransform: 'uppercase',
    marginBottom: 6,
  },
  modalTitle: { fontSize: 18, fontWeight: '700' },
  modalHelperText: {
    fontSize: 14,
    lineHeight: 20,
    marginTop: 8,
    marginBottom: 14,
  },
  sheetShell: {
    marginHorizontal: 12,
  },
  sheetAction: {
    paddingVertical: 14,
    borderWidth: 1,
    borderRadius: 16,
    alignItems: 'center',
    marginBottom: 10,
  },
  deleteShell: {
    width: '100%',
  },
  languageEditorCard: {
    borderWidth: 1,
    borderRadius: 18,
    padding: 14,
    marginBottom: 12,
  },
  languageEditorHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  proficiencyRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  proficiencyChip: {
    borderWidth: 1,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  selectorRow: {
    minHeight: 48,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  compactInput: {
    minHeight: 46,
  },
  actionRow: {
    minHeight: 58,
    borderWidth: 1,
    borderRadius: 18,
    paddingHorizontal: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  actionRowLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  actionIconWrap: {
    width: 34,
    height: 34,
    borderRadius: 17,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
