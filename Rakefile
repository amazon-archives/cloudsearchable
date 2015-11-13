require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

# make spec test the default task
task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb', "README", "LICENSE"]   # optional
  t.options = ['-m', 'markdown'] # optional
end
