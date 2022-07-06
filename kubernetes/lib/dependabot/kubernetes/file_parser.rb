# frozen_string_literal: true

require "yaml"

require "docker_registry2"

require "dependabot/dependency"
require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/errors"
require "dependabot/kubernetes/utils/credentials_finder"

module Dependabot
  module Kubernetes
    class FileParser < Dependabot::FileParsers::Base
      require "dependabot/file_parsers/base/dependency_set"

      # Adapted from the Dockerfile parser
      # Details of Docker regular expressions is at
      # https://github.com/docker/distribution/blob/master/reference/regexp.go
      DOMAIN_COMPONENT =
        /(?:[[:alnum:]]|[[:alnum:]][[[:alnum:]]-]*[[:alnum:]])/.freeze
      DOMAIN = /(?:#{DOMAIN_COMPONENT}(?:\.#{DOMAIN_COMPONENT})+)/.freeze
      REGISTRY = /(?<registry>#{DOMAIN}(?::\d+)?)/.freeze

      NAME_COMPONENT = /(?:[a-z\d]+(?:(?:[._]|__|[-]*)[a-z\d]+)*)/.freeze
      IMAGE = %r{(?<image>#{NAME_COMPONENT}(?:/#{NAME_COMPONENT})*)}.freeze

      TAG = /:(?<tag>[\w][\w.-]{0,127})/.freeze
      DIGEST = /@(?<digest>[^\s]+)/.freeze
      NAME = /\s+AS\s+(?<name>[\w-]+)/.freeze
      IMAGE_SPEC =
        %r{^(#{REGISTRY}/)?#{IMAGE}#{TAG}?#{DIGEST}?#{NAME}?}x.freeze

      def parse
        dependency_set = DependencySet.new

        workflow_files.each do |file|
          dependency_set += workfile_file_dependencies(file)
        end

        dependency_set.dependencies
      end

      private

      def workfile_file_dependencies(file)
        dependency_set = DependencySet.new

        json = YAML.safe_load(file.content, aliases: true)
        images = deep_fetch_images(json).uniq

        images.each do |string|
          # TODO: Support Docker references and path references
          details = string.match(IMAGE_SPEC).named_captures
          details["registry"] = nil if details["registry"] == "docker.io"
  
          version = version_from(details)
          next unless version

          dependency_set << build_image_dependency(file, details, version)
        end

        dependency_set
      rescue Psych::SyntaxError, Psych::DisallowedClass, Psych::BadAlias
        raise Dependabot::DependencyFileNotParseable, file.path
      end

      def build_image_dependency(file, details, version)
        Dependency.new(
          name: details.fetch("image"),
          version: version,
          package_manager: "kubernetes",
          requirements: [
            requirement: nil,
            groups: [],
            file: file.name,
            source: source_from(details)
          ]
        )
      end

      def version_from(parsed_from_line)
        return parsed_from_line.fetch("tag") if parsed_from_line.fetch("tag")

        version_from_digest(
          registry: parsed_from_line.fetch("registry"),
          image: parsed_from_line.fetch("image"),
          digest: parsed_from_line.fetch("digest")
        )
      end

      def source_from(parsed_from_line)
        source = {}

        source[:registry] = parsed_from_line.fetch("registry") if parsed_from_line.fetch("registry")

        source[:tag] = parsed_from_line.fetch("tag") if parsed_from_line.fetch("tag")

        source[:digest] = parsed_from_line.fetch("digest") if parsed_from_line.fetch("digest")

        source
      end

      def version_from_digest(registry:, image:, digest:)
        return unless digest

        repo = docker_repo_name(image, registry)
        client = docker_registry_client(registry)
        client.tags(repo, auto_paginate: true).fetch("tags").find do |tag|
          digest == client.digest(repo, tag)
        rescue DockerRegistry2::NotFound
          # Shouldn't happen, but it does. Example of existing tag with
          # no manifest is "library/python", "2-windowsservercore".
          false
        end
      rescue DockerRegistry2::RegistryAuthenticationException,
             RestClient::Forbidden
        raise if standard_registry?(registry)

        raise PrivateSourceAuthenticationFailure, registry
      end

      def docker_repo_name(image, registry)
        return image unless standard_registry?(registry)
        return image unless image.split("/").count < 2

        "library/#{image}"
      end

      def deep_fetch_images(json_obj)
        case json_obj
        when Hash then deep_fetch_images_from_hash(json_obj)
        when Array then json_obj.flat_map { |o| deep_fetch_images(o) }
        else []
        end
      end

      def deep_fetch_images_from_hash(json_object)
        img = json_object.fetch("image", nil)

        images = 
          if img != nil && img.is_a?(String) && img.length > 0
            [ img ]
          else
            []
          end

        images + json_object.values.flat_map { |obj| deep_fetch_images(obj)}
      end

      def workflow_files
        # The file fetcher only fetches workflow files, so no need to
        # filter here
        dependency_files
      end

      def check_required_files
        # Just check if there are any files at all.
        return if dependency_files.any?

        raise "No workflow files!"
      end

      def standard_registry?(registry)
        return true if registry.nil?

        registry == "registry.hub.docker.com"
      end

      def version_from_digest(registry:, image:, digest:)
        return unless digest

        repo = docker_repo_name(image, registry)
        client = docker_registry_client(registry)
        client.tags(repo, auto_paginate: true).fetch("tags").find do |tag|
          digest == client.digest(repo, tag)
        rescue DockerRegistry2::NotFound
          # Shouldn't happen, but it does. Example of existing tag with
          # no manifest is "library/python", "2-windowsservercore".
          false
        end
      rescue DockerRegistry2::RegistryAuthenticationException,
             RestClient::Forbidden
        raise if standard_registry?(registry)

        raise PrivateSourceAuthenticationFailure, registry
      end

      def docker_repo_name(image, registry)
        return image unless standard_registry?(registry)
        return image unless image.split("/").count < 2

        "library/#{image}"
      end

      def docker_registry_client(registry)
        if registry
          credentials = registry_credentials(registry)

          DockerRegistry2::Registry.new(
            "https://#{registry}",
            user: credentials&.fetch("username", nil),
            password: credentials&.fetch("password", nil)
          )
        else
          DockerRegistry2::Registry.new("https://registry.hub.docker.com")
        end
      end

      def registry_credentials(registry_url)
        credentials_finder.credentials_for_registry(registry_url)
      end

      def credentials_finder
        @credentials_finder ||= Utils::CredentialsFinder.new(credentials)
      end
    end
  end
end

Dependabot::FileParsers.register("kubernetes", Dependabot::Kubernetes::FileParser)
