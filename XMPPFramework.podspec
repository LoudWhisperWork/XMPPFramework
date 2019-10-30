Pod::Spec.new do |s|
  s.name = 'XMPPFramework'
  s.version = '4.0.0'

  s.ios.deployment_target = '10.0'

  s.license = { :type => 'BSD', :file => 'copying.txt' }
  s.summary = 'An XMPP Framework.'
  s.homepage = 'https://github.com/robbiehanson/XMPPFramework'
  s.author = { 'Robbie Hanson' => 'robbiehanson@deusty.com' }
  s.source = { :git => 'https://github.com/robbiehanson/XMPPFramework.git', :tag => s.version }
  # s.source = { :git => 'https://github.com/robbiehanson/XMPPFramework.git', :branch => 'master' }

  s.description = 'XMPPFramework'

  s.requires_arc = true

  s.default_subspec = 'default'

  s.subspec 'default' do |ss|
	  ss.source_files = ['Core/**/*.{h,m}',
	                    'Authentication/**/*.{h,m}', 'Categories/**/*.{h,m}',
	                    'Utilities/**/*.{h,m}', 'Extensions/**/*.{h,m}']
	  ss.ios.exclude_files = 'Extensions/SystemInputActivityMonitor/**/*.{h,m}'
	  ss.libraries = 'xml2', 'resolv'
	  ss.frameworks = 'CoreData', 'SystemConfiguration', 'CoreLocation'
	  ss.xcconfig = {
	    'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2 $(SDKROOT)/usr/include/libresolv',
	  }
    ss.resources = [ 'Extensions/**/*.{xcdatamodel,xcdatamodeld}']
	  ss.dependency 'CocoaLumberjack' # Skip pinning version because of the awkward 2.x->3.x transition
	  ss.dependency 'CocoaAsyncSocket'
	  ss.dependency 'KissXML'
	  ss.dependency 'libidn'
  end
end
