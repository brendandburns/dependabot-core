# frozen_string_literal: true

# These all need to be required so the various classes can be registered in a
# lookup table of package manager names to concrete classes.
require "dependabot/kubernetes/file_fetcher"
require "dependabot/kubernetes/file_parser"
require "dependabot/kubernetes/update_checker"
require "dependabot/kubernetes/file_updater"
require "dependabot/kubernetes/metadata_finder"
require "dependabot/kubernetes/requirement"
require "dependabot/kubernetes/version"

require "dependabot/pull_request_creator/labeler"
Dependabot::PullRequestCreator::Labeler.
  register_label_details("kubernetes", name: "kubernetes", colour: "21ceff")

require "dependabot/dependency"
Dependabot::Dependency.register_production_check("kubernetes", ->(_) { true })
