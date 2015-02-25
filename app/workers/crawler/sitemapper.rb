class Crawler::Sitemapper < Crawler::Base
  sidekiq_options queue: :sitemapper,
                  retry: true,
                  backtrace: true,
                  unique: true,
                  unique_job_expiration: 24 * 60

  def perform(url)
    @url = url
    get_xml
    sitemap.site_links.with_progress.each { |u| get_page u } if sitemap.sites?
    sitemap.index_links.with_progress.each { |u| get_sitemap u } if sitemap.indexes?
  rescue Net::HTTP::Persistent::Error
    Crawler::Sitemapper.perform_async @url
  end

  def get_xml
    sitemap.xml = scraper.get
  end

  def get_page(url)
    Crawler::Scrimper.perform_async url
  end

  def get_sitemap(url)
    Crawler::Sitemapper.perform_async url
  end

  def sitemap
    @sitemap ||= Crawl::Sitemap.new(@url)
  end
end
