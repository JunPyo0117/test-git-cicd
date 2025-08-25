# Build stage
FROM node:18-alpine as build

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Production stage - ultra simple static server
FROM node:18-alpine

# Install serve (better than http-server)
RUN npm install -g serve

# Copy built app
COPY --from=build /app/dist /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Change ownership
RUN chown -R nextjs:nodejs /app

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Start server on non-privileged port
CMD ["serve", "-s", "/app", "-l", "3000"]
