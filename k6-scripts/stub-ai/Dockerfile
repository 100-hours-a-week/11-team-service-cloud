FROM node:22-alpine

WORKDIR /app

COPY . .

ENV PORT=8000
EXPOSE 8000

USER node

CMD ["node", "server.js"]