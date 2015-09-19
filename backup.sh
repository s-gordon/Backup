#!/usr/bin/env sh

# Ensure only one instance of script is running --------------------------- {{{

# Adapted from here:
# http://mywiki.wooledge.org/BashFAQ/045
lockdir=/tmp/myscript.lock
if mkdir "$lockdir"
then
  echo >&2 "successfully acquired lock"

  # Remove lockdir when the script finishes, or when it receives a signal
  trap 'rm -rf "$lockdir"' 0    # remove directory when script finishes

else
  echo >&2 "cannot acquire lock, giving up on $lockdir"
  exit 0
fi

# }}}

# Error Reporting --------------------------------------------------------- {{{

# Taken from <http://www.linuxcommand.org/wss0150.php>

# A slicker error handling routine

# I put a variable in my scripts named PROGNAME which
# holds the name of the program being run.  You can get this
# value from the first item on the command line ($0).

PROGNAME=$(basename "$0")

error_exit() {
  # ----------------------------------------------------------------
  # Function for exit due to fatal program error
  #   Accepts 1 argument:
  #     string containing descriptive error message
  # ----------------------------------------------------------------
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

# Example call of the error_exit function.  Note the inclusion
# of the LINENO environment variable.  It contains the current
# line number.

# echo "Example of error with line number and message"
# error_exit "$LINENO: An error has occurred."

check_dir_exists() {
  if [ ! -d "$1" ]; then
    # error_exit "$LINENO: An error has occurred. Directory $1 not found."
    error_exit "An error has occurred. Directory $1 not found."
  fi
}

check_file_exists() {
  if [ ! -d "$1" ]; then
    # error_exit "$LINENO: An error has occurred. File $1 not found."
    error_exit "An error has occurred. File $1 not found."
  fi
}

check_program_exists() {
  if hash "$1" 2>/dev/null; then
    :
  else
    # error_exit "$LINENO: An error has occurred. Program $1 not found."
    error_exit "An error has occurred. Program $1 not found."
  fi
}

# }}}

# Absolute paths to packages
SSH=/usr/bin/ssh

# Check the command dependency
CMDS="date rsync find $SSH"

for i in $CMDS; do
  check_program_exists "$i"
done

# Step #0: Data Repository Models ----------------------------------------- {{{

# Variable to configure
HOST="backup"
USER="sgordon"
BACKUP_HOME="/mnt/SEGordon_Backup/MacBookAir/home"
# BACKUP_HOME="/mnt/Resources/backup/MacBookAir/home"
PROJECT_DIR="$(dirname "$0")"
BACKUP_SOURCE_DIR="/Users/$USER"
BACKUP_EXCLUDE_LIST="$PROJECT_DIR/exclude-list.txt"

# Dates
NOW=$(date +%Y%m%d%H%M)               #YYYYMMDDHHMM

# Backup Configuration
LOGFILE="/mnt/Resources/backup/MacBookAir/home/backups.log"
CURRENT_LINK="$BACKUP_HOME/current"
SNAPSHOT_DIR="$BACKUP_HOME/snapshots"

echo $CURRENT_LINK

start_time=$(date +%s)

# }}}

# Precautionary checks ---------------------------------------------------- {{{

# Init the folder structure
mkdir -p "$SNAPSHOT_DIR" "$DAILY_ARCHIVES_DIR" "$WEEKLY_ARCHIVES_DIR" "$MONTHLY_ARCHIVES_DIR" 2> /dev/null
touch $LOGFILE
printf "[%12d] Backup started\n" "$NOW" >> "$LOGFILE"

# }}}

# Step #1: Retrieve files to create snapshots with RSYNC ------------------ {{{

# rsync -azHvP --link-dest="$CURRENT_LINK" --exclude-from "$BACKUP_EXCLUDE_LIST" "$BACKUP_SOURCE_DIR" "$backup$SNAPSHOT_DIR/$NOW" \
rsync -azH --link-dest="$CURRENT_LINK" --exclude-from "$BACKUP_EXCLUDE_LIST" -e "$SSH" "$BACKUP_SOURCE_DIR" "$HOST:$SNAPSHOT_DIR/$NOW" \
  && RECENTSNAPSHOT=$("$SSH" $HOST "ls -1d $SNAPSHOT_DIR/* | tail -n1") \
  && "$SSH" $HOST "ln -snf $RECENTSNAPSHOT $CURRENT_LINK" \
  && printf "\t- Copy from %s to %s successful \n" "$BACKUP_SOURCE_DIR" "$SNAPSHOT_DIR/$NOW" >> $LOGFILE

# }}}

end_time=$(date +%s)
printf "\t===== Backup execute successfully in %6d s. =====\n" "$(echo "$end_time - $start_time" | bc -l)" >> "$LOGFILE"
