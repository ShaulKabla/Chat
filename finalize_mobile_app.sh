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
# Core dependencies
npm install \
  @react-native-async-storage/async-storage@1.21.0 \
  @react-navigation/native@6.1.18 \
  @react-navigation/native-stack@6.10.0 \
  @shopify/flash-list@1.7.2 \
  react-native-gesture-handler@2.17.0 \
  react-native-reanimated@3.12.1 \
  react-native-safe-area-context@4.10.5 \
  react-native-screens@3.32.0 \
  react-native-haptic-feedback@1.14.0 \
  react-native-image-picker@7.1.2 \
  react-native-fast-image@8.6.3 \
  react-native-device-info@10.13.2 \
  socket.io-client@4.7.5 \
  zustand@4.5.4 \
  lottie-react-native@6.7.2 \
  react-native-linear-gradient@2.8.3 \
  react-native-config@1.5.1

if command -v pod >/dev/null 2>&1; then
  (cd ios && pod install)
fi

mkdir -p \
  src/assets \
  src/components \
  src/config \
  src/screens \
  src/services \
  src/store \
  src/theme \
  src/types \
  src/utils \
  assets/fonts \
  assets/images \
  assets/lottie

cat <<'EOT' > assets/fonts/PLACEHOLDER.txt
Add your production fonts here (TTF/OTF). Example: Inter-Regular.ttf
EOT

cat <<'EOT' > assets/lottie/placeholder.json
{
  "v": "5.7.4",
  "fr": 30,
  "ip": 0,
  "op": 60,
  "w": 200,
  "h": 200,
  "nm": "placeholder",
  "ddd": 0,
  "assets": [],
  "layers": [
    {
      "ddd": 0,
      "ind": 1,
      "ty": 4,
      "nm": "ring",
      "sr": 1,
      "ks": {
        "o": { "a": 0, "k": 100 },
        "r": { "a": 1, "k": [
          { "t": 0, "s": 0 },
          { "t": 60, "s": 360 }
        ] },
        "p": { "a": 0, "k": [100, 100, 0] },
        "a": { "a": 0, "k": [0, 0, 0] },
        "s": { "a": 0, "k": [100, 100, 100] }
      },
      "shapes": [
        { "ty": "el", "p": { "a": 0, "k": [0, 0] }, "s": { "a": 0, "k": [120, 120] }, "nm": "Ellipse" },
        { "ty": "st", "c": { "a": 0, "k": [0.145, 0.827, 0.4, 1] }, "o": { "a": 0, "k": 100 }, "w": { "a": 0, "k": 8 }, "lc": 1, "lj": 1, "nm": "Stroke" }
      ],
      "ip": 0,
      "op": 60,
      "st": 0,
      "bm": 0
    }
  ]
}
EOT

printf '%s' "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==" | base64 -d > assets/images/placeholder.png

cat <<'EOT' > .env
API_URL=http://localhost:3000
TERMS_URL=https://example.com/terms
SOCKET_PING_INTERVAL=5000
SOCKET_BACKOFF_MAX_MS=15000
MAINTENANCE_MESSAGE=We are currently performing maintenance. Please check back soon.
EOT

cat <<'EOT' > .env.example
API_URL=http://localhost:3000
TERMS_URL=https://example.com/terms
SOCKET_PING_INTERVAL=5000
SOCKET_BACKOFF_MAX_MS=15000
MAINTENANCE_MESSAGE=We are currently performing maintenance. Please check back soon.
EOT

cat <<'EOT' > react-native.config.js
module.exports = {
  assets: ['./assets/fonts'],
};
EOT

cat <<'EOT' > src/config/Config.ts
import Config from 'react-native-config';

export const AppConfig = {
  apiUrl: Config.API_URL ?? 'http://localhost:3000',
  termsUrl: Config.TERMS_URL ?? 'https://example.com/terms',
  socketPingIntervalMs: Number(Config.SOCKET_PING_INTERVAL ?? '5000'),
  socketBackoffMaxMs: Number(Config.SOCKET_BACKOFF_MAX_MS ?? '15000'),
  maintenanceMessage:
    Config.MAINTENANCE_MESSAGE ?? 'We are currently performing maintenance. Please check back soon.',
};
EOT

