require 'logger'
require 'heroku-log-parser'
require_relative './queue_io.rb'
require_relative ENV.fetch("WRITER_LIB", "./writer/s3.rb") # provider of `Writer < WriterBase` singleton

class App

  PREFIX = ENV.fetch("FILTER_PREFIX", "")
  PREFIX_LENGTH = PREFIX.length
  LOG_REQUEST_URI = ENV['LOG_REQUEST_URI']

  def initialize
    @logger = Logger.new(STDOUT)
    @logger.formatter = proc do |severity, datetime, progname, msg|
       "[app #{$$} #{Thread.current.object_id}] #{msg}\n"
    end
    @logger.info "initialized"
  end

  def call(env)
    lines = if LOG_REQUEST_URI
      [{ msg: env['REQUEST_URI'], ts: '' }]
    else
      HerokuLogParser.parse(env['rack.input'].read).collect { |m| { msg: m[:message], ts: m[:emitted_at].strftime('%Y-%m-%dT%H:%M:%S.%L%z') } }
    end

    lines.each do |line|
			puts '_________BEGIN_______________'
			pp line
			puts '_________END_______________'
      msg = line[:msg]
      next unless msg.start_with?(PREFIX)
			write_canonical(line)
    end

  rescue Exception
    @logger.error $!
    @logger.error $@

  ensure
    return [200, { 'Content-Length' => '0' }, []]
  end

	def write_canonical(line)
		begin
			msg = line[:msg]
			matched = msg.match(/^(?<request_id>\[.+\])\s+(?<everything_else>.+)$/)
			log_line = JSON.load(matched[:everything_else])
			if log_line.key?(:user_id) || log_line.key?('user_id')
			  Writer.instance.write(log_line.to_json.strip) # WRITER_LIB
			end
		rescue => e
			@logger.error e
		end
	end
end
