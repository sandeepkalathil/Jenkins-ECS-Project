# Use the latest Alpine as the base image
FROM alpine:latest as builder

# Update Alpine, install Nginx and dependencies
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache \
        nginx \
        libxml2 \
        libxml2-utils && \
    rm -rf /var/cache/apk/*

# Create necessary directories with proper permissions
RUN mkdir -p /var/cache/nginx/client_temp /var/lib/nginx/logs && \
    chown -R root:root /var/cache/nginx /var/lib/nginx/logs && chmod -R 777 /var/lib/nginx/logs

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine 
# Copy the custom Nginx configuration file
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
