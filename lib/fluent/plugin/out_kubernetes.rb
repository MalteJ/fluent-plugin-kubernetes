#
# Fluentd Kubernetes Output Plugin - Enrich Fluentd events with Kubernetes
# metadata
#
# Copyright 2015 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class Fluent::KubernetesOutput < Fluent::Output
  Fluent::Plugin.register_output('kubernetes', self)

  config_param :tag, :string
  config_param :kubernetes_pod_regex, :string, default: '^[^_]+_([^\.]+)\.[^_]+_([^\.]+)\.([^\.]+)'

  def initialize
    super
  end

  def configure(conf)
    super

    require 'docker'
    require 'json'
  end

  def emit(tag, es, chain)
    es.each do |time,record|
      record = enrich_record(record)
      Fluent::Engine.emit(@tag,
                          time,
                          record)
    end

    chain.next
  end

  private
  
  def enrich_record(record)
    record = enrich_container_data(record)
    record = merge_json_log(record)
    record
  end

  def enrich_container_data(record)
    container_name = record["container_name"]
    container_name = container_name[1..-1] if container_name[0] == '/'
    regex = Regexp.new(@kubernetes_pod_regex)
    match = container_name.match(regex)
    if match
      pod_container_name, pod_name, pod_namespace =
        match.captures
      record["namespace"] = pod_namespace
      record["pod"] = pod_name
      record["pod_container"] = pod_container_name
    end
    record
  end

  def merge_json_log(record)
    if record.has_key?('log')
      log = record['log'].strip
      if log[0].eql?('{') && log[-1].eql?('}')
        begin
          parsed_log = JSON.parse(log)
          record['parsed_log'] = parsed_log
        rescue JSON::ParserError
        end
      end
    end
    record
  end

end
