require 'rake'
# require 'rake/testtask'
# require 'rdoc/task'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the yattr_encrypted gem.'
task :test do
  if ENV['TEST']
    system "ruby #{ENV['TEST']}"
  else
    system "ruby test/*_test.rb"
  end
end
# Rake::TestTask.new(:test) do |t|
#   t.libs << 'lib'
#   # t.pattern = 'test/**/*_test.rb'
#   t.pattern = ENV['TEST'] ? ENV['TEST'] : 'test/**/*_test.rb'
#   t.verbose = true
# end

desc 'Build Gem'
task 'gem' do
  system 'gem build yattr_encrypted.gemspec'
end

desc 'Generate documentation for the yattr_encrypted gem.'
task 'rdoc' do
  system 'rdoc README.rdoc lib/'
end
# RDoc::Task.new do |rdoc|
#     rdoc.rdoc_dir = 'rdoc'
#     rdoc.title    = 'yattr_encrypted'
#     rdoc.options << '--line-numbers' << '--inline-source'
#     rdoc.rdoc_files.include('README*')
#     rdoc.rdoc_files.include('lib/**/*.rb')
# end
