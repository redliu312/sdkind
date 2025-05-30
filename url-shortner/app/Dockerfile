FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install express redis
RUN apk add --no-cache curl busybox-extras
COPY app/app.js ./
EXPOSE 3000
CMD ["node", "app.js"]