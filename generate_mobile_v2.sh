#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AnonymousChatApp"
TEMPLATE="react-native-template-typescript"

if [ -d "$APP_NAME" ]; then
  echo "Directory $APP_NAME already exists. Remove it or choose a different name." >&2
  exit 1
fi

echo "Initializing React Native project..."
npx react-native init "$APP_NAME" --template "$TEMPLATE"

cd "$APP_NAME"

echo "Installing dependencies..."
npm install \
  @react-native-async-storage/async-storage \
  @react-navigation/native \
  @react-navigation/native-stack \
  react-native-gesture-handler \
  react-native-reanimated \
  react-native-safe-area-context \
  react-native-screens \
  react-native-gifted-chat \
  react-native-haptic-feedback \
  react-native-image-picker \
  socket.io-client \
  zustand

if command -v pod >/dev/null 2>&1; then
  (cd ios && pod install)
fi

rm -rf src
mkdir -p src/components src/screens src/services src/store src/theme src/utils

cat <<'EOT' > src/theme/colors.ts
export const colors = {
  background: '#0B141A',
  surface: '#111B21',
  textPrimary: '#E9EDEF',
  textSecondary: '#8696A0',
  accent: '#25D366',
  danger: '#EF4444',
  warning: '#F59E0B',
  border: '#202C33',
  card: '#1F2A30',
};
EOT

cat <<'EOT' > src/utils/ids.ts
export const createAnonymousId = (): string => {
  return `anon_${Date.now()}_${Math.random().toString(16).slice(2)}`;
};
EOT

cat <<'EOT' > src/store/useChatStore.ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import { GiftedChat, IMessage } from 'react-native-gifted-chat';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { createAnonymousId } from '../utils/ids';

export type ChatState = {
  userId: string;
  partnerId: string;
  isConnected: boolean;
  latencyMs: number | null;
  isMatching: boolean;
  messages: IMessage[];
  blockedUsers: string[];
  termsAccepted: boolean;
  setConnection: (connected: boolean) => void;
  setLatency: (latency: number | null) => void;
  setPartner: (partnerId: string) => void;
  setMatching: (matching: boolean) => void;
  setMessages: (messages: IMessage[]) => void;
  appendMessages: (messages: IMessage[]) => void;
  addBlockedUser: (userId: string) => void;
  acceptTerms: () => void;
  resetAll: () => void;
};

export const useChatStore = create<ChatState>()(
  persist(
    set => ({
      userId: createAnonymousId(),
      partnerId: '',
      isConnected: true,
      latencyMs: null,
      isMatching: true,
      messages: [],
      blockedUsers: [],
      termsAccepted: false,
      setConnection: connected => set({ isConnected: connected }),
      setLatency: latency => set({ latencyMs: latency }),
      setPartner: partnerId => set({ partnerId }),
      setMatching: matching => set({ isMatching: matching }),
      setMessages: messages => set({ messages }),
      appendMessages: messages =>
        set(state => ({ messages: GiftedChat.append(state.messages, messages) })),
      addBlockedUser: userId =>
        set(state => ({ blockedUsers: [...new Set([...state.blockedUsers, userId])] })),
      acceptTerms: () => set({ termsAccepted: true }),
      resetAll: () =>
        set({
          userId: createAnonymousId(),
          partnerId: '',
          isConnected: true,
          latencyMs: null,
          isMatching: true,
          messages: [],
          blockedUsers: [],
          termsAccepted: false,
        }),
    }),
    {
      name: 'anonymous-chat-store',
      storage: {
        getItem: AsyncStorage.getItem,
        setItem: AsyncStorage.setItem,
        removeItem: AsyncStorage.removeItem,
      },
      partialize: state => ({
        userId: state.userId,
        messages: state.messages,
        blockedUsers: state.blockedUsers,
        termsAccepted: state.termsAccepted,
      }),
    },
  ),
);
EOT

cat <<'EOT' > src/services/socketService.ts
import { io, Socket } from 'socket.io-client';
import { IMessage } from 'react-native-gifted-chat';
import { useChatStore } from '../store/useChatStore';

const API_URL = process.env.API_URL ?? 'http://localhost:3000';

