# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Reports exceptions to self-hosted GlitchTip (Sentry-compatible). No-ops
# if SENTRY_DSN isn't set, so local dev/test don't need a real DSN.
if ENV['SENTRY_DSN'].present?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']
    config.environment = Rails.env
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    # Error tracking only, no performance tracing — that's a separate
    # concern from what this is set up to do.
    config.traces_sample_rate = 0.0
  end
end
