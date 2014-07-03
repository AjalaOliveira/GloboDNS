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

# = Domain
#
# A #Domain is a unique domain name entry, and contains various #Record entries to
# represent its data.
#
# The domain is used for the following purposes:
# * It is the $ORIGIN off all its records
# * It specifies a default $TTL

class Domain < ActiveRecord::Base
    include SyslogHelper
    include BindTimeFormatHelper

    # define helper constants and methods to handle domain types
    AUTHORITY_TYPES  = define_enum(:authority_type,  [:MASTER, :SLAVE, :FORWARD, :STUB, :HINT], ['M', 'S', 'F', 'U', 'H'])
    ADDRESSING_TYPES = define_enum(:addressing_type, [:REVERSE, :NORMAL], ['R', 'N'])

    REVERSE_DOMAIN_SUFFIXES = ['.in-addr.arpa', '.ip6.arpa']

    # virtual attributes that ease new zone creation. If present, they'll be
    # used to create an SOA for the domain
    # SOA_FIELDS = [ :primary_ns, :contact, :refresh, :retry, :expire, :minimum, :ttl ]
    SOA::SOA_FIELDS.each do |field|
        delegate field.to_sym, (field.to_s + '=').to_sym, :to => :soa_record
    end

    attr_accessor :importing
    attr_accessible :user_id, :name, :master, :last_check, :notified_serial, :account, :ttl, :notes, :authority_type, :addressing_type, :view_id, \
    :primary_ns, :contact, :refresh, :retry, :expire, :minimum

    audited :protect => false
    has_associated_audits

    # associations
    belongs_to :view
    has_many   :records,            :dependent => :destroy,      :inverse_of => :domain
    has_one    :soa_record,         :class_name => 'SOA',        :inverse_of => :domain
    has_many   :aaaa_records,       :class_name => 'AAAA',       :inverse_of => :domain
    has_many   :a_records,          :class_name => 'A',          :inverse_of => :domain
    has_many   :cert_records,       :class_name => 'CERT',       :inverse_of => :domain
    has_many   :cname_records,      :class_name => 'CNAME',      :inverse_of => :domain
    has_many   :dlv_records,        :class_name => 'DLV',        :inverse_of => :domain
    has_many   :dnskey_records,     :class_name => 'DNSKEY',     :inverse_of => :domain
    has_many   :ds_records,         :class_name => 'DS',         :inverse_of => :domain
    has_many   :ipseckey_records,   :class_name => 'IPSECKEY',   :inverse_of => :domain
    has_many   :key_records,        :class_name => 'KEY',        :inverse_of => :domain
    has_many   :kx_records,         :class_name => 'KX',         :inverse_of => :domain
    has_many   :loc_records,        :class_name => 'LOC',        :inverse_of => :domain
    has_many   :mx_records,         :class_name => 'MX',         :inverse_of => :domain
    has_many   :nsec3param_records, :class_name => 'NSEC3PARAM', :inverse_of => :domain
    has_many   :nsec3_records,      :class_name => 'NSEC3',      :inverse_of => :domain
    has_many   :nsec_records,       :class_name => 'NSEC',       :inverse_of => :domain
    has_many   :ns_records,         :class_name => 'NS',         :inverse_of => :domain
    has_many   :ptr_records,        :class_name => 'PTR',        :inverse_of => :domain
    has_many   :rrsig_records,      :class_name => 'RRSIG',      :inverse_of => :domain
    has_many   :sig_records,        :class_name => 'SIG',        :inverse_of => :domain
    has_many   :spf_records,        :class_name => 'SPF',        :inverse_of => :domain
    has_many   :srv_records,        :class_name => 'SRV',        :inverse_of => :domain
    has_many   :ta_records,         :class_name => 'TA',         :inverse_of => :domain
    has_many   :tkey_records,       :class_name => 'TKEY',       :inverse_of => :domain
    has_many   :tsig_records,       :class_name => 'TSIG',       :inverse_of => :domain
    has_many   :txt_records,        :class_name => 'TXT',        :inverse_of => :domain

    # validations
    validates_presence_of      :name
    validates_uniqueness_of    :name, :scope => :view_id
    validates_inclusion_of     :authority_type,  :in => AUTHORITY_TYPES.keys,  :message => "must be one of #{AUTHORITY_TYPES.keys.join(', ')}"
    validates_inclusion_of     :addressing_type, :in => ADDRESSING_TYPES.keys, :message => "must be one of #{ADDRESSING_TYPES.keys.join(', ')}"
    validates_presence_of      :ttl,        :if => :master?
    validates_bind_time_format :ttl,        :if => :master?
    validates_associated       :soa_record, :if => :master?
    validates_presence_of      :master,     :if => :slave?
    validate                   :validate_recursive_subdomains, :unless => :importing?

    # validations that generate 'warnings' (i.e., doesn't prevent 'saving' the record)
    # validation_scope :warnings do |scope|
    # end

    # callbacks
    after_save :save_soa_record

    # scopes
    default_scope             order("#{self.table_name}.name")
    scope :master,            where("#{self.table_name}.authority_type   = ?", MASTER).where("#{self.table_name}.addressing_type = ?", NORMAL)
    scope :slave,             where("#{self.table_name}.authority_type   = ?", SLAVE)
    scope :forward,           where("#{self.table_name}.authority_type   = ?", FORWARD)
    scope :master_or_reverse, where("#{self.table_name}.authority_type   = ?", MASTER)
    scope :reverse,           where("#{self.table_name}.authority_type   = ?", MASTER).where("#{self.table_name}.addressing_type = ?", REVERSE)
    scope :nonreverse,        where("#{self.table_name}.addressing_type  = ?", NORMAL)
    scope :noview,            where("#{self.table_name}.view_id IS NULL")
    scope :_reverse,          reverse # 'reverse' is an Array method; having an alias is useful when using the scope on associations
    scope :updated_since,     lambda { |timestamp| Domain.where("#{self.table_name}.updated_at > ? OR #{self.table_name}.id IN (?)", timestamp, Record.updated_since(timestamp).select(:domain_id).pluck(:domain_id).uniq) }
    scope :matching,          lambda { |query|
        if query.index('*')
            where("#{self.table_name}.name LIKE ?", query.gsub(/\*/, '%'))
        else
            where("#{self.table_name}.name" => query)
        end
    }

    def self.last_update
        select('updated_at').reorder('updated_at DESC').limit(1).first.updated_at
    end

    # instantiate soa_record association on domain creation (this is required as
    # we delegate several attributes to the 'soa_record' association and want to
    # be able to set these attributes on 'Domain.new')
    def soa_record
        super || (self.soa_record = SOA.new.tap{|soa| soa.domain = self})
    end

    # deprecated in favor of the 'updated_since' scope
    def updated_since?(timestamp)
        self.updated_at > timestamp
    end

    # return the records, excluding the SOA record
    def records_without_soa
        records.includes(:domain).where('type != ?', 'SOA')
    end

    def name=(value)
        rv = write_attribute :name, value == '.' ? value : value.chomp('.')
        set_addressing_type
        rv
    end

    def addressing_type
        read_attribute('addressing_type').presence || set_addressing_type
    end

    # aliases to mascarade the fact that we're reusing the "master" attribute
    # to hold the "forwarder" values of domains with "forward" type
    def forwarder; self.master; end
    def forwarder=(val); self.master = val; end

    def importing?
        !!importing
    end

    # expand our validations to include SOA details
    def after_validation_on_create #:nodoc:
        soa = SOA.new( :domain => self )
        SOA_FIELDS.each do |f|
            soa.send( "#{f}=", send( f ) )
        end
        soa.serial = serial unless serial.nil? # Optional

        unless soa.valid?
            soa.errors.each_full do |e|
                errors.add_to_base e
            end
        end
    end

    # setup an SOA if we have the requirements
    def save_soa_record #:nodoc:
        return unless self.master?
        soa_record.save or raise "[ERROR] unable to save SOA record (#{soa_record.errors.full_messages})"
    end

    def after_audit
        syslog_audit(self.audits.last)
    end

    # ------------- 'BIND9 export' utility methods --------------
    def query_key_name
        (self.view || View.first).try(:key_name)
    end

    def query_key
        (self.view || View.first).try(:key)
    end

    def zonefile_path
        dir = if self.slave?
                  self.view ? self.view.slaves_dir   : GloboDns::Config::SLAVES_DIR
              elsif self.forward?
                  self.view ? self.view.forwards_dir : GloboDns::Config::FORWARDS_DIR
              elsif self.reverse?
                  self.view ? self.view.reverse_dir  : GloboDns::Config::REVERSE_DIR
              else
                  self.view ? self.view.zones_dir    : GloboDns::Config::ZONES_DIR
              end
        if self.slave?
            File.join(dir, 'dbs.' + self.name)
        else            
            File.join(dir, 'db.' + self.name)
        end
    end

    def to_bind9_conf(zones_dir, indent = '')
        view = self.view || View.first
        str  = "#{indent}zone \"#{self.name}\" {\n"
        str << "#{indent}    type       #{self.authority_type_str.downcase};\n"
        str << "#{indent}    file       \"#{File.join(zones_dir, zonefile_path)}\";\n" unless self.forward?
        str << "#{indent}    masters    { #{self.master.strip.chomp(';')}; };\n"       if self.slave?   && self.master
        str << "#{indent}    forwarders { #{self.forwarder.strip.chomp(';')}; };\n"    if self.forward? && (self.master || self.slave?)
        str << "#{indent}};\n\n"
        str
    end

    def to_zonefile(output)
        logger.warn "[WARN] called 'to_zonefile' on slave/forward domain (#{self.id})" and return if slave? || forward?

        output = File.open(output, 'w') if output.is_a?(String) || output.is_a?(Pathname)

        output.puts "$ORIGIN #{self.name.chomp('.')}."
        output.puts "$TTL    #{self.ttl}"
        output.puts

        format = records_format
        records.order("FIELD(type, #{GloboDns::Config::RECORD_ORDER.map{|x| "'#{x}'"}.join(', ')}), name ASC").each do |record|
            record.domain = self
            record.update_serial(true) if record.is_a?(SOA)
            record.to_zonefile(output, format)
        end
    ensure
        output.close if output.is_a?(File)
    end

    def validate_recursive_subdomains
        return if self.name.blank?

        record_name = nil
        domain_name = self.name.clone
        while suffix = domain_name.slice!(/.*?\./).try(:chop)
            record_name = record_name ? "#{record_name}.#{suffix}" : suffix
            records     = Record.joins(:domain).
                                  where("#{Record.table_name}.name = ? OR #{Record.table_name}.name LIKE ?", record_name, "%.#{record_name}").
                                  where("#{Domain.table_name}.name = ?", domain_name).all
            if records.any?
                records_excerpt = self.class.truncate(records.collect {|r| "\"#{r.name} #{r.type} #{r.content}\" from \"#{r.domain.name}\"" }.join(', '))
                self.errors.add(:base, I18n.t('records_unreachable_by_domain', :records => records_excerpt, :scope => 'activerecord.errors.messages'))
                return
            end
        end
    end

    private

    def set_addressing_type
        REVERSE_DOMAIN_SUFFIXES.each do |suffix|
            self.reverse! and return if name.ends_with?(suffix)
        end
        self.normal!
    end

    def records_format
        sizes = self.records.select('MAX(LENGTH(name)) AS name, LENGTH(MAX(ttl)) AS ttl, MAX(LENGTH(type)) AS mtype, LENGTH(MAX(prio)) AS prio').first
        "%-#{sizes.name}s %-#{sizes.ttl}s IN %-#{sizes.mtype}s %-#{sizes.prio}s %s\n"
    end

    def self.truncate(str, limit = 80)
        str.size > limit ? str[0..limit] + '...' : str
    end
end
