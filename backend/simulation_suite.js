/* eslint-disable no-console */
const assert = require('assert');
const { io } = require('socket.io-client');
const { performance } = require('perf_hooks');
const Ajv = require('ajv');
const schema = require('../docs/socket_events.schema.json');

const BASE_URL = process.env.SIM_BASE_URL || 'http://localhost:3000';
const REQUEST_TIMEOUT_MS = Number(process.env.SIM_TIMEOUT_MS || 7000);
const REVEAL_WAIT_MS = Number(process.env.SIM_REVEAL_WAIT_MS || 3500);

const logPass = (message) => console.log(`[PASS] ${message}`);
const logInfo = (message) => console.log(`[INFO] ${message}`);
const logFail = (message) => console.error(`[FAIL] ${message}`);

const withTimeout = (promise, timeoutMs, label) =>
  Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`Timeout waiting for ${label}`)), timeoutMs)
    ),
  ]);

const waitForEvent = (socket, event, timeoutMs = REQUEST_TIMEOUT_MS) =>
  withTimeout(
    new Promise((resolve) => {
      socket.once(event, (payload) => resolve(payload));
    }),
    timeoutMs,
    `${event}`
  );

const expectNoEvent = (socket, event, windowMs) =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off(event, handler);
      resolve();
    }, windowMs);
    const handler = (payload) => {
      clearTimeout(timer);
      reject(new Error(`Unexpected ${event} payload: ${JSON.stringify(payload)}`));
    };
    socket.once(event, handler);
  });

const ajv = new Ajv({ allErrors: true, strict: false });

const validateServerPayload = (event, payload) => {
  const eventSchema = schema?.properties?.serverToClient?.properties?.[event];
  if (!eventSchema) {
    return;
  }
  const validate = ajv.compile(eventSchema);
  const valid = validate(payload ?? {});
  if (!valid) {
    throw new Error(`Schema validation failed for ${event}: ${ajv.errorsText(validate.errors)}`);
  }
};

const attachSchemaValidation = (socket) => {
  socket.onAny((event, payload) => {
    if (event === 'connect' || event === 'disconnect') {
      return;
    }
    validateServerPayload(event, payload);
  });
};

const registerAnonymous = async () => {
  if (typeof fetch !== 'function') {
    throw new Error('Global fetch is not available. Use Node 18+ or add a fetch polyfill.');
  }
  const response = await fetch(`${BASE_URL}/api/auth/anonymous`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fcmToken: `sim_${Date.now()}_${Math.random().toString(16).slice(2)}` }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`Anonymous auth failed: ${data?.error || response.statusText}`);
  }
  assert.ok(data.token, 'Missing token');
  assert.ok(data.userId, 'Missing userId');
  return data;
};

const connectSocket = async (token) => {
  const socket = io(BASE_URL, {
    transports: ['websocket'],
    autoConnect: false,
    reconnection: false,
    auth: { token },
  });
  attachSchemaValidation(socket);
  socket.connect();
  await waitForEvent(socket, 'connect');
  return socket;
};

const updateProfile = (socket, payload) =>
  new Promise((resolve, reject) => {
    socket.emit('update_profile', payload, (ack) => {
      if (!ack?.ok) {
        return reject(new Error(`update_profile failed: ${ack?.error || 'unknown'}`));
      }
      return resolve(ack.profile);
    });
  });

const findMatch = (socket, mode) => socket.emit('find_match', { mode });

const sendMessage = (socket, payload) =>
  new Promise((resolve, reject) => {
    socket.emit('message', payload, (ack) => {
      if (!ack?.ok) {
        return reject(new Error(`message failed: ${ack?.error || 'unknown'}`));
      }
      return resolve(ack.messageId);
    });
  });

const ensureMatchFound = (payload) => {
  assert.ok(payload?.partnerId, 'Missing partnerId');
  assert.ok(payload?.mode, 'Missing mode');
  assert.ok(typeof payload?.revealAvailable === 'boolean', 'Missing revealAvailable');
};

