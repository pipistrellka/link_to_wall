#!/usr/bin/env rake
require 'rake/testtask'
require 'rdoc/task'

desc 'Default: run unit tests.'
task :default => :link_to_wall

desc 'Test the test plugin.'
Rake::TestTask.new(:link_to_wall) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the link_to_wall plugin.'
RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'LinkToWall'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
