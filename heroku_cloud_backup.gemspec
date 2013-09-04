# encoding: utf-8

$:.push File.expand_path("../lib", __FILE__)
require "heroku_cloud_backup/version"

Gem::Specification.new do |s|
  s.name        = "heroku_cloud_backup"
  s.version     = HerokuCloudBackup::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jack Chu"]
  s.email       = ["jack@jackchu.com"]
  s.homepage    = "http://jackchu.com/blog/2011/06/10/automated-heroku-database-backups-to-amazon-s3/"
  s.summary     = %q{Backup pg dumps to the cloud}
  s.description = %q{PG backups into the cloud with fog}
  s.license       = "MIT"

  s.rubyforge_project = "heroku_cloud_backup"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'fog', '>= 1.6.0'
  s.add_runtime_dependency 'heroku', '>= 2.32.14'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
end
