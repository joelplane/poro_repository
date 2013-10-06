class PoroRepository::RecordMetaData

  def id
    @id ||= random_id
  end

  private

  def random_id
    Digest::SHA1.hexdigest("#{rand}#{rand}#{rand}#{Time.now.to_i}")
  end

end