FROM node:23-alpine as builder

RUN apk update && \
    apk upgrade --no-cache

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine3.19

RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache libxml2=2.13.4-r5
    
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]