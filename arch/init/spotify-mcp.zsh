#!/usr/bin/zsh

cd ~/src || exit
gh repo clone marcelmarais/spotify-mcp-server || exit
cd spotify-mcp-server || exit

ln -s "$ENV_DIR/arch/config/spotify-config.json" ~/src/spotify-mcp-server/spotify-config.json || exit
npm install
npm run build
npm run auth