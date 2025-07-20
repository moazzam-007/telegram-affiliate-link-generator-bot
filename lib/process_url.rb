require_relative 'bitlyurl'

module ProcessUrl
  def self.individual(url:, chat_id:, redis:)
    case url
    when /amazon.in/
      amazon(url, chat_id, redis, short: false)
    when /amzn.to/, /amzn.in/
      amazon(url, chat_id, redis, short: true)
    when /flipkart.com/
      flipkart(url, chat_id, redis, short: false)
    when /fkrt.it/
      flipkart(url, chat_id, redis, short: true)
    else
      redirection(url, chat_id, redis)
    end
  end

  def self.amazon(url, chat_id, redis, short: false)
    amazon = AffiliateProcess.new(url, 'tag')
    amazon.fetch_url if short
    amazon.clean_url
    amzn_id = redis.get("#{chat_id}:amzn_id")
    amazon.add_tracking_id(amzn_id)
    shorten_url(amazon.updated_url, chat_id, redis)
  end

  def self.flipkart(url, chat_id, redis, short: false)
    flipkart = AffiliateProcess.new(url, 'affid')
    flipkart.fetch_url if short
    flipkart.clean_url
    fkrt_id = redis.get("#{chat_id}:fkrt_id")
    flipkart.add_tracking_id(fkrt_id)
    shorten_url(flipkart.updated_url, chat_id, redis, flipkart: true)
  end

  def self.redirection(url, chat_id, redis)
    url = get_redirected_url(url)

    found_url = match_first_url(url)

    return individual(url: found_url, chat_id: chat_id, redis: redis) if found_url

    return "URL Not Supported: #{url}" if url.is_a?(String)

    return flipkart(url.request.last_uri, chat_id, redis) if url.request.last_uri.host.include? 'flipkart'

    return amazon(url.request.last_uri, chat_id, redis) if url.request.last_uri.host.include? 'amazon'

    urls = URI.extract(url.parsed_response, %w[http https])
    flipkart = nil
    urls.each { |u| flipkart = u if u.include? 'flipkart' }
    return flipkart(flipkart, chat_id, redis) unless flipkart.nil?

    url = get_redirected_url(urls[2]) if url.include? 'cashbackUrl'
    "URL Not Supported: #{url.is_a?(String) ? url : url.request.last_uri}"
  end

  def self.get_redirected_url(url)
    processed_url = url
    res = nil
    loop do
      res = HTTParty.get(processed_url, timeout: 3)
      break if res.request.last_uri.to_s == processed_url

      processed_url = res.request.last_uri.to_s
    end
    res
  rescue StandardError => e
    "Error: #{e.message}: #{res&.request&.last_uri} #{url if res.nil?} "
  end

  def self.shorten_url(url, chat_id, redis, flipkart: false)
    if flipkart
      fkrt_url = "https://affiliate.flipkart.com/a_url_shorten?url=#{CGI.escape(url)}"
      res = HTTParty.get(fkrt_url, follow_redirects: false)
      res['response']['shortened_url']
    else
      bitly_id = redis.get("#{chat_id}:bitly_id")
      BitlyUrl.new(bitly_id, url).short_url
    end
  rescue StandardError => e
    puts e.inspect
    e.inspect
  end

  def self.match_first_url(url)
    found_url = %r{(https?:/)?\w*\.\w+(\.\w+)*(/\w+)*(\.\w*)?}.match(url).to_s

    found_url = "http://#{found_url}" unless found_url.include? 'http'

    return found_url if found_url.include? 'amazon'

    false
  end
end
