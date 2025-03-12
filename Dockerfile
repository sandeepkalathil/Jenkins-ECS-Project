# Use the latest Alpine as the base image
FROM alpine:latest

# Update Alpine, install Nginx and dependencies
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache \
        nginx \
        libxml2 \
        libxml2-utils && \
    rm -rf /var/cache/apk/*

# Create necessary directories with proper permissions
RUN mkdir -p /var/cache/nginx/client_temp /var/lib/nginx/logs /usr/share/nginx/html && \
    chown -R root:root /var/cache/nginx /var/lib/nginx/logs /usr/share/nginx/html && chmod -R 777 /var/lib/nginx/logs

# Copy the custom Nginx configuration file
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the index.html file into the correct directory
COPY index.html /usr/share/nginx/html/index.html

# Ensure log files exist
RUN touch /var/lib/nginx/logs/error.log /var/lib/nginx/logs/access.log && \
    chmod 777 /var/lib/nginx/logs/*.log

# Expose port 80
EXPOSE 80

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
