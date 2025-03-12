# Use multi-stage build to optimize the final image
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

# Use Nginx as the final stage
FROM nginx:alpine

# Set working directory
WORKDIR /usr/share/nginx/html

# Remove the default nginx index.html
RUN rm -rf ./*

# Copy built application from the builder stage
COPY --from=builder /app/dist ./

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Ensure proper permissions for cache directory
RUN mkdir -p /var/cache/nginx && \
    chmod -R 755 /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
