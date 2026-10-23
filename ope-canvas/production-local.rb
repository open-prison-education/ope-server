# frozen_string_literal: true

# Loaded by config/environments/production.rb (production-*.rb) inside
# Rails.application.configure. Keep this file in that binding: `config` is
# already in scope, and `environment_configuration` is not.
#
# This image ships fingerprinted files in /usr/src/app/public/dist, and the
# gateway does not have that tree. Rails has to serve them. User uploads still
# go through send_file; this does not set X-Accel-Redirect.
config.public_file_server.enabled = true