class SocketService {
  private socket: Socket | null = null;
  private pingTimer: NodeJS.Timeout | null = null;

  connect() {
    const { userId, setConnection, setLatency, setPartner, setMatching, appendMessages } =
      useChatStore.getState();

    this.socket = io(API_URL, {
      transports: ['websocket'],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      auth: { userId },
    });

    this.socket.on('connect', () => setConnection(true));
    this.socket.on('disconnect', () => setConnection(false));
    this.socket.on('match_found', payload => {
      setPartner(payload.partnerId);
      setMatching(false);
    });
    this.socket.on('message', payload => {
      const incoming: IMessage = {
        _id: payload.id,
        text: payload.text,
        createdAt: new Date(payload.createdAt),
        user: { _id: payload.userId },
        image: payload.image,
      };
      appendMessages([incoming]);
    });
    this.socket.on('partner_left', () => {
      setPartner('');
      setMatching(true);
    });
    this.socket.on('pong', (payload: { ts: number }) => {
      setLatency(Date.now() - payload.ts);
    });

    this.startPing();
  }

  findMatch() {
    this.socket?.emit('find_match');
  }

  sendMessage(message: { text: string; createdAt: string; userId: string; image?: string }) {
    this.socket?.emit('message', message);
  }

  reportUser(payload: { reporterId: string; reportedId: string; reason: string }) {
    return fetch(`${API_URL}/api/report`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  }

  blockUser(payload: { blockerId: string; blockedId: string }) {
    this.socket?.emit('block_user', payload);
  }

  disconnect() {
    this.stopPing();
    this.socket?.disconnect();
    this.socket = null;
  }

  private startPing() {
    this.stopPing();
    this.pingTimer = setInterval(() => {
      this.socket?.emit('ping', { ts: Date.now() });
    }, 5000);
  }

  private stopPing() {
    if (this.pingTimer) {
      clearInterval(this.pingTimer);
      this.pingTimer = null;
    }
  }
}

export const socketService = new SocketService();
EOT

cat <<'EOT' > src/components/OfflineBanner.tsx
import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { colors } from '../theme/colors';

export const OfflineBanner = ({ isOffline }: { isOffline: boolean }) => {
  if (!isOffline) {
    return null;
  }

  return (
    <View style={styles.container}>
      <Text style={styles.text}>Offline · Trying to reconnect</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.warning,
    paddingVertical: 6,
    paddingHorizontal: 12,
  },
  text: {
    color: '#1F2937',
    textAlign: 'center',
    fontWeight: '600',
  },
});
EOT

cat <<'EOT' > src/components/PrimaryButton.tsx
import React from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import { colors } from '../theme/colors';

export const PrimaryButton = ({ label, onPress }: { label: string; onPress: () => void }) => (
  <Pressable style={styles.button} onPress={onPress}>
    <Text style={styles.text}>{label}</Text>
  </Pressable>
);

const styles = StyleSheet.create({
  button: {
    backgroundColor: colors.accent,
    paddingVertical: 12,
    borderRadius: 16,
    alignItems: 'center',
  },
  text: { color: '#0B141A', fontWeight: '700' },
});
EOT

cat <<'EOT' > src/components/LatencyPill.tsx
import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { colors } from '../theme/colors';

export const LatencyPill = ({ latency }: { latency: number | null }) => (
  <View style={styles.container}>
    <Text style={styles.text}>{latency ? `${latency}ms` : '—'}</Text>
  </View>
);

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.card,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.border,
  },
  text: { color: colors.textSecondary, fontSize: 12 },
});
EOT

cat <<'EOT' > src/screens/WelcomeScreen.tsx
import React, { useState } from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { colors } from '../theme/colors';
import { PrimaryButton } from '../components/PrimaryButton';
import { useChatStore } from '../store/useChatStore';

type RootStackParamList = {
  Welcome: undefined;
  Matching: undefined;
  Chat: undefined;
  Settings: undefined;
};

type Props = NativeStackScreenProps<RootStackParamList, 'Welcome'>;

