FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY src/ ./src/
RUN mkdir -p /data
VOLUME ["/data"]
ENV DATA_DIR=/data
EXPOSE 3001
CMD ["node", "src/index.js"]