cat <<'EOT' > src/theme/colors.ts
export const colors = {
  background: '#0B141A',
  surface: '#111B21',
  textPrimary: '#E9EDEF',
  textSecondary: '#9FB0BC',
  accent: '#25D366',
  accentSoft: '#2D6A4F',
  danger: '#EF4444',
  warning: '#F59E0B',
  border: '#202C33',
  card: '#1F2A30',
  gradientStart: '#0F172A',
  gradientEnd: '#111827',
};
EOT

cat <<'EOT' > src/utils/ids.ts
export const createAnonymousId = (): string => {
  return `anon_${Date.now()}_${Math.random().toString(16).slice(2)}`;
};
EOT

cat <<'EOT' > src/utils/messageUtils.ts
const IMAGE_URL_REGEX = /(https?:\/\/[^\s]+?\.(?:png|jpe?g|gif|webp|heic|heif))/i;

export const extractImageUrl = (text?: string): string | undefined => {
  if (!text) {
    return undefined;
  }

  const match = text.match(IMAGE_URL_REGEX);
  return match ? match[0] : undefined;
};

export const resolveMessageImage = (payload: {
  text?: string;
  image?: string;
  imageUrl?: string;
}): string | undefined => {
  return payload.imageUrl ?? payload.image ?? extractImageUrl(payload.text);
};
EOT

cat <<'EOT' > src/types/react-native-config.d.ts
declare module 'react-native-config' {
  export interface NativeConfig {
    API_URL?: string;
    TERMS_URL?: string;
    SOCKET_PING_INTERVAL?: string;
    SOCKET_BACKOFF_MAX_MS?: string;
    MAINTENANCE_MESSAGE?: string;
  }

  const Config: NativeConfig;
  export default Config;
}
EOT

cat <<'EOT' > src/types/chat.ts
export type MessageStatus = 'pending' | 'sent' | 'delivered' | 'failed';

export type ReplyReference = {
  id: string;
  text?: string;
  image?: string;
  userId: string;
};

export type ChatMessage = {
  id: string;
  serverId?: string;
  text: string;
  createdAt: number;
  userId: string;
  image?: string;
  status: MessageStatus;
  replyTo?: ReplyReference;
};
EOT

cat <<'EOT' > src/store/useChatStore.ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { createAnonymousId } from '../utils/ids';
import { ChatMessage, MessageStatus } from '../types/chat';

export type SystemNotice = {
  type: 'error' | 'warning';
  message: string;
};

