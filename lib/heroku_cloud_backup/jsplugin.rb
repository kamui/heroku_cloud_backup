module HerokuCloudBackup
  class JSPlugin
    class << self
      def spawn(topic, command, args)
        cmd = command ? "#{topic}:#{command}" : topic
        system self.bin, cmd, *args
      end

      private

      def bin
        File.join(app_dir, 'cli', 'bin', windows? ? 'heroku.exe' : 'heroku')
      end

      def app_dir
        localappdata = HerokuCloudBackup::Env['LOCALAPPDATA']
        xdg_data_home =
          HerokuCloudBackup::Env['XDG_DATA_HOME'] ||
            File.join(HerokuCloudBackup::Auth.home_directory, '.local', 'share')
        if windows? && localappdata
          File.join(localappdata, 'heroku')
        else
          File.join(xdg_data_home, 'heroku')
        end
      end

      def windows?
        HerokuCloudBackup::Auth.running_on_windows?
      end
    end
  end
end
