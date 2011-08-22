#!/bin/bash
#
# Copyright (c) 2008-2010 Damon Timm.
# Copyright (c) 2010 Mario Santagiuliana.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
# MORE ABOUT THIS SCRIPT AVAILABLE IN THE README AND AT:
#
# http://damontimm.com/code/dt-s3-backup
#
# ---------------------------------------------------------------------------- #

# AMAZON S3 INFORMATION
# Comment out this lines if you're not using S3
export AWS_ACCESS_KEY_ID="foobar_aws_key_id"
export AWS_SECRET_ACCESS_KEY="foobar_aws_access_key"

# If you aren't running this from a cron, comment this line out
# and duplicity should prompt you for your password.
# Comment out if you're not using encryption
export PASSPHRASE="foobar_gpg_passphrase"

# Specify which GPG key you would like to use (even if you have only one).
# Comment out if you're not using encryption
GPG_KEY="foobar_gpg_key"

# Do you want your backup to be encrypted? yes/no
ENCRYPTION='yes'

# The ROOT of your backup (where you want the backup to start);
# This can be / or somwhere else -- I use /home/ because all the
# directories start with /home/ that I want to backup.
ROOT="/home"

# BACKUP DESTINATION INFORMATION
# In my case, I use Amazon S3 use this - so I made up a unique
# bucket name (you don't have to have one created, it will do it
# for you).  If you don't want to use Amazon S3, you can backup
# to a file or any of duplicity's supported outputs.
#
# NOTE: You do need to keep the "s3+http://<your location>/" format
# even though duplicity supports "s3://<your location>/".
#DEST="s3+http://backup-bucket/backup-folder/"

# Other possible locations
#DEST="ftp://user[:password]@other.host[:port]/some_dir"
#DEST="rsync://user@host.com[:port]//absolute_path"
#DEST="ssh://user[:password]@other.host[:port]/[/]some_dir"
DEST="file:///home/foobar_user_name/new-backup-test/"

# INCLUDE LIST OF DIRECTORIES
# Here is a list of directories to include; if you want to include
# everything that is in root, you could leave this list empty (I think).
#
# Here is an example with multiple locations:
#INCLIST=(  "/home/*/Documents" \
#           "/home/*/Projects" \
#           "/home/*/logs" \
#           "/home/www/mysql-backups" \
#        )
#
# Simpler example with one location:
INCLIST=( "/home/foobar_user_name/Documents/Prose/" ) 

# EXCLUDE LIST OF DIRECTORIES
# Even though I am being specific about what I want to include,
# there is still a lot of stuff I don't need.
EXCLIST=(   "/home/*/Trash" \
            "/home/*/Projects/Completed" \
            "/**.DS_Store" "/**Icon?" "/**.AppleDouble" \
        )

# STATIC BACKUP OPTIONS
# Here you can define the static backup options that you want to run with
# duplicity.  I use both the `--full-if-older-than` option plus the
# `--s3-use-new-style` option (for European buckets).  Be sure to separate your
# options with appropriate spacing.
STATIC_OPTIONS="--full-if-older-than 14D --s3-use-new-style"

# FULL BACKUP & REMOVE OLDER THAN SETTINGS
# Because duplicity will continue to add to each backup as you go,
# it will eventually create a very large set of files.  Also, incremental
# backups leave room for problems in the chain, so doing a "full"
# backup every so often isn't not a bad idea.
#
# You can either remove older than a specific time period:
#CLEAN_UP_TYPE="remove-older-than"
#CLEAN_UP_VARIABLE="31D"

# Or, If you would rather keep a certain (n) number of full backups (rather
# than removing the files based on their age), you can use what I use:
CLEAN_UP_TYPE="remove-all-but-n-full"
CLEAN_UP_VARIABLE="2"

# LOGFILE INFORMATION DIRECTORY
# Provide directory for logfile, ownership of logfile, and verbosity level.
# I run this script as root, but save the log files under my user name --
# just makes it easier for me to read them and delete them as needed.

LOGDIR="/home/foobar_user_name/logs/test2/"
LOG_FILE="duplicity-`date +%Y-%m-%d_%H-%M`.txt"
LOG_FILE_OWNER="foobar_user_name:foobar_user_name"
VERBOSITY="-v3"

# EMAIL ALERT (*thanks: rmarescu*)
# Provide an email address to receive the logfile by email. If no email
# address is provided, no alert will be sent.
# You can set a custom from email address and a custom subject (both optionally)
# If no value is provided for the subject, the following value will be
# used by default: "DT-S3 Alert ${LOG_FILE}"
# MTA used: mailx
#EMAIL="admin@example.com"
EMAIL_TO=
EMAIL_FROM=
EMAIL_SUBJECT=

