# Launch

Automated launch script - move files and database from a source environment to a target environment (in the same server) with ease

With this script you can:

 * Push a site from development to staging, or from staging to production
 * Sync down from production to staging or from staging to development

It works for LAMP sites that use the `/srv/www/` directory for the root of VirtualHosts

The script will prompt for information about the source and target environments:

 * Get the names of the root directories (excluding `/srv/www` an assuming they use the `public_html` folder)
 * Get the domain names
 * Get the database credentials
 
And executes as follows:

 * Copies the source environment files into a temporary location under the target directory
 * Prompts the user to preserve the htaccess, wp-config and deploy-config file from the target environment to the temporary directory
 * Backs up the target database
 * Exports the source database
 * Imports the source database into the target environment
 * Updates the siteurl and home options in WordPress on the target database to update the domain name (you still need to run search-replace on the rest of the database)
 * Swaps the target root directory with the temporary directory
 
Once completed it provides an option to rollback all the changes.

It also provides an option to clean up the backups and exports created in the process.
