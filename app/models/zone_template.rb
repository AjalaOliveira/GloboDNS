class ZoneTemplate < ActiveRecord::Base
  
  belongs_to :user
  has_many :record_templates
  
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :ttl
  
  class << self
    
    # Custom find that takes one additional parameter, :require_soa (bool), for
    # restricting the returned resultset to only instances that #has_soa?
    def find_with_validations( *args )
      options = args.extract_options!
      valid_soa = options.delete( :require_soa ) || false
      
      # find as per usual
      records = find_without_validations( *args << options )
      
      if valid_soa
        records.delete_if { |z| !z.has_soa? }
      end
      
      records # give back
    end
    alias_method_chain :find, :validations
    
    # Convenient scoped finder method that restricts lookups to the specified
    # :user. If the user has an admin role, the scoping is discarded totally,
    # since an admin _is an admin_.
    #
    # Example:
    # 
    #   ZoneTemplate.find(:all) # Normal behavior
    #   ZoneTemplate.find(:all, :user => user_instance) # Will scope lookups to 
    #     the user
    #
    def find_with_scope( *args )
      options = args.extract_options!
      user = options.delete( :user )
      
      unless user.nil? || user.has_role?( 'admin' )
        with_scope( :find => { :conditions => [ 'user_id = ?', user.id ] } ) do
          find_without_scope( *args << options )
        end
      else
        find_without_scope( *args << options )
      end
    end
    alias_method_chain :find, :scope
  end
  
  # Build a new zone using +self+ as a template. +zone+ should be valid zone
  # name. Pass the optional +user+ object along to have the new one owned by the
  # user, otherwise it's for admins only.
  # 
  # This method will throw exceptions as it encounters errors, and will use a 
  # transaction to complete/rollback the operation.
  def build( zone_name, user = nil )
    zone = Zone.new( :name => zone_name, :ttl => self.ttl )
    zone.user = user if user.is_a?( User )
    
    self.class.transaction do
      # Pick our SOA template out, and populate the zone
      soa_template = record_templates.detect { |r| r.record_type == 'SOA' }
      built_soa_template = soa_template.build( zone_name )
      Zone::SOA_FIELDS.each do |f|
        zone.send( "#{f}=", built_soa_template.send( f ) )
      end
      
      # save the zone or die
      zone.save!
      
      # get the templates
      templates = record_templates.dup
      
      # now build the remaining records according to the templates
      templates.delete( soa_template )
      templates.each do |template|
        record = template.build( zone_name )
        record.zone = zone
        record.save!
      end
    end
    
    zone
  end
  
  # If the template has an SOA record, it can be used for building zones
  def has_soa?
    record_templates.count( :conditions => "record_type LIKE 'SOA'" ) == 1
  end
  
end
