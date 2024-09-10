# inspec-reporter-honeycomb

## install

You can install using cinc-auditor or inspec with:

`inspec plugin install inspec-reporter-honeycomb`

or

`cinc-auditor plugin install inspec-reporter-honeycomb`


## [OpenTelemetry Ruby SDK required](https://docs.honeycomb.io/send-data/ruby/opentelemetry-sdk/)

You can install using chef workstation or local ruby with:

`chef gem install opentelemetry-sdk opentelemetry-otlp opentelemetry-exporter-otlp google-protobuf opentelemetry-instrumentation-all`
Note: you may have to add the above binary location into your path, 
eg, export PATH=/home/vagrant/.chef/gem/ruby/3.1.0/bin:$PATH

or 

`gem install opentelemetry-sdk opentelemetry-otlp opentelemetry-exporter-otlp google-protobuf opentelemetry-instrumentation-all`


## Required environment variables

You must set three environment variables:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io" # US instance
# export OTEL_EXPORTER_OTLP_ENDPOINT="https://api.eu1.honeycomb.io" # EU instance
export OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=<your API key>" # ingest key
export OTEL_SERVICE_NAME="<dataset name>" # will be created on first run
```
Note, you can put the above into a honeycomb_env.sh file and then use 
`source honeycomb_env.sh` to enable those environment vars. 

## Run with the new reporter

```bash
inspec exec <PROFILE_NAME> --reporter honeycomb
```
additional switches for debug --log-level debug --log-location honeycomb_logs

or add an additonal reporter(ie x2 reporters, honeycomb and json)

--reporter honeycomb json:/dev/stdout > outfile.json

Please ensure you replace the api key and dataset name in the URL.

Without these you'll receive a cryptic error about `bad argument (expected URI object or URI string)`