export type ChatState = {
  userId: string;
  partnerId: string;
  isConnected: boolean;
  latencyMs: number | null;
  isMatching: boolean;
  messages: ChatMessage[];
  blockedUsers: string[];
  termsAccepted: boolean;
  maintenanceMode: boolean;
  maintenanceMessage: string;
  isPartnerTyping: boolean;
  systemNotice: SystemNotice | null;
  setConnection: (connected: boolean) => void;
  setLatency: (latency: number | null) => void;
  setPartner: (partnerId: string) => void;
  setMatching: (matching: boolean) => void;
  addMessage: (message: ChatMessage) => void;
  updateMessageStatus: (id: string, status: MessageStatus) => void;
  updateMessage: (id: string, updates: Partial<ChatMessage>) => void;
  setMessages: (messages: ChatMessage[]) => void;
  addBlockedUser: (userId: string) => void;
  acceptTerms: () => void;
  setMaintenance: (enabled: boolean, message?: string) => void;
  setPartnerTyping: (isTyping: boolean) => void;
  setSystemNotice: (notice: SystemNotice | null) => void;
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
      maintenanceMode: false,
      maintenanceMessage: '',
      isPartnerTyping: false,
      systemNotice: null,
      setConnection: connected => set({ isConnected: connected }),
      setLatency: latency => set({ latencyMs: latency }),
      setPartner: partnerId => set({ partnerId }),
      setMatching: matching => set({ isMatching: matching }),
      addMessage: message => set(state => ({ messages: [message, ...state.messages] })),
      updateMessageStatus: (id, status) =>
        set(state => ({
          messages: state.messages.map(message =>
            message.id === id ? { ...message, status } : message,
          ),
        })),
      updateMessage: (id, updates) =>
        set(state => ({
          messages: state.messages.map(message =>
            message.id === id ? { ...message, ...updates } : message,
          ),
        })),
      setMessages: messages => set({ messages }),
      addBlockedUser: userId =>
        set(state => ({ blockedUsers: [...new Set([...state.blockedUsers, userId])] })),
      acceptTerms: () => set({ termsAccepted: true }),
      setMaintenance: (enabled, message) =>
        set({ maintenanceMode: enabled, maintenanceMessage: message ?? '' }),
      setPartnerTyping: isTyping => set({ isPartnerTyping: isTyping }),
      setSystemNotice: notice => set({ systemNotice: notice }),
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
          maintenanceMode: false,
          maintenanceMessage: '',
          isPartnerTyping: false,
          systemNotice: null,
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

EOT

cat <<'EOT' > src/services/socketService.ts
import { io, Socket } from 'socket.io-client';
import DeviceInfo from 'react-native-device-info';
import { AppConfig } from '../config/Config';
import { useChatStore } from '../store/useChatStore';
import { ChatMessage } from '../types/chat';
import { resolveMessageImage } from '../utils/messageUtils';

const BASE_BACKOFF_MS = 1000;

type OutgoingPayload = {
  clientId: string;
  text: string;
  createdAt: number;
  userId: string;
  image?: string;
  replyTo?: ChatMessage['replyTo'];
};

class SocketService {
  private socket: Socket | null = null;
  private pingTimer: NodeJS.Timeout | null = null;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;
  private manuallyDisconnected = false;

  async connect() {
    const { userId, setConnection, setLatency, setPartner, setMatching, addMessage, setMaintenance, setPartnerTyping, setSystemNotice } =
      useChatStore.getState();

    const deviceId = await DeviceInfo.getUniqueId();

    this.socket = io(AppConfig.apiUrl, {
      transports: ['websocket'],
      autoConnect: false,
      reconnection: false,
      auth: { userId, deviceId },
    });

    this.socket.on('connect', () => {
      setConnection(true);
      this.reconnectAttempts = 0;
      this.clearReconnectTimer();
    });
    this.socket.on('disconnect', () => {
      setConnection(false);
      if (!this.manuallyDisconnected) {
        this.scheduleReconnect();
      }
    });
    this.socket.on('connect_error', (error: { message?: string }) => {
      setSystemNotice({ type: 'warning', message: error.message ?? 'Connection error' });
      this.scheduleReconnect();
    });
    this.socket.on('match_found', payload => {
      setPartner(payload.partnerId);
      setMatching(false);
    });
    this.socket.on('message', payload => {
      const image = resolveMessageImage(payload);
      const text = image && payload.text ? payload.text.replace(image, '').trim() : payload.text ?? '';
      const incoming: ChatMessage = {
        id: payload.clientId ?? payload.id,
        serverId: payload.id,
        text,
        createdAt: new Date(payload.createdAt).getTime(),
        userId: payload.userId,
        image,
        status: 'delivered',
        replyTo: payload.replyTo,
      };
      addMessage(incoming);
    });
    this.socket.on('message_delivered', payload => {
      if (payload?.clientId) {
        useChatStore.getState().updateMessageStatus(payload.clientId, 'delivered');
      }
    });
    this.socket.on('partner_left', () => {
      setPartner('');
      setMatching(true);
    });
    this.socket.on('typing', () => setPartnerTyping(true));
    this.socket.on('stop_typing', () => setPartnerTyping(false));
    this.socket.on('pong', (payload: { ts: number }) => {
      setLatency(Date.now() - payload.ts);
    });
    this.socket.on('ping', (payload?: { ts?: number }) => {
      this.socket?.emit('pong', { ts: payload?.ts ?? Date.now() });
    });
    this.socket.on('maintenance_mode', (payload?: { enabled?: boolean; message?: string }) => {
      const enabled = payload?.enabled ?? true;
      setMaintenance(enabled, payload?.message ?? AppConfig.maintenanceMessage);
      if (enabled) {
        setPartner('');
        setMatching(true);
      }
    });
    this.socket.on('auth_error', (payload?: { code?: string; message?: string }) => {
      setSystemNotice({
        type: 'error',
        message: payload?.message ?? 'Authentication error. Please sign in again.',
      });
    });
    this.socket.on('banned', (payload?: { message?: string }) => {
      setSystemNotice({ type: 'error', message: payload?.message ?? 'Account banned.' });
    });

    this.socket.connect();
    this.startPing();
  }

  findMatch() {
    this.socket?.emit('find_match');
  }

  sendMessage(message: OutgoingPayload) {
    if (!this.socket) {
      useChatStore.getState().updateMessageStatus(message.clientId, 'failed');
      return;
    }

    this.socket.emit('message', message, (ack?: { ok?: boolean; messageId?: string }) => {
      if (!ack?.ok) {
        useChatStore.getState().updateMessageStatus(message.clientId, 'failed');
        return;
      }

      useChatStore.getState().updateMessage(message.clientId, {
        status: 'sent',
        serverId: ack.messageId,
      });
    });
  }

  retryMessage(message: OutgoingPayload) {
    useChatStore.getState().updateMessageStatus(message.clientId, 'pending');
    this.sendMessage(message);
  }

  setTyping(isTyping: boolean) {
    if (!this.socket) {
      return;
    }
    this.socket.emit(isTyping ? 'typing' : 'stop_typing');
  }

  reportUser(payload: { reporterId: string; reportedId: string; reason: string }) {
    return fetch(`${AppConfig.apiUrl}/api/report`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  }

  blockUser(payload: { blockerId: string; blockedId: string }) {
    this.socket?.emit('block_user', payload);
  }

  disconnect() {
    this.manuallyDisconnected = true;
    this.stopPing();
    this.clearReconnectTimer();
    this.socket?.disconnect();
    this.socket = null;
  }

  private scheduleReconnect() {
    if (!this.socket) {
      return;
    }
    this.clearReconnectTimer();
    const jitter = Math.random() * 300;
    const delay = Math.min(BASE_BACKOFF_MS * 2 ** this.reconnectAttempts, AppConfig.socketBackoffMaxMs) + jitter;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectAttempts += 1;
      this.socket?.connect();
    }, delay);
  }

  private clearReconnectTimer() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  private startPing() {
    this.stopPing();
    this.pingTimer = setInterval(() => {
      this.socket?.emit('ping', { ts: Date.now() });
    }, AppConfig.socketPingIntervalMs);
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
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';
import { colors } from '../theme/colors';

export const PrimaryButton = ({ label, onPress }: { label: string; onPress: () => void }) => (
  <Pressable
    style={styles.button}
    onPress={() => {
      ReactNativeHapticFeedback.trigger('impactLight');
      onPress();
    }}
  >
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

cat <<'EOT' > src/components/MaintenanceBanner.tsx
import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { colors } from '../theme/colors';

export const MaintenanceBanner = ({ message }: { message: string }) => (
  <View style={styles.container}>
    <Text style={styles.title}>Maintenance Mode</Text>
    <Text style={styles.message}>{message}</Text>
  </View>
);

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    padding: 12,
  },
  title: {
    color: colors.warning,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 1,
    fontSize: 12,
  },
  message: {
    color: colors.textSecondary,
    marginTop: 4,
  },
});
EOT

