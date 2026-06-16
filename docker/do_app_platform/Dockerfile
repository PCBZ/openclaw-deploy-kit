FROM ghcr.io/openclaw/openclaw:latest

USER root

# Install grammy (Telegram plugin dependency)
RUN npm install -g grammy @grammyjs/runner @grammyjs/transformer-throttler

USER node

COPY --chown=node:node entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 18789

ENTRYPOINT ["/entrypoint.sh"]
