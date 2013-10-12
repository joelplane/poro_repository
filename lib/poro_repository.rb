require 'digest/sha1'
require 'fileutils'

class PoroRepository

  autoload :WeakHash, "poro_repository/weak_hash"
  autoload :RecordMetaData, "poro_repository/record_meta_data"
  autoload :BoundaryToken, "poro_repository/boundary_token"

  attr_accessor :remember

  def initialize root
    @root = root
    @instantiated_records = {}
    @boundaries = {}
    @remember = true
  end

  # When serialising, attributes identified as "boundaries" are not serialised with the
  # larger object, but are instead serialised separately. A placeholder is used in the
  # original object, with an ID for the extracted object.
  # @param type [Symbol]
  # @param instance_var [Symbol]
  def boundary type, instance_var
    @boundaries[type] ||= []
    @boundaries[type] << instance_var
  end

  def nuke! really
    if really == 'yes, really'
      FileUtils.rm_rf @root
    else
      raise "wont do it!"
    end
  end

  def load_record type, id
    record = previous_instantiated type, id
    return record unless record.nil?
    data = read_if_exists(record_path(type, id))
    data && deserialise(data).tap do |record|
      record.instance_variables.each do |inst_var|
        if (token = record.instance_variable_get(inst_var)).is_a? BoundaryToken
          object = load_record token.original_type, token.original_id
          record.instance_variable_set inst_var, object
        end
      end
      remember_record record if @remember
    end
  end

  # @return [String] record id
  def save_record record, remember=true
    id = id_from_record(record)
    path = record_path(type_from_record(record), id)
    open_for_write path do |file|
      with_boundary_objects_extracted record do |extracted|
        file.write serialise record
        extracted.each do |extracted_record|
          save_record extracted_record
        end
      end
    end
    remember_record record if @remember
    id
  end

  def load_all type
    all_ids_for_type(type).collect do |id|
      load_record type, id
    end
  end

  private

  def open_for_write path, &block
    FileUtils.mkdir_p File.dirname(path)
    File.open path, 'w', &block
  end

  # @return [String, nil]
  def read_if_exists path
    if File.exist? path
      File.read path
    else
      nil
    end
  end

  def record_metadata record
    record.instance_eval do
      @_repository_data ||= RecordMetaData.new
    end
  end

  def serialise record
    Marshal.dump(record)
  end

  def deserialise data
    Marshal.load(data)
  end

  # @return [String]
  def type_from_record record
    if record.respond_to? :type
      record.type
    else
      record.class.name.split('::').last
    end
  end

  def id_from_record record
    if record.respond_to?(:id) && record.id
      record.id
    else
      record_metadata(record).id
    end
  end

  def record_path type, id
    raise if id.nil?
    "#{@root}/#{type}/records/#{id}"
  end

  def index_path type, field
    "#{@root}/#{type}/index/#{field}"
  end

  def with_boundary_objects_extracted record, &block
    originals = {}
    boundaries(record).each do |inst_var|
      value = record.instance_variable_get(inst_var)
      originals[inst_var] = value
      record.instance_variable_set(inst_var, boundary_token(value))
    end
    block.call originals.values
  ensure
    originals.each do |inst_var, original_value|
      record.instance_variable_set(inst_var, original_value)
    end
  end

  def boundaries record
    @boundaries[type_from_record(record).to_sym] || []
  end

  def boundary_token record
    BoundaryToken.new type_from_record(record), id_from_record(record)
  end

  def remember_record record
    type = type_from_record(record)
    @instantiated_records[type] ||= WeakHash.new
    @instantiated_records[type][id_from_record(record)] = record
  end

  def previous_instantiated type, id
    records = @instantiated_records[type] || {}
    ref = records[id]
    ref && ref.actual
  end

  # this method is only used in test
  def remembered_records
    @instantiated_records.values.collect do |h|
      h.values.compact.collect(&:actual)
    end.flatten.compact
  end

  def all_ids_for_type type
    glob = record_path type, '*'
    Dir[glob].collect do |path|
      path.split('/').last # id
    end
  end

end
