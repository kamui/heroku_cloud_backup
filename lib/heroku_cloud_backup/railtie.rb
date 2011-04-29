require 'heroku_cloud_backup'

module HerokuCloudBackup
  if defined? Rails::Railtie
    require 'rails'
    class Railtie < Rails::Railtie
      rake_tasks do
        require "heroku_cloud_backup/tasks"
      end
    end
  end
end