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

# Get the domains
while true; do
	read -p "Please enter the production domain (e.g. www.example.com): " domain
	case $domain in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Please enter the development domain (e.g. dev.example.com): " devdomain
	case $devdomain in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done

printf $DIVIDER

# Get the directories
while true; do
	read -p "Please enter the production directory (e.g. example.com): " directory
	case $directory in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Please enter the development directory (e.g. dev.example.com): " devdirectory
	case $devdirectory in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done

printf $DIVIDER

# Get the database credentials
while true; do
	read -p "Production database name: " dbname
	case $dbname in
		"" ) printf "Database name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Production database user: " dbuser
	case $dbuser in
		"" ) printf "User name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -sp "Production database password: " dbpass
	case $dbpass in
		"" ) printf "\nPassword may not be left blank\n";;
		* ) break;;
	esac
done

printf $DIVIDER

while true; do
	printf "\n"
	read -p "Development database name: " devdbname
	case $devdbname in
		"" ) printf "Database name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Development database user: " devdbuser
	case $devdbuser in
		"" ) printf "User name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -sp "Development database password: " devdbpass
	case $devdbpass in
		"" ) printf "\nPassword may not be left blank\n";;
		* ) break;;
	esac
done

printf $DIVIDER

# Copy the development files into a temporary folder
printf "\nCopying development files into a temporary folder under production directory...\n"
cp -r /srv/www/$devdirectory/public_html /srv/www/$directory/public_html.tmp

printf $DIVIDER

# Copy htaccess wp-config.php and deploy-config.php
printf "Copying htaccess wp-config and deploy-config to temporary directory...\n"
cp -f /srv/www/$directory/public_html/.htaccess /srv/www/$directory/public_html.tmp
cp -f /srv/www/$directory/public_html/deploy-config.php /srv/www/$directory/public_html.tmp
cp -f /srv/www/$directory/public_html/wp-config.php /srv/www/$directory/public_html.tmp

# Delete VERSION file
printf "Delete the VERSION file from the temporary directory...\n"
rm /srv/www/$directory/public_html.tmp/VERSION

printf $DIVIDER

# Backup production database pre-launch
printf "Backing up the pre-launch production database...\n"
mysqldump -u $dbuser -p$dbpass $dbname > /srv/www/$directory/$dbname-backup-prelaunch-$TS.sql

# Export the development database
printf "Exporting the development database...\n"
mysqldump -u $devdbuser -p$devdbpass $devdbname > /srv/www/$devdirectory/$devdbname-launch-$TS.sql

# Import the development database into production
printf "Importing the development database...\n"
mysql -u $dbuser -p$dbpass $dbname < /srv/www/$devdirectory/$devdbname-launch-$TS.sql

printf $DIVIDER

# Download Search-Replace-DB and update domains
printf "Downloading Search-Replace-DB...\n"
wget -q -O srdb.zip https://github.com/interconnectit/Search-Replace-DB/archive/refs/heads/master.zip
printf "Extracting Search-Replace-DB...\n"
unzip -q srdb.zip
mv Search-Replace-DB-* srdb
printf "Search-Replace the development domain to the production domain...\n"
php srdb/srdb.cli.php -h localhost -n $dbname -u $dbuser -p $dbpass -s $devdomain -r $domain
rm -r srdb*

printf $DIVIDER

# Backup production database post-launch
printf "Backing up the post-launch production database...\n"
mysqldump -u $dbuser -p$dbpass $dbname > /srv/www/$directory/$dbname-backup-postlaunch-$TS.sql

# Swap file directories
printf "Swapping file directories...\n"
mv /srv/www/$directory/public_html /srv/www/$directory/public_html.bak
mv /srv/www/$directory/public_html.tmp /srv/www/$directory/public_html

printf $DIVIDER

# Prompt to rollback
printf "Launch is complete, please check everything is working as expected!\n"
while true; do
	read -p "Rollback? [Y/N] " rollback
	case $rollback in
		[Yy]* )
			printf "Rolling back...\n"

			# Swap file directories
			printf "Swapping file directories...\n"
			mv /srv/www/$directory/public_html /srv/www/$directory/public_html.tmp
			mv /srv/www/$directory/public_html.bak /srv/www/$directory/public_html

			# Import the development database into production
			printf "Import the production database backup...\n"
			mysql -u $dbuser -p$dbpass $dbname < /srv/www/$directory/$dbname-backup-prelaunch-$TS.sql

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
printf "  /srv/www/$directory/public_html.bak\n"
printf "  /srv/www/$directory/$dbname-backup-prelaunch-$TS.sql\n"
printf "  /srv/www/$directory/$dbname-backup-postlaunch-$TS.sql\n"
printf "  /srv/www/$devdirectory/$devdbname-launch-$TS.sql\n\n"
while true; do
	read -p "Delete backups? [Y/N] " cleanup
	case $cleanup in
		[Yy]* )
			printf "Deleting backups...\n"

			rm -r /srv/www/$directory/public_html.bak
			rm /srv/www/$directory/$dbname-backup-prelaunch-$TS.sql
			rm /srv/www/$directory/$dbname-backup-postlaunch-$TS.sql
			rm /srv/www/$devdirectory/$devdbname-launch-$TS.sql

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
