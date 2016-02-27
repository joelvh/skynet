class Record::Base
  def initialize(container = nil, record = nil)
    @record = record
    @container = container
  end

  def delete
    cloud.head(@record + '.json').try(:destroy)
  end

  def url
    @url ||= data['url']
  end

  def screenshots
    @screenshots ||= data['screenshot'].map { |_key, value| { value => url } }.reduce({}, :merge)
  end

  def data
    JSON.parse(cloud.get(@record + '.json').try(:body), quirks_mode: true)
  rescue
    {}
  end

  def current_data(options = { crawl: true, social: false })
    return { id: @record, container: @container, error: 'not available' } unless old_data = data
    new_data = { id: nil,
                 container: @container,
                 social: {},
                 price:{}
               }

    old_data.each do |k, v|

      if v.is_a?(Hash)
        if k.include?('_shares')
          new_data[:social][k] = sanitize_value(v.values.last)
        elsif k.include?('price')
          new_data[:price][k] = sanitize_value(v.values.last)
        else
          new_data[k] = sanitize_value(v.values.last)
        end
      else
        if k.include?('_shares')
          new_data[:social][k] = sanitize_value(v)
        elsif k.include?('price')
          new_data[:price][k] = sanitize_value(v)
        else
          new_data[k] = sanitize_value(v)
        end
      end
    end if old_data['id']
    recrawl(old_data['url'], options) if old_data['url']
    new_data.deep_symbolize_keys!
  end

  def historical_data(options = { crawl: true, social: false })
    return { id: @record, container: @container, error: 'not available' } unless old_data = data
    new_data = { id: old_data['id'],
                 container: @container,
                 name: old_data['name'] }
    old_data.each do |k, v|
      if v.is_a?(Hash) && v.count > 1
        new_data[k] = v.merge({Date.today.to_s => v.values.last}).group_by_week {|k,v| k }.map do |k,v|
          if value = v.try(:first).try(:last)
            @last = sanitize_value(value)
          end
          {k.to_date => @last}
        end.inject({},:merge)
      end
    end if old_data['id']
    recrawl(old_data['url'], options) if old_data['url']

    if new_data.count <= 3
      new_data.merge(error: 'no history available').deep_symbolize_keys!
    else
      new_data.deep_symbolize_keys!
    end
  end

  def data=(new_hash = {})
    cloud.sync @record + '.json', new_hash.to_json
  end

  def cloud
    Cloud.new(@container)
  end

  private

  def sanitize_value value
    if value.is_a?(Array) || !!value == value
      return value
    elsif value.to_i.to_s == value.to_s
      return value.to_i
    elsif (Float(value) rescue false)
      return value.to_f
    else
      return value
    end
  end

  def recrawl(url, options)
    if options[:crawl]
      options[:social] ? Crawler::Socializer.perform_async(url) : Crawler::Slider.perform_async(url)
    end
  rescue #TODO find the correct error for Redis not responding
    nil
  end
end
