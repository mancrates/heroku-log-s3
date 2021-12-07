require 'fileutils'

workers Integer(ENV["WEB_CONCURRENCY"] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 4)
threads threads_count, threads_count

rackup      DefaultRackup
bind        "unix:///tmp/nginx.socket"
environment ENV['RACK_ENV'] || 'development'

preload_app!

on_worker_fork do
  FileUtils.touch('/tmp/app-initialized')
end
