# frozen_string_literal: true

require "dependabot/utils"

module Dependabot
  module Kubernetes
    class Version < Gem::Version
    end
  end
end

Dependabot::Utils.
  register_version_class("kubernetes", Dependabot::Kubernetes::Version)
