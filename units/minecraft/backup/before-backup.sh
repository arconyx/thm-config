#! /usr/bin/env bash

# Check if the socket path exists and is a socket file
if [[ -p "$SOCKET_PATH" ]]; then
    echo "Minecraft server socket found. Proceeding with save commands."

    # Send the 'save-off' command to the server via the socket
    echo "Sending 'save-off' command..."
    if echo "save-off" > "$SOCKET_PATH"; then
        if [ "$ANNOUNCE" -eq 1 ]; then
            echo "say $BACKUP_DEST backup started. Autosave disabled." > "$SOCKET_PATH"
        fi
        echo "'save-off' command sent successfully."
    else
        echo "Warning: Failed to send 'save-off' command via socket."
        # Continue execution even if sending fails, server might be shutting down
    fi

    # Add a small delay to ensure the server processes the save-off command
    sleep 1

    # Send the 'save-all' command to the server via the socket
    echo "Sending 'save-all' command..."
    if echo "save-all" > "$SOCKET_PATH"; then
         echo "'save-all' command sent successfully."
    else
        echo "Warning: Failed to send 'save-all' command via socket."
        # Continue execution even if sending fails
    fi

    # Add a delay to allow the server to complete the manual save before backup starts
    echo "Waiting $SAVE_WAIT_TIME seconds for the server to complete saving (if online)..."
    sleep "$SAVE_WAIT_TIME"

else
    echo "Warning: Socket file '$SOCKET_PATH' not found or is not a socket."
    echo "Minecraft server appears to be offline or socket is not active."
    echo "Skipping save commands. Backup will proceed without pausing server saves."
fi


if "$SQLITE_PATH" "$DATA_PATH/world/ledger.sqlite" "VACUUM INTO '$DATA_PATH/ledger_backup.sqlite'"; then
    echo "Exported ledger database"
else
    echo "Warning: Unable to export ledger database"
fi

echo "Minecraft Server Pre-Backup Script Finished."
exit 0 # Always exit successfully so the backup process continues