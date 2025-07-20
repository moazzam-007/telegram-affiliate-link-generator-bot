# Class contain validations
class Validate
  def initialize(chat_id, redis)
    @chat_id = chat_id
    @redis = redis
  end

  def affiliate_tags
    @redis.exists?("#{@chat_id}:bitly_id") &&
      @redis.exists?("#{@chat_id}:fkrt_id") &&
      @redis.exists?("#{@chat_id}:amzn_id")
  end
end
