class PoroRepository::BoundaryToken

  attr_reader :original_type, :original_id

  def initialize original_type, original_id
    @original_type = original_type
    @original_id = original_id
  end

end
