# Use the latest stable Alpine as the base image for building the app
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy all project files
COPY . .

# Build the application
RUN npm run build

# Use the latest stable Alpine as the base image for the final stage
FROM alpine:latest

# Set environment variables to prevent interactive prompts
ENV LIBXML2_VERSION=2.13.4-r5

# Update Alpine, install the latest Nginx and dependencies, and fix vulnerabilities
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache \
        nginx \
        libxml2=${LIBXML2_VERSION} \
        libxml2-utils && \
    rm -rf /var/cache/apk/*

# Set working directory for Nginx
WORKDIR /usr/share/nginx/html

# Remove the default nginx index.html
RUN rm -rf ./*

# Copy built application from the builder stage
COPY --from=builder /app/dist ./ 

# Copy the custom Nginx configuration file
COPY nginx.conf /etc/nginx/nginx.conf

# Ensure proper permissions for cache directory
RUN mkdir -p /var/cache/nginx/client_temp && \
    chown -R nginx:nginx /var/cache/nginx

# Run Nginx as a non-root user
USER nginx

# Expose port 80
EXPOSE 80

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
