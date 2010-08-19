# vim: syntax=Ruby

# require 'hoe'
# require 'active_record'
# require 'lib/model_cacher'
# load 'init.rb'
# require 'lib/cached_model'
# 
# Hoe.new 'cached_model', CachedModel::VERSION do |p|
#   p.summary = 'An ActiveRecord abstract model that caches records in memcached'
#   p.description = 'CachedModel caches simple (by id) finds in memcached reducing the amount of work the database needs to perform for simple queries.'
#   p.author = ['Eric Hodel', 'Robert Cottrell']
#   p.email = 'eric@robotcoop.com'
#   p.rubyforge_name = 'seattlerb'
# 
#   p.changes = File.read('History.txt').scan(/\A(=.*?)^=/m).first.first
# 
#   p.extra_deps << ['memcache-client', '>= 1.1.0']
#   p.extra_deps << ['activerecord', '>= 1.14.4']
#   p.extra_deps << ['ZenTest', '>= 3.4.1']
# end

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')

require 'model_cacher'
ActiveRecord::Base.class_eval { extend ModelCacher }
require 'cached_model'

desc 'Default: run unit tests.'
task :default => [:test]

desc 'Test the paperclip plugin under all supported Rails versions.'
task :all do |t|
  exec('rake RAILS_VERSION=2.3')
end

desc 'Test the paperclip plugin.'
Rake::TestTask.new(:test) do |t|
#   t.libs << 'lib' << 'profile'
  t.pattern = 'test/**/*_test.rb'
  t.libs << 'lib'
#   t.test_files = FileList( 'test/**/*_test.rb')
  t.verbose = true
end