export const WelcomeScreen = ({ navigation }: Props) => {
  const { termsAccepted, acceptTerms } = useChatStore();
  const [showTerms, setShowTerms] = useState(!termsAccepted);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Anonymous Chat</Text>
      <Text style={styles.subtitle}>Connect instantly with a safe, respectful community.</Text>
      <PrimaryButton
        label="Start Matching"
        onPress={() => {
          if (!termsAccepted) {
            setShowTerms(true);
          } else {
            navigation.replace('Matching');
          }
        }}
      />
      <Modal visible={showTerms} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Terms & Privacy</Text>
            <Text style={styles.modalText}>
              By continuing you agree to our Terms of Service and Privacy Policy. Respectful
              conduct is required. You may report or block users at any time.
            </Text>
            <PrimaryButton
              label="I Agree"
              onPress={() => {
                acceptTerms();
                setShowTerms(false);
                navigation.replace('Matching');
              }}
            />
            <Pressable onPress={() => setShowTerms(false)}>
              <Text style={styles.modalCancel}>Not now</Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
    padding: 24,
    justifyContent: 'center',
    gap: 16,
  },
  title: { color: colors.textPrimary, fontSize: 28, fontWeight: '700' },
  subtitle: { color: colors.textSecondary, fontSize: 16 },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalCard: {
    backgroundColor: colors.surface,
    padding: 20,
    borderRadius: 16,
    width: '85%',
    gap: 12,
  },
  modalTitle: { color: colors.textPrimary, fontSize: 18, fontWeight: '600' },
  modalText: { color: colors.textSecondary },
  modalCancel: { color: colors.textSecondary, textAlign: 'center' },
});
EOT

cat <<'EOT' > src/screens/MatchingScreen.tsx
import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import Animated, { useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';
import { LatencyPill } from '../components/LatencyPill';

export const MatchingScreen = () => {
  const navigation = useNavigation();
  const { latencyMs, isMatching } = useChatStore();
  const pulse = useSharedValue(0.7);

  useEffect(() => {
    socketService.findMatch();
    pulse.value = withRepeat(withTiming(1, { duration: 900 }), -1, true);
  }, [pulse]);

  useEffect(() => {
    if (!isMatching) {
      navigation.navigate('Chat' as never);
    }
  }, [isMatching, navigation]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pulse.value }],
    opacity: pulse.value,
  }));

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Finding a partner</Text>
      <Animated.View style={[styles.orb, animatedStyle]} />
      <LatencyPill latency={latencyMs} />
      <Text style={styles.subtitle}>Stay respectful. You can report or block anytime.</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    gap: 16,
  },
  title: {
    color: colors.textPrimary,
    fontSize: 22,
    fontWeight: '600',
  },
  orb: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: colors.accent,
  },
  subtitle: {
    marginTop: 8,
    textAlign: 'center',
    color: colors.textSecondary,
  },
});
EOT

