#!/bin/bash

DIVIDER="\n***************************************\n\n"

# Get the username of the current user
CURRUSER=$(whoami)

# Check if the current user is www-data
if [ "$CURRUSER" != "www-data" ]; then
   printf "This script must be run as www-data!\n"
   exit 1
fi

# Timestamp
TS=$(date +"%Y%m%d%H%M%S")

# Get script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"
cd /srv/www

# Get the source domain and directory
while true; do
	read -p "Please enter the source domain (e.g. dev.example.com): " SOURCE_DOMAIN
	case $SOURCE_DOMAIN in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Please enter the source directory (e.g. dev.example.com): " SOURCE_DIR
	case $SOURCE_DIR in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Source database name: " SOURCE_DBNAME
	case $SOURCE_DBNAME in
		"" ) printf "Database name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Source database user: " SOURCE_DBUSER
	case $SOURCE_DBUSER in
		"" ) printf "User name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -sp "Source database password: " SOURCE_DBPASS
	case $SOURCE_DBPASS in
		"" ) printf "\nPassword may not be left blank\n";;
		* ) break;;
	esac
done

printf $DIVIDER

# Get the target domain and directory
while true; do
	read -p "Please enter the target domain (e.g. www.example.com): " TARGET_DOMAIN
	case $TARGET_DOMAIN in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Please enter the target directory (e.g. example.com): " TARGET_DIR
	case $TARGET_DIR in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Target database name: " TARGET_DBNAME
	case $TARGET_DBNAME in
		"" ) printf "Database name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Target database user: " TARGET_DBUSER
	case $TARGET_DBUSER in
		"" ) printf "User name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -sp "Target database password: " TARGET_DBPASS
	case $TARGET_DBPASS in
		"" ) printf "\nPassword may not be left blank\n";;
		* ) break;;
	esac
done

printf $DIVIDER

# Copy the source files into a temporary folder
printf "\nCopying source files into a temporary folder under target directory...\n"
if [ -d "/srv/www/$TARGET_DIR/public_html.tmp" ]; then
    rm -rf /srv/www/$TARGET_DIR/public_html.tmp
fi
cp -r /srv/www/$SOURCE_DIR/public_html /srv/www/$TARGET_DIR/public_html.tmp

printf $DIVIDER

# Prompt to continue
while true; do
	read -p "Preserve wp-config, deploy-config, and htaccess in the target directory [Y/N]? " PRESERVE_FILES
	case $PRESERVE_FILES in
	[Yy]*) 
		# Copy htaccess wp-config.php and deploy-config.php
		printf "Copying htaccess wp-config and deploy-config to temporary directory...\n"
		cp -f /srv/www/$TARGET_DIR/public_html/.htaccess /srv/www/$TARGET_DIR/public_html.tmp
		cp -f /srv/www/$TARGET_DIR/public_html/deploy-config.php /srv/www/$TARGET_DIR/public_html.tmp
		cp -f /srv/www/$TARGET_DIR/public_html/wp-config.php /srv/www/$TARGET_DIR/public_html.tmp
		break ;;
	[Nn]*) break ;;
	*) echo "Please answer Y or N" ;;
	esac
done

# Delete VERSION file
printf "Delete the VERSION file from the temporary directory...\n"
rm /srv/www/$TARGET_DIR/public_html.tmp/VERSION

printf $DIVIDER

# Backup target database pre-launch
printf "Backing up the pre-launch target database...\n"
mysqldump -u $TARGET_DBUSER -p$TARGET_DBPASS $TARGET_DBNAME > /srv/www/$TARGET_DIR/$TARGET_DBNAME-backup-prelaunch-$TS.sql

# Export the source database
printf "Exporting the source database...\n"
mysqldump -u $SOURCE_DBUSER -p$SOURCE_DBPASS $SOURCE_DBNAME > /srv/www/$SOURCE_DIR/$SOURCE_DBNAME-launch-$TS.sql

