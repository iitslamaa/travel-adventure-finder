import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { ImageBackground, Pressable, StyleSheet, Text, View } from 'react-native';
import type { BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';

type TabIconName =
  | 'compass-outline'
  | 'list-outline'
  | 'people-outline'
  | 'person-outline'
  | 'ellipsis-horizontal';

function FloatingTabBar({ state, descriptors, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const colors = useTheme();
  const visibleRoutes = state.routes.filter(
    (route) => route.name !== 'when-to-go' && route.name !== 'countries'
  );

  return (
    <View
      pointerEvents="box-none"
      style={[
        styles.tabBarWrap,
        {
          paddingBottom: Math.max(insets.bottom, 10),
        },
      ]}
    >
      <ImageBackground
        source={require('../../assets/scrapbook/country-tab.png')}
        style={styles.tabBarShell}
        imageStyle={styles.tabBarImage}
      >
        <View
          style={[
            styles.tabBarOverlay,
            {
              backgroundColor: 'rgba(21, 17, 14, 0.18)',
              borderColor: 'rgba(255,255,255,0.18)',
            },
          ]}
        >
          {visibleRoutes.map((route) => {
            const { options } = descriptors[route.key];
            const label =
              typeof options.tabBarLabel === 'string'
                ? options.tabBarLabel
                : typeof options.title === 'string'
                ? options.title
                : route.name;

            const routeIndex = state.routes.findIndex((candidate) => candidate.key === route.key);
            const isFocused = state.index === routeIndex;
            const iconName = (options.tabBarIcon
              ? ({
                  discovery: 'compass-outline',
                  planning: 'list-outline',
                  friends: 'people-outline',
                  profile: 'person-outline',
                  more: 'ellipsis-horizontal',
                }[route.name] as TabIconName | undefined)
              : undefined) ?? 'ellipse-outline';

            const onPress = () => {
              const event = navigation.emit({
                type: 'tabPress',
                target: route.key,
                canPreventDefault: true,
              });

              if (!isFocused && !event.defaultPrevented) {
                navigation.navigate(route.name, route.params);
              }
            };

            const onLongPress = () => {
              navigation.emit({
                type: 'tabLongPress',
                target: route.key,
              });
            };

            return (
              <Pressable
                key={route.key}
                accessibilityRole="button"
                accessibilityState={isFocused ? { selected: true } : {}}
                onPress={onPress}
                onLongPress={onLongPress}
                style={({ pressed }) => [
                  styles.tabButton,
                  isFocused && [styles.tabButtonActive, { backgroundColor: 'rgba(255,255,255,0.16)' }],
                  { opacity: pressed ? 0.85 : 1 },
                ]}
              >
                <View style={styles.tabIconWrap}>
                  <Ionicons
                    name={iconName}
                    size={20}
                    color={isFocused ? '#FFFFFF' : 'rgba(255,255,255,0.72)'}
                  />
                  {route.name === 'planning' ? (
                    <View
                      style={[
                        styles.tabBadge,
                        {
                          backgroundColor: colors.redText,
                          opacity: 0,
                        },
                      ]}
                    />
                  ) : null}
                </View>
                <Text
                  style={[
                    styles.tabLabel,
                    { color: isFocused ? '#FFFFFF' : 'rgba(255,255,255,0.72)' },
                  ]}
                  numberOfLines={1}
                >
                  {label}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </ImageBackground>
    </View>
  );
}

export default function TabLayout() {
  return (
    <Tabs
      tabBar={(props) => <FloatingTabBar {...props} />}
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: '#FFFFFF',
        tabBarInactiveTintColor: 'rgba(255,255,255,0.72)',
        tabBarStyle: {
          display: 'none',
        },
        tabBarLabelStyle: {
          fontWeight: '600',
          fontSize: 12,
        },
      }}
    >
      <Tabs.Screen
        name="discovery"
        options={{
          title: 'Discover',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="compass-outline" size={size} color={color} />
          ),
        }}
      />

      <Tabs.Screen
        name="planning"
        options={{
          title: 'Plan',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="list-outline" size={size} color={color} />
          ),
        }}
      />

      <Tabs.Screen
        name="when-to-go"
        options={{
          href: null,
        }}
      />

      <Tabs.Screen
        name="countries"
        options={{
          href: null,
        }}
      />

      <Tabs.Screen
        name="friends"
        options={{
          title: 'Friends',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="people-outline" size={size} color={color} />
          ),
        }}
      />

      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="person-outline" size={size} color={color} />
          ),
        }}
      />

      <Tabs.Screen
        name="more"
        options={{
          title: 'More',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="ellipsis-horizontal" size={size} color={color} />
          ),
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  tabBarWrap: {
    position: 'absolute',
    left: 16,
    right: 16,
    bottom: 0,
  },
  tabBarShell: {
    overflow: 'hidden',
    borderRadius: 30,
  },
  tabBarImage: {
    resizeMode: 'cover',
  },
  tabBarOverlay: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 10,
    paddingVertical: 10,
    borderWidth: 1,
    borderRadius: 30,
    shadowColor: '#000000',
    shadowOpacity: 0.18,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 12,
  },
  tabButton: {
    flex: 1,
    minHeight: 52,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    paddingHorizontal: 6,
  },
  tabButtonActive: {
    borderRadius: 22,
  },
  tabIconWrap: {
    minHeight: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 2,
  },
  tabBadge: {
    position: 'absolute',
    right: -6,
    top: -3,
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  tabLabel: {
    fontSize: 11,
    fontWeight: '700',
    marginTop: 4,
  },
});
