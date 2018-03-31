//
//  SourceKit.h
//  SearchLight
//
//  Created by John Holdsworth on 06/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SourceKit : NSObject

+ (instancetype)shared;
- (NSString *)formatFile:(NSString *)path;

@end
