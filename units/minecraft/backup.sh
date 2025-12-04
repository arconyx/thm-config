#!/usr/bin/env bash

# setup
if [[ -p "$SOCKET" ]]; then
  if echo "save-off" > "$SOCKET"; then
    echo "tell @a Local backup started. Autosave disabled." > "$SOCKET"
    echo "'save-off' command sent successfully."
  else
    echo "Warning: Failed to send 'save-off' command via socket."
    echo "say Backup error: Unable to pause autosave" > "$SOCKET"
  fi
  # Add a small delay to ensure the server processes the save-off command
  sleep 1
  # Send the 'save-all' command to the server via the socket
  echo "Sending 'save-all' command..."
  if echo "save-all" > "$SOCKET"; then
    echo "'save-all' command sent successfully."

    # Add a delay to allow the server to complete the manual save before backup starts
    echo "Waiting $SAVE_WAIT_TIME seconds for the server to complete saving (if online)..."
    sleep "$SAVE_WAIT_TIME"
  else
    echo "Warning: Failed to send 'save-all' command via socket."
    echo "say Backup error: Unable to force save" > "$SOCKET"
  fi
else
    echo "Socket not available, skipping save commands. Backup will proceed without pausing server saves."
fi

if [[ -f "$DATA_DIR/world/ledger.sqlite" ]]; then
  if sqlite3 "$DATA_DIR/world/ledger.sqlite" "VACUUM INTO '$DATA_DIR/ledger_backup.sqlite'"; then
    echo "Exported ledger database"
  else
    echo "Warning: Unable to export ledger database"
    echo "say Backup error: Unable to export ledger" > "$SOCKET"
  fi
fi

# actual backup
BACKUP_PATH="$BACKUP_ROOT/$(date +%Y%m%d-%H%M)"
mkdir -p "$BACKUP_PATH"
cp --reflink=always -r "$DATA_DIR" "$BACKUP_PATH"
echo "Backup done"

# cleanup
if [[ -p "$SOCKET" ]]; then
  if echo "save-on" > "$SOCKET"; then
    echo "tell @a Local backup finished. Autosave enabled." > "$SOCKET"
    echo "'save-on' command sent successfully. Autosave re-enabled."
  else
    echo "Warning: Failed to send 'save-on' command via socket."
    echo "say Backup error: Unable to resume autosave" > "$SOCKET"
  fi
else
  echo "Socket not found, skipping save-on"
fi

if [[ -f "$DATA_DIR/ledger_backup.sqlite" ]]; then
  if rm "$DATA_DIR/ledger_backup.sqlite"; then
    echo "Removed ledger backup db"
  else
    echo "Warning: Unable to cleanup ledger database"
    echo "say Backup error: Unable to cleanup ledger export" > "$SOCKET"
  fi
fi

echo "Cleaning old backups"
fd --type directory --exact-depth 1 --changed-before 1d --absolute-path --full-path "$BACKUP_ROOT" "$BACKUP_ROOT" | xargs --no-run-if-empty rm --recursive --preserve-root=all
echo "Cleanup done"