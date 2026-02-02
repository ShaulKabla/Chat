const { v4: uuidv4 } = require("uuid");

const requestId = (req, res, next) => {
  const incoming = req.headers["x-request-id"];
  const id = incoming || uuidv4();
  req.requestId = id;
  res.setHeader("x-request-id", id);
  next();
};

module.exports = requestId;