# TROUBLESHOOTING: If you are having any problems running this script it is
# helpful to see the command output that is being generated to determine if the
# script is causing a problem or if it is an issue with duplicity (or your
# setup).  Simply  uncomment the ECHO line below and the commands will be
# printed to the logfile.  This way, you can see if the problem is with the
# script or with duplicity.
#ECHO=$(which echo)

##############################################################
# Script Happens Below This Line - Shouldn't Require Editing #
##############################################################
LOGFILE="${LOGDIR}${LOG_FILE}"
DUPLICITY="$(which duplicity)"
S3CMD="$(which s3cmd)"
MAIL="$(which mailx)"

if [ $ENCRYPTION = "yes" ]; then
  ENCRYPT="--encrypt-key=${GPG_KEY} --sign-key=${GPG_KEY}"
elif [ $ENCRYPTION = "no" ]; then
  ENCRYPT="--no-encryption"
fi

NO_S3CMD="WARNING: s3cmd is not installed, remote file \
size information unavailable."
NO_S3CMD_CFG="WARNING: s3cmd is not configured, run 's3cmd --configure' \
in order to retrieve remote file size information. Remote file \
size information unavailable."
README_TXT="In case you've long forgotten, this is a backup script that you used to backup some files (most likely remotely at Amazon S3).  In order to restore these files, you first need to import your GPG private key (if you haven't already).  The key is in this directory and the following command should do the trick:\n\ngpg --allow-secret-key-import --import s3-secret.key.txt\n\nAfter your key as been succesfully imported, you should be able to restore your files.\n\nGood luck!"
CONFIG_VAR_MSG="Oops!! ${0} was unable to run!\nWe are missing one or more important variables at the top of the script.\nCheck your configuration because it appears that something has not been set yet."

if [ ! -x "$DUPLICITY" ]; then
  echo "ERROR: duplicity not installed, that's gotta happen first!" >&2
  exit 1
elif  [ `echo ${DEST} | cut -c 1,2` = "s3" ]; then
  if [ ! -x "$S3CMD" ]; then
    echo $NO_S3CMD; S3CMD_AVAIL=false
  elif [ ! -f "${HOME}/.s3cfg" ]; then
    echo $NO_S3CMD_CFG; S3CMD_AVAIL=false
  else
    S3CMD_AVAIL=true
  fi
fi

if [ ! -d ${LOGDIR} ]; then
  echo "Attempting to create log directory ${LOGDIR} ..."
  if ! mkdir -p ${LOGDIR}; then
    echo "Log directory ${LOGDIR} could not be created by this user: ${USER}"
    echo "Aborting..."
    exit 1
  else
    echo "Directory ${LOGDIR} successfully created."
  fi
elif [ ! -w ${LOGDIR} ]; then
  echo "Log directory ${LOGDIR} is not writeable by this user: ${USER}"
  echo "Aborting..."
  exit 1
fi

get_source_file_size()
{
  echo "---------[ Source File Size Information ]---------" >> ${LOGFILE}

  for exclude in ${EXCLIST[@]}; do
    DUEXCLIST="${DUEXCLIST}${exclude}\n"
  done

  for include in ${INCLIST[@]}
    do
      echo -e $DUEXCLIST | \
      du -hs --exclude-from="-" ${include} | \
      awk '{ print $2"\t"$1 }' \
      >> ${LOGFILE}
  done
  echo >> ${LOGFILE}
}

get_remote_file_size()
{
  echo "------[ Destination File Size Information ]------" >> ${LOGFILE}
  if [ `echo ${DEST} | cut -c 1,2` = "fi" ]; then
    TMPDEST=`echo ${DEST} | cut -c 6-`
    SIZE=`du -hs ${TMPDEST} | awk '{print $1}'`
  elif [ `echo ${DEST} | cut -c 1,2` = "s3" ] &&  $S3CMD_AVAIL ; then
      TMPDEST=$(echo ${DEST} | cut -c 11-)
      SIZE=`s3cmd du -H s3://${TMPDEST} | awk '{print $1}'`
  else
      SIZE="s3cmd not installed."
  fi
  echo "Current Remote Backup File Size: ${SIZE}" >> ${LOGFILE}
  echo >> ${LOGFILE}
}

include_exclude()
{
  for include in ${INCLIST[@]}
    do
      TMP=" --include="$include
      INCLUDE=$INCLUDE$TMP
  done
  for exclude in ${EXCLIST[@]}
      do
      TMP=" --exclude "$exclude
      EXCLUDE=$EXCLUDE$TMP
    done
    EXCLUDEROOT="--exclude=**"
}

