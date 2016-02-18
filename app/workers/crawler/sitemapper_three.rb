class Crawler::SitemapperThree < Crawler::Sitemapper
  sidekiq_options queue: :sitemapper_three,
                  retry: true,
                  backtrace: true,
                  unique: :until_and_while_executing,
                  unique_expiration: 120 * 60

  def perform(url, type = 'ScrimperThree')
    return if url.nil?
    if Sidekiq::Queue.new(type.underscore).size <= 10_000
      @url = url
      @type = type
      @name = Page::Url.new(url).name
      @container = Rails.configuration.config[:admin][:api_containers].find { |c| c.include?(@name) }
      @index = Rails.env + '-' + @container

      get_xml

      sitemap.site_links.each do |u|
        check_page(u)
      end if sitemap.sites?

      sitemap.index_links.each do |u|
        get_sitemap u
      end if sitemap.indexes?
    else
      raise "#{type} queue still too large"
    end
  rescue Net::HTTP::Persistent::Error
    Crawler::SitemapperThree.perform_async @url, @type
  end

  def get_sitemap(url)
    Crawler::SitemapperThree.perform_async url, @type
  end
end