cat <<'EOT' > src/screens/ChatScreen.tsx
import React, { useCallback, useMemo, useState } from 'react';
import { Alert, Linking, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { GiftedChat, IMessage } from 'react-native-gifted-chat';
import { launchImageLibrary } from 'react-native-image-picker';
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';

export const ChatScreen = () => {
  const { userId, partnerId, isConnected, messages, appendMessages, addBlockedUser } = useChatStore();
  const [isReportOpen, setReportOpen] = useState(false);

  const reportReasons = useMemo(
    () => ['Harassment', 'Spam', 'Hate Speech', 'Inappropriate Content', 'Other'],
    [],
  );

  const handleSend = useCallback(
    (outgoing: IMessage[] = []) => {
      appendMessages(outgoing);
      outgoing.forEach(msg => {
        socketService.sendMessage({
          text: msg.text,
          createdAt: msg.createdAt.toISOString(),
          userId: String(msg.user._id),
          image: msg.image,
        });
      });
    },
    [appendMessages],
  );

  const handleImagePick = useCallback(async () => {
    const result = await launchImageLibrary({ mediaType: 'photo', selectionLimit: 1 });
    const asset = result.assets?.[0];
    if (!asset?.uri) {
      return;
    }

    const imageMessage: IMessage = {
      _id: `${Date.now()}`,
      createdAt: new Date(),
      user: { _id: userId },
      text: '',
      image: asset.uri,
    };

    handleSend([imageMessage]);
  }, [handleSend, userId]);

  const handleReport = useCallback(
    async (reason: string) => {
      await socketService.reportUser({
        reporterId: userId,
        reportedId: partnerId,
        reason,
      });
    },
    [partnerId, userId],
  );

  const handleBlock = useCallback(() => {
    socketService.blockUser({ blockerId: userId, blockedId: partnerId });
    addBlockedUser(partnerId);
  }, [addBlockedUser, partnerId, userId]);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>Anonymous Chat</Text>
          <Text style={styles.headerSubtitle}>Partner ID: {partnerId || 'Searching...'}</Text>
        </View>
        <View style={styles.headerActions}>
          <Pressable style={styles.headerButton} onPress={() => setReportOpen(true)}>
            <Text style={styles.headerButtonText}>Report</Text>
          </Pressable>
          <Pressable
            style={[styles.headerButton, styles.blockButton]}
            onPress={() =>
              Alert.alert('Block user', 'Are you sure you want to block this user?', [
                { text: 'Cancel', style: 'cancel' },
                {
                  text: 'Block',
                  style: 'destructive',
                  onPress: () => {
                    handleBlock();
                    ReactNativeHapticFeedback.trigger('impactMedium');
                  },
                },
              ])
            }
          >
            <Text style={styles.headerButtonText}>Block</Text>
          </Pressable>
        </View>
      </View>
      {!isConnected && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>Offline · Messages will send when reconnected</Text>
        </View>
      )}
      <GiftedChat
        messages={messages}
        onSend={handleSend}
        user={{ _id: userId }}
        placeholder="Type a message"
        renderUsernameOnMessage
        alwaysShowSend
        timeTextStyle={{ left: styles.timeText, right: styles.timeText }}
        textInputStyle={styles.input}
        messagesContainerStyle={styles.messagesContainer}
        renderActions={() => (
          <Pressable style={styles.imageButton} onPress={handleImagePick}>
            <Text style={styles.imageButtonText}>＋</Text>
          </Pressable>
        )}
        onLongPress={() => ReactNativeHapticFeedback.trigger('impactLight')}
      />
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          By chatting you agree to our
          <Text style={styles.link} onPress={() => Linking.openURL('https://example.com/terms')}>
            {' '}Terms of Service
          </Text>
        </Text>
      </View>
      <Modal animationType="slide" transparent visible={isReportOpen}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Report user</Text>
            {reportReasons.map(reason => (
              <Pressable
                key={reason}
                style={styles.modalOption}
                onPress={() => {
                  handleReport(reason);
                  setReportOpen(false);
                }}
              >
                <Text style={styles.modalOptionText}>{reason}</Text>
              </Pressable>
            ))}
            <Pressable style={styles.modalClose} onPress={() => setReportOpen(false)}>
              <Text style={styles.modalCloseText}>Cancel</Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  header: {
    padding: 16,
    backgroundColor: colors.surface,
    borderBottomColor: colors.border,
    borderBottomWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerTitle: { color: colors.textPrimary, fontSize: 18, fontWeight: '600' },
  headerSubtitle: { color: colors.textSecondary, fontSize: 12, marginTop: 4 },
  headerActions: { flexDirection: 'row', gap: 8 },
  headerButton: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.border,
  },
  blockButton: { backgroundColor: colors.danger, borderColor: colors.danger },
  headerButtonText: { color: colors.textPrimary, fontSize: 12 },
  offlineBanner: { backgroundColor: colors.warning, padding: 8 },
  offlineText: { textAlign: 'center', color: '#1F2937', fontWeight: '600' },
  messagesContainer: { backgroundColor: colors.background },
  input: { color: colors.textPrimary },
  timeText: { color: colors.textSecondary },
  footer: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
  },
  footerText: { color: colors.textSecondary, textAlign: 'center', fontSize: 12 },
  link: { color: colors.accent },
  imageButton: {
    backgroundColor: colors.card,
    borderRadius: 16,
    paddingHorizontal: 10,
    paddingVertical: 6,
    marginLeft: 8,
  },
  imageButtonText: { color: colors.textPrimary, fontSize: 18 },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: colors.surface,
    padding: 20,
    borderRadius: 16,
    width: '80%',
  },
  modalTitle: { color: colors.textPrimary, fontSize: 16, fontWeight: '600', marginBottom: 12 },
  modalOption: { paddingVertical: 10 },
  modalOptionText: { color: colors.textPrimary },
  modalClose: { marginTop: 12 },
  modalCloseText: { color: colors.textSecondary, textAlign: 'center' },
});
EOT