const ensurePartnerProfile = (payload) => {
  assert.ok(payload?.partnerProfile, 'Missing partnerProfile');
  assert.ok(payload.partnerProfile.gender, 'Missing partnerProfile.gender');
  assert.ok(payload.partnerProfile.ageGroup, 'Missing partnerProfile.ageGroup');
  assert.ok(Array.isArray(payload.partnerProfile.interests), 'Missing partnerProfile.interests');
};

const runMeetFlow = async () => {
  logInfo('Meet flow: register users A/B');
  const userA = await registerAnonymous();
  const userB = await registerAnonymous();

  const socketA = await connectSocket(userA.token);
  const socketB = await connectSocket(userB.token);

  logInfo('Meet flow: update profiles');
  await updateProfile(socketA, {
    gender: 'Man',
    ageGroup: '25-34',
    interests: ['music', 'travel', 'coffee'],
    genderPreference: 'Woman',
  });
  await updateProfile(socketB, {
    gender: 'Woman',
    ageGroup: '25-34',
    interests: ['music', 'art', 'coffee'],
    genderPreference: 'Man',
  });
  logPass('Profiles updated via update_profile');

  findMatch(socketA, 'meet');
  findMatch(socketB, 'meet');

  const [matchA, matchB] = await Promise.all([
    waitForEvent(socketA, 'match_found'),
    waitForEvent(socketB, 'match_found'),
  ]);
  ensureMatchFound(matchA);
  ensureMatchFound(matchB);
  ensurePartnerProfile(matchA);
  ensurePartnerProfile(matchB);
  logPass('match_found includes partnerProfile');

  const imageUrl = 'https://example.com/test.jpg';
  const messagePromise = waitForEvent(socketB, 'message');
  await sendMessage(socketA, {
    clientId: `client_${Date.now()}`,
    text: 'photo',
    createdAt: Date.now(),
    userId: userA.userId,
    image: imageUrl,
  });
  const messagePayload = await messagePromise;
  assert.ok(messagePayload, 'Missing message payload');
  assert.strictEqual(messagePayload.imagePending, true, 'Expected imagePending true');
  assert.ok(messagePayload.image == null, 'Expected image URL to be hidden');
  logPass('Image message is reveal-gated with imagePending');

  await sendMessage(socketB, {
    clientId: `client_${Date.now()}_b`,
    text: 'hello',
    createdAt: Date.now(),
    userId: userB.userId,
  });

  const revealTimer = await Promise.all([
    waitForEvent(socketA, 'reveal_timer_started'),
    waitForEvent(socketB, 'reveal_timer_started'),
  ]);
  assert.ok(revealTimer[0]?.revealAt, 'Missing revealAt');
  logPass('Reveal timer started on server session');

  await Promise.all([
    waitForEvent(socketA, 'reveal_available'),
    waitForEvent(socketB, 'reveal_available'),
  ]);
  logPass('Reveal is available for both users');

  socketA.emit('reveal_request');
  await expectNoEvent(socketA, 'reveal_granted', 500);
  await expectNoEvent(socketB, 'reveal_granted', 500);
  logPass('Single reveal_request does not grant reveal');

  const revealGrantedPromiseA = waitForEvent(socketA, 'reveal_granted');
  const revealGrantedPromiseB = waitForEvent(socketB, 'reveal_granted');
  socketB.emit('reveal_request');
  const [revealGrantedA, revealGrantedB] = await Promise.all([
    revealGrantedPromiseA,
    revealGrantedPromiseB,
  ]);

  assert.ok(Array.isArray(revealGrantedA?.images), 'Missing revealGranted images for A');
  assert.ok(Array.isArray(revealGrantedB?.images), 'Missing revealGranted images for B');
  const imageEntry = revealGrantedB.images.find((entry) => entry.imageUrl === imageUrl);
  assert.ok(imageEntry?.messageId, 'Missing messageId for revealed image');
  logPass('Reveal granted and image URLs delivered');

  socketA.disconnect();
  socketB.disconnect();
};

