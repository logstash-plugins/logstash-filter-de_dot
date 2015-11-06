# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"

# This filter _appears_ to rename fields by replacing `.` characters with a different
# separator.  In reality, it's a somewhat expensive filter that has to copy the
# source field contents to a new destination field (whose name no longer contains
# dots), and then remove the corresponding source field.
#
# It should only be used if no other options are available.
class LogStash::Filters::De_dot < LogStash::Filters::Base

  config_name "de_dot"

  # Replace dots with this value.
  config :separator, :validate => :string, :default => "_"

  # If `nested` is _true_, then create sub-fields instead of replacing dots with
  # a different separator.
  config :nested, :validate => :boolean, :default => false

  # The `fields` array should contain a list of known fields to act on.
  # If undefined, all top-level fields will be checked.  Sub-fields must be
  # manually specified in the array.  For example: `["field.suffix","[foo][bar.suffix]"]`
  # will result in "field_suffix" and nested or sub field ["foo"]["bar_suffix"]
  #
  # WARNING: This is an expensive operation.
  #
  config :fields, :validate => :array


  public
  def register
    raise ArgumentError, "separator cannot be '.'" unless (@separator =~ /\./).nil?
    # Add instance variables here, if any
  end # def register

  private
  def rename_field(event, fieldref)
    @logger.debug? && @logger.debug("preprocess", :event => event.to_hash.to_s)
    @logger.debug? && @logger.debug("source field reference", :fieldref => fieldref)
    newref = fieldref.gsub('.', @separator)
    @logger.debug? && @logger.debug("replacement field reference", :newref => newref)
    event[newref] = event[fieldref]
    @logger.debug? && @logger.debug("event with both new and old field references", :event => event.to_hash.to_s)
    event.remove(fieldref)
    @logger.debug? && @logger.debug("postprocess", :event => event.to_hash.to_s)
  end

  public
  def filter(event)
    @separator = '][' if @nested
    @logger.debug? && @logger.debug("Replace dots with separator", :separator => @separator)
    @fields = event.to_hash.keys if @fields.nil?
    @logger.debug? && @logger.debug("Act on these fields", :fields => @fields)
    @fields.each { |ref| rename_field(event, ref) if !(ref =~ /\./).nil? }
    filter_matched(event)
  end # def filter
end # class LogStash::Filters::De_dot
