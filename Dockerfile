FROM node:18-alpine as builder

# Update and upgrade to install the latest security patches
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache libxml2=2.13.4-r5

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