# Import the source database into target
printf "Importing the source database...\n"
mysql -u $TARGET_DBUSER -p$TARGET_DBPASS $TARGET_DBNAME < /srv/www/$SOURCE_DIR/$SOURCE_DBNAME-launch-$TS.sql

printf $DIVIDER

# Update WordPress site URL in the database
printf "Updating the site URL in the WordPress database...\n"
WP_PREFIX=$(mysql -u $TARGET_DBUSER -p$TARGET_DBPASS $TARGET_DBNAME -se "SELECT table_name FROM information_schema.tables WHERE table_name LIKE '%options' LIMIT 1;" | sed 's/options//')
mysql -u $TARGET_DBUSER -p$TARGET_DBPASS $TARGET_DBNAME <<EOF
UPDATE ${WP_PREFIX}options
SET option_value = REPLACE(option_value, '$SOURCE_DOMAIN', '$TARGET_DOMAIN')
WHERE option_name IN ('siteurl', 'home');
EOF

printf $DIVIDER

# Backup target database post-launch
printf "Backing up the post-launch target database...\n"
mysqldump -u $TARGET_DBUSER -p$TARGET_DBPASS $TARGET_DBNAME > /srv/www/$TARGET_DIR/$TARGET_DBNAME-backup-postlaunch-$TS.sql

# Swap file directories
printf "Swapping file directories...\n"
mv /srv/www/$TARGET_DIR/public_html /srv/www/$TARGET_DIR/public_html.bak
mv /srv/www/$TARGET_DIR/public_html.tmp /srv/www/$TARGET_DIR/public_html

printf $DIVIDER

# Prompt to rollback
printf "Launch is complete, please check everything is working as expected!\n"
while true; do
	read -p "Rollback? [Y/N] " ROLLBACK
	case $ROLLBACK in
		[Yy]* )
			printf "Rolling back...\n"

			# Swap file directories
			printf "Swapping file directories...\n"
			mv /srv/www/$TARGET_DIR/public_html /srv/www/$TARGET_DIR/public_html.tmp
			mv /srv/www/$TARGET_DIR/public_html.bak /srv/www/$TARGET_DIR/public_html

			# Import the source database into target
			printf "Import the target database backup...\n"
			mysql -u $TARGET_DBUSER -p$TARGET_DBPASS $TARGET_DBNAME < /srv/www/$TARGET_DIR/$TARGET_DBNAME-backup-prelaunch-$TS.sql

			break
			;;
		[Nn]* )
			break
			;;
		* )
			# Code to be executed if the answer is not y or n
			echo "Please enter Y or N"
			;;
	esac
done

printf $DIVIDER

# Prompt to clean up
printf "Do you want to automatically delete these backups?\n"
printf "  /srv/www/$TARGET_DIR/public_html.bak\n"
printf "  /srv/www/$TARGET_DIR/$TARGET_DBNAME-backup-prelaunch-$TS.sql\n"
printf "  /srv/www/$TARGET_DIR/$TARGET_DBNAME-backup-postlaunch-$TS.sql\n"
printf "  /srv/www/$SOURCE_DIR/$SOURCE_DBNAME-launch-$TS.sql\n\n"
while true; do
	read -p "Delete backups? [Y/N] " cleanup
	case $cleanup in
		[Yy]* )
			printf "Deleting backups...\n"

			rm -r /srv/www/$TARGET_DIR/public_html.bak
			rm /srv/www/$TARGET_DIR/$TARGET_DBNAME-backup-prelaunch-$TS.sql
			rm /srv/www/$TARGET_DIR/$TARGET_DBNAME-backup-postlaunch-$TS.sql
			rm /srv/www/$SOURCE_DIR/$SOURCE_DBNAME-launch-$TS.sql

			break
			;;
		[Nn]* )
			printf "Remember to clean up the files and directories listed above!\n"

			break
			;;
		* )
			# Code to be executed if the answer is not y or n
			echo "Please enter Y or N"
			;;
	esac
done

cd $DIR
exit
