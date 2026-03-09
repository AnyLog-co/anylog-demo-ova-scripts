#!/bin/bash

# ================================
# AnyLog Desktop Startup Script
# ================================

ANYLOG_HOME="/home/edgelake/Anylog"
LOGFILE="$ANYLOG_HOME/logs/startup.log"

echo "--------------------------------------" >> "$LOGFILE"
echo "AnyLog startup triggered: $(date)" >> "$LOGFILE"

# Wait for desktop environment to finish loading
sleep 8

# Open documentation
echo "Opening README..." >> "$LOGFILE"
xdg-open $ANYLOG_HOME/README.html >> "$LOGFILE" 2>&1 &

# Start AnyLog
echo "Starting AnyLog..." >> "$LOGFILE"
$ANYLOG_HOME/ALstartup.sh >> "$LOGFILE" 2>&1 &

echo "Startup script finished: $(date)" >> "$LOGFILE"