cat <<'EOT' > src/screens/WelcomeScreen.tsx
import React, { useState } from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import LinearGradient from 'react-native-linear-gradient';
import LottieView from 'lottie-react-native';
import { colors } from '../theme/colors';
import { PrimaryButton } from '../components/PrimaryButton';
import { useChatStore } from '../store/useChatStore';

const brandAnimation = require('../../assets/lottie/placeholder.json');

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
    <LinearGradient colors={[colors.gradientStart, colors.gradientEnd]} style={styles.container}>
      <View style={styles.hero}>
        <LottieView source={brandAnimation} autoPlay loop style={styles.lottie} />
        <Text style={styles.title}>Anonymous Chat</Text>
        <Text style={styles.subtitle}>Connect instantly with a safe, respectful community.</Text>
      </View>
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
    </LinearGradient>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
    justifyContent: 'space-between',
  },
  hero: {
    marginTop: 32,
    alignItems: 'center',
    gap: 12,
  },
  lottie: {
    width: 160,
    height: 160,
  },
  title: { color: colors.textPrimary, fontSize: 28, fontWeight: '700' },
  subtitle: { color: colors.textSecondary, fontSize: 16, textAlign: 'center' },
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
import Animated, { useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';
import LottieView from 'lottie-react-native';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';
import { LatencyPill } from '../components/LatencyPill';

const matchingAnimation = require('../../assets/lottie/placeholder.json');

export const MatchingScreen = () => {
  const { latencyMs, isMatching, maintenanceMode } = useChatStore();
  const pulse = useSharedValue(0.7);

  useEffect(() => {
    if (!maintenanceMode) {
      socketService.findMatch();
    }
    pulse.value = withRepeat(withTiming(1, { duration: 900 }), -1, true);
  }, [maintenanceMode, pulse]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pulse.value }],
    opacity: pulse.value,
  }));

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{maintenanceMode ? 'Maintenance in progress' : 'Finding a partner'}</Text>
      <Animated.View style={[styles.orb, animatedStyle]} />
      <LottieView source={matchingAnimation} autoPlay loop style={styles.lottie} />
      <LatencyPill latency={latencyMs} />
      <Text style={styles.subtitle}>
        {isMatching
          ? 'Stay respectful. You can report or block anytime.'
          : 'Connecting you to a new conversation.'}
      </Text>
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
  lottie: {
    width: 140,
    height: 140,
  },
  subtitle: {
    marginTop: 8,
    textAlign: 'center',
    color: colors.textSecondary,
  },
});
EOT

