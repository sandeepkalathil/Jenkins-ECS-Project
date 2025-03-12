# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Runtime stage
FROM nginx:alpine

# Set non-root user (nginx runs as `nginx` user)
USER root

# Create required directories with proper permissions
RUN mkdir -p /var/run/nginx && \
    chown -R nginx:nginx /var/run/nginx

# Set working directory
WORKDIR /usr/share/nginx/html

# Copy build output from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Switch to non-root user
USER nginx

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
