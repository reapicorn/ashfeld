FROM node:18-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY . .

# Directory for OIDC keystore persistence
RUN mkdir -p /app/data

EXPOSE 3000

CMD ["node", "src/index.js"]
