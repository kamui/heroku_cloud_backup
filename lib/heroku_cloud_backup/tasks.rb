require 'heroku_cloud_backup'

namespace :heroku do
  desc "Transfer PostgreSQL database backups from Heroku to the cloud"
  task :cloud_backup => :environment do
    HerokuCloudBackup.execute
  end
end