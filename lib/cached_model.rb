
class CachedModel < ActiveRecord::Base
  acts_as_cached_model

  self.abstract_class = true

  VERSION = '1.3.4.Umur'

  @cache_delay_commit = {}
  @cache_local = {}
  @cache_transaction_level = 0
  @use_local_cache = false
  @use_memcache = true
  @ttl = 60 * 15

  class << self

    # :stopdoc:

    ##
    # The transaction commit buffer.  You shouldn't touch me.

    attr_accessor :cache_delay_commit

    ##
    # The local process cache.  You shouldn't touch me.

    attr_reader :cache_local

    ##
    # The transaction nesting level.  You shouldn't touch me.

    attr_accessor :cache_transaction_level

    # :startdoc:

    ##
    # Enables or disables use of the local cache.
    #
    # NOTE if you enable this you must call #cache_reset or you will
    # experience uncontrollable process growth!
    #
    # Defaults to false.

    attr_writer :use_local_cache

    ##
    # Enables or disables the use of memcache.

    attr_writer :use_memcache

    ##
    # Memcache record time-to-live for stored records.

    attr_accessor :ttl

  end

  ##
  # Returns true if use of the local cache is enabled.

  def self.use_local_cache?
    return @use_local_cache
  end

  ##
  # Returns true if use of memcache is enabled.

  def self.use_memcache?
    return @use_memcache
  end

end

