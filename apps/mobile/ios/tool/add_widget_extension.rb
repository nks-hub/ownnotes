# Adds the OwnNotesWidgets WidgetKit extension to Runner.xcodeproj and the
# `de` region. Idempotent.
# Run from apps/mobile/ios: ruby tool/add_widget_extension.rb
require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
project.root_object.known_regions |= ['de']

# German Runner InfoPlist.strings, when another change has created the file.
runner_group = project.main_group['Runner']
info_strings = runner_group.children.find { |c| c.display_name == 'InfoPlist.strings' }
if info_strings && File.exist?('Runner/de.lproj/InfoPlist.strings') &&
   info_strings.children.none? { |c| c.display_name == 'de' }
  info_strings.new_reference('de.lproj/InfoPlist.strings').name = 'de'
end

if project.targets.any? { |t| t.name == 'OwnNotesWidgets' }
  project.save
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
ext = project.new_target(:app_extension, 'OwnNotesWidgets', :ios, '15.0')

group = project.main_group.new_group('OwnNotesWidgets', 'OwnNotesWidgets')
swift = %w[OwnNotesWidgets.swift OwnWidgetView.swift Snapshot.swift].map { |f| group.new_file(f) }
ext.add_file_references(swift)
group.new_file('Info.plist')
group.new_file('OwnNotesWidgets.entitlements')

strings = group.new_variant_group('Localizable.strings')
%w[en cs de].each { |l| strings.new_reference("#{l}.lproj/Localizable.strings").name = l }
ext.resources_build_phase.add_file_reference(strings)

ext.build_configurations.each do |config|
  s = config.build_settings
  s['INFOPLIST_FILE'] = 'OwnNotesWidgets/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'OwnNotesWidgets/OwnNotesWidgets.entitlements'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.nkshub.nextcloudnotes.Widgets'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['DEVELOPMENT_TEAM'] = ENV.fetch('DEVELOPMENT_TEAM', '')
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  # Flutter's generated build name/number, as in Runner.
  base = runner.build_configurations.find { |c| c.name == config.name }
  config.base_configuration_reference = base.base_configuration_reference
end

runner.add_dependency(ext)
embed = runner.copy_files_build_phases.find { |p| p.display_name == 'Embed Foundation Extensions' }
embed.add_file_reference(ext.product_reference, true)
     .settings = { 'ATTRIBUTES' => ['RemoveHeaderOnCopy'] }

project.save
puts 'OwnNotesWidgets added'
