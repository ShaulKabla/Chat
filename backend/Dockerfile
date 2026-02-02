FROM node:20-alpine

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY server.js ./
COPY controllers ./controllers
COPY middleware ./middleware
COPY services ./services
COPY healthcheck.sh ./healthcheck.sh

RUN chmod +x /app/healthcheck.sh

USER app

EXPOSE 3000

CMD ["node", "server.js"]
