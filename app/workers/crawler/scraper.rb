class Crawler::Scraper < Crawler::Base
  sidekiq_options queue: :scraper,
                  retry: true,
                  backtrace: true,
                  unique: :until_and_while_executing,
                  unique_expiration: 120 * 60

  def perform(url, type = nil)
    return if url.nil?

    if type.nil?
      next_type
    else
      @type = type
    end

    @url = url

    Timeout::timeout(60) do
      parser.page = scraper.get
    end

    if scraping.presence
      scraping.each do |hash|
        if hash[:url].presence
          ('Crawler::' + next_type).constantize.perform_async hash[:url], hash
        else
          Recorder::Uploader.perform_async hash.merge(url: @url)
        end
      end
    else
      raise "Scraping not found"
    end

    paginate

    # upload
  rescue Mechanize::ResponseCodeError => e
    if e.response_code == '404' ||
         e.response_code == '410' ||
         e.response_code == '520' ||
         e.response_code == '500' ||
         e.response_code == '301' ||
         e.response_code == '302'
      Mapper::UrlAvailability.perform_async url
    else
      raise
    end
  rescue Mechanize::RedirectLimitReachedError => e
    nil
  rescue Timeout::Error => e
    Crawler::Stretcher.perform_async url
  end

  def next_type
    @type ||= 'Scrimper'
  end

  def scraping
    @scraping ||= parser.scraping.compact
  end

  def paginate
    parser.paginate.each do |next_url|
      Crawler::Scraper.perform_async next_url
    end
  end
end