cat <<'EOT' > src/screens/ChatScreen.tsx
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Alert, Linking, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { FlashList } from '@shopify/flash-list';
import FastImage from 'react-native-fast-image';
import { Swipeable } from 'react-native-gesture-handler';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { launchImageLibrary } from 'react-native-image-picker';
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';
import { AppConfig } from '../config/Config';
import { ChatMessage } from '../types/chat';

const TYPING_DEBOUNCE_MS = 1200;

const statusLabels: Record<ChatMessage['status'], string> = {
  pending: 'Sending',
  sent: 'Sent',
  delivered: 'Delivered',
  failed: 'Failed',
};

const MessageBubble = React.memo(
  ({
    message,
    isOwn,
    onReply,
    onRetry,
  }: {
    message: ChatMessage;
    isOwn: boolean;
    onReply: () => void;
    onRetry: () => void;
  }) => {
    const bubbleStyle = isOwn ? styles.bubbleOutgoing : styles.bubbleIncoming;
    const textStyle = isOwn ? styles.textOutgoing : styles.textIncoming;
    const replyLabel = message.replyTo?.text
      ? `↪ ${message.replyTo.text}`
      : message.replyTo?.image
        ? '↪ Photo'
        : undefined;

    return (
      <Swipeable
        renderLeftActions={() => (
          <View style={styles.replyAction}>
            <Text style={styles.replyActionText}>Reply</Text>
          </View>
        )}
        onSwipeableOpen={() => {
          ReactNativeHapticFeedback.trigger('impactLight');
          onReply();
        }}
      >
        <Animated.View entering={FadeInDown} style={[styles.messageRow, isOwn && styles.messageRowOwn]}>
          <View style={[styles.bubble, bubbleStyle]}>
            {replyLabel ? <Text style={styles.replyText}>{replyLabel}</Text> : null}
            {message.image ? (
              <FastImage source={{ uri: message.image }} style={styles.imageMessage} resizeMode={FastImage.resizeMode.cover} />
            ) : null}
            {message.text ? <Text style={[styles.messageText, textStyle]}>{message.text}</Text> : null}
            {isOwn ? (
              <View style={styles.statusRow}>
                <Text style={styles.statusText}>{statusLabels[message.status]}</Text>
                {message.status === 'failed' ? (
                  <Pressable onPress={onRetry} style={styles.retryButton}>
                    <Text style={styles.retryButtonText}>Retry</Text>
                  </Pressable>
                ) : null}
              </View>
            ) : null}
          </View>
        </Animated.View>
      </Swipeable>
    );
  },
);

MessageBubble.displayName = 'MessageBubble';

