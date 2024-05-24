task :version do
  version_file = 'lib/gq/version.rb'

  # Read the version file
  content = File.read(version_file)

  # Extract the version string
  version = content.match(/VERSION = "(\d+\.\d+\.\d+)"/)[1]

  # Display the version
  puts version
end

namespace :version do
  desc "Increments the build number in version.rb"
  task :bump do
    version_file = 'lib/gq/version.rb'

    # Read the version file
    content = File.read(version_file)

    # Extract the version string
    version = content.match(/VERSION = "(\d+\.\d+\.\d+)"/)[1]

    # Split the version into major, minor, and build parts
    major, minor, build = version.split('.').map(&:to_i)

    # Increment the build number
    build += 1

    # Generate the new version string
    new_version = "#{major}.#{minor}.#{build}"

    # Replace the old version with the new version in the file content
    new_content = content.sub(/VERSION = "\d+\.\d+\.\d+"/, "VERSION = \"#{new_version}\"")

    # Write the new content back to the version file
    File.open(version_file, 'w') { |file| file.write(new_content) }

    puts "Version bumped to #{new_version}"
  end
end
