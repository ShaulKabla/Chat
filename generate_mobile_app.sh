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
npm install socket.io-client @react-native-async-storage/async-storage react-native-gifted-chat

# iOS pod install when on macOS
if command -v pod >/dev/null 2>&1; then
  (cd ios && pod install)
fi

mkdir -p src/components src/screens src/services src/storage src/theme src/utils

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
  bubbleIncoming: '#202C33',
  bubbleOutgoing: '#005C4B',
};
EOT

cat <<'EOT' > src/utils/ids.ts
export const createAnonymousId = (): string => {
  return `anon_${Date.now()}_${Math.random().toString(16).slice(2)}`;
};
EOT

cat <<'EOT' > src/storage/storage.ts
import AsyncStorage from '@react-native-async-storage/async-storage';

const USER_ID_KEY = 'anonymous_user_id';
const CHAT_HISTORY_KEY = 'chat_history';

export const storage = {
  async getUserId(): Promise<string | null> {
    return AsyncStorage.getItem(USER_ID_KEY);
  },
  async setUserId(id: string): Promise<void> {
    await AsyncStorage.setItem(USER_ID_KEY, id);
  },
  async getChatHistory(): Promise<string | null> {
    return AsyncStorage.getItem(CHAT_HISTORY_KEY);
  },
  async setChatHistory(history: string): Promise<void> {
    await AsyncStorage.setItem(CHAT_HISTORY_KEY, history);
  },
  async clearChat(): Promise<void> {
    await AsyncStorage.removeItem(CHAT_HISTORY_KEY);
  },
};
EOT

cat <<'EOT' > src/services/socketService.ts
import { io, Socket } from 'socket.io-client';

const API_URL = process.env.API_URL ?? 'http://localhost:3000';

type SocketEvents = {
  onConnect: () => void;
  onDisconnect: () => void;
  onMatchFound: (payload: { partnerId: string }) => void;
  onMessage: (payload: { id: string; text: string; createdAt: string; userId: string }) => void;
  onPartnerLeft: () => void;
};

class SocketService {
  private socket: Socket | null = null;

  connect(userId: string, events: SocketEvents) {
    this.socket = io(API_URL, {
      transports: ['websocket'],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      auth: { userId },
    });

    this.socket.on('connect', events.onConnect);
    this.socket.on('disconnect', events.onDisconnect);
    this.socket.on('match_found', events.onMatchFound);
    this.socket.on('message', events.onMessage);
    this.socket.on('partner_left', events.onPartnerLeft);
  }

  findMatch() {
    this.socket?.emit('find_match');
  }

  sendMessage(message: { text: string; createdAt: string; userId: string }) {
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
    this.socket?.disconnect();
    this.socket = null;
  }
}

export const socketService = new SocketService();
EOT

cat <<'EOT' > src/components/MatchingAnimation.tsx
import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View } from 'react-native';
import { colors } from '../theme/colors';

const DOT_COUNT = 3;

export const MatchingAnimation = () => {
  const animations = useRef([...Array(DOT_COUNT)].map(() => new Animated.Value(0))).current;

  useEffect(() => {
    const loops = animations.map((anim, index) =>
      Animated.loop(
        Animated.sequence([
          Animated.timing(anim, {
            toValue: 1,
            duration: 300,
            delay: index * 150,
            useNativeDriver: true,
          }),
          Animated.timing(anim, {
            toValue: 0.3,
            duration: 300,
            useNativeDriver: true,
          }),
        ]),
      ),
    );

    loops.forEach(loop => loop.start());
    return () => loops.forEach(loop => loop.stop());
  }, [animations]);

  return (
    <View style={styles.container}>
      {animations.map((anim, index) => (
        <Animated.View
          key={`dot-${index}`}
          style={[styles.dot, { opacity: anim, transform: [{ scale: anim }] }]}
        />
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    gap: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: colors.accent,
  },
});
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

cat <<'EOT' > src/screens/MatchingScreen.tsx
import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { MatchingAnimation } from '../components/MatchingAnimation';
import { colors } from '../theme/colors';

export const MatchingScreen = () => (
  <View style={styles.container}>
    <Text style={styles.title}>Finding a partner</Text>
    <MatchingAnimation />
    <Text style={styles.subtitle}>Stay respectful. You can report or block anytime.</Text>
  </View>
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  title: {
    color: colors.textPrimary,
    fontSize: 22,
    fontWeight: '600',
    marginBottom: 16,
  },
  subtitle: {
    marginTop: 24,
    textAlign: 'center',
    color: colors.textSecondary,
  },
});
EOT

cat <<'EOT' > src/screens/ChatScreen.tsx
import React, { useMemo, useState } from 'react';
import { Alert, Linking, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { GiftedChat, IMessage } from 'react-native-gifted-chat';
import { colors } from '../theme/colors';

type Props = {
  userId: string;
  partnerId: string;
  isOffline: boolean;
  messages: IMessage[];
  onSend: (messages: IMessage[]) => void;
  onReport: (reason: string) => void;
  onBlock: () => void;
};

export const ChatScreen = ({
  userId,
  partnerId,
  isOffline,
  messages,
  onSend,
  onReport,
  onBlock,
}: Props) => {
  const [isReportOpen, setReportOpen] = useState(false);

  const reportReasons = useMemo(
    () => ['Harassment', 'Spam', 'Hate Speech', 'Inappropriate Content', 'Other'],
    [],
  );

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>Anonymous Chat</Text>
          <Text style={styles.headerSubtitle}>Partner ID: {partnerId}</Text>
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
                { text: 'Block', style: 'destructive', onPress: onBlock },
              ])
            }
          >
            <Text style={styles.headerButtonText}>Block</Text>
          </Pressable>
        </View>
      </View>
      {isOffline && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>Offline · Messages will send when reconnected</Text>
        </View>
      )}
      <GiftedChat
        messages={messages}
        onSend={onSend}
        user={{ _id: userId }}
        placeholder="Type a message"
        renderUsernameOnMessage
        alwaysShowSend
        timeTextStyle={{ left: styles.timeText, right: styles.timeText }}
        textInputStyle={styles.input}
        messagesContainerStyle={styles.messagesContainer}
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
                  onReport(reason);
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

