#!/usr/bin/zsh

cd ~/src || exit
gh repo clone marcelmarais/spotify-mcp-server
cd spotify-mcp-server || exit

cp "$ENV_DIR/arch/config/spotify-config.json" . || exit
npm install
npm run build
npm run auth