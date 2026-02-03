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
  i18next@23.12.2 \
  react-i18next@14.1.2 \
  react-native-gesture-handler@2.17.0 \
  react-native-reanimated@3.12.1 \
  react-native-safe-area-context@4.10.5 \
  react-native-screens@3.32.0 \
  react-native-haptic-feedback@1.14.0 \
  react-native-image-picker@7.1.2 \
  react-native-fast-image@8.6.3 \
  react-native-device-info@10.13.2 \
  react-native-localize@3.1.0 \
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
  src/i18n \
  src/locales \
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

cat <<'EOT' > assets/lottie/searching.json
{
  "v": "5.7.4",
  "fr": 30,
  "ip": 0,
  "op": 90,
  "w": 200,
  "h": 200,
  "nm": "searching",
  "ddd": 0,
  "assets": [],
  "layers": [
    {
      "ddd": 0,
      "ind": 1,
      "ty": 4,
      "nm": "pulse",
      "sr": 1,
      "ks": {
        "o": { "a": 0, "k": 100 },
        "r": { "a": 0, "k": 0 },
        "p": { "a": 0, "k": [100, 100, 0] },
        "a": { "a": 0, "k": [0, 0, 0] },
        "s": { "a": 1, "k": [
          { "t": 0, "s": [80, 80, 100] },
          { "t": 45, "s": [110, 110, 100] },
          { "t": 90, "s": [80, 80, 100] }
        ] }
      },
      "shapes": [
        { "ty": "el", "p": { "a": 0, "k": [0, 0] }, "s": { "a": 0, "k": [120, 120] }, "nm": "Ellipse" },
        { "ty": "st", "c": { "a": 0, "k": [0.2, 0.6, 1, 1] }, "o": { "a": 0, "k": 100 }, "w": { "a": 0, "k": 6 }, "lc": 1, "lj": 1, "nm": "Stroke" }
      ],
      "ip": 0,
      "op": 90,
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
  maintenanceMessage: Config.MAINTENANCE_MESSAGE ?? '',
};
EOT

cat <<'EOT' > src/locales/en.json
{
  "app": {
    "name": "Anonymous Chat",
    "tagline": "Connect instantly with a safe, respectful community."
  },
  "welcome": {
    "start": "Start Matching"
  },
  "terms": {
    "title": "Terms & Privacy",
    "body": "By continuing you agree to our Terms of Service and Privacy Policy. Respectful conduct is required. You may report or block users at any time.",
    "agree": "I Agree",
    "later": "Not now"
  },
  "mode": {
    "title": "Choose your vibe",
    "justTalk": "Just Talk",
    "justTalkDesc": "Instant random chat with anyone online.",
    "letsMeet": "Let's Meet",
    "letsMeetDesc": "Match by gender preference and shared interests.",
    "switch": "Switch Mode"
  },
  "matching": {
    "finding": "Finding a partner",
    "maintenance": "Server busy",
    "respect": "Stay respectful. You can report or block anytime.",
    "connecting": "Connecting you to a new conversation.",
    "friends": "Friends"
  },
  "chat": {
    "title": "Anonymous Chat",
    "searching": "Searching for a partner...",
    "clear": "Clear",
    "skip": "Skip",
    "report": "Report",
    "connect": "Connect",
    "connectRequest": "Partner wants to connect",
    "connectAccept": "Accept",
    "block": "Block",
    "offline": "Offline · Messages will send when reconnected",
    "maintenance": "Maintenance Mode · Messaging disabled",
    "typing": "Partner is typing...",
    "reply": "Reply",
    "replyingTo": "Replying to {{name}}: {{preview}}",
    "dismiss": "Dismiss",
    "inputPlaceholder": "Type a message",
    "maintenancePlaceholder": "Maintenance in progress",
    "send": "Send",
    "addPhoto": "＋",
    "tapToReveal": "Reveal after 7 minutes",
    "photoHidden": "Hidden until reveal",
    "revealAvailable": "Reveal available",
    "revealButton": "Reveal",
    "revealCountdown": "Reveal in {{time}}",
    "revealWaiting": "Reveal after 7 minutes of chat",
    "revealTitle": "7-Minute Reveal",
    "termsPrefix": "By chatting you agree to our",
    "termsLink": "Terms of Service",
    "status": {
      "pending": "Sending",
      "sent": "Sent",
      "delivered": "Delivered",
      "failed": "Failed"
    },
    "retry": "Retry"
  },
  "profile": {
    "title": "Build Your Profile",
    "subtitle": "Complete this once to unlock Meet matches.",
    "gender": "Gender",
    "ageGroup": "Age Group",
    "interestedIn": "Interested In",
    "interests": "Top 3 Interests",
    "interestPlaceholder": "Interest #{{index}}",
    "save": "Save Profile",
    "error": "Please select gender, age group, and enter 3 interests.",
    "ageGroups": {
      "18_24": "18-24",
      "25_34": "25-34",
      "35_44": "35-44",
      "45_plus": "45+"
    },
    "genders": {
      "woman": "Woman",
      "man": "Man",
      "nonbinary": "Non-binary",
      "any": "Any"
    }
  },
  "friends": {
    "title": "Friends",
    "refresh": "Refresh",
    "empty": "No friends yet. Send a connect request in chat.",
    "profilePending": "Profile pending",
    "startConversation": "Start a conversation"
  },
  "friendChat": {
    "title": "Friend Chat",
    "placeholder": "Message your friend"
  },
  "settings": {
    "title": "Blocked Users",
    "empty": "No blocked users yet.",
    "delete": "Delete My Account/Data",
    "language": "Language",
    "languageEN": "English",
    "languageHE": "Hebrew",
    "languagePrompt": "Language changed. Please restart the app to apply RTL layout."
  },
  "system": {
    "offline": "Offline · Trying to reconnect",
    "maintenanceTitle": "Maintenance Mode",
    "defaultMaintenance": "We are currently performing maintenance. Please check back soon."
  },
  "notifications": {
    "profileRequired": "Complete your profile to start matching.",
    "authError": "Authentication error. Please sign in again.",
    "banned": "Account banned.",
    "rateLimited": "Too many requests. Please wait."
  },
  "errors": {
    "registerFailed": "Failed to register.",
    "connectionError": "Connection error",
    "uploadFailed": "Upload failed",
    "saveProfile": "Failed to save profile",
    "loadFriends": "Failed to load friends",
    "loadMessages": "Failed to load messages",
    "sendMessage": "Failed to send message"
  },
  "misc": {
    "latencyUnknown": "—",
    "latencyMs": "{{value}}ms",
    "you": "yourself",
    "partner": "partner",
    "photo": "Photo"
  },
  "actions": {
    "cancel": "Cancel",
    "block": "Block",
    "blockTitle": "Block user",
    "blockConfirm": "Are you sure you want to block this user?",
    "reportReason": "Other",
    "deleteDataTitle": "Delete data",
    "deleteDataBody": "This will erase your chat history and account data."
  }
}
EOT

cat <<'EOT' > src/locales/he.json
{
  "app": {
    "name": "Anonymous Chat",
    "tagline": "Connect instantly with a safe, respectful community."
  },
  "welcome": {
    "start": "Start Matching"
  },
  "terms": {
    "title": "Terms & Privacy",
    "body": "By continuing you agree to our Terms of Service and Privacy Policy. Respectful conduct is required. You may report or block users at any time.",
    "agree": "I Agree",
    "later": "Not now"
  },
  "mode": {
    "title": "Choose your vibe",
    "justTalk": "Just Talk",
    "justTalkDesc": "Instant random chat with anyone online.",
    "letsMeet": "Let's Meet",
    "letsMeetDesc": "Match by gender preference and shared interests.",
    "switch": "Switch Mode"
  },
  "matching": {
    "finding": "Finding a partner",
    "maintenance": "Server busy",
    "respect": "Stay respectful. You can report or block anytime.",
    "connecting": "Connecting you to a new conversation.",
    "friends": "Friends"
  },
  "chat": {
    "title": "Anonymous Chat",
    "searching": "Searching for a partner...",
    "clear": "Clear",
    "skip": "Skip",
    "report": "Report",
    "connect": "Connect",
    "connectRequest": "Partner wants to connect",
    "connectAccept": "Accept",
    "block": "Block",
    "offline": "Offline · Messages will send when reconnected",
    "maintenance": "Maintenance Mode · Messaging disabled",
    "typing": "Partner is typing...",
    "reply": "Reply",
    "replyingTo": "Replying to {{name}}: {{preview}}",
    "dismiss": "Dismiss",
    "inputPlaceholder": "Type a message",
    "maintenancePlaceholder": "Maintenance in progress",
    "send": "Send",
    "addPhoto": "＋",
    "tapToReveal": "Reveal after 7 minutes",
    "photoHidden": "Hidden until reveal",
    "revealAvailable": "Reveal available",
    "revealButton": "Reveal",
    "revealCountdown": "Reveal in {{time}}",
    "revealWaiting": "Reveal after 7 minutes of chat",
    "revealTitle": "7-Minute Reveal",
    "termsPrefix": "By chatting you agree to our",
    "termsLink": "Terms of Service",
    "status": {
      "pending": "Sending",
      "sent": "Sent",
      "delivered": "Delivered",
      "failed": "Failed"
    },
    "retry": "Retry"
  },
  "profile": {
    "title": "Build Your Profile",
    "subtitle": "Complete this once to unlock Meet matches.",
    "gender": "Gender",
    "ageGroup": "Age Group",
    "interestedIn": "Interested In",
    "interests": "Top 3 Interests",
    "interestPlaceholder": "Interest #{{index}}",
    "save": "Save Profile",
    "error": "Please select gender, age group, and enter 3 interests.",
    "ageGroups": {
      "18_24": "18-24",
      "25_34": "25-34",
      "35_44": "35-44",
      "45_plus": "45+"
    },
    "genders": {
      "woman": "Woman",
      "man": "Man",
      "nonbinary": "Non-binary",
      "any": "Any"
    }
  },
  "friends": {
    "title": "Friends",
    "refresh": "Refresh",
    "empty": "No friends yet. Send a connect request in chat.",
    "profilePending": "Profile pending",
    "startConversation": "Start a conversation"
  },
  "friendChat": {
    "title": "Friend Chat",
    "placeholder": "Message your friend"
  },
  "settings": {
    "title": "Blocked Users",
    "empty": "No blocked users yet.",
    "delete": "Delete My Account/Data",
    "language": "Language",
    "languageEN": "English",
    "languageHE": "Hebrew",
    "languagePrompt": "Language changed. Please restart the app to apply RTL layout."
  },
  "system": {
    "offline": "Offline · Trying to reconnect",
    "maintenanceTitle": "Maintenance Mode",
    "defaultMaintenance": "We are currently performing maintenance. Please check back soon."
  },
  "notifications": {
    "profileRequired": "Complete your profile to start matching.",
    "authError": "Authentication error. Please sign in again.",
    "banned": "Account banned.",
    "rateLimited": "Too many requests. Please wait."
  },
  "errors": {
    "registerFailed": "Failed to register.",
    "connectionError": "Connection error",
    "uploadFailed": "Upload failed",
    "saveProfile": "Failed to save profile",
    "loadFriends": "Failed to load friends",
    "loadMessages": "Failed to load messages",
    "sendMessage": "Failed to send message"
  },
  "misc": {
    "latencyUnknown": "—",
    "latencyMs": "{{value}}ms",
    "you": "yourself",
    "partner": "partner",
    "photo": "Photo"
  },
  "actions": {
    "cancel": "Cancel",
    "block": "Block",
    "blockTitle": "Block user",
    "blockConfirm": "Are you sure you want to block this user?",
    "reportReason": "Other",
    "deleteDataTitle": "Delete data",
    "deleteDataBody": "This will erase your chat history and account data."
  }
}
EOT

cat <<'EOT' > src/i18n/index.ts
import { I18nManager } from 'react-native';
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from '../locales/en.json';
import he from '../locales/he.json';

export type SupportedLanguage = 'en' | 'he';

const resources = {
  en: { translation: en },
  he: { translation: he },
};

const isRtlLanguage = (language: SupportedLanguage) => language === 'he';

export const setI18nLanguage = async (language: SupportedLanguage) => {
  await i18n.changeLanguage(language);
  const shouldBeRTL = isRtlLanguage(language);
  if (I18nManager.isRTL !== shouldBeRTL) {
    I18nManager.allowRTL(shouldBeRTL);
    I18nManager.forceRTL(shouldBeRTL);
  }
};

i18n.use(initReactI18next).init({
  compatibilityJSON: 'v3',
  fallbackLng: 'en',
  lng: 'en',
  resources,
  interpolation: { escapeValue: false },
});

export default i18n;
EOT

cat <<'EOT' > src/theme/colors.ts
export const colors = {
  background: '#0A0A12',
  surface: '#121428',
  textPrimary: '#F5F7FF',
  textSecondary: '#9AA3C7',
  accent: '#7CFFB2',
  accentSoft: '#1E2F3A',
  accentGlow: '#5BE7FF',
  danger: '#FF5F7A',
  warning: '#FBBF24',
  border: '#1E233C',
  card: '#151A33',
  gradientStart: '#0B0F1E',
  gradientEnd: '#131B2D',
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

export const normalizeImageUrl = (url?: string, baseUrl?: string): string | undefined => {
  if (!url) {
    return undefined;
  }
  if (baseUrl && url.startsWith('/')) {
    return `${baseUrl}${url}`;
  }
  return url;
};

export const resolveMessageImage = (
  payload: {
    text?: string;
    image?: string;
    imageUrl?: string;
  },
  baseUrl?: string,
): string | undefined => {
  const raw = payload.imageUrl ?? payload.image ?? extractImageUrl(payload.text);
  return normalizeImageUrl(raw, baseUrl);
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
export type MatchMode = 'talk' | 'meet';

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
  imageSource?: string;
  imagePending?: boolean;
  status: MessageStatus;
  replyTo?: ReplyReference;
};

export type UserProfile = {
  userId: string;
  gender: string;
  ageGroup: string;
  interests: string[];
  genderPreference: string;
};

export type FriendSummary = {
  friendId: string;
  gender?: string;
  ageGroup?: string;
  interests?: string[];
  lastMessage?: string;
};

export type FriendMessage = {
  id: string;
  senderId: string;
  recipientId: string;
  body: string;
  imageUrl?: string | null;
  createdAt: string;
};
EOT

cat <<'EOT' > src/store/useChatStore.ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import * as RNLocalize from 'react-native-localize';
import { createAnonymousId } from '../utils/ids';
import { ChatMessage, FriendMessage, FriendSummary, MatchMode, MessageStatus, UserProfile } from '../types/chat';

const defaultLanguage = RNLocalize.getLocales()[0]?.languageCode === 'he' ? 'he' : 'en';

export type SystemNotice = {
  type: 'error' | 'warning';
  message: string;
};

export type ChatState = {
  userId: string;
  authToken: string;
  profile: UserProfile | null;
  partnerProfile: UserProfile | null;
  profileComplete: boolean;
  partnerId: string;
  matchMode: MatchMode;
  modeSelected: boolean;
  isConnected: boolean;
  latencyMs: number | null;
  isMatching: boolean;
  revealAvailable: boolean;
  revealConfirmed: boolean;
  revealAt: number | null;
  messages: ChatMessage[];
  blockedUsers: string[];
  termsAccepted: boolean;
  language: 'en' | 'he';
  maintenanceMode: boolean;
  maintenanceMessage: string;
  isPartnerTyping: boolean;
  systemNotice: SystemNotice | null;
  friends: FriendSummary[];
  friendMessages: Record<string, FriendMessage[]>;
  pendingConnectRequest: string | null;
  setConnection: (connected: boolean) => void;
  setLatency: (latency: number | null) => void;
  setUserId: (userId: string) => void;
  setAuthToken: (token: string) => void;
  setProfile: (profile: UserProfile | null) => void;
  setPartnerProfile: (profile: UserProfile | null) => void;
  setProfileComplete: (complete: boolean) => void;
  setPartner: (partnerId: string) => void;
  setMatchMode: (mode: MatchMode) => void;
  setModeSelected: (selected: boolean) => void;
  setMatching: (matching: boolean) => void;
  setRevealAvailable: (available: boolean) => void;
  setRevealConfirmed: (confirmed: boolean) => void;
  setRevealAt: (revealAt: number | null) => void;
  addMessage: (message: ChatMessage) => void;
  updateMessageStatus: (id: string, status: MessageStatus) => void;
  updateMessage: (id: string, updates: Partial<ChatMessage>) => void;
  updateMessageByServerId: (serverId: string, updates: Partial<ChatMessage>) => void;
  setMessages: (messages: ChatMessage[]) => void;
  addBlockedUser: (userId: string) => void;
  acceptTerms: () => void;
  setLanguage: (language: 'en' | 'he') => void;
  setMaintenance: (enabled: boolean, message?: string) => void;
  setPartnerTyping: (isTyping: boolean) => void;
  setSystemNotice: (notice: SystemNotice | null) => void;
  setPendingConnectRequest: (userId: string | null) => void;
  setFriends: (friends: FriendSummary[]) => void;
  setFriendMessages: (friendId: string, messages: FriendMessage[]) => void;
  addFriendMessage: (friendId: string, message: FriendMessage) => void;
  resetAll: () => void;
};

export const useChatStore = create<ChatState>()(
  persist(
    set => ({
      userId: createAnonymousId(),
      authToken: '',
      profile: null,
      partnerProfile: null,
      profileComplete: false,
      partnerId: '',
      matchMode: 'talk',
      modeSelected: false,
      isConnected: true,
      latencyMs: null,
      isMatching: true,
      revealAvailable: false,
      revealConfirmed: false,
      revealAt: null,
      messages: [],
      blockedUsers: [],
      termsAccepted: false,
      language: defaultLanguage,
      maintenanceMode: false,
      maintenanceMessage: '',
      isPartnerTyping: false,
      systemNotice: null,
      friends: [],
      friendMessages: {},
      pendingConnectRequest: null,
      setConnection: connected => set({ isConnected: connected }),
      setLatency: latency => set({ latencyMs: latency }),
      setUserId: userId => set({ userId }),
      setAuthToken: token => set({ authToken: token }),
      setProfile: profile => set({ profile, profileComplete: Boolean(profile) }),
      setPartnerProfile: profile => set({ partnerProfile: profile }),
      setProfileComplete: complete => set({ profileComplete: complete }),
      setPartner: partnerId => set({ partnerId }),
      setMatchMode: mode => set({ matchMode: mode, modeSelected: true }),
      setModeSelected: selected => set({ modeSelected: selected }),
      setMatching: matching => set({ isMatching: matching }),
      setRevealAvailable: available => set({ revealAvailable: available }),
      setRevealConfirmed: confirmed => set({ revealConfirmed: confirmed }),
      setRevealAt: revealAt => set({ revealAt }),
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
      updateMessageByServerId: (serverId, updates) =>
        set(state => ({
          messages: state.messages.map(message =>
            message.serverId === serverId ? { ...message, ...updates } : message,
          ),
        })),
      setMessages: messages => set({ messages }),
      addBlockedUser: userId =>
        set(state => ({ blockedUsers: [...new Set([...state.blockedUsers, userId])] })),
      acceptTerms: () => set({ termsAccepted: true }),
      setLanguage: language => set({ language }),
      setMaintenance: (enabled, message) =>
        set({ maintenanceMode: enabled, maintenanceMessage: message ?? '' }),
      setPartnerTyping: isTyping => set({ isPartnerTyping: isTyping }),
      setSystemNotice: notice => set({ systemNotice: notice }),
      setPendingConnectRequest: userId => set({ pendingConnectRequest: userId }),
      setFriends: friends => set({ friends }),
      setFriendMessages: (friendId, messages) =>
        set(state => ({ friendMessages: { ...state.friendMessages, [friendId]: messages } })),
      addFriendMessage: (friendId, message) =>
        set(state => ({
          friendMessages: {
            ...state.friendMessages,
            [friendId]: [message, ...(state.friendMessages[friendId] || [])],
          },
        })),
      resetAll: () =>
        set({
          userId: createAnonymousId(),
          authToken: '',
          profile: null,
          partnerProfile: null,
          profileComplete: false,
          partnerId: '',
          matchMode: 'talk',
          modeSelected: false,
          isConnected: true,
          latencyMs: null,
          isMatching: true,
          revealAvailable: false,
          revealConfirmed: false,
          revealAt: null,
          messages: [],
          blockedUsers: [],
          termsAccepted: false,
          language: defaultLanguage,
          maintenanceMode: false,
          maintenanceMessage: '',
          isPartnerTyping: false,
          systemNotice: null,
          friends: [],
          friendMessages: {},
          pendingConnectRequest: null,
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
        authToken: state.authToken,
        profile: state.profile,
        profileComplete: state.profileComplete,
        messages: state.messages,
        blockedUsers: state.blockedUsers,
        termsAccepted: state.termsAccepted,
        matchMode: state.matchMode,
        modeSelected: state.modeSelected,
        language: state.language,
      }),
    },
  ),
);
EOT

cat <<'EOT' > src/services/socketService.ts
import { io, Socket } from 'socket.io-client';
import DeviceInfo from 'react-native-device-info';
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';
import i18n from '../i18n';
import { AppConfig } from '../config/Config';
import { useChatStore } from '../store/useChatStore';
import { ChatMessage, MatchMode } from '../types/chat';
import { normalizeImageUrl, resolveMessageImage } from '../utils/messageUtils';

const BASE_BACKOFF_MS = 1000;

const buildHeaders = (token?: string, contentType?: string) => {
  const language = useChatStore.getState().language;
  return {
    ...(contentType ? { 'Content-Type': contentType } : {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    'Accept-Language': language,
  };
};

type OutgoingPayload = {
  clientId: string;
  text: string;
  createdAt: number;
  userId: string;
  image?: string;
  imagePreview?: string;
  imageSource?: string;
  replyTo?: ChatMessage['replyTo'];
};

class SocketService {
  private socket: Socket | null = null;
  private pingTimer: NodeJS.Timeout | null = null;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;
  private manuallyDisconnected = false;
  private authFailed = false;

  async connect() {
    const {
      authToken,
      language,
      setUserId,
      setAuthToken,
      setConnection,
      setLatency,
      setPartner,
      setPartnerProfile,
      setMatchMode,
      setMatching,
      setRevealAvailable,
      setRevealConfirmed,
      setRevealAt,
      setMessages,
      addMessage,
      setMaintenance,
      setPartnerTyping,
      setSystemNotice,
      setProfile,
      setProfileComplete,
      setPendingConnectRequest,
      addFriendMessage,
    } = useChatStore.getState();

    const deviceId = await DeviceInfo.getUniqueId();

    let token = authToken;
    if (!token) {
      try {
        const response = await fetch(`${AppConfig.apiUrl}/api/auth/anonymous`, {
          method: 'POST',
          headers: buildHeaders(undefined, 'application/json'),
          body: JSON.stringify({ fcmToken: deviceId }),
        });
        const data = await response.json();
        if (!response.ok || !data?.token) {
          throw new Error(data?.error || i18n.t('errors.registerFailed'));
        }
        token = data.token;
        setUserId(data.userId);
        setAuthToken(token);
      } catch (error) {
        const message = error instanceof Error ? error.message : i18n.t('errors.registerFailed');
        setSystemNotice({ type: 'error', message });
        return;
      }
    }

    this.socket = io(AppConfig.apiUrl, {
      transports: ['websocket'],
      autoConnect: false,
      reconnection: false,
      auth: { token, lang: language },
    });

    this.socket.on('connect', () => {
      setConnection(true);
      this.reconnectAttempts = 0;
      this.authFailed = false;
      this.clearReconnectTimer();
    });
    this.socket.on('disconnect', () => {
      setConnection(false);
      if (!this.manuallyDisconnected && !this.authFailed) {
        this.scheduleReconnect();
      }
    });
    this.socket.on('connect_error', (error: { message?: string }) => {
      setSystemNotice({ type: 'warning', message: error.message ?? i18n.t('errors.connectionError') });
      if (!this.authFailed) {
        this.scheduleReconnect();
      }
    });
    this.socket.on('user:id', payload => {
      if (payload?.userId) {
        setUserId(payload.userId);
      }
    });
    this.socket.on('user:id', payload => {
      if (payload?.userId) {
        setUserId(payload.userId);
      }
    });
    this.socket.on('match_found', payload => {
      setPartner(payload.partnerId);
      setMatchMode(payload?.mode === 'meet' ? 'meet' : 'talk');
      setRevealAvailable(Boolean(payload?.revealAvailable));
      setRevealConfirmed(false);
      setRevealAt(null);
      setPendingConnectRequest(null);
      setMessages([]);
      ReactNativeHapticFeedback.trigger('impactHeavy');
      if (payload?.partnerProfile) {
        setPartnerProfile({
          userId: payload.partnerId,
          gender: payload.partnerProfile.gender ?? '',
          ageGroup: payload.partnerProfile.ageGroup ?? '',
          interests: payload.partnerProfile.interests ?? [],
          genderPreference: payload.partnerProfile.genderPreference ?? 'any',
        });
      } else {
        setPartnerProfile(null);
      }
      setMatching(false);
    });
    this.socket.on('match_searching', payload => {
      setPartner('');
      setPartnerProfile(null);
      setMatching(true);
      setRevealAvailable(false);
      setRevealConfirmed(false);
      setRevealAt(null);
      setPendingConnectRequest(null);
      setMessages([]);
      if (payload?.message) {
        setSystemNotice({ type: 'warning', message: payload.message });
      }
    });
    this.socket.on('message', payload => {
      const image = payload?.image ? resolveMessageImage(payload, AppConfig.apiUrl) : undefined;
      const text = image && payload.text ? payload.text.replace(image, '').trim() : payload.text ?? '';
      const incoming: ChatMessage = {
        id: payload.clientId ?? payload.id,
        serverId: payload.id,
        text,
        createdAt: new Date(payload.createdAt).getTime(),
        userId: payload.userId,
        image,
        imagePending: Boolean(payload?.imagePending),
        status: 'delivered',
        replyTo: payload.replyTo,
      };
      addMessage(incoming);
    });
    this.socket.on('message_ack', payload => {
      if (!payload?.clientId) {
        return;
      }
      const status = payload.status === 'delivered' ? 'delivered' : 'sent';
      useChatStore.getState().updateMessage(payload.clientId, {
        status,
        serverId: payload.messageId,
      });
    });
    this.socket.on('partner_left', payload => {
      setPartner('');
      setPartnerProfile(null);
      setMatching(true);
      setRevealAvailable(false);
      setRevealConfirmed(false);
      setRevealAt(null);
      setPendingConnectRequest(null);
      setMessages([]);
      if (payload?.systemMessage) {
        setSystemNotice({ type: 'warning', message: payload.systemMessage });
      }
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
      const maintenanceMessage = payload?.message ?? AppConfig.maintenanceMessage ?? i18n.t('system.defaultMaintenance');
      setMaintenance(enabled, maintenanceMessage);
      if (enabled) {
        setPartner('');
        setPartnerProfile(null);
        setMatching(false);
        setRevealAvailable(false);
        setRevealConfirmed(false);
      } else {
        setMatching(true);
      }
    });
    this.socket.on('profile_required', (payload?: { message?: string }) => {
      setProfileComplete(false);
      setSystemNotice({ type: 'warning', message: payload?.message ?? i18n.t('notifications.profileRequired') });
    });
    this.socket.on('auth_error', (payload?: { code?: string; message?: string }) => {
      setSystemNotice({
        type: 'error',
        message: payload?.message ?? i18n.t('notifications.authError'),
      });
      this.authFailed = true;
      this.manuallyDisconnected = true;
      this.clearReconnectTimer();
      this.socket?.disconnect();
    });
    this.socket.on('banned', (payload?: { message?: string }) => {
      setSystemNotice({ type: 'error', message: payload?.message ?? i18n.t('notifications.banned') });
      this.authFailed = true;
      this.manuallyDisconnected = true;
      this.clearReconnectTimer();
      this.socket?.disconnect();
    });
    this.socket.on('rate_limit', () => {
      setSystemNotice({ type: 'warning', message: i18n.t('notifications.rateLimited') });
    });
    this.socket.on('rate_limit_reached', () => {
      setSystemNotice({ type: 'warning', message: i18n.t('notifications.rateLimited') });
    });
    this.socket.on('connect_request', payload => {
      if (payload?.userId) {
        setPendingConnectRequest(payload.userId);
      }
    });
    this.socket.on('friend_added', payload => {
      setPendingConnectRequest(null);
      if (payload?.friendId) {
        this.loadFriends().catch(() => {});
      }
    });
    this.socket.on('reveal_available', () => {
      setRevealAvailable(true);
    });
    this.socket.on('reveal_timer_started', payload => {
      if (payload?.revealAt) {
        setRevealAt(payload.revealAt);
      }
    });
    this.socket.on('reveal_confirmed', () => {
      setRevealConfirmed(true);
      setRevealAt(null);
    });
    this.socket.on('reveal_granted', () => {
      ReactNativeHapticFeedback.trigger('notificationSuccess');
    });
    this.socket.on('source_revealed', payload => {
      if (payload?.images?.length) {
        payload.images.forEach((entry: { messageId: string; imageUrl: string }) => {
          useChatStore.getState().updateMessageByServerId(entry.messageId, {
            image: normalizeImageUrl(entry.imageUrl, AppConfig.apiUrl),
            imagePending: false,
          });
        });
      }
    });
    this.socket.on('search_expanding', payload => {
      if (payload?.message) {
        setSystemNotice({ type: 'warning', message: payload.message });
      }
    });
    this.socket.on('friend_message', payload => {
      if (!payload?.senderId || !payload?.recipientId) {
        return;
      }
      const friendId = payload.senderId;
      addFriendMessage(friendId, {
        id: String(payload.id),
        senderId: payload.senderId,
        recipientId: payload.recipientId,
        body: payload.body ?? '',
        imageUrl: payload.imageUrl ?? null,
        createdAt: payload.createdAt,
      });
    });

    this.socket.connect();
    this.startPing();

    this.loadProfile().then(profile => {
      setProfile(profile);
      setProfileComplete(Boolean(profile));
    });
    this.loadFriends().catch(() => {});
  }

  findMatch(mode: MatchMode) {
    this.socket?.emit('find_match', { mode });
  }

  skipMatch() {
    const {
      setPartner,
      setPartnerProfile,
      setMatching,
      setMessages,
      setRevealAvailable,
      setRevealConfirmed,
      setRevealAt,
    } = useChatStore.getState();
    setPartner('');
    setPartnerProfile(null);
    setMatching(true);
    setRevealAvailable(false);
    setRevealConfirmed(false);
    setRevealAt(null);
    setMessages([]);
    this.socket?.emit('skip');
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
    const token = useChatStore.getState().authToken;
    return fetch(`${AppConfig.apiUrl}/api/report`, {
      method: 'POST',
      headers: buildHeaders(token, 'application/json'),
      body: JSON.stringify(payload),
    });
  }

  async loadProfile() {
    const token = useChatStore.getState().authToken;
    const response = await fetch(`${AppConfig.apiUrl}/api/profile`, {
      headers: buildHeaders(token),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      return null;
    }
    return this.mapProfile(data.profile);
  }

  async saveProfile(payload: {
    gender: string;
    ageGroup: string;
    interests: string[];
    genderPreference?: string;
  }) {
    const token = useChatStore.getState().authToken;
    const response = await fetch(`${AppConfig.apiUrl}/api/profile`, {
      method: 'POST',
      headers: buildHeaders(token, 'application/json'),
      body: JSON.stringify(payload),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data?.error || i18n.t('errors.saveProfile'));
    }
    const profile = this.mapProfile(data.profile);
    useChatStore.getState().setProfile(profile);
    useChatStore.getState().setProfileComplete(Boolean(profile));
    return profile;
  }

  async loadFriends() {
    const token = useChatStore.getState().authToken;
    const response = await fetch(`${AppConfig.apiUrl}/api/friends`, {
      headers: buildHeaders(token),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data?.error || i18n.t('errors.loadFriends'));
    }
    const friends = (data.friends || []).map((friend: any) => ({
      friendId: friend.friend_id,
      gender: friend.gender,
      ageGroup: friend.age_group,
      interests: friend.interests,
      lastMessage: friend.last_message,
    }));
    useChatStore.getState().setFriends(friends);
    return friends;
  }

  async loadFriendMessages(friendId: string) {
    const token = useChatStore.getState().authToken;
    const response = await fetch(`${AppConfig.apiUrl}/api/friends/${friendId}/messages`, {
      headers: buildHeaders(token),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data?.error || i18n.t('errors.loadMessages'));
    }
    const messages = (data.messages || []).map((message: any) => ({
      id: String(message.id),
      senderId: message.sender_id,
      recipientId: message.recipient_id,
      body: message.body,
      imageUrl: message.image_url,
      createdAt: message.created_at,
    }));
    useChatStore.getState().setFriendMessages(friendId, messages);
    return messages;
  }

  async sendFriendMessage(friendId: string, payload: { text?: string; imageUrl?: string }) {
    const token = useChatStore.getState().authToken;
    const response = await fetch(`${AppConfig.apiUrl}/api/friends/${friendId}/messages`, {
      method: 'POST',
      headers: buildHeaders(token, 'application/json'),
      body: JSON.stringify(payload),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data?.error || i18n.t('errors.sendMessage'));
    }
    return data.message;
  }

  sendConnectRequest() {
    this.socket?.emit('connect_request');
  }

  acceptConnectRequest() {
    this.socket?.emit('connect_request');
  }

  requestReveal() {
    this.socket?.emit('reveal_request');
  }

  private mapProfile(profile?: {
    user_id?: string;
    gender?: string;
    age_group?: string;
    interests?: string[];
    gender_preference?: string;
  } | null) {
    if (!profile) {
      return null;
    }
    return {
      userId: profile.user_id ?? '',
      gender: profile.gender ?? '',
      ageGroup: profile.age_group ?? '',
      interests: profile.interests ?? [],
      genderPreference: profile.gender_preference ?? 'any',
    };
  }

  async uploadImage(uri: string, filename?: string, type?: string, mode?: MatchMode) {
    const token = useChatStore.getState().authToken;
    const form = new FormData();
    form.append('image', {
      uri,
      name: filename ?? `upload-${Date.now()}.jpg`,
      type: type ?? 'image/jpeg',
    } as unknown as Blob);
    if (mode) {
      form.append('mode', mode);
    }

    const response = await fetch(`${AppConfig.apiUrl}/api/uploads/report`, {
      method: 'POST',
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        'Accept-Language': useChatStore.getState().language,
        'Content-Type': 'multipart/form-data',
      },
      body: form,
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data?.error || i18n.t('errors.uploadFailed'));
    }
    return {
      imageUrl: normalizeImageUrl(data?.imageUrl, AppConfig.apiUrl),
      previewUrl: normalizeImageUrl(data?.previewUrl, AppConfig.apiUrl),
      sourceUrl: normalizeImageUrl(data?.sourceUrl, AppConfig.apiUrl),
    };
  }

  blockUser(payload: { blockedUserId: string }) {
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

cat <<'EOT' > src/components/OfflineBanner.tsx
import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';

export const OfflineBanner = ({ isOffline }: { isOffline: boolean }) => {
  const { t } = useTranslation();
  if (!isOffline) {
    return null;
  }

  return (
    <View style={styles.container}>
      <Text style={styles.text}>{t('system.offline')}</Text>
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
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';

export const LatencyPill = ({ latency }: { latency: number | null }) => {
  const { t } = useTranslation();
  return (
    <View style={styles.container}>
      <Text style={styles.text}>
        {latency ? t('misc.latencyMs', { value: latency }) : t('misc.latencyUnknown')}
      </Text>
    </View>
  );
};

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
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';

export const MaintenanceBanner = ({ message }: { message: string }) => {
  const { t } = useTranslation();
  return (
    <View style={styles.container}>
      <Text style={styles.title}>{t('system.maintenanceTitle')}</Text>
      <Text style={styles.message}>{message}</Text>
    </View>
  );
};

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
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';
import { PrimaryButton } from '../components/PrimaryButton';
import { useChatStore } from '../store/useChatStore';

const brandAnimation = require('../../assets/lottie/placeholder.json');

type RootStackParamList = {
  Welcome: undefined;
  ModeSelect: undefined;
  Matching: undefined;
  Chat: undefined;
  Settings: undefined;
};

type Props = NativeStackScreenProps<RootStackParamList, 'Welcome'>;

export const WelcomeScreen = ({ navigation }: Props) => {
  const { termsAccepted, acceptTerms } = useChatStore();
  const [showTerms, setShowTerms] = useState(!termsAccepted);
  const { t } = useTranslation();

  return (
    <LinearGradient colors={[colors.gradientStart, colors.gradientEnd]} style={styles.container}>
      <View style={styles.hero}>
        <LottieView source={brandAnimation} autoPlay loop style={styles.lottie} />
        <Text style={styles.title}>{t('app.name')}</Text>
        <Text style={styles.subtitle}>{t('app.tagline')}</Text>
      </View>
      <PrimaryButton
        label={t('welcome.start')}
        onPress={() => {
          if (!termsAccepted) {
            setShowTerms(true);
          } else {
            navigation.replace('ModeSelect');
          }
        }}
      />
      <Modal visible={showTerms} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>{t('terms.title')}</Text>
            <Text style={styles.modalText}>{t('terms.body')}</Text>
            <PrimaryButton
              label={t('terms.agree')}
              onPress={() => {
                acceptTerms();
                setShowTerms(false);
                navigation.replace('ModeSelect');
              }}
            />
            <Pressable onPress={() => setShowTerms(false)}>
              <Text style={styles.modalCancel}>{t('terms.later')}</Text>
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

cat <<'EOT' > src/screens/ModeSelectScreen.tsx
import React from 'react';
import { I18nManager, Pressable, StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import LinearGradient from 'react-native-linear-gradient';
import Animated, {
  FadeInDown,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';

export const ModeSelectScreen = () => {
  const navigation = useNavigation();
  const { profileComplete, setMatchMode } = useChatStore();
  const { t } = useTranslation();

  const handleSelect = (mode: 'talk' | 'meet') => {
    setMatchMode(mode);
    if (mode === 'meet' && !profileComplete) {
      navigation.navigate('ProfileSetup' as never);
      return;
    }
    navigation.navigate('Matching' as never);
  };

  return (
    <LinearGradient colors={[colors.gradientStart, colors.gradientEnd]} style={styles.container}>
      <Text style={styles.title}>{t('mode.title')}</Text>
      <View style={styles.cardGrid}>
        <Animated.View entering={FadeInDown} style={styles.cardWrapper}>
          <Pressable style={styles.card} onPress={() => handleSelect('talk')}>
            <Text style={styles.cardTitle}>{t('mode.justTalk')}</Text>
            <Text style={styles.cardBody}>{t('mode.justTalkDesc')}</Text>
          </Pressable>
        </Animated.View>
        <Animated.View entering={FadeInDown.delay(80)} style={styles.cardWrapper}>
          <Pressable style={[styles.card, styles.cardMeet]} onPress={() => handleSelect('meet')}>
            <Text style={styles.cardTitle}>{t('mode.letsMeet')}</Text>
            <Text style={styles.cardBody}>{t('mode.letsMeetDesc')}</Text>
          </Pressable>
        </Animated.View>
      </View>
    </LinearGradient>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
    backgroundColor: colors.background,
  },
  title: {
    color: colors.textPrimary,
    fontSize: 24,
    fontWeight: '700',
    marginBottom: 24,
    textAlign: I18nManager.isRTL ? 'right' : 'left',
  },
  cardGrid: {
    gap: 16,
  },
  cardWrapper: {
    borderRadius: 20,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
    overflow: 'hidden',
  },
  card: {
    padding: 20,
    gap: 8,
  },
  cardMeet: {
    borderColor: colors.accentGlow,
  },
  cardTitle: { color: colors.accent, fontSize: 20, fontWeight: '700' },
  cardBody: { color: colors.textSecondary, lineHeight: 20 },
});
EOT

cat <<'EOT' > src/screens/MatchingScreen.tsx
import React, { useEffect } from 'react';
import { I18nManager, Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, { FadeIn, useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';
import LottieView from 'lottie-react-native';
import { useNavigation } from '@react-navigation/native';
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';
import { LatencyPill } from '../components/LatencyPill';

const matchingAnimation = require('../../assets/lottie/searching.json');

export const MatchingScreen = () => {
  const navigation = useNavigation();
  const { latencyMs, isMatching, maintenanceMode, maintenanceMessage, profileComplete, partnerId, matchMode } =
    useChatStore();
  const pulse = useSharedValue(0.7);
  const { t } = useTranslation();

  useEffect(() => {
    if (maintenanceMode) {
      pulse.value = withTiming(1, { duration: 150 });
      return;
    }
    if (matchMode === 'meet' && !profileComplete) {
      navigation.navigate('ProfileSetup' as never);
      return;
    }
    socketService.findMatch(matchMode);
    pulse.value = withRepeat(withTiming(1, { duration: 900 }), -1, true);
  }, [maintenanceMode, profileComplete, matchMode, navigation, pulse]);

  useEffect(() => {
    if (partnerId) {
      navigation.navigate('Chat' as never);
    }
  }, [partnerId, navigation]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pulse.value }],
    opacity: pulse.value,
  }));

  return (
    <View style={styles.container}>
      <Animated.View entering={FadeIn} style={styles.modeBadge}>
        <Text style={styles.modeText}>
          {matchMode === 'meet' ? t('mode.letsMeet') : t('mode.justTalk')}
        </Text>
      </Animated.View>
      {maintenanceMode ? (
        <Text style={styles.title}>{maintenanceMessage || t('matching.maintenance')}</Text>
      ) : null}
      <Animated.View style={[styles.orb, animatedStyle]} />
      <LottieView
        source={matchingAnimation}
        autoPlay={!maintenanceMode}
        loop={!maintenanceMode}
        style={styles.lottie}
      />
      <LatencyPill latency={latencyMs} />
      <Text style={styles.subtitle}>
        {isMatching ? t('matching.respect') : t('matching.connecting')}
      </Text>
      <View style={styles.actionRow}>
        <Pressable style={styles.friendsButton} onPress={() => navigation.navigate('Friends' as never)}>
          <Text style={styles.friendsButtonText}>{t('matching.friends')}</Text>
        </Pressable>
        <Pressable style={styles.modeButton} onPress={() => navigation.navigate('ModeSelect' as never)}>
          <Text style={styles.modeButtonText}>{t('mode.switch')}</Text>
        </Pressable>
      </View>
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
  modeBadge: {
    backgroundColor: colors.card,
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: colors.accentGlow,
  },
  modeText: {
    color: colors.accentGlow,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 1,
    fontSize: 12,
  },
  orb: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: colors.accent,
    shadowColor: colors.accentGlow,
    shadowOpacity: 0.6,
    shadowRadius: 14,
    elevation: 6,
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
  actionRow: {
    marginTop: 12,
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
    gap: 12,
  },
  friendsButton: {
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 18,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  friendsButtonText: { color: colors.textPrimary, fontWeight: '600' },
  modeButton: {
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 18,
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.accentGlow,
  },
  modeButtonText: { color: colors.accentGlow, fontWeight: '600' },
});
EOT

cat <<'EOT' > src/screens/ChatScreen.tsx
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Alert, I18nManager, Linking, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { FlashList } from '@shopify/flash-list';
import { useNavigation } from '@react-navigation/native';
import FastImage from 'react-native-fast-image';
import { Swipeable } from 'react-native-gesture-handler';
import Animated, {
  FadeInDown,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { launchImageLibrary } from 'react-native-image-picker';
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';
import { AppConfig } from '../config/Config';
import { ChatMessage } from '../types/chat';

const TYPING_DEBOUNCE_MS = 1200;

const MessageBubble = React.memo(
  ({
    message,
    isOwn,
    blurImage,
    labels,
    onReply,
    onRetry,
    pulseOverlay,
  }: {
    message: ChatMessage;
    isOwn: boolean;
    blurImage: boolean;
    pulseOverlay: boolean;
    labels: {
      reply: string;
      tapToReveal: string;
      photoHidden: string;
      retry: string;
      status: Record<ChatMessage['status'], string>;
      photo: string;
    };
    onReply: () => void;
    onRetry: () => void;
  }) => {
    const bubbleStyle = isOwn ? styles.bubbleOutgoing : styles.bubbleIncoming;
    const textStyle = isOwn ? styles.textOutgoing : styles.textIncoming;
    const replyLabel = message.replyTo?.text
      ? `↪ ${message.replyTo.text}`
      : message.replyTo?.image
        ? `↪ ${labels.photo}`
        : undefined;
    const blurProgress = useSharedValue(blurImage ? 1 : 0);
    const overlayPulse = useSharedValue(1);
    const blurStyle = useAnimatedStyle(() => ({
      opacity: blurProgress.value,
    }));
    const clearStyle = useAnimatedStyle(() => ({
      opacity: 1 - blurProgress.value,
    }));
    const overlayPulseStyle = useAnimatedStyle(() => ({
      transform: [{ scale: overlayPulse.value }],
    }));

    useEffect(() => {
      blurProgress.value = withTiming(blurImage ? 1 : 0, { duration: 420 });
    }, [blurImage, blurProgress]);

    useEffect(() => {
      if (pulseOverlay) {
        overlayPulse.value = withRepeat(
          withSequence(withTiming(1.03, { duration: 900 }), withTiming(1, { duration: 900 })),
          -1,
        );
      } else {
        overlayPulse.value = withTiming(1, { duration: 200 });
      }
    }, [overlayPulse, pulseOverlay]);

    return (
      <Swipeable
        renderLeftActions={() => (
          <View style={styles.replyAction}>
            <Text style={styles.replyActionText}>{labels.reply}</Text>
          </View>
        )}
        onSwipeableOpen={() => {
          ReactNativeHapticFeedback.trigger('impactLight');
          onReply();
        }}
      >
        <Animated.View
          entering={FadeInDown}
          style={[styles.messageRow, isOwn ? styles.messageRowOwn : styles.messageRowPartner]}
        >
          <View style={[styles.bubble, bubbleStyle]}>
            {replyLabel ? <Text style={styles.replyText}>{replyLabel}</Text> : null}
            {message.image ? (
              <View style={styles.imageWrapper}>
                <Animated.View style={[styles.imageLayer, blurStyle]}>
                  <FastImage
                    source={{ uri: message.image }}
                    style={styles.imageMessage}
                    resizeMode={FastImage.resizeMode.cover}
                    blurRadius={20}
                  />
                </Animated.View>
                <Animated.View style={[styles.imageLayer, clearStyle]}>
                  <FastImage
                    source={{ uri: message.image }}
                    style={styles.imageMessage}
                    resizeMode={FastImage.resizeMode.cover}
                  />
                </Animated.View>
                {blurImage ? (
                  <Animated.View style={[styles.blurOverlay, blurStyle, overlayPulseStyle]}>
                    <Text style={styles.blurText}>{labels.tapToReveal}</Text>
                  </Animated.View>
                ) : null}
              </View>
            ) : message.imagePending ? (
              <View style={styles.imagePlaceholder}>
                <Text style={styles.imagePlaceholderText}>{labels.photoHidden}</Text>
              </View>
            ) : null}
            {message.text ? <Text style={[styles.messageText, textStyle]}>{message.text}</Text> : null}
            {isOwn ? (
              <View style={styles.statusRow}>
                <Text style={styles.statusText}>{labels.status[message.status]}</Text>
                {message.status === 'failed' ? (
                  <Pressable onPress={onRetry} style={styles.retryButton}>
                    <Text style={styles.retryButtonText}>{labels.retry}</Text>
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
  const navigation = useNavigation();
  const {
    userId,
    partnerId,
    partnerProfile,
    isConnected,
    messages,
    addMessage,
    addBlockedUser,
    maintenanceMode,
    isPartnerTyping,
    systemNotice,
    setSystemNotice,
    pendingConnectRequest,
    setPendingConnectRequest,
    matchMode,
    revealAvailable,
    revealConfirmed,
    revealAt,
  } = useChatStore();
  const [draft, setDraft] = useState('');
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const [revealRequested, setRevealRequested] = useState(false);
  const [revealCountdownMs, setRevealCountdownMs] = useState<number | null>(null);
  const typingTimeout = useRef<NodeJS.Timeout | null>(null);
  const { t } = useTranslation();
  const isRTL = I18nManager.isRTL;

  const pulse = useSharedValue(1);
  const pulseStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pulse.value }],
    opacity: 0.7 + 0.3 * pulse.value,
  }));

  useEffect(() => {
    pulse.value = withRepeat(withSequence(withTiming(1.05, { duration: 800 }), withTiming(1, { duration: 800 })), -1);
  }, [pulse]);

  const sortedMessages = useMemo(() => messages, [messages]);
  const statusLabels = useMemo(
    () => ({
      pending: t('chat.status.pending'),
      sent: t('chat.status.sent'),
      delivered: t('chat.status.delivered'),
      failed: t('chat.status.failed'),
    }),
    [t],
  );

  useEffect(() => () => socketService.setTyping(false), []);

  useEffect(() => {
    setRevealRequested(false);
  }, [partnerId]);

  useEffect(() => {
    if (revealConfirmed) {
      setRevealRequested(false);
    }
  }, [revealConfirmed]);

  useEffect(() => {
    if (!revealAt || revealAvailable || revealConfirmed) {
      setRevealCountdownMs(null);
      return;
    }
    const tick = () => {
      const remaining = Math.max(0, revealAt - Date.now());
      setRevealCountdownMs(remaining);
    };
    tick();
    const timer = setInterval(tick, 1000);
    return () => clearInterval(timer);
  }, [revealAt, revealAvailable, revealConfirmed]);

  useEffect(() => {
    if (partnerId) {
      ReactNativeHapticFeedback.trigger('impactLight');
    } else if (!partnerId && messages.length > 0) {
      ReactNativeHapticFeedback.trigger('notificationWarning');
    }
  }, [partnerId, messages.length]);

  useEffect(() => {
    if (!partnerId && !maintenanceMode) {
      navigation.navigate('Matching' as never);
    }
  }, [maintenanceMode, navigation, partnerId]);

  const sendMessage = useCallback(
    (payload: { text: string; imagePreview?: string; imageSource?: string }) => {
      const text = payload.text.trim();
      if (!text && !payload.imagePreview && !payload.imageSource) {
        return;
      }

      const clientId = `client_${Date.now()}_${Math.random().toString(16).slice(2)}`;
      const message: ChatMessage = {
        id: clientId,
        text,
        createdAt: Date.now(),
        userId,
        image: payload.imagePreview ?? payload.imageSource,
        imageSource: payload.imageSource,
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
        imagePreview: payload.imagePreview,
        imageSource: payload.imageSource,
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

    try {
      const uploaded = await socketService.uploadImage(
        asset.uri,
        asset.fileName ?? undefined,
        asset.type ?? undefined,
        matchMode,
      );
      const imagePreview = uploaded?.previewUrl ?? uploaded?.imageUrl;
      const imageSource = uploaded?.sourceUrl ?? uploaded?.imageUrl;
      if (!imagePreview && !imageSource) {
        throw new Error(t('errors.uploadFailed'));
      }
      sendMessage({ text: '', imagePreview, imageSource });
    } catch (error) {
      const message = error instanceof Error ? error.message : t('errors.uploadFailed');
      setSystemNotice({ type: 'error', message });
    }
  }, [matchMode, sendMessage, setSystemNotice, t]);

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
    socketService.blockUser({ blockedUserId: partnerId });
    addBlockedUser(partnerId);
  }, [addBlockedUser, partnerId]);

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

  const handleReveal = () => {
    if (!revealAvailable || revealRequested) {
      return;
    }
    setRevealRequested(true);
    socketService.requestReveal();
  };

  const renderItem = useCallback(
    ({ item }: { item: ChatMessage }) => {
      const isOwn = item.userId === userId;
      const shouldBlur = matchMode === 'meet' && !revealConfirmed;
      const shouldPulse = matchMode === 'meet' && Boolean(revealAt) && !revealAvailable && !revealConfirmed;
      return (
        <MessageBubble
          message={item}
          isOwn={isOwn}
          blurImage={Boolean(item.image) && shouldBlur}
          pulseOverlay={shouldPulse}
          labels={{
            reply: t('chat.reply'),
            tapToReveal: t('chat.tapToReveal'),
            photoHidden: t('chat.photoHidden'),
            retry: t('chat.retry'),
            photo: t('misc.photo'),
            status: statusLabels,
          }}
          onReply={() => setReplyTo(item)}
          onRetry={() =>
            socketService.retryMessage({
              clientId: item.id,
              text: item.text,
              createdAt: item.createdAt,
              userId,
              image: item.image,
              imageSource: item.imageSource,
              replyTo: item.replyTo,
            })
          }
        />
      );
    },
    [matchMode, revealAt, revealAvailable, revealConfirmed, statusLabels, t, userId],
  );

  const replyName = replyTo?.userId === userId ? t('misc.you') : t('misc.partner');
  const replyPreview = replyTo?.text || t('misc.photo');

  const revealCountdownText = useMemo(() => {
    if (!revealCountdownMs) {
      return null;
    }
    const totalSeconds = Math.ceil(revealCountdownMs / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }, [revealCountdownMs]);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>{t('chat.title')}</Text>
          <Text style={styles.headerSubtitle}>
            {partnerProfile
              ? `${partnerProfile.gender} · ${partnerProfile.ageGroup}`
              : t('chat.searching')}
          </Text>
          {partnerProfile?.interests?.length ? (
            <View style={styles.tagRow}>
              {partnerProfile.interests.map(tag => (
                <View key={tag} style={styles.tag}>
                  <Text style={styles.tagText}>{tag}</Text>
                </View>
              ))}
            </View>
          ) : null}
          {matchMode === 'meet' && revealCountdownText ? (
            <View style={[styles.revealCountdown, isRTL && styles.revealCountdownRtl]}>
              <Animated.View style={[styles.revealPulse, pulseStyle]} />
              <Text style={styles.revealCountdownText}>
                {t('chat.revealCountdown', { time: revealCountdownText })}
              </Text>
            </View>
          ) : null}
        </View>
        <View style={styles.headerActions}>
          <Pressable style={styles.headerButton} onPress={() => setSystemNotice(null)}>
            <Text style={styles.headerButtonText}>{t('chat.clear')}</Text>
          </Pressable>
          <Pressable style={styles.headerButton} onPress={() => navigation.navigate('Friends' as never)}>
            <Text style={styles.headerButtonText}>{t('matching.friends')}</Text>
          </Pressable>
          <Pressable
            style={styles.headerButton}
            onPress={() => {
              socketService.skipMatch();
              ReactNativeHapticFeedback.trigger('impactMedium');
            }}
          >
            <Text style={styles.headerButtonText}>{t('chat.skip')}</Text>
          </Pressable>
          <Pressable style={styles.headerButton} onPress={() => handleReport(t('actions.reportReason'))}>
            <Text style={styles.headerButtonText}>{t('chat.report')}</Text>
          </Pressable>
          <Pressable style={styles.headerButton} onPress={() => socketService.sendConnectRequest()}>
            <Text style={styles.headerButtonText}>{t('chat.connect')}</Text>
          </Pressable>
          <Pressable
            style={[styles.headerButton, styles.blockButton]}
            onPress={() =>
              Alert.alert(t('actions.blockTitle'), t('actions.blockConfirm'), [
                { text: t('actions.cancel'), style: 'cancel' },
                {
                  text: t('actions.block'),
                  style: 'destructive',
                  onPress: () => {
                    handleBlock();
                    ReactNativeHapticFeedback.trigger('impactMedium');
                  },
                },
              ])
            }
          >
            <Text style={styles.headerButtonText}>{t('chat.block')}</Text>
          </Pressable>
        </View>
      </View>
      {!isConnected && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>{t('chat.offline')}</Text>
        </View>
      )}
      {maintenanceMode && (
        <View style={styles.maintenanceBanner}>
          <Text style={styles.maintenanceText}>{t('chat.maintenance')}</Text>
        </View>
      )}
      {matchMode === 'meet' && !revealConfirmed ? (
        <View style={styles.revealBanner}>
          <View style={styles.revealCopy}>
            <Text style={styles.revealTitle}>{t('chat.revealTitle')}</Text>
            <Text style={styles.revealText}>
              {revealAvailable ? t('chat.revealAvailable') : t('chat.revealWaiting')}
            </Text>
          </View>
          <Pressable
            style={[styles.revealButton, (!revealAvailable || revealRequested) && styles.revealButtonDisabled]}
            onPress={handleReveal}
            disabled={!revealAvailable || revealRequested}
          >
            <Text style={styles.revealButtonText}>{t('chat.revealButton')}</Text>
          </Pressable>
        </View>
      ) : null}
      {systemNotice ? (
        <View style={styles.systemNotice}>
          <Text style={styles.systemNoticeText}>{systemNotice.message}</Text>
        </View>
      ) : null}
      {pendingConnectRequest ? (
        <View style={styles.friendRequestBanner}>
          <Text style={styles.friendRequestText}>{t('chat.connectRequest')}</Text>
          <Pressable
            style={styles.friendRequestButton}
            onPress={() => {
              socketService.acceptConnectRequest();
              setPendingConnectRequest(null);
            }}
          >
            <Text style={styles.friendRequestButtonText}>{t('chat.connectAccept')}</Text>
          </Pressable>
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
          <Text style={styles.typingText}>{t('chat.typing')}</Text>
        </View>
      ) : null}
      {replyTo ? (
        <View style={styles.replyPreview}>
          <Text style={styles.replyPreviewText} numberOfLines={1}>
            {t('chat.replyingTo', { name: replyName, preview: replyPreview })}
          </Text>
          <Pressable onPress={() => setReplyTo(null)}>
            <Text style={styles.replyPreviewDismiss}>{t('chat.dismiss')}</Text>
          </Pressable>
        </View>
      ) : null}
      <View style={styles.inputBar}>
        <Pressable style={styles.imageButton} onPress={handleImagePick}>
          <Text style={styles.imageButtonText}>{t('chat.addPhoto')}</Text>
        </Pressable>
        <TextInput
          style={styles.input}
          value={draft}
          onChangeText={handleTyping}
          placeholder={maintenanceMode ? t('chat.maintenancePlaceholder') : t('chat.inputPlaceholder')}
          placeholderTextColor={colors.textSecondary}
          editable={!maintenanceMode}
          multiline
        />
        <Pressable
          style={[styles.sendButton, (!draft.trim() && !maintenanceMode) && styles.sendButtonMuted]}
          onPress={() => sendMessage({ text: draft })}
          disabled={maintenanceMode}
        >
          <Text style={styles.sendButtonText}>{t('chat.send')}</Text>
        </Pressable>
      </View>
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          {t('chat.termsPrefix')}{' '}
          <Text style={styles.link} onPress={() => Linking.openURL(AppConfig.termsUrl)}>
            {t('chat.termsLink')}
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
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  headerTitle: { color: colors.textPrimary, fontSize: 18, fontWeight: '600' },
  headerSubtitle: { color: colors.textSecondary, fontSize: 12, marginTop: 4 },
  headerActions: {
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
    gap: 8,
    flexWrap: 'wrap',
    justifyContent: 'flex-end',
  },
  revealCountdown: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 6,
    gap: 6,
  },
  revealCountdownRtl: {
    flexDirection: 'row-reverse',
  },
  revealPulse: {
    width: 8,
    height: 8,
    borderRadius: 999,
    backgroundColor: colors.accentGlow,
  },
  revealCountdownText: { color: colors.textSecondary, fontSize: 12 },
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
  revealBanner: {
    backgroundColor: colors.card,
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  revealCopy: { flex: 1 },
  revealTitle: { color: colors.accentGlow, fontWeight: '700' },
  revealText: { color: colors.textSecondary, marginTop: 2 },
  revealButton: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 12,
    backgroundColor: colors.accent,
  },
  revealButtonDisabled: { opacity: 0.5 },
  revealButtonText: { color: '#0A0A12', fontWeight: '700' },
  systemNotice: {
    backgroundColor: colors.card,
    padding: 10,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  systemNoticeText: { color: colors.textSecondary, textAlign: 'center' },
  messageList: { paddingHorizontal: 16, paddingVertical: 12 },
  messageRow: { flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row', marginBottom: 12 },
  messageRowOwn: { justifyContent: I18nManager.isRTL ? 'flex-end' : 'flex-start' },
  messageRowPartner: { justifyContent: I18nManager.isRTL ? 'flex-start' : 'flex-end' },
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
  imageWrapper: { width: 220, height: 180, marginBottom: 8, borderRadius: 12, overflow: 'hidden' },
  imageLayer: { position: 'absolute', top: 0, left: 0 },
  imageMessage: { width: 220, height: 180, borderRadius: 12 },
  blurOverlay: {
    position: 'absolute',
    inset: 0,
    borderRadius: 12,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  blurText: { color: colors.textPrimary, fontWeight: '600' },
  imagePlaceholder: {
    width: 220,
    height: 180,
    borderRadius: 12,
    backgroundColor: colors.card,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
    borderWidth: 1,
    borderColor: colors.border,
  },
  imagePlaceholderText: { color: colors.textSecondary },
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
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  replyPreviewText: { color: colors.textSecondary, flex: 1, marginRight: 12 },
  replyPreviewDismiss: { color: colors.accent, fontSize: 12 },
  tagRow: { flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row', flexWrap: 'wrap', gap: 6, marginTop: 6 },
  tag: {
    backgroundColor: colors.card,
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  tagText: { color: colors.textSecondary, fontSize: 11 },
  friendRequestBanner: {
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    padding: 10,
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  friendRequestText: { color: colors.textPrimary, fontWeight: '600' },
  friendRequestButton: {
    backgroundColor: colors.accent,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
  },
  friendRequestButtonText: { color: '#0B141A', fontWeight: '700' },
  inputBar: {
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
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
    textAlign: I18nManager.isRTL ? 'right' : 'left',
  },
  sendButton: {
    backgroundColor: colors.accent,
    borderRadius: 16,
    paddingVertical: 10,
    paddingHorizontal: 16,
  },
  sendButtonMuted: { opacity: 0.6 },
  sendButtonText: { color: '#0A0A12', fontWeight: '700' },
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

cat <<'EOT' > src/screens/ProfileSetupScreen.tsx
import React, { useMemo, useState } from 'react';
import { I18nManager, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';
import { socketService } from '../services/socketService';
import { useChatStore } from '../store/useChatStore';

export const ProfileSetupScreen = () => {
  const { profile } = useChatStore();
  const { t } = useTranslation();
  const [gender, setGender] = useState(profile?.gender || '');
  const [ageGroup, setAgeGroup] = useState(profile?.ageGroup || '');
  const [genderPreference, setGenderPreference] = useState(profile?.genderPreference || 'any');
  const [interestOne, setInterestOne] = useState(profile?.interests?.[0] || '');
  const [interestTwo, setInterestTwo] = useState(profile?.interests?.[1] || '');
  const [interestThree, setInterestThree] = useState(profile?.interests?.[2] || '');
  const [error, setError] = useState('');

  const genderOptions = [
    { value: 'Woman', label: t('profile.genders.woman') },
    { value: 'Man', label: t('profile.genders.man') },
    { value: 'Non-binary', label: t('profile.genders.nonbinary') },
  ];

  const ageGroupOptions = [
    { value: '18-24', label: t('profile.ageGroups.18_24') },
    { value: '25-34', label: t('profile.ageGroups.25_34') },
    { value: '35-44', label: t('profile.ageGroups.35_44') },
    { value: '45+', label: t('profile.ageGroups.45_plus') },
  ];

  const interests = useMemo(
    () => [interestOne, interestTwo, interestThree].map(item => item.trim()).filter(Boolean),
    [interestOne, interestTwo, interestThree],
  );

  const saveProfile = async () => {
    setError('');
    if (!gender || !ageGroup || interests.length < 3) {
      setError(t('profile.error'));
      return;
    }
    try {
      await socketService.saveProfile({
        gender,
        ageGroup,
        interests,
        genderPreference,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : t('errors.saveProfile');
      setError(message);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{t('profile.title')}</Text>
      <Text style={styles.subtitle}>{t('profile.subtitle')}</Text>

      <Text style={styles.sectionTitle}>{t('profile.gender')}</Text>
      <View style={styles.row}>
        {genderOptions.map(option => (
          <Pressable
            key={option.value}
            style={[styles.choiceChip, gender === option.value && styles.choiceChipActive]}
            onPress={() => setGender(option.value)}
          >
            <Text style={styles.choiceText}>{option.label}</Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.sectionTitle}>{t('profile.ageGroup')}</Text>
      <View style={styles.row}>
        {ageGroupOptions.map(option => (
          <Pressable
            key={option.value}
            style={[styles.choiceChip, ageGroup === option.value && styles.choiceChipActive]}
            onPress={() => setAgeGroup(option.value)}
          >
            <Text style={styles.choiceText}>{option.label}</Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.sectionTitle}>{t('profile.interestedIn')}</Text>
      <View style={styles.row}>
        {[{ value: 'any', label: t('profile.genders.any') }, ...genderOptions].map(option => (
          <Pressable
            key={option.value}
            style={[styles.choiceChip, genderPreference === option.value && styles.choiceChipActive]}
            onPress={() => setGenderPreference(option.value)}
          >
            <Text style={styles.choiceText}>{option.label}</Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.sectionTitle}>{t('profile.interests')}</Text>
      <View style={styles.inputGroup}>
        <TextInput
          style={styles.input}
          value={interestOne}
          placeholder={t('profile.interestPlaceholder', { index: 1 })}
          placeholderTextColor={colors.textSecondary}
          onChangeText={setInterestOne}
        />
        <TextInput
          style={styles.input}
          value={interestTwo}
          placeholder={t('profile.interestPlaceholder', { index: 2 })}
          placeholderTextColor={colors.textSecondary}
          onChangeText={setInterestTwo}
        />
        <TextInput
          style={styles.input}
          value={interestThree}
          placeholder={t('profile.interestPlaceholder', { index: 3 })}
          placeholderTextColor={colors.textSecondary}
          onChangeText={setInterestThree}
        />
      </View>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <Pressable style={styles.saveButton} onPress={saveProfile}>
        <Text style={styles.saveButtonText}>{t('profile.save')}</Text>
      </Pressable>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
    padding: 24,
    gap: 16,
  },
  title: { color: colors.textPrimary, fontSize: 24, fontWeight: '700', textAlign: I18nManager.isRTL ? 'right' : 'left' },
  subtitle: { color: colors.textSecondary, textAlign: I18nManager.isRTL ? 'right' : 'left' },
  sectionTitle: { color: colors.textPrimary, fontWeight: '600', marginTop: 8, textAlign: I18nManager.isRTL ? 'right' : 'left' },
  row: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  choiceChip: {
    backgroundColor: colors.card,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 1,
    borderColor: colors.border,
  },
  choiceChipActive: { backgroundColor: colors.accentSoft, borderColor: colors.accent },
  choiceText: { color: colors.textPrimary, fontSize: 12 },
  inputGroup: { gap: 10 },
  input: {
    backgroundColor: colors.card,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    color: colors.textPrimary,
    textAlign: I18nManager.isRTL ? 'right' : 'left',
  },
  error: { color: colors.danger, fontWeight: '600' },
  saveButton: {
    marginTop: 'auto',
    backgroundColor: colors.accent,
    borderRadius: 18,
    paddingVertical: 12,
    alignItems: 'center',
  },
  saveButtonText: { color: '#0B141A', fontWeight: '700' },
});
EOT

cat <<'EOT' > src/screens/FriendsScreen.tsx
import React, { useEffect, useState } from 'react';
import { I18nManager, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';

export const FriendsScreen = () => {
  const navigation = useNavigation();
  const { friends } = useChatStore();
  const [error, setError] = useState('');
  const { t } = useTranslation();

  const loadFriends = async () => {
    setError('');
    try {
      await socketService.loadFriends();
    } catch (err) {
      const message = err instanceof Error ? err.message : t('errors.loadFriends');
      setError(message);
    }
  };

  useEffect(() => {
    loadFriends();
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>{t('friends.title')}</Text>
        <Pressable style={styles.refreshButton} onPress={loadFriends}>
          <Text style={styles.refreshText}>{t('friends.refresh')}</Text>
        </Pressable>
      </View>
      {error ? <Text style={styles.error}>{error}</Text> : null}
      <ScrollView contentContainerStyle={styles.list}>
        {friends.length === 0 ? (
          <Text style={styles.empty}>{t('friends.empty')}</Text>
        ) : (
          friends.map(friend => (
            <Pressable
              key={friend.friendId}
              style={styles.card}
              onPress={() => navigation.navigate('FriendChat' as never, { friendId: friend.friendId } as never)}
            >
              <Text style={styles.cardTitle}>{friend.friendId}</Text>
              <Text style={styles.cardSubtitle}>
                {friend.gender && friend.ageGroup ? `${friend.gender} · ${friend.ageGroup}` : t('friends.profilePending')}
              </Text>
              <Text style={styles.cardMessage}>{friend.lastMessage || t('friends.startConversation')}</Text>
            </Pressable>
          ))
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: 20 },
  header: {
    flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  title: { color: colors.textPrimary, fontSize: 22, fontWeight: '700' },
  refreshButton: {
    backgroundColor: colors.card,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  refreshText: { color: colors.textSecondary, fontWeight: '600' },
  error: { color: colors.danger, marginTop: 8 },
  list: { paddingVertical: 16, gap: 12 },
  empty: { color: colors.textSecondary },
  card: {
    backgroundColor: colors.surface,
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: colors.border,
    gap: 6,
  },
  cardTitle: { color: colors.textPrimary, fontWeight: '700' },
  cardSubtitle: { color: colors.textSecondary, fontSize: 12 },
  cardMessage: { color: colors.textSecondary },
});
EOT

cat <<'EOT' > src/screens/FriendChatScreen.tsx
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { I18nManager, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { FlashList } from '@shopify/flash-list';
import FastImage from 'react-native-fast-image';
import { useRoute } from '@react-navigation/native';
import { useTranslation } from 'react-i18next';
import { colors } from '../theme/colors';
import { socketService } from '../services/socketService';
import { useChatStore } from '../store/useChatStore';

type RouteParams = { friendId: string };

export const FriendChatScreen = () => {
  const route = useRoute();
  const { friendId } = route.params as RouteParams;
  const { friendMessages, addFriendMessage } = useChatStore();
  const [draft, setDraft] = useState('');
  const { t } = useTranslation();

  const messages = useMemo(() => friendMessages[friendId] || [], [friendId, friendMessages]);

  useEffect(() => {
    socketService.loadFriendMessages(friendId).catch(() => {});
  }, [friendId]);

  const send = useCallback(async () => {
    const text = draft.trim();
    if (!text) {
      return;
    }
    setDraft('');
    const message = await socketService.sendFriendMessage(friendId, { text });
    if (message) {
      addFriendMessage(friendId, {
        id: String(message.id),
        senderId: message.senderId,
        recipientId: message.recipientId,
        body: message.body,
        imageUrl: message.imageUrl,
        createdAt: message.createdAt,
      });
    }
  }, [addFriendMessage, draft, friendId]);

  return (
    <View style={styles.container}>
      <FlashList
        data={messages}
        inverted
        keyExtractor={item => String(item.id)}
        estimatedItemSize={72}
        renderItem={({ item }) => (
          <View style={styles.messageRow}>
            <View style={styles.messageBubble}>
              {item.imageUrl ? (
                <FastImage source={{ uri: item.imageUrl }} style={styles.messageImage} resizeMode={FastImage.resizeMode.cover} />
              ) : null}
              {item.body ? <Text style={styles.messageText}>{item.body}</Text> : null}
            </View>
          </View>
        )}
      />
      <View style={styles.inputBar}>
        <TextInput
          style={styles.input}
          value={draft}
          onChangeText={setDraft}
          placeholder={t('friendChat.placeholder')}
          placeholderTextColor={colors.textSecondary}
        />
        <Pressable style={styles.sendButton} onPress={send}>
          <Text style={styles.sendButtonText}>{t('chat.send')}</Text>
        </Pressable>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  messageRow: { paddingHorizontal: 16, paddingVertical: 8 },
  messageBubble: {
    backgroundColor: colors.surface,
    borderRadius: 16,
    padding: 12,
    borderWidth: 1,
    borderColor: colors.border,
  },
  messageText: { color: colors.textPrimary },
  messageImage: { width: 220, height: 180, borderRadius: 12, marginBottom: 8 },
  inputBar: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    backgroundColor: colors.surface,
    gap: 8,
  },
  input: {
    flex: 1,
    backgroundColor: colors.card,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 8,
    color: colors.textPrimary,
    textAlign: I18nManager.isRTL ? 'right' : 'left',
  },
  sendButton: {
    backgroundColor: colors.accent,
    borderRadius: 16,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  sendButtonText: { color: '#0B141A', fontWeight: '700' },
});
EOT

cat <<'EOT' > src/screens/SettingsScreen.tsx
import React from 'react';
import { Alert, I18nManager, Pressable, StyleSheet, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { setI18nLanguage } from '../i18n';
import { colors } from '../theme/colors';
import { useChatStore } from '../store/useChatStore';
import { socketService } from '../services/socketService';

export const SettingsScreen = () => {
  const { blockedUsers, resetAll, language, setLanguage } = useChatStore();
  const { t } = useTranslation();

  const handleDelete = () => {
    Alert.alert(t('actions.deleteDataTitle'), t('actions.deleteDataBody'), [
      { text: t('actions.cancel'), style: 'cancel' },
      {
        text: t('settings.delete'),
        style: 'destructive',
        onPress: () => {
          resetAll();
        },
      },
    ]);
  };

  const handleLanguageChange = async (nextLanguage: 'en' | 'he') => {
    if (nextLanguage === language) {
      return;
    }
    setLanguage(nextLanguage);
    await setI18nLanguage(nextLanguage);
    socketService.disconnect();
    socketService.connect();
    Alert.alert(t('settings.language'), t('settings.languagePrompt'));
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{t('settings.title')}</Text>
      <View style={styles.languageSection}>
        <Text style={styles.languageTitle}>{t('settings.language')}</Text>
        <View style={styles.languageRow}>
          <Pressable
            style={[styles.languageButton, language === 'en' && styles.languageButtonActive]}
            onPress={() => handleLanguageChange('en')}
          >
            <Text style={styles.languageButtonText}>{t('settings.languageEN')}</Text>
          </Pressable>
          <Pressable
            style={[styles.languageButton, language === 'he' && styles.languageButtonActive]}
            onPress={() => handleLanguageChange('he')}
          >
            <Text style={styles.languageButtonText}>{t('settings.languageHE')}</Text>
          </Pressable>
        </View>
      </View>
      {blockedUsers.length === 0 ? (
        <Text style={styles.empty}>{t('settings.empty')}</Text>
      ) : (
        blockedUsers.map(user => (
          <View key={user} style={styles.blockedCard}>
            <Text style={styles.blockedText}>{user}</Text>
          </View>
        ))
      )}
      <Pressable style={styles.deleteButton} onPress={handleDelete}>
        <Text style={styles.deleteButtonText}>{t('settings.delete')}</Text>
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
  languageSection: { marginTop: 8, gap: 8 },
  languageTitle: { color: colors.textSecondary, fontWeight: '600' },
  languageRow: { flexDirection: I18nManager.isRTL ? 'row-reverse' : 'row', gap: 8 },
  languageButton: {
    backgroundColor: colors.card,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: colors.border,
  },
  languageButtonActive: { borderColor: colors.accentGlow },
  languageButtonText: { color: colors.textPrimary },
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
import { SafeAreaView, StatusBar } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';
import { useTranslation } from 'react-i18next';
import { setI18nLanguage } from './i18n';
import { OfflineBanner } from './components/OfflineBanner';
import { MaintenanceBanner } from './components/MaintenanceBanner';
import { ChatScreen } from './screens/ChatScreen';
import { FriendChatScreen } from './screens/FriendChatScreen';
import { FriendsScreen } from './screens/FriendsScreen';
import { MatchingScreen } from './screens/MatchingScreen';
import { ModeSelectScreen } from './screens/ModeSelectScreen';
import { ProfileSetupScreen } from './screens/ProfileSetupScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { WelcomeScreen } from './screens/WelcomeScreen';
import { socketService } from './services/socketService';
import { useChatStore } from './store/useChatStore';
import { colors } from './theme/colors';

const Stack = createNativeStackNavigator();

export default function App() {
  const {
    isConnected,
    isMatching,
    termsAccepted,
    maintenanceMode,
    maintenanceMessage,
    profileComplete,
    matchMode,
    modeSelected,
    language,
  } = useChatStore();
  const { t } = useTranslation();

  useEffect(() => {
    socketService.connect();
    return () => socketService.disconnect();
  }, []);

  useEffect(() => {
    setI18nLanguage(language).catch(() => {});
  }, [language]);

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
        <MaintenanceBanner
          message={maintenanceMessage || t('system.defaultMaintenance')}
        />
      )}
      <NavigationContainer>
        <Stack.Navigator
          screenOptions={{ headerStyle: { backgroundColor: colors.surface }, headerTintColor: colors.textPrimary }}
        >
          {!termsAccepted ? (
            <Stack.Screen name="Welcome" component={WelcomeScreen} options={{ headerShown: false }} />
          ) : !modeSelected ? (
            <Stack.Screen name="ModeSelect" component={ModeSelectScreen} options={{ headerShown: false }} />
          ) : matchMode === 'meet' && !profileComplete ? (
            <Stack.Screen name="ProfileSetup" component={ProfileSetupScreen} options={{ headerShown: false }} />
          ) : (
            <>
              <Stack.Screen name="Matching" component={MatchingScreen} options={{ title: t('matching.finding') }} />
              <Stack.Screen name="Chat" component={ChatScreen} options={{ title: t('chat.title') }} />
              <Stack.Screen name="Friends" component={FriendsScreen} options={{ title: t('friends.title') }} />
              <Stack.Screen name="FriendChat" component={FriendChatScreen} options={{ title: t('friendChat.title') }} />
              <Stack.Screen name="Settings" component={SettingsScreen} options={{ title: t('settings.title') }} />
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
import './src/i18n';
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
