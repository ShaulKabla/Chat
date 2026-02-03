const getFriends = (pool) => async (req, res) => {
  const t = req.t || ((key) => key);
  const userId = req.user?.sub;
  if (!userId) {
    return res.status(401).json({ error: t("errors.unauthorized") });
  }
  try {
    const { rows } = await pool.query(
      `
        SELECT f.friend_id,
               p.gender,
               p.age_group,
               p.interests,
               p.gender_preference,
               (
                 SELECT body
                 FROM friend_messages
                 WHERE (sender_id = $1 AND recipient_id = f.friend_id)
                    OR (sender_id = f.friend_id AND recipient_id = $1)
                 ORDER BY created_at DESC
                 LIMIT 1
               ) AS last_message
        FROM friends f
        LEFT JOIN profiles p ON p.user_id = f.friend_id
        WHERE f.user_id = $1
        ORDER BY f.created_at DESC
      `,
      [userId]
    );
    return res.json({ friends: rows });
  } catch (err) {
    return res.status(500).json({ error: t("errors.failedFriendsLoad") });
  }
};

const getFriendMessages = (pool) => async (req, res) => {
  const t = req.t || ((key) => key);
  const userId = req.user?.sub;
  const friendId = String(req.params.friendId || "");
  if (!userId) {
    return res.status(401).json({ error: t("errors.unauthorized") });
  }
  if (!friendId) {
    return res.status(400).json({ error: t("errors.missingFriendId") });
  }
  try {
    const { rows } = await pool.query(
      `
        SELECT id, sender_id, recipient_id, body, image_url, created_at
        FROM friend_messages
        WHERE (sender_id = $1 AND recipient_id = $2)
           OR (sender_id = $2 AND recipient_id = $1)
        ORDER BY created_at DESC
        LIMIT 200
      `,
      [userId, friendId]
    );
    return res.json({ messages: rows });
  } catch (err) {
    return res.status(500).json({ error: t("errors.failedMessagesLoad") });
  }
};

const sendFriendMessage = (pool, io, socketByUser) => async (req, res) => {
  const t = req.t || ((key) => key);
  const userId = req.user?.sub;
  const friendId = String(req.params.friendId || "");
  const { text, imageUrl } = req.body || {};
  if (!userId) {
    return res.status(401).json({ error: t("errors.unauthorized") });
  }
  if (!friendId) {
    return res.status(400).json({ error: t("errors.missingFriendId") });
  }
  if (!text && !imageUrl) {
    return res.status(400).json({ error: t("errors.missingMessage") });
  }

  try {
    const { rows: exists } = await pool.query(
      "SELECT 1 FROM friends WHERE user_id = $1 AND friend_id = $2",
      [userId, friendId]
    );
    if (!exists.length) {
      return res.status(403).json({ error: t("errors.unauthorized") });
    }

    const { rows } = await pool.query(
      "INSERT INTO friend_messages (sender_id, recipient_id, body, image_url) VALUES ($1, $2, $3, $4) RETURNING id, created_at",
      [userId, friendId, text || "", imageUrl || null]
    );
    const message = {
      id: rows[0].id,
      senderId: userId,
      recipientId: friendId,
      body: text || "",
      imageUrl: imageUrl || null,
      createdAt: rows[0].created_at
    };

    const friendSocketId = socketByUser.get(friendId);
    if (friendSocketId) {
      io.to(friendSocketId).emit("friend_message", message);
    }

    return res.json({ message });
  } catch (err) {
    return res.status(500).json({ error: t("errors.failedMessageSend") });
  }
};

module.exports = {
  getFriends,
  getFriendMessages,
  sendFriendMessage
};