const runDoubleSkipTest = async () => {
  logInfo('Double skip test: connect users');
  const userA = await registerAnonymous();
  const userB = await registerAnonymous();

  const socketA = await connectSocket(userA.token);
  const socketB = await connectSocket(userB.token);

  findMatch(socketA, 'talk');
  findMatch(socketB, 'talk');

  await Promise.all([
    waitForEvent(socketA, 'match_found'),
    waitForEvent(socketB, 'match_found'),
  ]);

  let partnerLeftCount = 0;
  socketB.on('partner_left', () => {
    partnerLeftCount += 1;
  });

  socketA.emit('skip');
  socketA.emit('skip');

  await new Promise((resolve) => setTimeout(resolve, 300));
  assert.strictEqual(partnerLeftCount, 1, 'partner_left emitted more than once');
  logPass('Double skip emits partner_left once');

  socketA.disconnect();
  socketB.disconnect();
};

const runChaosDisconnectTest = async () => {
  logInfo('Chaos test: meet mode disconnect during reveal');
  const userA = await registerAnonymous();
  const userB = await registerAnonymous();

  const socketA = await connectSocket(userA.token);
  const socketB = await connectSocket(userB.token);

  await updateProfile(socketA, {
    gender: 'Man',
    ageGroup: '25-34',
    interests: ['sports', 'tech', 'coffee'],
    genderPreference: 'Woman',
  });
  await updateProfile(socketB, {
    gender: 'Woman',
    ageGroup: '25-34',
    interests: ['sports', 'travel', 'coffee'],
    genderPreference: 'Man',
  });

  findMatch(socketA, 'meet');
  findMatch(socketB, 'meet');

  await Promise.all([
    waitForEvent(socketA, 'match_found'),
    waitForEvent(socketB, 'match_found'),
  ]);

  await sendMessage(socketA, {
    clientId: `client_${Date.now()}_a`,
    text: 'hello',
    createdAt: Date.now(),
    userId: userA.userId,
  });
  await sendMessage(socketB, {
    clientId: `client_${Date.now()}_b`,
    text: 'hello',
    createdAt: Date.now(),
    userId: userB.userId,
  });

  await waitForEvent(socketA, 'reveal_timer_started');
  await waitForEvent(socketB, 'reveal_timer_started');

  const partnerLeftPromise = waitForEvent(socketB, 'partner_left', 1500);
  await new Promise((resolve) => setTimeout(resolve, 2000));
  const start = performance.now();
  socketA.disconnect();
  const partnerLeftPayload = await partnerLeftPromise;
  const elapsedMs = performance.now() - start;

  assert.ok(partnerLeftPayload?.reason, 'Missing partner_left reason');
  assert.ok(elapsedMs < 100, `partner_left exceeded 100ms (${elapsedMs.toFixed(1)}ms)`);
  logPass(`partner_left delivered in ${elapsedMs.toFixed(1)}ms`);

  await expectNoEvent(socketB, 'reveal_available', REVEAL_WAIT_MS);
  logPass('Reveal timer cleared after disconnect (no reveal_available)');

  const matchSearchingPayload = await waitForEvent(socketB, 'match_searching');
  assert.ok(matchSearchingPayload?.message, 'Missing match_searching message');
  logPass('Partner requeued after disconnect');

  socketB.disconnect();
};

const runConcurrentLoadTest = async () => {
  logInfo('Concurrent load: 5 pairs in parallel');
  const users = await Promise.all(Array.from({ length: 10 }, () => registerAnonymous()));
  const sockets = await Promise.all(users.map((user) => connectSocket(user.token)));

  sockets.forEach((socket) => findMatch(socket, 'talk'));

  const matches = await Promise.all(sockets.map((socket) => waitForEvent(socket, 'match_found')));
  matches.forEach(ensureMatchFound);

  const partnerPairs = new Map();
  matches.forEach((match, index) => {
    partnerPairs.set(sockets[index].id, match.partnerId);
  });

  assert.strictEqual(partnerPairs.size, 10, 'Expected matches for all sockets');
  logPass('All sockets matched in concurrent load');

  sockets.forEach((socket) => socket.disconnect());
};

const main = async () => {
  try {
    await runMeetFlow();
    await runDoubleSkipTest();
    await runChaosDisconnectTest();
    await runConcurrentLoadTest();
    logPass('Simulation suite completed successfully.');
  } catch (err) {
    logFail(err.message);
    process.exit(1);
  }
};

main();