duplicity_cleanup()
{
  echo "-----------[ Duplicity Cleanup ]-----------" >> ${LOGFILE}
  ${ECHO} ${DUPLICITY} ${CLEAN_UP_TYPE} ${CLEAN_UP_VARIABLE} --force \
	    ${ENCRYPT} \
	    ${DEST} >> ${LOGFILE}
  echo >> ${LOGFILE}
}

duplicity_backup()
{
  ${ECHO} ${DUPLICITY} ${OPTION} ${VERBOSITY} ${STATIC_OPTIONS} \
  ${ENCRYPT} \
  ${EXCLUDE} \
  ${INCLUDE} \
  ${EXCLUDEROOT} \
  ${ROOT} ${DEST} \
  >> ${LOGFILE}
}

get_file_sizes()
{
  get_source_file_size
  get_remote_file_size

  sed -i '/-------------------------------------------------/d' ${LOGFILE}
  chown ${LOG_FILE_OWNER} ${LOGFILE}
}

backup_this_script()
{
  if [ `echo ${0} | cut -c 1` = "." ]; then
    SCRIPTFILE=$(echo ${0} | cut -c 2-)
    SCRIPTPATH=$(pwd)${SCRIPTFILE}
  else
    SCRIPTPATH=$(which ${0})
  fi
  TMPDIR=dt-s3-backup-`date +%Y-%m-%d`
  TMPFILENAME=${TMPDIR}.tar.gpg
  README=${TMPDIR}/README

  echo "You are backing up: "
  echo "      1. ${SCRIPTPATH}"
  echo "      2. GPG Secret Key: ${GPG_KEY}"
  echo "Backup will be saved to: `pwd`/${TMPFILENAME}"
  echo
  echo ">> Are you sure you want to do that ('yes' to continue)?"
  read ANSWER
  if [ "$ANSWER" != "yes" ]; then
    echo "You said << ${ANSWER} >> so I am exiting now."
    exit 1
  fi

  mkdir -p ${TMPDIR}
  cp $SCRIPTPATH ${TMPDIR}/
  gpg -a --export-secret-keys ${GPG_KEY} > ${TMPDIR}/s3-secret.key.txt
  echo -e ${README_TXT} > ${README}
  echo "Encrypting tarball, choose a password you'll remember..."
  tar c ${TMPDIR} | gpg -aco ${TMPFILENAME}
  rm -Rf ${TMPDIR}
  echo -e "\nIMPORTANT!!"
  echo ">> To restore these files, run the following (remember your password):"
  echo "gpg -d ${TMPFILENAME} | tar x"
  echo -e "\nYou may want to write the above down and save it with the file."
}

check_variables ()
{
  if [[ ${ROOT} = "" || ${DEST} = "" || ${INCLIST} = "" || \
        ${AWS_ACCESS_KEY_ID} = "foobar_aws_key_id" || \
        ${AWS_SECRET_ACCESS_KEY} = "foobar_aws_access_key" || \
        ${GPG_KEY} = "foobar_gpg_key" || \
        ${PASSPHRASE} = "foobar_gpg_passphrase" ]]; then
    echo -e ${CONFIG_VAR_MSG}
    echo -e ${CONFIG_VAR_MSG}"\n--------    END    --------" >> ${LOGFILE}
    exit 1
  fi
}

echo -e "--------    START DT-S3-BACKUP SCRIPT    --------\n" >> ${LOGFILE}

if [ "$1" = "--backup-script" ]; then
  backup_this_script
  exit
elif [ "$1" = "--full" ]; then
  check_variables
  OPTION="full"
  include_exclude
  duplicity_backup
  duplicity_cleanup
  get_file_sizes

elif [ "$1" = "--verify" ]; then
  check_variables
  OLDROOT=${ROOT}
  ROOT=${DEST}
  DEST=${OLDROOT}
  OPTION="verify"

  echo -e "-------[ Verifying Source & Destination ]-------\n" >> ${LOGFILE}
  include_exclude
  duplicity_backup

  OLDROOT=${ROOT}
  ROOT=${DEST}
  DEST=${OLDROOT}

  get_file_sizes

  echo -e "Verify complete.  Check the log file for results:\n>> ${LOGFILE}"

