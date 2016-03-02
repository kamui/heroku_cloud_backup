# Heroku Cloud Backup

## Installation

    require "heroku_cloud_backup"
    task :backup do
      HerokuCloudBackup.execute
    end

## Usage

The first thing you'll want to do is configure the addon.

HCB_PROVIDER (aws, rackspace, google) - Add which provider you're using. **Required**

    heroku config:add HCB_PROVIDER='aws' # or 'google' or 'rackspace'

HCB_BUCKET (alphanumberic characters, dashes, period, underscore are allowed, between 3 and 255 characters long) - Select a bucket name to upload to. This the bucket or root directory that your files will be stored in. If the bucket doesn't exist, it will be created. **Required**

    heroku config:add HCB_BUCKET='mywebsite'

HCB_PREFIX (Defaults to "db") - The direction prefix for where the backups are stored. This is so you can store your backups within a specific sub directory within the bucket. heroku_cloud_backup will also append the ENV var of the database to the path, so you can backup multiple databases, by their ENV names. **Optional**

    heroku config:add HCB_PREFIX='backups/pg'

HCB_MAX (Defaults to no limit) - The number of backups to store before the script will prune out older backups. A value of 10 will allow you to store 10 of the most recent backups. Newer backups will replace older ones. **Optional**

    heroku config:add HCB_MAX=10

HCB_REGION (AWS defaults 'us-east-1', Rackspace defaults to :dfw) - The region of the provider. **Optional**

    heroku config:add HCB_REGION=us-west-1

Depending on which provider you specify, you'll need to provide different login credentials.

For Amazon:

    heroku config:add HCB_KEY1="aws_access_key_id"
    heroku config:add HCB_KEY2="aws_secret_access_key"
    heroku config:add HCB_REGION="us-east-1"

For Rackspace:

    heroku config:add HCB_KEY1="rackspace_username"
    heroku config:add HCB_KEY2="rackspace_api_key"
    heroku config:add HCB_REGION="dfw"

For Google Storage:

    heroku config:add HCB_KEY1="google_storage_secret_access_key"
    heroku config:add HCB_KEY2="google_storage_access_key_id"

You can run this manually like this:

    heroku rake heroku_backup
    heroku rake heroku:cloud_backup

HCB_APP_NAME

  heroku config:add HCB_APP_NAME=<heroku_app_name>

HEROKU_API_KEY

  heroku config:add HEROKU_API_KEY=<heroku_api_key>
