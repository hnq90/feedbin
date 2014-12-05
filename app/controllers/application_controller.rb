class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include SessionsHelper

  before_action :authorize
  before_action :set_user
  before_action :set_view_mode
  before_action :honeybadger_context
  before_action :block_if_maintenance_mode

  etag { current_user.try :id }

  add_flash_types :analytics_event, :one_time_content

  def append_info_to_payload(payload)
    super
    payload[:feedbin_request_id] = request.headers['X-Feedbin-Request-ID']
  end

  def update_selected_feed!(type, data = nil)
    if data.nil?
      selected_feed = type
    else
      session[:selected_feed_data] = data
      selected_feed = "#{type}_#{data}"
    end
    session[:selected_feed_type] = type
    session[:selected_feed] = selected_feed
  end

  def render_404
    render 'errors/not_found', status: 404, layout: 'application', formats: [:html]
  end

  def get_collections
    collections = []
    collections << {
      title: 'Unread',
      path: unread_entries_path,
      count_data: {behavior: 'needs_count', count_group: 'all'},
      id: 'collection_unread',
      favicon_class: 'favicon-unread',
      parent_class: 'collection-unread',
      parent_data: { behavior: 'all_unread', feed_id: 'collection_unread', count_type: 'unread' },
      data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'unread', message: 'Mark all items as read?'}.to_json }
    }
    collections << {
      title: 'All',
      path: entries_path,
      count_data: {behavior: 'needs_count', count_group: 'all'},
      id: 'collection_all',
      favicon_class: 'favicon-all',
      parent_class: 'collection-all',
      parent_data: { behavior: 'all_unread', feed_id: 'collection_all', count_type: 'unread' },
      data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'all', message: 'Mark all items as read?'}.to_json }
    }
    collections << {
      title: 'Starred',
      path: starred_entries_path,
      count_data: {behavior: 'needs_count', count_group: 'all'},
      id: 'collection_starred',
      favicon_class: 'favicon-star',
      parent_class: 'collection-starred',
      parent_data: { behavior: 'starred', feed_id: 'collection_starred', count_type: 'starred' },
      data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'starred', message: 'Mark starred items as read?'}.to_json }
    }
    collections << {
      title: 'Recently Read',
      path: recently_read_entries_path,
      id: 'collection_recently_read',
      favicon_class: 'favicon-recently-read',
      parent_class: 'collection-recently-read',
      parent_data: { behavior: 'recently_read', feed_id: 'collection_recently_read', count_type: 'recently_read' },
      data: { behavior: 'selectable show_entries open_item feed_link', mark_read: {type: 'recently_read', message: 'Mark recently read items as read?'}.to_json }
    }
    if current_user.try(:admin)
      collections << {
        title: 'Updated',
        path: updated_entries_path,
        count_data: {behavior: 'needs_count', count_group: 'all', count_collection: 'updated', count_hide: 'on'},
        id: 'collection_updated',
        favicon_class: 'favicon-updated',
        parent_class: 'collection-updated',
        parent_data: { behavior: 'updated', feed_id: 'collection_updated', count_type: 'updated' },
        data: { behavior: 'selectable show_entries open_item feed_link', special_collection: 'updated', mark_read: {type: 'updated', message: 'Mark updated items as read?'}.to_json }
      }
    end
    collections
  end

  def get_feeds_list
    @mark_selected = true
    @user = current_user

    if @user.hide_tagged_feeds == '1'
      excluded_feeds = @user.taggings.pluck(:feed_id).uniq
      @feeds = @user.feeds.where.not(id: excluded_feeds).include_user_title
    else
      @feeds = @user.feeds.include_user_title
    end

    @count_data = {
      unread_entries: @user.unread_entries.pluck('feed_id, entry_id'),
      starred_entries: @user.starred_entries.pluck('feed_id, entry_id'),
      updated_entries: @user.updated_entries.pluck('feed_id, entry_id'),
      tag_map: @user.taggings.group(:feed_id).pluck('feed_id, array_agg(tag_id)'),
      entry_sort: @user.entry_sort
    }
    @feed_data = {
      feeds: @feeds,
      collections: get_collections,
      tags: @user.tag_group,
      saved_searches: @user.saved_searches.order("lower(name)"),
      count_data: @count_data
    }
  end

  private

  def set_user
    @user = current_user
  end

  def feeds_response
    if 'view_all' == session[:view_mode]
      # Get all entries 100 at a time, then get unread info
      @entries = Entry.where(feed_id: @feed_ids).page(params[:page]).includes(:feed).sort_preference('DESC')
    elsif 'view_starred' == session[:view_mode]
      # Get starred info, then get entries
      starred_entries = @user.starred_entries.select(:entry_id).where(feed_id: @feed_ids).page(params[:page]).order("published DESC")
      @entries = Entry.entries_with_feed(starred_entries, 'DESC')
    else
      # Get unread info, then get entries
      @all_unread = 'true'
      unread_entries = @user.unread_entries.select(:entry_id).where(feed_id: @feed_ids).page(params[:page]).sort_preference(@user.entry_sort)
      @entries = Entry.entries_with_feed(unread_entries, @user.entry_sort)
    end

    if 'view_all' == session[:view_mode]
      @page_query = @entries
    elsif 'view_starred' == session[:view_mode]
      @page_query = starred_entries
    else
      @page_query = unread_entries
    end
  end

  def set_view_mode
    session[:view_mode] ||= 'view_unread'
  end

  def block_if_maintenance_mode
    if ENV['FEEDBIN_MAINTENANCE_MODE']
      if request.format.json?
        render status: 503, json: {message: 'The site is undergoing maintenance.'}
      else
        render 'errors/service_unavailable', status: 503, layout: 'application'
      end
    end
  end

  def honeybadger_context
    Honeybadger.context(user_id: current_user.id) if current_user
  end

  def verify_push_token(authentication_token)
    authentication_token = CGI::unescape(authentication_token)
    verifier = ActiveSupport::MessageVerifier.new(Feedbin::Application.config.secret_key_base)
    verifier.verify(authentication_token)
  end

  def user_classes
    @classes = []
    @classes.push("theme-#{@user.theme || 'day'}")
    @classes.push(session[:view_mode])
    @classes.push(@user.entry_width)
    @classes.push("entries-body-#{@user.entries_body || '1'}")
    @classes.push("entries-time-#{@user.entries_time || '1'}")
    @classes.push("entries-feed-#{@user.entries_feed || '1'}")
    @classes.push("entries-display-#{@user.entries_display || 'block'}")
    @classes = @classes.join(" ")
  end

end
