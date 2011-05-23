$TESTING_CM = defined? $TESTING_CM

require 'timeout'
#require 'memcache_util' unless $TESTING_CM
require 'active_record' unless $TESTING_CM

##
# An abstract ActiveRecord descendant that caches records in memcache and in
# local memory.
#
# CachedModel can store into both a local in-memory cache and in memcached.
# By default memcached is enabled and the local cache is disabled.
#
# Local cache use can be enabled or disabled with
# CachedModel::use_local_cache=.  If you do enable the local cache be sure to
# add a before filter that calls CachedModel::cache_reset for every request.
#
# memcached use can be enabled or disabled with CachedModel::use_memcache=.
#
# You can adjust the memcached TTL with CachedModel::ttl=

module ModelCacher
  VERSION = '1.3.4.Umur'
  module InstanceMethods

  ##
  # Delete the entry from the cache now that it isn't in the DB.

  def destroy_with_model_cacher
    return destroy_without_model_cacher
  ensure
    cache_delete
  end

  ##
  # Invalidate the cache for this record before reloading from the DB.

  def reload_with_model_cacher(*args)
    cache_delete
    return reload_without_model_cacher(*args)
  ensure
    cache_store
  end

  ##
  # Store a new copy of ourselves into the cache.

  def update_with_model_cacher
    return update_without_model_cacher
  ensure
    cache_store
  end

  ##
  # Remove this record from the cache.

  def cache_delete
    cache_local.delete cache_key_local if CachedModel.use_local_cache?
    Rails.cache.delete cache_key_memcache if CachedModel.use_memcache?
  end

  ##
  # The local cache key for this record.

  def cache_key_local
    return "#{self.class}:#{id}"
  end

  ##
  # The memcache key for this record.

  def cache_key_memcache
    return "active_record:#{cache_key_local}"
  end

  ##
  # The local object cache.

  def cache_local
    return CachedModel.cache_local
  end

  ##
  # Store this record in the cache without associations.  Storing associations
  # leads to wasted cache space and hard-to-debug problems.

  def cache_store
    obj = dup
    obj.send :instance_variable_set, :@attributes, attributes_before_type_cast
    transaction_level = CachedModel.cache_transaction_level
    if CachedModel.cache_delay_commit[transaction_level].nil? then
      if CachedModel.use_local_cache? then
        cache_local[cache_key_local] = obj
      end
      if CachedModel.use_memcache? then
        Rails.cache.write cache_key_memcache, obj, :expires_in => CachedModel.ttl
      end
    else
      CachedModel.cache_delay_commit[transaction_level] << obj
    end
    nil
  end

  end

  module ClassMethods

  ##
  # Invalidate the cache entry for a record.  The update method will
  # automatically invalidate the cache when updates are made through
  # ActiveRecord model record.  However, several methods update tables with
  # direct sql queries for effeciency.  These methods should call this method
  # to invalidate the cache after making those changes.
  #
  # NOTE - if a SQL query updates multiple rows with one query, there is
  # currently no way to invalidate the affected entries unless the entire
  # cache is dumped or until the TTL expires, so try not to do this.

  def cache_delete(klass, id)
    key = "#{klass}:#{id}"
    CachedModel.cache_local.delete key if CachedModel.use_local_cache?
    Rails.cache.delete "active_record:#{key}" if CachedModel.use_memcache?
  end

  ##
  # Invalidate the local process cache.  This should be called from a before
  # filter at the beginning of each request.

  def cache_reset
    CachedModel.cache_local.clear if CachedModel.use_local_cache?
  end

  ##
  # Override the find method to look for values in the cache before going to
  # the database.
  #--
  # TODO Push a bunch of code down into find_by_sql where it really should
  # belong.

  def find_with_model_cacher(*args)
logger.debug "CachedModel.find #{args.to_json}"
    args[0] = args.first.to_i if args.first =~ /\A\d+\Z/
    # Only handle simple find requests.  If the request was more complicated,
    # let the base class handle it, but store the retrieved records in the
    # local cache in case we need them later.
    if args.length != 1 or not Fixnum === args.first then
      # Rails requires multiple levels of indirection to look up a record
      # First call super
      records = find_without_model_cacher(*args)
      # Then, if it was a :all, just return
      return records if args.first == :all
      return records if Rails.env == 'test'
      case records
      when Array then
logger.debug "CachedModel.find STORE"
        records.each { |r| r.cache_store }
      end
      return records
    end

    return find_without_model_cacher(*args)
  end

  ##
  # Find by primary key from the cache.

  def find_by_sql_with_model_cacher(*args)
logger.debug "CachedModel.find_by_sql #{args.join(',')}"
    expected_query = %r{^SELECT \* FROM "#{table_name}" WHERE \("#{table_name}"\."#{primary_key}" = '?(\d+)'?\)}
    return find_by_sql_without_model_cacher(*args) unless args.first =~ expected_query

    id = $1.to_i

    # Try to find the record in the local cache.
    cache_key_local = "#{name}:#{id}"
    if CachedModel.use_local_cache? then
      record = CachedModel.cache_local[cache_key_local]
      return [record] unless record.nil?
    end

    # Try to find the record in memcache and add it to the local cache
    if CachedModel.use_memcache? then
      record = Rails.cache.read "active_record:#{cache_key_local}"
logger.debug "CachedModel.find_by_sql #{record ? 'HIT' : 'MISS'} #{cache_key_local}!"
      unless record.nil? then
        if CachedModel.use_local_cache? then
          CachedModel.cache_local[cache_key_local] = record
        end
        return [record]
      end
    end

    # Fetch the record from the DB
    records = find_by_sql_without_model_cacher(*args)
logger.debug "CachedModel.find_by_sql STORE #{cache_key_local}" unless records.empty?
    records.first.cache_store unless records.empty? # only one
    return records
  end

  ##
  # Delay updating the cache while in a transaction.

  def transaction_with_model_cacher(options={}, &block)
    level = CachedModel.cache_transaction_level += 1
    CachedModel.cache_delay_commit[level] = []

    value = transaction_without_model_cacher(options, &block)
puts "transaction #{value}"
    waiting = CachedModel.cache_delay_commit.delete level
    waiting.each do |obj|
      obj.cache_store
    end

    return value
  ensure
    CachedModel.cache_transaction_level -= 1
  end

  end

  def acts_as_cached_model
    include InstanceMethods
    extend ClassMethods
    alias_method_chain :destroy, :model_cacher
    alias_method_chain :reload, :model_cacher
    alias_method_chain :update, :model_cacher
    class << self
      alias_method_chain :find, :model_cacher
      alias_method_chain :find_by_sql, :model_cacher
      alias_method_chain :transaction, :model_cacher
    end
  end

end