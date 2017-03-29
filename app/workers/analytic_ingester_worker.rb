require 'faraday'

class AnalyticIngesterWorker
  include Sidekiq::Worker

  def perform(crash, error, fastfile_id, action)
    start = Time.now
    
    if action == 'fastlane'
      analytic_event_body = analytic_event_body_fastlane(crash, error, fastfile_id)
    else 
      analytic_event_body = analytic_event_body_action(crash, error, fastfile_id, action)
    end

    puts "Sending analytic event: #{analytic_event_body}"

    Faraday.new(:url => ENV["ANALYTIC_INGESTER_URL"]).post do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = analytic_event_body
    end

    stop = Time.now
    puts "Sending analytic ingester event took #{(stop - start) * 1000}ms"
  end

  def analytic_event_body_fastlane(crash, error, fastfile_id)
    completion_status =  crash.present? ? 'crash' : ( error.present? ? 'error' : 'success')

    return {
      analytics: [{
        event_source: {
          oauth_app_name: 'fastlane-enhancer',
          product: 'fastlane_web_onboarding'
        },
        actor: {
          name:'customer',
          detail: fastfile_id
        },
        action: {
          name: 'fastfile_executed'
        },
        primary_target: {
          name: 'fastlane_completion_status',
          detail: completion_status
        },
        millis_since_epoch: Time.now.to_i * 1000,
        version: 1
      }]
    }.to_json
  end

  def analytic_event_body_action(crash, error, fastfile_id, action)
    completion_status =  crash == action ? 'crash' : ( error == action ? 'error' : 'success')

    return {
      analytics: [{
        event_source: {
          oauth_app_name: 'fastlane-enhancer',
          product: 'fastlane_web_onboarding'
        },
        actor: {
          name:'customer',
          detail: fastfile_id
        },
        action: {
          name: 'fastfile_action_executed'
        },
        primary_target: {
          name: 'action_name',
          detail: action
        },
        secondary_target: {
          name: 'action_completion_status',
          detail: completion_status
        },
        millis_since_epoch: Time.now.to_i * 1000,
        version: 1
      }]
    }.to_json
  end
end
