# Adds the ShareExtension target to Runner.xcodeproj. Idempotent.
# Run from apps/mobile/ios: ruby tool/add_share_extension.rb
require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
exit 0 if project.targets.any? { |t| t.name == 'ShareExtension' }

runner = project.targets.find { |t| t.name == 'Runner' }
ext = project.new_target(:app_extension, 'ShareExtension', :ios, '15.0')

group = project.main_group.new_group('ShareExtension', 'ShareExtension')
ext.add_file_references([group.new_file('ShareViewController.swift')])
group.new_file('Info.plist')
group.new_file('ShareExtension.entitlements')

inbox = project.main_group['Runner'].new_file('ShareInbox.swift')
runner.add_file_references([inbox])
ext.add_file_references([inbox])

ext.build_configurations.each do |config|
  s = config.build_settings
  s['INFOPLIST_FILE'] = 'ShareExtension/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'ShareExtension/ShareExtension.entitlements'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.nkshub.nextcloudnotes.ShareExtension'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  # Flutter's generated build name/number, as in Runner.
  base = runner.build_configurations.find { |c| c.name == config.name }
  config.base_configuration_reference = base.base_configuration_reference
end

runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference, true)
  .settings = { 'ATTRIBUTES' => ['RemoveHeaderOnCopy'] }
# Flutter's "Thin Binary" script must run after embedding, or Xcode reports a
# dependency cycle.
phases = runner.build_phases
phases.move(embed, phases.index { |p| p.display_name == 'Thin Binary' } || phases.count - 1)

project.save
puts 'ShareExtension added'