export const ChatScreen = () => {
  const {
    userId,
    partnerId,
    isConnected,
    messages,
    addMessage,
    addBlockedUser,
    maintenanceMode,
    isPartnerTyping,
    systemNotice,
    setSystemNotice,
  } = useChatStore();
  const [draft, setDraft] = useState('');
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const typingTimeout = useRef<NodeJS.Timeout | null>(null);

  const sortedMessages = useMemo(() => messages, [messages]);

  useEffect(() => () => socketService.setTyping(false), []);

  const sendMessage = useCallback(
    (payload: { text: string; image?: string }) => {
      const text = payload.text.trim();
      if (!text && !payload.image) {
        return;
      }

      const clientId = `client_${Date.now()}_${Math.random().toString(16).slice(2)}`;
      const message: ChatMessage = {
        id: clientId,
        text,
        createdAt: Date.now(),
        userId,
        image: payload.image,
        status: 'pending',
        replyTo: replyTo
          ? {
              id: replyTo.id,
              text: replyTo.text,
              image: replyTo.image,
              userId: replyTo.userId,
            }
          : undefined,
      };

      addMessage(message);
      socketService.sendMessage({
        clientId: message.id,
        text: message.text,
        createdAt: message.createdAt,
        userId: message.userId,
        image: message.image,
        replyTo: message.replyTo,
      });

      setDraft('');
      setReplyTo(null);
      socketService.setTyping(false);
    },
    [addMessage, replyTo, userId],
  );

  const handleImagePick = useCallback(async () => {
    const result = await launchImageLibrary({ mediaType: 'photo', selectionLimit: 1 });
    const asset = result.assets?.[0];
    if (!asset?.uri) {
      return;
    }

    sendMessage({ text: '', image: asset.uri });
  }, [sendMessage]);

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

  const handleTyping = useCallback(
    (text: string) => {
      setDraft(text);
      if (typingTimeout.current) {
        clearTimeout(typingTimeout.current);
      }
      if (text.length > 0) {
        socketService.setTyping(true);
        typingTimeout.current = setTimeout(() => socketService.setTyping(false), TYPING_DEBOUNCE_MS);
      } else {
        socketService.setTyping(false);
      }
    },
    [],
  );

  const renderItem = useCallback(
    ({ item }: { item: ChatMessage }) => {
      const isOwn = item.userId === userId;
      return (
        <MessageBubble
          message={item}
          isOwn={isOwn}
          onReply={() => setReplyTo(item)}
          onRetry={() =>
            socketService.retryMessage({
              clientId: item.id,
              text: item.text,
              createdAt: item.createdAt,
              userId,
              image: item.image,
              replyTo: item.replyTo,
            })
          }
        />
      );
    },
    [userId],
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>Anonymous Chat</Text>
          <Text style={styles.headerSubtitle}>Partner ID: {partnerId || 'Searching...'}</Text>
        </View>
        <View style={styles.headerActions}>
          <Pressable style={styles.headerButton} onPress={() => setSystemNotice(null)}>
            <Text style={styles.headerButtonText}>Clear</Text>
          </Pressable>
          <Pressable style={styles.headerButton} onPress={() => handleReport('Other')}>
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
      {maintenanceMode && (
        <View style={styles.maintenanceBanner}>
          <Text style={styles.maintenanceText}>Maintenance Mode · Messaging disabled</Text>
        </View>
      )}
      {systemNotice ? (
        <View style={styles.systemNotice}>
          <Text style={styles.systemNoticeText}>{systemNotice.message}</Text>
        </View>
      ) : null}
      <FlashList
        data={sortedMessages}
        inverted
        keyExtractor={item => item.id}
        renderItem={renderItem}
        estimatedItemSize={72}
        contentContainerStyle={styles.messageList}
      />
      {isPartnerTyping ? (
        <View style={styles.typingIndicator}>
          <Text style={styles.typingText}>Partner is typing...</Text>
        </View>
      ) : null}
      {replyTo ? (
        <View style={styles.replyPreview}>
          <Text style={styles.replyPreviewText} numberOfLines={1}>
            Replying to {replyTo.userId === userId ? 'yourself' : 'partner'}: {replyTo.text || 'Photo'}
          </Text>
          <Pressable onPress={() => setReplyTo(null)}>
            <Text style={styles.replyPreviewDismiss}>Dismiss</Text>
          </Pressable>
        </View>
      ) : null}
      <View style={styles.inputBar}>
        <Pressable style={styles.imageButton} onPress={handleImagePick}>
          <Text style={styles.imageButtonText}>＋</Text>
        </Pressable>
        <TextInput
          style={styles.input}
          value={draft}
          onChangeText={handleTyping}
          placeholder={maintenanceMode ? 'Maintenance in progress' : 'Type a message'}
          placeholderTextColor={colors.textSecondary}
          editable={!maintenanceMode}
          multiline
        />
        <Pressable
          style={[styles.sendButton, (!draft.trim() && !maintenanceMode) && styles.sendButtonMuted]}
          onPress={() => sendMessage({ text: draft })}
          disabled={maintenanceMode}
        >
          <Text style={styles.sendButtonText}>Send</Text>
        </Pressable>
      </View>
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          By chatting you agree to our
          <Text style={styles.link} onPress={() => Linking.openURL(AppConfig.termsUrl)}>
            {' '}Terms of Service
          </Text>
        </Text>
      </View>
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
    gap: 12,
  },
  headerTitle: { color: colors.textPrimary, fontSize: 18, fontWeight: '600' },
  headerSubtitle: { color: colors.textSecondary, fontSize: 12, marginTop: 4 },
  headerActions: { flexDirection: 'row', gap: 8, flexWrap: 'wrap', justifyContent: 'flex-end' },
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
  maintenanceBanner: { backgroundColor: colors.surface, padding: 8 },
  maintenanceText: { textAlign: 'center', color: colors.warning, fontWeight: '600' },
  systemNotice: {
    backgroundColor: '#1F2937',
    padding: 10,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  systemNoticeText: { color: colors.textSecondary, textAlign: 'center' },
  messageList: { paddingHorizontal: 16, paddingVertical: 12 },
  messageRow: { flexDirection: 'row', marginBottom: 12 },
  messageRowOwn: { justifyContent: 'flex-end' },
  bubble: {
    maxWidth: '80%',
    padding: 12,
    borderRadius: 16,
  },
  bubbleIncoming: { backgroundColor: colors.surface },
  bubbleOutgoing: { backgroundColor: colors.accentSoft },
  messageText: { fontSize: 15, lineHeight: 20 },
  textIncoming: { color: colors.textPrimary },
  textOutgoing: { color: '#E6FFFA' },
  imageMessage: { width: 220, height: 180, borderRadius: 12, marginBottom: 8 },
  replyText: { color: colors.textSecondary, fontSize: 12, marginBottom: 6 },
  statusRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: 6 },
  statusText: { color: colors.textSecondary, fontSize: 11 },
  retryButton: { paddingHorizontal: 8, paddingVertical: 2, borderRadius: 12, borderWidth: 1, borderColor: colors.warning },
  retryButtonText: { color: colors.warning, fontSize: 11 },
  replyAction: { justifyContent: 'center', paddingHorizontal: 12 },
  replyActionText: { color: colors.textSecondary },
  typingIndicator: { paddingHorizontal: 16, paddingBottom: 6 },
  typingText: { color: colors.textSecondary, fontSize: 12 },
  replyPreview: {
    backgroundColor: colors.surface,
    paddingVertical: 8,
    paddingHorizontal: 16,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  replyPreviewText: { color: colors.textSecondary, flex: 1, marginRight: 12 },
  replyPreviewDismiss: { color: colors.accent, fontSize: 12 },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 8,
    padding: 12,
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
  },
  input: {
    flex: 1,
    minHeight: 40,
    maxHeight: 120,
    color: colors.textPrimary,
    backgroundColor: colors.card,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  sendButton: {
    backgroundColor: colors.accent,
    borderRadius: 16,
    paddingVertical: 10,
    paddingHorizontal: 16,
  },
  sendButtonMuted: { opacity: 0.6 },
  sendButtonText: { color: '#0B141A', fontWeight: '700' },
  imageButton: {
    backgroundColor: colors.card,
    borderRadius: 16,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  imageButtonText: { color: colors.textPrimary, fontSize: 18 },
  footer: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
  },
  footerText: { color: colors.textSecondary, textAlign: 'center', fontSize: 12 },
  link: { color: colors.accent },
});
EOT

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
import { MaintenanceBanner } from './components/MaintenanceBanner';
import { ChatScreen } from './screens/ChatScreen';
import { MatchingScreen } from './screens/MatchingScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { WelcomeScreen } from './screens/WelcomeScreen';
import { socketService } from './services/socketService';
import { useChatStore } from './store/useChatStore';
import { colors } from './theme/colors';

const Stack = createNativeStackNavigator();

export default function App() {
  const { isConnected, isMatching, termsAccepted, maintenanceMode, maintenanceMessage } = useChatStore();

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
      {maintenanceMode && (
        <MaintenanceBanner message={maintenanceMessage || 'Maintenance in progress. Please try again soon.'} />
      )}
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

echo "React Native app finalized successfully in $APP_NAME"
