#import "RapidoReachPlugin.h"
#if __has_include(<rapidoreach/rapidoreach-Swift.h>)
#import <rapidoreach/rapidoreach-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "rapidoreach-Swift.h"
#endif

@implementation RapidoReachPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRapidoReachPlugin registerWithRegistrar:registrar];
}
@end
