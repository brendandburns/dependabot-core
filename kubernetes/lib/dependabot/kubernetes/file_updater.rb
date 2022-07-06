# frozen_string_literal: true

require "dependabot/file_updaters"
require "dependabot/file_updaters/base"
require "dependabot/errors"

module Dependabot
  module Kubernetes
    class FileUpdater < Dependabot::FileUpdaters::Base
      def self.updated_files_regex
        [/.*yaml/i]
      end

      def updated_dependency_files
        updated_files = []

        dependency_files.each do |file|
          next unless requirement_changed?(file, dependency)

          updated_files <<
            updated_file(
              file: file,
              content: updated_yaml_content(file)
            )
        end

        updated_files.reject! { |f| dependency_files.include?(f) }
        raise "No files changed!" if updated_files.none?

        updated_files
      end

      private

      def dependency
        dependencies.first
      end

      def check_required_files
        return if dependency_files.any?

        raise "No YAML!"
      end

      def updated_yaml_content(file)
        updated_content = update_image(file)

        raise "Expected content to change!" if updated_content == file.content

        updated_content
      end

      def update_image(file)
        old_images = old_images(file)
        return if old_images.empty?

        modified_content = file.content

        old_images.each do |old_image|
          old_image_regex = %r{^\s+image:\s+#{old_image}(?=\s|$)}
          modified_content = modified_content.gsub(old_image_regex) do |old_img|
            old_img.gsub("#{old_image}", "#{new_image(file)}")
          end
        end

        modified_content
      end

      def new_image(file)
        elt = dependency.requirements.find { |r| r[:file] == file.name }
        prefix = if elt.fetch(:source)[:registry] then "#{elt.fetch(:source)[:registry]}/" else "" end
        digest = if elt.fetch(:source)[:digest] then "@#{elt.fetch(:source)[:digest]}" else "" end
        tag = if elt.fetch(:source)[:tag] then ":#{elt.fetch(:source)[:tag]}" else "" end
        "#{prefix}#{dependency.name}#{tag}#{digest}"
      end

      def old_images(file)
        dependency.
          previous_requirements.
          select { |r| r[:file] == file.name }.map do |r|
            prefix = if r.fetch(:source)[:registry] then "#{r.fetch(:source)[:registry]}/" else "" end
            digest = if r.fetch(:source)[:digest] then "@#{r.fetch(:source)[:digest]}" else "" end
            tag = if r.fetch(:source)[:tag] then ":#{r.fetch(:source)[:tag]}" else "" end
            "#{prefix}#{dependency.name}#{tag}#{digest}"
          end
      end
    end
  end
end

Dependabot::FileUpdaters.register("kubernetes", Dependabot::Kubernetes::FileUpdater)
