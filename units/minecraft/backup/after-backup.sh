#! /usr/bin/env bash

# Check if the socket path exists and is a socket file
if [[ -p "$SOCKET_PATH" ]]; then
    echo "Minecraft server socket found. Proceeding with save-on command."

    # Send the 'save-on' command to the server via the socket
    echo "Sending 'save-on' command..."
    if echo "save-on" > "$SOCKET_PATH"; then
        if [ "$ANNOUNCE" -eq 1 ]; then
            echo "say $BACKUP_DEST backup finished. Autosave enabled." > "$SOCKET_PATH"
        fi
        echo "'save-on' command sent successfully. Autosave re-enabled."
    else
        echo "Warning: Failed to send 'save-on' command via socket."
        # Continue execution even if sending fails
    fi

else
    echo "Warning: Socket file '$SOCKET_PATH' not found or is not a socket."
    echo "Minecraft server appears to be offline or socket is not active."
    echo "Skipping save-on command."
fi

if rm "$DATA_PATH/ledger_backup.sqlite"; then
    echo "Removed ledger backup db"
else
    echo "Warning: Unable to cleanup ledger database"
fi

exit 0 # Always exit successfully so the backup process continues