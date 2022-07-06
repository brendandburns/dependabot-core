# frozen_string_literal: true

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"

module Dependabot
  module Kubernetes
    class FileFetcher < Dependabot::FileFetchers::Base
      def self.required_files_in?(filenames)
        filenames.any? { |f| f.match?(/.*yaml/i) }
      end

      def self.required_files_message
        "Repo must contain a Kubernetes YAML."
      end

      private

      def fetch_files
        fetched_files = []
        fetched_files += correctly_encoded_yamlfiles

        return fetched_files if fetched_files.any?

        if incorrectly_encoded_yamlfiles.none?
          raise(
            Dependabot::DependencyFileNotFound,
            File.join(directory, "*.yaml")
          )
        else
          raise(
            Dependabot::DependencyFileNotParseable,
            incorrectly_encoded_yamlfiles.first.path
          )
        end
      end

      def yamlfiles
        @yamlfiles ||=
          repo_contents(raise_errors: false).
          select { |f| f.type == "file" && f.name.match?(/.*yaml/i) }.
          map { |f| fetch_file_from_host(f.name) }
      end

      def correctly_encoded_yamlfiles
        yamlfiles.select { |f| f.content.valid_encoding? }
      end

      def incorrectly_encoded_yamlfiles
        yamlfiles.reject { |f| f.content.valid_encoding? }
      end
    end
  end
end

Dependabot::FileFetchers.register("kubernetes", Dependabot::Kubernetes::FileFetcher)
