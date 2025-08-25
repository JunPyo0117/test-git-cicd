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

# Expose port
EXPOSE 80

# Start server (no proxy, just static files)
CMD ["serve", "-s", "/app", "-l", "80"]