elif [ "$1" = "--restore" ]; then
  check_variables
  ROOT=$DEST
  OPTION="restore"

  if [[ ! "$2" ]]; then
    echo "Please provide a destination path (eg, /home/user/dir):"
    read -e NEWDESTINATION
    DEST=$NEWDESTINATION
		echo ">> You will restore from ${ROOT} to ${DEST}"
		echo "Are you sure you want to do that ('yes' to continue)?"
		read ANSWER
		if [[ "$ANSWER" != "yes" ]]; then
			echo "You said << ${ANSWER} >> so I am exiting now."
			echo -e "User aborted restore process ...\n" >> ${LOGFILE}
			exit 1
		fi
  else
    DEST=$2
  fi

  echo "Attempting to restore now ..."
  duplicity_backup

elif [ "$1" = "--restore-file" ]; then
  check_variables
  ROOT=$DEST
  INCLUDE=
  EXCLUDE=
  EXLUDEROOT=
  OPTION=

  if [[ ! "$2" ]]; then
    echo "Which file do you want to restore (eg, mail/letter.txt):"
    read -e FILE_TO_RESTORE
    FILE_TO_RESTORE=$FILE_TO_RESTORE
    echo
  else
    FILE_TO_RESTORE=$2
  fi

  if [[ "$3" ]]; then
		DEST=$3
	else
    DEST=$(basename $FILE_TO_RESTORE)
	fi

  echo -e "YOU ARE ABOUT TO..."
  echo -e ">> RESTORE: $FILE_TO_RESTORE"
  echo -e ">> TO: ${DEST}"
  echo -e "\nAre you sure you want to do that ('yes' to continue)?"
  read ANSWER
  if [ "$ANSWER" != "yes" ]; then
    echo "You said << ${ANSWER} >> so I am exiting now."
    echo -e "--------    END    --------\n" >> ${LOGFILE}
    exit 1
  fi

  echo "Restoring now ..."
  #use INCLUDE variable without create another one
  INCLUDE="--file-to-restore ${FILE_TO_RESTORE}"
  duplicity_backup

elif [ "$1" = "--list-current-files" ]; then
  check_variables
  OPTION="list-current-files"
  ${DUPLICITY} ${OPTION} ${VERBOSITY} ${STATIC_OPTIONS} \
  $ENCRYPT \
  ${DEST}
	echo -e "--------    END    --------\n" >> ${LOGFILE}

elif [ "$1" = "--collection-status" ]; then
  check_variables
  OPTION="collection-status"
  ${DUPLICITY} ${OPTION} ${VERBOSITY} ${STATIC_OPTIONS} \
  $ENCRYPT \
  ${DEST}
	echo -e "--------    END    --------\n" >> ${LOGFILE}

elif [ "$1" = "--backup" ]; then
  check_variables
  include_exclude
  duplicity_backup
  duplicity_cleanup
  get_file_sizes

else
  echo -e "[Only show `basename $0` usage options]\n" >> ${LOGFILE}
  echo "  USAGE:
    `basename $0` [options]

  Options:
    --backup: runs an incremental backup
    --full: forces a full backup

    --verify: verifies the backup
    --restore [path]: restores the entire backup
    --restore-file [file] [destination/filename]: restore a specific file
    --list-current-files: lists the files currently backed up in the archive
    --collection-status: show all the backup sets in the archive

    --backup-script: automatically backup the script and secret key to the current working directory

  CURRENT SCRIPT VARIABLES:
  ========================
    DEST (backup destination) = ${DEST}
    INCLIST (directories included) = ${INCLIST[@]:0}
    EXCLIST (directories excluded) = ${EXCLIST[@]:0}
    ROOT (root directory of backup) = ${ROOT}
  "
fi

echo -e "--------    END DT-S3-BACKUP SCRIPT    --------\n" >> ${LOGFILE}

if [ $EMAIL_TO ]; then
	if [ ! -x "$MAIL" ]; then
		echo -e "Email coulnd't be sent. mailx not available." >> ${LOGFILE}
	else
		EMAIL_FROM=${EMAIL_FROM:+"-r ${EMAIL_FROM}"}
		EMAIL_SUBJECT=${EMAIL_SUBJECT:="DT-S3 Alert ${LOG_FILE}"}
		${MAIL} -s """${EMAIL_SUBJECT}""" $EMAIL_FROM ${EMAIL_TO} < ${LOGFILE}
		echo -e "Email alert sent to ${EMAIL_TO} using ${MAIL}" >> ${LOGFILE}
	fi
fi

if [ ${ECHO} ]; then
  echo "TEST RUN ONLY: Check the logfile for command output."
fi

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset PASSPHRASE

# vim: set tabstop=2 shiftwidth=2 sts=2 autoindent smartindent:
