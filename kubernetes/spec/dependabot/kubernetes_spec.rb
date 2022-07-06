# frozen_string_literal: true

require "spec_helper"
require "dependabot/kubernetes"
require_common_spec "shared_examples_for_autoloading"

RSpec.describe Dependabot::Kubernetes do
  it_behaves_like "it registers the required classes", "kubernetes"
end
