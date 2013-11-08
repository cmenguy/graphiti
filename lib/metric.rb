class Metric
  include Redised

  def self.all(refresh = false)
    redis_metrics = redis.get("metrics")
    @metrics = redis_metrics.split("\n") if redis_metrics
    return @metrics if @metrics && !@metrics.empty? && !refresh
    @metrics = []
    get_metrics_list
    redis.set "metrics", @metrics.join("\n")
    @metrics
  end

  def self.find(match, max = 100)
    match = match.to_s.strip
    matches = []
    all.each do |m|
      if m =~ /#{match.strip}/i
        matches << m
      end
      break if matches.length > max
    end
    matches
  end

  private
  def self.get_metrics_list(prefix = Graphiti.settings.metric_prefix)
    urls = []
    @metrics = []
    puts "#{Graphiti.settings.graphite_caches.length}"
    if Graphiti.settings.graphite_caches.length <= 0
      urls << Graphiti.settings.graphite_base_url
    else
      urls.concat(Graphiti.settings.graphite_caches)
    end
    urls.each do |u|
      url = "#{u}/metrics/index.json"
      puts "Getting #{url}"
      response = Typhoeus::Request.get(url)
      if response.success?
        json = Yajl::Parser.parse(response.body)
        if prefix.nil?
          @metrics.concat(json)
        elsif prefix.kind_of?(Array)
          @metrics.concat(json.grep(/^[#{prefix.map! { |k| Regexp.escape k }.join("|")}]/))
        else
          @metrics.concat(json.grep(/^#{Regexp.escape prefix}/))
        end
      else
        puts "Error fetching #{url}. #{response.inspect}"
      end
    end
    @metrics.sort
  end

end
