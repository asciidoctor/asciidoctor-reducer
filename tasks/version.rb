# frozen_string_literal: true

require 'time'

release_version = ENV['RELEASE_VERSION']
release_date = Time.now.strftime '%Y-%m-%d'
release_user = ENV['RELEASE_USER']

version_file = Dir['lib/**/version.rb'].first
version_contents = (File.readlines version_file, mode: 'r:UTF-8').map do |l|
  (l.include? 'VERSION') ? (l.sub %r/'[^']+'/, %('#{release_version}')) : l
end
File.write version_file, version_contents.join, mode: 'w:UTF-8'

readme_file = 'README.adoc'
readme_contents = (File.readlines readme_file, mode: 'r:UTF-8').insert 2, %(v#{release_version}, #{release_date}\n)
File.write readme_file, readme_contents.join, mode: 'w:UTF-8'

changelog_file = 'CHANGELOG.adoc'
changelog_contents = File.readlines changelog_file, mode: 'r:UTF-8'
last_release_idx = changelog_contents.index {|l| (l.start_with? '== ') && (%r/^== \d/.match? l) }
if last_release_idx
  previous_release_version = (changelog_contents[last_release_idx].match %r/\d\S+/)[0]
else
  lasat_release_idx = changelog_contents.length
end
unreleased_idx = changelog_contents.index {|l| (l.start_with? '== Unreleased') && l.rstrip == '== Unreleased' }
changelog_contents[unreleased_idx] = %(== #{release_version} (#{release_date}) - @#{release_user}\n)
changelog_contents.insert last_release_idx, <<~END
=== Details

{url-repo}/releases/tag/v#{release_version}[git tag]#{previous_release_version ? %( | {url-repo}/compare/v#{previous_release_version}\\...v#{release_version}[full diff]) : ''}

END
File.write changelog_file, changelog_contents.join, mode: 'w:UTF-8'
