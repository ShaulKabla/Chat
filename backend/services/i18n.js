const i18next = require("i18next");
const en = require("../locales/en.json");
const he = require("../locales/he.json");

const supportedLanguages = new Set(["en", "he"]);

const detectLanguage = (value) => {
  if (!value) {
    return "en";
  }
  const candidate = String(value).split(",")[0].trim().toLowerCase();
  if (candidate.startsWith("he")) {
    return "he";
  }
  return supportedLanguages.has(candidate) ? candidate : "en";
};

const initI18n = async () => {
  await i18next.init({
    fallbackLng: "en",
    supportedLngs: ["en", "he"],
    resources: {
      en: { translation: en },
      he: { translation: he }
    },
    interpolation: { escapeValue: false }
  });
};

const i18nMiddleware = (req, res, next) => {
  const lang = detectLanguage(req.headers["x-lang"] || req.headers["accept-language"]);
  req.language = lang;
  req.t = i18next.getFixedT(lang);
  next();
};

const getSocketTranslator = (socket) => {
  const lang = detectLanguage(socket.handshake.auth?.lang || socket.handshake.headers["accept-language"]);
  socket.data.language = lang;
  return i18next.getFixedT(lang);
};

module.exports = {
  initI18n,
  i18nMiddleware,
  getSocketTranslator
};
