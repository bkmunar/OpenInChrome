#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Copyright 2012-2014, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import <UIKit/UIKit.h>

#import "OpenInChromeController.h"

static NSString * const kGoogleChromeHTTPScheme = @"googlechrome:";
static NSString * const kGoogleChromeHTTPSScheme = @"googlechromes:";
static NSString * const kGoogleChromeCallbackScheme = @"googlechrome-x-callback:";
static NSString * const firefoxScheme = @"firefox:";
static NSString * const firefoxCallbackScheme = @"firefox-x-callback:"

static NSString *encodeByAddingPercentEscapes(NSString *input) {
  NSString *encodedValue = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
      kCFAllocatorDefault,
      (CFStringRef)input,
      NULL,
      (CFStringRef)@"!*'();:@&=+$,/?%#[]",
      kCFStringEncodingUTF8));
  return encodedValue;
}

@implementation OpenInChromeController

+ (OpenInChromeController *)sharedInstance {
  static OpenInChromeController *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (BOOL)isChromeInstalled {
  NSURL *simpleURL = [NSURL URLWithString:kGoogleChromeHTTPScheme];
  NSURL *callbackURL = [NSURL URLWithString:kGoogleChromeCallbackScheme];
  return  [[UIApplication sharedApplication] canOpenURL:simpleURL] ||
      [[UIApplication sharedApplication] canOpenURL:callbackURL];
}

- (BOOL)isFirefoxInstalled {
  NSURL *simpleURL = [NSURL URLWithString:firefoxScheme];
  NSURL *callbackURL = [NSURL URLWithString:firefoxCallbackScheme];
  return  [[UIApplication sharedApplication] canOpenURL:simpleURL] ||
      [[UIApplication sharedApplication] canOpenURL:callbackURL];
}

- (BOOL)openInChrome:(NSURL *)url {
  return [self openURL:url simple:kGoogleChromeHTTPScheme callback:kGoogleChromeCallbackScheme withCallbackURL:nil createNewTab:NO];
}

- (BOOL)openInFirefox:(NSURL *)url {
  return [self openURL:url simple:firefoxScheme callback:firefoxCallbackScheme withCallbackURL:nil createNewTab:NO];
}

- (BOOL)openURL:(NSURL *)url
     simple:(NSString *)simpleScheme
     callback:(NSString *)callbackScheme
     withCallbackURL:(NSURL *)callbackURL
     createNewTab:(BOOL)createNewTab {
  NSURL *simpleURL = [NSURL URLWithString:simpleScheme];
  NSURL *callbackURL = [NSURL URLWithString:callbackScheme];
  if ([[UIApplication sharedApplication] canOpenURL:callbackURL]) {
    NSString *appName =
        [[NSBundle mainBundle]
            objectForInfoDictionaryKey:@"CFBundleDisplayName"];

    NSString *scheme = [url.scheme lowercaseString];

    // Proceed only if scheme is http or https.
    if ([scheme isEqualToString:@"http"] ||
        [scheme isEqualToString:@"https"]) {

      NSMutableString *urlString = [NSMutableString string];
      [urlString appendFormat:
          @"%@//x-callback-url/open/?x-source=%@&url=%@",
          callbackScheme,
          encodeByAddingPercentEscapes(appName),
          encodeByAddingPercentEscapes([url absoluteString])];
      if (callbackURL) {
        [urlString appendFormat:@"&x-success=%@",
            encodeByAddingPercentEscapes([callbackURL absoluteString])];
      }
      if (createNewTab) {
        [urlString appendString:@"&create-new-tab"];
      }

      NSURL *url = [NSURL URLWithString:urlString];

      // Open the URL with callback.
      return [[UIApplication sharedApplication] openURL:url];
    }
  } else if ([[UIApplication sharedApplication] canOpenURL:simpleURL]) {
    NSString *scheme = [url.scheme lowercaseString];

    // Replace the URL Scheme with the Browser equivalent.
    NSString *browserScheme = nil;
    if ([scheme isEqualToString:@"http"]) {
      if ([simpleScheme isEqualToString:kGoogleChromeHTTPScheme]) {
        browserScheme = kGoogleChromeHTTPScheme;
      } else {
        browserScheme = firefoxScheme;
      }
    } else if ([scheme isEqualToString:@"https"]) {
      if ([callbackScheme isEqualToString:kGoogleChromeCallbackScheme]) {
        browserScheme = kGoogleChromeHTTPSScheme;
      } else {
        browserScheme = firefoxCallbackScheme;
      }
    }

    // Proceed only if a valid URI Scheme is available.
    if (browserScheme) {
      NSString *absoluteString = [url absoluteString];
      NSRange rangeForScheme = [absoluteString rangeOfString:@":"];
      NSString *urlNoScheme =
          [absoluteString substringFromIndex:rangeForScheme.location + 1];
      NSString *urlString =
          [browserScheme stringByAppendingString:urlNoScheme];
      NSURL *url = [NSURL URLWithString:urlString];

      // Open the URL 
      return [[UIApplication sharedApplication] openURL:url];
    }
  }
  return NO;
}

@end
