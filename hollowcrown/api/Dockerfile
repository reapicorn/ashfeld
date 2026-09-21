FROM node:18-alpine@sha256:8d6421d663b4c28fd3ebc498332f249011d118945588d0a35cb9bc4b8ca09d9e
RUN apk add --no-cache curl
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY src/ ./src/
EXPOSE 4000
CMD ["node", "src/index.js"]
