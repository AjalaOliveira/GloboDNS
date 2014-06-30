# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class Bind9Controller < ApplicationController
    include GloboDns::Config

    respond_to :html, :json
    responders :flash

    before_filter :admin?,             :except => :schedule_export
    before_filter :admin_or_operator?, :only   => :schedule_export

    def index
        get_current_config
    end

    def configuration
        get_current_config
        respond_with(@current_config) do |format|
            format.html { render :text => @current_config if request.xhr? }
        end
    end

    def export
        if params['now'].try(:downcase) == 'true'
            @output, status = run_export
        elsif File.exists?(EXPORT_STAMP_FILE)
            last_update = [ Record.last_update, Domain.last_update, File.stat(EXPORT_STAMP_FILE).mtime ].max
            if Time.now > (last_update + EXPORT_DELAY)
                @output, status = run_export
            else
                @output = I18n.t('export_scheduled', :timestamp => export_timestamp(last_update + EXPORT_DELAY))
                status  = :ok
            end
        else
            @output = I18n.t('no_export_scheduled')
            status  = :ok
        end

        respond_to do |format|
            format.html { render :status => status, :layout => false } if request.xhr?
            format.json { render :status => status, :json   => { ((status == :ok) ? 'output' : 'error') => @output } }
        end
    end

    def schedule_export
        if not File.exists?(EXPORT_STAMP_FILE)
            FileUtils.touch(EXPORT_STAMP_FILE)
        end
        @output = I18n.t('export_scheduled', :timestamp => export_timestamp(File.stat(EXPORT_STAMP_FILE).mtime + EXPORT_DELAY).to_formatted_s(:short))
        respond_to do |format|
            format.html { render :status => status, :layout => false } if request.xhr?
            format.json { render :status => status, :json   => { 'output' => @output } }
        end
    end

    private

    def get_current_config
        @master_named_conf = GloboDns::Exporter.load_named_conf(EXPORT_MASTER_CHROOT_DIR, BIND_MASTER_NAMED_CONF_FILE)
        @slave_named_conf  = GloboDns::Exporter.load_named_conf(EXPORT_SLAVE_CHROOT_DIR,  BIND_SLAVE_NAMED_CONF_FILE)
    end

    def run_export
        exporter = GloboDns::Exporter.new
        exporter.export_all(params['master-named-conf'], params['slave-named-conf'], :all => params['all'] == 'true', :keep_tmp_dir => true) # :abort_on_rndc_failure => false,
        [ exporter.logger.string, :ok ]
    rescue Exception => e
        logger.error "[ERROR] export failed: #{e}\n#{exporter.logger.string}\nbacktrace:\n#{e.backtrace.join("\n")}"
        [ e.to_s, :unprocessable_entity ]
    ensure
        File.unlink(EXPORT_STAMP_FILE) rescue nil
    end

    # round up to the nearest round minute, as it's the smallest time grain
    # supported by cron jobs
    def export_timestamp(timestamp)
        Time.at((timestamp.to_i / 60 + 1) * 60)
    end
end