cat <<'EOT' > src/App.tsx
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { SafeAreaView, StatusBar } from 'react-native';
import { GiftedChat, IMessage } from 'react-native-gifted-chat';
import { OfflineBanner } from './components/OfflineBanner';
import { ChatScreen } from './screens/ChatScreen';
import { MatchingScreen } from './screens/MatchingScreen';
import { socketService } from './services/socketService';
import { storage } from './storage/storage';
import { createAnonymousId } from './utils/ids';
import { colors } from './theme/colors';

export default function App() {
  const [userId, setUserId] = useState('');
  const [partnerId, setPartnerId] = useState('');
  const [messages, setMessages] = useState<IMessage[]>([]);
  const [isOffline, setIsOffline] = useState(false);
  const [isMatching, setIsMatching] = useState(true);

  useEffect(() => {
    const init = async () => {
      const storedId = await storage.getUserId();
      const nextId = storedId ?? createAnonymousId();
      if (!storedId) {
        await storage.setUserId(nextId);
      }
      setUserId(nextId);

      const storedMessages = await storage.getChatHistory();
      if (storedMessages) {
        setMessages(JSON.parse(storedMessages));
      }
    };

    init();
  }, []);

  useEffect(() => {
    if (!userId) {
      return;
    }

    socketService.connect(userId, {
      onConnect: () => setIsOffline(false),
      onDisconnect: () => setIsOffline(true),
      onMatchFound: payload => {
        setPartnerId(payload.partnerId);
        setIsMatching(false);
      },
      onMessage: payload => {
        const incoming: IMessage = {
          _id: payload.id,
          text: payload.text,
          createdAt: new Date(payload.createdAt),
          user: { _id: payload.userId },
        };
        setMessages(prev => GiftedChat.append(prev, [incoming]));
      },
      onPartnerLeft: () => {
        setPartnerId('');
        setIsMatching(true);
      },
    });

    socketService.findMatch();

    return () => socketService.disconnect();
  }, [userId]);

  useEffect(() => {
    storage.setChatHistory(JSON.stringify(messages));
  }, [messages]);

  const handleSend = useCallback(
    (outgoing: IMessage[] = []) => {
      setMessages(prev => GiftedChat.append(prev, outgoing));
      outgoing.forEach(msg => {
        socketService.sendMessage({
          text: msg.text,
          createdAt: msg.createdAt.toISOString(),
          userId: String(msg.user._id),
        });
      });
    },
    [],
  );

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
    setPartnerId('');
    setIsMatching(true);
  }, [partnerId, userId]);

  const content = useMemo(() => {
    if (isMatching) {
      return <MatchingScreen />;
    }

    return (
      <ChatScreen
        userId={userId}
        partnerId={partnerId}
        isOffline={isOffline}
        messages={messages}
        onSend={handleSend}
        onReport={handleReport}
        onBlock={handleBlock}
      />
    );
  }, [handleBlock, handleReport, handleSend, isMatching, isOffline, messages, partnerId, userId]);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.background }}>
      <StatusBar barStyle="light-content" backgroundColor={colors.surface} />
      <OfflineBanner isOffline={isOffline} />
      {content}
    </SafeAreaView>
  );
}
EOT

cat <<'EOT' > index.js
import { AppRegistry } from 'react-native';
import App from './src/App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
EOT

echo "React Native app scaffolded successfully in $APP_NAME"

chmod +x /workspace/Chat/generate_mobile_app.sh