cat <<'EOT' > src/screens/SettingsScreen.tsx
import React from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';

export const SettingsScreen = () => {
  const { blockedUsers, resetAll } = useChatStore();

  const handleDelete = () => {
    Alert.alert('Delete data', 'This will erase your chat history and account data.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          resetAll();
        },
      },
    ]);
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Blocked Users</Text>
      {blockedUsers.length === 0 ? (
        <Text style={styles.empty}>No blocked users yet.</Text>
      ) : (
        blockedUsers.map(user => (
          <View key={user} style={styles.blockedCard}>
            <Text style={styles.blockedText}>{user}</Text>
          </View>
        ))
      )}
      <Pressable style={styles.deleteButton} onPress={handleDelete}>
        <Text style={styles.deleteButtonText}>Delete My Account/Data</Text>
      </Pressable>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
    padding: 24,
    gap: 12,
  },
  title: { color: colors.textPrimary, fontSize: 20, fontWeight: '600' },
  empty: { color: colors.textSecondary },
  blockedCard: {
    padding: 12,
    borderRadius: 12,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  blockedText: { color: colors.textPrimary },
  deleteButton: {
    marginTop: 24,
    paddingVertical: 12,
    borderRadius: 16,
    backgroundColor: colors.danger,
    alignItems: 'center',
  },
  deleteButtonText: { color: 'white', fontWeight: '600' },
});
EOT

cat <<'EOT' > src/App.tsx
import React, { useEffect } from 'react';
import { Pressable, SafeAreaView, StatusBar, Text } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';
import { OfflineBanner } from './components/OfflineBanner';
import { ChatScreen } from './screens/ChatScreen';
import { MatchingScreen } from './screens/MatchingScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { WelcomeScreen } from './screens/WelcomeScreen';
import { socketService } from './services/socketService';
import { useChatStore } from './store/useChatStore';
import { colors } from './theme/colors';

const Stack = createNativeStackNavigator();

export default function App() {
  const { isConnected, isMatching, termsAccepted } = useChatStore();

  useEffect(() => {
    socketService.connect();
    return () => socketService.disconnect();
  }, []);

  useEffect(() => {
    if (!isMatching) {
      ReactNativeHapticFeedback.trigger('notificationSuccess');
    }
  }, [isMatching]);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.background }}>
      <StatusBar barStyle="light-content" backgroundColor={colors.surface} />
      <OfflineBanner isOffline={!isConnected} />
      <NavigationContainer>
        <Stack.Navigator
          screenOptions={{ headerStyle: { backgroundColor: colors.surface }, headerTintColor: colors.textPrimary }}
        >
          {!termsAccepted ? (
            <Stack.Screen name="Welcome" component={WelcomeScreen} options={{ headerShown: false }} />
          ) : (
            <>
              <Stack.Screen name="Matching" component={MatchingScreen} options={{ title: 'Matching' }} />
              <Stack.Screen
                name="Chat"
                component={ChatScreen}
                options={({ navigation }) => ({
                  title: 'Chat',
                  headerRight: () => (
                    <Pressable onPress={() => navigation.navigate('Settings')} style={{ paddingHorizontal: 8 }}>
                      <Text style={{ color: colors.textPrimary }}>Settings</Text>
                    </Pressable>
                  ),
                })}
              />
              <Stack.Screen name="Settings" component={SettingsScreen} options={{ title: 'Settings' }} />
            </>
          )}
        </Stack.Navigator>
      </NavigationContainer>
    </SafeAreaView>
  );
}
EOT

cat <<'EOT' > index.js
import 'react-native-gesture-handler';
import { AppRegistry } from 'react-native';
import App from './src/App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
EOT

cat <<'EOT' > babel.config.js
module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
  plugins: ['react-native-reanimated/plugin'],
};
EOT

echo "React Native app v2 scaffolded successfully in $APP_NAME"
