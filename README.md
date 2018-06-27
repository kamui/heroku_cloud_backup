# Heroku Cloud Backup

Adapted from a more general cloud backup solution for Heroku app databases by
  Jack Chu, this fork is now specialized for exclusive use with AWS S3.

## Installation

  add

    gem 'heroku_cloud_backup',
      git: "https://github.com/pathwaysmedical/heroku_cloud_backup.git"

  to your Gemfile and run `bundle install`, or else install the gem directly.

## Configuration

Heroku Cloud Backup requires a few config vars, which should be set as ENV
  variables:

HCB_BUCKET (alphanumeric characters, dashes, period, underscore are allowed,
  between 3 and 255 characters long) - Select a bucket name to upload to. This
  the bucket or root directory that your files will be stored in. If the bucket
  doesn't exist, it will be created. **Required**

    heroku config:add HCB_BUCKET='mywebsite'

HCB_REGION (AWS defaults 'us-east-1') - The region of the provider. **Optional**

    heroku config:add HCB_REGION=us-west-1

Amazon Web Services keys: **Required**

    heroku config:add HCB_KEY1="access_key_id"
    heroku config:add HCB_KEY2="secret_access_key"

HCB_APP_NAME **Required**

    heroku config:add HCB_APP_NAME=<heroku_app_name>

HEROKU_API_KEY **Required**

    heroku config:add HEROKU_API_KEY=<heroku_api_key>

## Usage

    require "heroku_cloud_backup"

    task :backup do
      HerokuCloudBackup.execute
    end

You can run this manually like this:

    heroku rake heroku_backup
    heroku rake heroku:cloud_backup
