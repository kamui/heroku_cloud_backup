module HerokuCloudBackup
  class Env
    def self.[](key)
      val = ENV[key]
      if (
        val &&
          HerokuCloudBackup::Auth.running_on_windows? &&
          val.encoding == Encoding::ASCII_8BIT
      )
        val = val.dup.force_encoding('utf-8')
      end
      val
    end
  end
end
