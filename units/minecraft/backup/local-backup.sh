#!/usr/bin/env bash
bash ./before-backup.sh
BACKUP_PATH="/srv/minecraft/backup/$SERVER_NAME/$(date --iso-8601=minutes)"
mkdir -p "$BACKUP_PATH"
cp -r "$DATA_PATH" "$BACKUP_PATH"
# for the eventual cleanup script
echo $(fd --type directory --exact-depth 1 --changed-before 1d)
bash ./after-backup.sh