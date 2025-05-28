# Dockerfile for Vite + React + Bun frontend
FROM oven/bun:1.1.13 as builder
WORKDIR /app
COPY . .
RUN bun install
RUN bun run build
RUN bun add wagmi ethers @rainbow-me/rainbowkit viem

FROM node:20-alpine as runner
WORKDIR /app
COPY --from=builder /app/dist ./dist
RUN npm install -g serve
EXPOSE 4173
CMD ["serve", "-s", "dist", "-l", "4173"] 