# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/source"
require "dependabot/kubernetes/file_updater"
require_common_spec "file_updaters/shared_examples_for_file_updaters"

RSpec.describe Dependabot::Kubernetes::FileUpdater do
  it_behaves_like "a dependency file updater"

  let(:updater) do
    described_class.new(
      dependency_files: files,
      dependencies: [dependency],
      credentials: credentials
    )
  end
  let(:files) { [podfile] }
  let(:credentials) do
    [{
      "type" => "git_source",
      "host" => "github.com",
      "username" => "x-access-token",
      "password" => "token"
    }]
  end
  let(:podfile) do
    Dependabot::DependencyFile.new(
      content: podfile_body,
      name: "multiple.yaml"
    )
  end
  let(:podfile_body) { fixture("kubernetes", "yaml", "multiple.yaml") }
  let(:dependency) do
    Dependabot::Dependency.new(
      name: "ubuntu",
      version: "17.10",
      previous_version: "17.04",
      requirements: [{
        requirement: nil,
        groups: [],
        file: "multiple.yaml",
        source: { tag: "17.10" }
      }],
      previous_requirements: [{
        requirement: nil,
        groups: [],
        file: "multiple.yaml",
        source: { tag: "17.04" }
      }],
      package_manager: "kubernetes"
    )
  end

  describe "#updated_dependency_files" do
    subject(:updated_files) { updater.updated_dependency_files }

    it "returns DependencyFile objects" do
      updated_files.each { |f| expect(f).to be_a(Dependabot::DependencyFile) }
    end

    its(:length) { is_expected.to eq(1) }

    describe "the updated podfile" do
      subject(:updated_podfile) do
        updated_files.find { |f| f.name == "multiple.yaml" }
      end

      its(:content) { is_expected.to include "image: ubuntu:17.10\n" }
      its(:content) { is_expected.to include "image: nginx:1.14.2\n" }
      its(:content) { is_expected.to include "kind: Pod" }
    end

    context "when multiple identical lines need to be updated" do
      let(:podfile_body) do
        fixture("kubernetes", "yaml", "multiple_identical.yaml")
      end
      let(:podfile) do
        Dependabot::DependencyFile.new(
          content: podfile_body,
          name: "multiple_identical.yaml"
        )
      end
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "nginx",
          version: "1.14.3",
          previous_version: "1.14.2",
          requirements: [{
            requirement: nil,
            groups: [],
            file: "multiple_identical.yaml",
            source: { tag: "1.14.3" }
          }],
          previous_requirements: [{
            requirement: nil,
            groups: [],
            file: "multiple_identical.yaml",
            source: { tag: "1.14.2" }
          }],
          package_manager: "kubernetes"
        )
      end

      describe "the updated podfile" do
        subject(:updated_podfile) do
          updated_files.find { |f| f.name == "multiple_identical.yaml" }
        end

        its(:content) { is_expected.to include "  - name: nginx2\n    image: nginx:1.14.3" }
        its(:content) { is_expected.to include "  - name: nginx\n    image: nginx:1.14.3" }
        its(:content) { is_expected.to include "kind: Pod" }
      end
    end

    context "when the dependency has a namespace" do
      let(:podfile) do
        Dependabot::DependencyFile.new(
          content: podfile_body,
          name: "namespace.yaml"
        )
      end
      let(:podfile_body) { fixture("kubernetes", "yaml", "namespace.yaml") }
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "my-repo/nginx",
          version: "1.14.3",
          previous_version: "1.14.2",
          requirements: [{
            requirement: nil,
            groups: [],
            file: "namespace.yaml",
            source: { tag: "1.14.3" }
          }],
          previous_requirements: [{
            requirement: nil,
            groups: [],
            file: "namespace.yaml",
            source: { tag: "1.14.2" }
          }],
          package_manager: "kubernetes"
        )
      end

      its(:length) { is_expected.to eq(1) }

      describe "the updated podfile" do
        subject(:updated_podfile) do
          updated_files.find { |f| f.name == "namespace.yaml" }
        end

        its(:content) { is_expected.to include "    image: my-repo/nginx:1.14.3\n" }
        its(:content) { is_expected.to include "kind: Pod\n" }
      end
    end

    context "when the dependency is from a private registry" do
      let(:podfile) do
        Dependabot::DependencyFile.new(
          content: podfile_body,
          name: "private_tag.yaml"
        )
      end
      let(:podfile_body) { fixture("kubernetes", "yaml", "private_tag.yaml") }
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "myreg/ubuntu",
          version: "17.10",
          previous_version: "17.04",
          requirements: [{
            requirement: nil,
            groups: [],
            file: "private_tag.yaml",
            source: {
              registry: "registry-host.io:5000",
              tag: "17.10"
            }
          }],
          previous_requirements: [{
            requirement: nil,
            groups: [],
            file: "private_tag.yaml",
            source: {
              registry: "registry-host.io:5000",
              tag: "17.04"
            }
          }],
          package_manager: "kubernetes"
        )
      end

      its(:length) { is_expected.to eq(1) }

      describe "the updated podfile" do
        subject(:updated_podfile) do
          updated_files.find { |f| f.name == "private_tag.yaml" }
        end

        its(:content) do
          is_expected.
            to include("    image: registry-host.io:5000/myreg/ubuntu:17.10\n")
        end
        its(:content) { is_expected.to include "kind: Pod" }
      end
    end

    context "when the dependency is podfile using the v1 API" do
      let(:podfile) do
        Dependabot::DependencyFile.new(
          content: podfile_body,
          name: "v1_tag.yaml"
        )
      end
      let(:podfile_body) { fixture("kubernetes", "yaml", "v1_tag.yaml") }
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "myreg/ubuntu",
          version: "17.10",
          previous_version: "17.04",
          requirements: [{
            requirement: nil,
            groups: [],
            file: "v1_tag.yaml",
            source: {
              registry: "docker.io",
              tag: "17.10"
            }
          }],
          previous_requirements: [{
            requirement: nil,
            groups: [],
            file: "v1_tag.yaml",
            source: {
              registry: "docker.io",
              tag: "17.04"
            }
          }],
          package_manager: "kubernetes"
        )
      end

      its(:length) { is_expected.to eq(1) }

      describe "the updated podfile" do
        subject(:updated_podfile) do
          updated_files.find { |f| f.name == "v1_tag.yaml" }
        end

        its(:content) do
          is_expected.
            to include("    image: docker.io/myreg/ubuntu:17.10\n")
        end
        its(:content) { is_expected.to include "kind: Pod" }
      end
    end

    context "when the dependency has a digest" do
      let(:podfile) do
        Dependabot::DependencyFile.new(
          content: podfile_body,
          name: "digest.yaml"
        )
      end
      let(:podfile_body) { fixture("kubernetes", "yaml", "digest.yaml") }
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "ubuntu",
          version: "17.10",
          previous_version: "12.04.5",
          requirements: [{
            requirement: nil,
            groups: [],
            file: "digest.yaml",
            source: {
              digest: "sha256:3ea1ca1aa8483a38081750953ad75046e6cc9f6b86"\
                      "ca97eba880ebf600d68608"
            }
          }],
          previous_requirements: [{
            requirement: nil,
            groups: [],
            file: "digest.yaml",
            source: {
              digest: "sha256:18305429afa14ea462f810146ba44d4363ae76e4c8"\
                      "dfc38288cf73aa07485005"
            }
          }],
          package_manager: "kubernetes"
        )
      end

      its(:length) { is_expected.to eq(1) }

      describe "the updated podfile" do
        subject(:updated_podfile) do
          updated_files.find { |f| f.name == "digest.yaml" }
        end

        its(:content) { is_expected.to include "    image: ubuntu@sha256:3ea1ca1aa" }
        its(:content) { is_expected.to include "kind: Pod" }

        context "when the podfile has a tag as well as a digest" do
          let(:podfile) do
            Dependabot::DependencyFile.new(
              content: podfile_body,
              name: "digest_and_tag.yaml"
            )
          end
          let(:podfile_body) do
            fixture("kubernetes", "yaml", "digest_and_tag.yaml")
          end
          let(:dependency) do
            Dependabot::Dependency.new(
              name: "ubuntu",
              version: "17.10",
              previous_version: "12.04.5",
              requirements: [{
                requirement: nil,
                groups: [],
                file: "digest_and_tag.yaml",
                source: {
                  tag: "17.10",
                  digest: "sha256:3ea1ca1aa8483a38081750953ad75046e6cc9f6b86"\
                          "ca97eba880ebf600d68608"
                }
              }],
              previous_requirements: [{
                requirement: nil,
                groups: [],
                file: "digest_and_tag.yaml",
                source: {
                  tag: "12.04.5",
                  digest: "sha256:18305429afa14ea462f810146ba44d4363ae76e4c8"\
                          "dfc38288cf73aa07485005"
                }
              }],
              package_manager: "kubernetes"
            )
          end

          subject(:updated_podfile) do
            updated_files.find { |f| f.name == "digest_and_tag.yaml" }
          end

          its(:content) do
            is_expected.to include "    image: ubuntu:17.10@sha256:3ea1ca1aa"
          end
        end
      end

      context "when the dependency has a private registry" do
        let(:podfile) do
          Dependabot::DependencyFile.new(
            content: podfile_body,
            name: "private_digest.yaml"
          )
        end
        let(:podfile_body) do
          fixture("kubernetes", "yaml", "private_digest.yaml")
        end
        let(:dependency) do
          Dependabot::Dependency.new(
            name: "myreg/ubuntu",
            version: "17.10",
            previous_version: "17.10",
            requirements: [{
              requirement: nil,
              groups: [],
              file: "private_digest.yaml",
              source: {
                registry: "registry-host.io:5000",
                digest: "sha256:3ea1ca1aa8483a38081750953ad75046e6cc9f6b86"\
                        "ca97eba880ebf600d68608"
              }
            }],
            previous_requirements: [{
              requirement: nil,
              groups: [],
              file: "private_digest.yaml",
              source: {
                registry: "registry-host.io:5000",
                digest: "sha256:18305429afa14ea462f810146ba44d4363ae76e4c8"\
                        "dfc38288cf73aa07485005"
              }
            }],
            package_manager: "kubernetes"
          )
        end

        its(:length) { is_expected.to eq(1) }

        describe "the updated podfile" do
          subject(:updated_podfile) do
            updated_files.find { |f| f.name == "private_digest.yaml" }
          end

          its(:content) do
            is_expected.to include("image: registry-host.io:5000/"\
                                   "myreg/ubuntu@sha256:3ea1ca1aa")
          end
          its(:content) { is_expected.to include "kind: Pod" }
        end
      end
    end

    context "when multiple yaml to be updated" do
      let(:files) { [podfile, podfile2] }
      let(:podfile2) do
        Dependabot::DependencyFile.new(
          name: "digest_and_tag.yaml",
          content: podfile_body2
        )
      end
      let(:podfile) do
        Dependabot::DependencyFile.new(
          content: podfile_body,
          name: "digest.yaml"
        )
      end
      let(:podfile_body) { fixture("kubernetes", "yaml", "digest.yaml") }
      let(:podfile_body2) do
        fixture("kubernetes", "yaml", "digest_and_tag.yaml")
      end
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "ubuntu",
          version: "17.10",
          previous_version: "12.04.5",
          requirements: [{
            requirement: nil,
            groups: [],
            file: "digest.yaml",
            source: {
              digest: "sha256:3ea1ca1aa8483a38081750953ad75046e6cc9f6b86"\
                      "ca97eba880ebf600d68608"
            }
          }, {
            requirement: nil,
            groups: [],
            file: "digest_and_tag.yaml",
            source: {
              digest: "sha256:3ea1ca1aa8483a38081750953ad75046e6cc9f6b86"\
                      "ca97eba880ebf600d68608",
              tag: "17.10"
            }
          }],
          previous_requirements: [{
            requirement: nil,
            groups: [],
            file: "digest.yaml",
            source: {
              digest: "sha256:18305429afa14ea462f810146ba44d4363ae76e4c8"\
                      "dfc38288cf73aa07485005"
            }
          }, {
            requirement: nil,
            groups: [],
            file: "digest_and_tag.yaml",
            source: {
              digest: "sha256:18305429afa14ea462f810146ba44d4363ae76e4c8"\
                      "dfc38288cf73aa07485005",
              tag: "12.04.5"
            }
          }],
          package_manager: "kubernetes"
        )
      end

      describe "the updated podfile" do
        subject { updated_files.find { |f| f.name == "digest.yaml" } }
        its(:content) { is_expected.to include "image: ubuntu@sha256:3ea1ca1aa" }
      end

      describe "the updated custom-name file" do
        subject { updated_files.find { |f| f.name == "digest_and_tag.yaml" } }

        its(:content) do
          is_expected.to include "image: ubuntu:17.10@sha256:3ea1ca1aa"
        end
      end

      context "when only one needs updating" do
        let(:podfile_body) { fixture("kubernetes", "yaml", "bare.yaml") }

        let(:dependency) do
          Dependabot::Dependency.new(
            name: "ubuntu",
            version: "17.10",
            previous_version: "12.04.5",
            requirements: [{
              requirement: nil,
              groups: [],
              file: "digest_and_tag.yaml",
              source: {
                tag: "17.10",
                digest: "sha256:3ea1ca1aa8483a38081750953ad75046e6cc9f6b86"\
                        "ca97eba880ebf600d68608"
              }
            }],
            previous_requirements: [{
              requirement: nil,
              groups: [],
              file: "digest_and_tag.yaml",
              source: {
                tag: "12.04.5",
                digest: "sha256:18305429afa14ea462f810146ba44d4363ae76e4c8"\
                        "dfc38288cf73aa07485005"
              }
            }],
            package_manager: "kubernetes"
          )
        end

        describe "the updated custom-name file" do
          subject { updated_files.find { |f| f.name == "digest_and_tag.yaml" } }

          its(:content) do
            is_expected.to include "image: ubuntu:17.10@sha256:3ea1ca1aa"
          end
        end
      end
    end
  end
end
