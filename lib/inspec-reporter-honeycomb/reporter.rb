
require 'inspec/plugin/v2'
require 'json'
require 'socket'
require 'securerandom' unless defined?(SecureRandom)
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

module InspecPlugins::HoneycombReporter
  class Reporter < Inspec.plugin(2, :reporter)
    def initialize(config)
      super(config)
      configure_opentelemetry
    end

    def render
      output(report.to_json, false)
    end

    def self.run_data_schema_constraints
      '~> 0.0' # Accept any non-breaking change
    end

    def report
      report = Inspec::Reporters::JsonAutomate.new(@config).report
      tracer = OpenTelemetry.tracer_provider.tracer('inspec')
      
      tracer.in_span('inspec-run') do |root_span|
        set_attributes(root_span, {
          'service.name' => ENV['OTEL_SERVICE_NAME'] || 'inspec-honeycomb-reporter',
          'platform.name' => report[:platform][:name],
          'platform.release' => report[:platform][:release],
          'version' => report[:version],
          'hostname' => Socket.gethostname,
          'arch' => ::RbConfig::CONFIG['arch'],
          'os' => ::RbConfig::CONFIG['host_os'],
          'ip_addresses' => get_ip_addresses.join(',')
        })

        report[:profiles].each do |profile|
          process_profile(profile, tracer)
        end

        set_attributes(root_span, {
          'duration' => (report[:statistics][:duration] * 1000).to_f
        })
      end

      OpenTelemetry.tracer_provider.force_flush

      Inspec::Log.debug "Successfully sent report"
      report
    end

    private

    def configure_opentelemetry
      OpenTelemetry::SDK.configure do |c|
        c.service_name = ENV['OTEL_SERVICE_NAME'] || 'inspec-honeycomb-reporter'
        c.use_all # To enable all auto-instrumentations

        # Use the OTLP exporter with the Honeycomb endpoint
        c.add_span_processor(
          OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
            OpenTelemetry::Exporter::OTLP::Exporter.new(
              # The endpoint and headers are set via env vars, so we don't need to specify them here
            )
          )
        )
      end
    end

    def process_profile(profile, tracer)
      tracer.in_span("profile: #{profile[:name]}") do |profile_span|
        set_attributes(profile_span, {
          'profile.name' => profile[:name],
          'profile.title' => profile[:title],
          'profile.version' => profile[:version],
          'profile.attributes' => profile[:attributes].to_json
        })

        profile[:controls].each do |control|
          process_control(control, tracer, profile)
        end
      end
    end

    def process_control(control, tracer, profile)
      tracer.in_span("control: #{control[:id]}") do |control_span|
        set_attributes(control_span, {
          'control.name' => control[:name],
          'control.id' => control[:id],
          'control.desc' => control[:desc],
          'control.impact' => control[:impact].to_f,
          'profile.name' => profile[:name],
          'profile.title' => profile[:title],
          'profile.version' => profile[:version]
        })

        # Insert a sleep for 5 seconds to simulate a delay
        sleep 5
        
        control[:results].each do |result|
          process_result(result, tracer, control, profile)
        end
      end
    end

    def process_result(result, tracer, control, profile)
      tracer.in_span("result: #{result[:code_desc]}") do |result_span|
        set_attributes(result_span, {
          'result.status' => result[:status],
          'result.code_desc' => result[:code_desc],
          'result.run_time' => result[:run_time].to_f,
          'control.name' => control[:name],
          'control.id' => control[:id],
          'profile.name' => profile[:name],
          'profile.title' => profile[:title],
          'profile.version' => profile[:version]
        })
      end
    end

    def get_ip_addresses
      Socket.ip_address_list.map(&:ip_address).reject { |ip| ip == '127.0.0.1' }
    end

    def set_attributes(span, attributes)
      attributes.each do |key, value|
        span.set_attribute(key, sanitize_attribute(value)) unless value.nil?
      end
    end

    def sanitize_attribute(value)
      case value
      when String
        value
      when Numeric
        value
      when TrueClass, FalseClass
        value
      else
        value.to_s
      end
    end
  end
end
