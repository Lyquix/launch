# Launch
Automated launch script - move Development environment to Production with ease

This script pushes an entire development environment to production

It works for LAMP sites that use the `/srv/www/` directory for the root of VirtualHosts

The script will information about the production and development environments

 * Get the names of the root directories (excluding `/srv/www` an assuming they use the `public_html` folder)
 * Get the domain names
 * Get the database credentials
 
And executes as follows:

 * Copies the development environment files into a temporary location under the production directory
 * Copies htaccess, wp-config and deploy-config from the production environment to the temporary directory
 * Backs up the production database
 * Exports the development database
 * Imports the development database into the production environment
 * Performs search-replace on the production database to update the site domain name
 * Swaps the production root directory with the temporary directory
 
Once completed it provides an option to rollback all the changes.

It also provides an option to clean up the backups and exports created in the process.
