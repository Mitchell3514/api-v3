### INSTALLER STAGE ###
FROM node:12.13.1-alpine AS installer

# Create app directory
WORKDIR /usr/src/installer

ENV NODE_ENV=production

# Run update and upgrade/install in the same step to avoid reusing an old package cache from `apk update`
RUN apk update \
	&& apk add yarn

COPY package.json yarn.lock ./

RUN yarn install --production=true

### BUILDER STAGE ###
FROM node:12.13.1-alpine AS builder

# Create app directory
WORKDIR /usr/src/builder

ENV NODE_ENV=production

RUN apk update \
	&& apk upgrade \
	&& apk add yarn

# Install dependencies
COPY package.json yarn.lock ./

# Copy dependencies that were installed before
COPY --from=installer /usr/src/installer/node_modules node_modules

# Install the other devdependencies
RUN yarn install --production=false

# Copy build configurations
COPY tsconfig.json tsconfig.build.json ./

# Copy types
COPY types ./types

# Copy source
COPY src ./src

# Build the project
RUN yarn run build

ENTRYPOINT ["yarn", "run", "start:prod"]


### SERVER STAGE ###
FROM node:12.13.1-alpine AS server

LABEL maintainer 'Jonah Snider <jonah@jonah.pw> (jonah.pw)'

# Same workdir as the build stage
WORKDIR /usr/src/discoin

ENV NODE_ENV=production PORT=80

# Change this number if you change the port above
EXPOSE 80

# Start the program and try doing a health check for 12s after waiting 15s for the program to sart
# Repeat this every 12s
# If it fails 3 times this instance is declared unhealthy
HEALTHCHECK --interval=12s --timeout=12s --start-period=15s \
	# Change the port number below if you change the port above
	CMD curl -X GET --fail http://localhost:80/health || exit 1

RUN apk update \
	&& apk upgrade \
	&& apk add yarn curl

# Copy compiled TypeScript
COPY --from=builder /usr/src/builder/tsc_output ./tsc_output

# Install dependencies
COPY --from=installer /usr/src/installer/node_modules ./node_modules
COPY --from=installer /usr/src/installer/yarn.lock ./yarn.lock

# Copy other required files
COPY package.json package.json

ENTRYPOINT ["yarn", "run", "start:prod"]
