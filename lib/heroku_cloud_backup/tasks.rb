# encoding: utf-8

require 'heroku_cloud_backup'

namespace :heroku do
  desc "Transfer PostgreSQL database backups from Heroku to S3"
  task cloud_backup: :environment do
    HerokuCloudBackup.execute
  end
end
