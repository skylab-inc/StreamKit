#
# Be sure to run `pod lib lint Reflex.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Reflex'
  s.version          = '0.1.0'
  s.summary          = 'Reflex is a very small and compact Functional Reactive Programming library which is used to implement the Edge event system.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
It is inspired by ReactiveCocoa, but the API has been greatly reduced in scope and simplified. The Reflex API is designed so that it can also be used as a simple callback system, much like Node.js Events. No functional programming necessary.
                       DESC

  s.homepage         = 'https://github.com/SwiftOnEdge/Reflex'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'SwiftOnEdge' => 'https://github.com/SwiftOnEdge' }
  s.source           = { :git => 'https://github.com/SwiftOnEdge/Reflex.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'Sources/**/*'
  
  # s.resource_bundles = {
  #   'Reflex' => ['Reflex/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
