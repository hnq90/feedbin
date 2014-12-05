class EntryPresenter < BasePresenter

  presents :entry

  def entry_link(&block)
    options = {
      remote: true, class: 'wrap', data: {
        behavior: 'selectable open_item show_entry_content entry_info',
        mark_as_read_path: @template.mark_as_read_entry_path(entry),
        recently_read_path: @template.recently_read_entry_path(entry),
        entry_id: entry.id,
        entry_info: {id: entry.id, feed_id: entry.feed_id, published: entry.published.to_i}
      }
    }
    @template.link_to @template.entry_path(entry), options do
      yield
    end
  end

  def published_date
    if entry.published
      entry.published.to_s(:feed)
    else
      ''
    end
  end

  def datetime
    if entry.published
      entry.published.to_s(:datetime)
    else
      ''
    end
  end

  def parsed_date(date, format)
    begin
      date = Time.parse(date)
      date.to_s(format)
    rescue Exception
      nil
    end
  end

  def abbr_time
    seconds_since_published = Time.now.utc - entry.published
    if seconds_since_published > 86400
      if Time.now.strftime("%Y") != entry.published.strftime("%Y")
        format = 'day_year'
      else
        format = 'day'
      end
      string = entry.published.to_s(:datetime)
    elsif seconds_since_published < 0
      format = 'none'
      string = "the future"
    elsif seconds_since_published < 60
      format = 'none'
      string = "now"
    elsif seconds_since_published < 3600
      format = 'none'
      string = (seconds_since_published / 60).round
      string = "#{string}m"
    else
      format = 'none'
      string = (seconds_since_published / 60 / 60).round
      string = "#{string}h"
    end
    @template.time_tag(entry.published, string, class: 'time', data: {format: format})
  end

  def content
    ContentFormatter.format!(entry.content, entry)
  rescue HTML::Pipeline::Filter::InvalidDocumentException
    '(no content)'
  end

  def has_content?
    entry.summary.respond_to?(:length) && entry.summary.length > 0
  end

  def title
    text = sanitized_title
    if text.blank?
      text = entry.summary.html_safe
    end
    if text.blank?
      text = '&hellip;'.html_safe
    end
    text
  end

  def sanitized_title
    @sanitized_title ||= @template.raw(@template.strip_tags(entry.title))
  end

  def author
    if entry.author
      clean_author = @template.strip_tags(entry.author)
      clean_author = "by " + @template.content_tag(:span, clean_author, class: "author")
    else
      clean_author = ''
    end
    clean_author.html_safe
  end

  def media_size
    begin
      size = Integer(entry.data['enclosure_length'])
      size = @template.number_to_human_size(size)
      size = "(#{size})"
    rescue Exception
      size = ''
    end
  end

  def media
    output = ''
    if entry.data['enclosure_type'] == 'video/mp4'
      output += @template.video_tag entry.data['enclosure_url'], preload: 'none'
    elsif entry.data['enclosure_type'] == 'audio/mpeg'
      output += @template.audio_tag entry.data['enclosure_url'], preload: 'none'
    end
    output += @template.link_to "Download #{media_size}", entry.data['enclosure_url'], class: 'download-link'
    output
  end

  def media_type
    if entry.data && entry.data['enclosure_type'] == 'video/mp4'
      :video
    elsif entry.data && entry.data['enclosure_type'] == 'audio/mpeg'
      :audio
    else
      nil
    end
  end

  def media_duration
    if entry.data['itunes_duration']
      entry.data['itunes_duration']
    else
      ''
    end
  end

  def feed_domain_matches?(comparison)
    begin
      uri = URI.parse(entry.feed.site_url)
      puts uri.host
      uri.host == comparison || uri.host == comparison.sub('www.', '')
    rescue Exception
      false
    end
  end

  def has_media?
    !media_type.nil? || content.include?('<iframe')
  end

end