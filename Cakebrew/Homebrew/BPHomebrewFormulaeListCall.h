//
//  BPHomebrewInterfaceListCall.h
//  Cakebrew
//
//  Created by Bruno Philipe on 4/19/15.
//  Copyright (c) 2015 Bruno Philipe. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BPFormula.h"

@interface BPHomebrewFormulaeListCall : NSObject

@property (strong, readonly) NSArray *arguments;

- (instancetype)initWithArguments:(NSArray *)arguments;
- (NSArray *)parseData:(NSString *)data;
- (BPFormula *)parseFormulaItem:(NSString *)item;

@end

@interface BPHomebrewFormulaeListCallInstalled : BPHomebrewFormulaeListCall
@end

@interface BPHomebrewFormulaeListCallAll : BPHomebrewFormulaeListCall
@end

@interface BPHomebrewFormulaeListCallLeaves : BPHomebrewFormulaeListCall
@end

@interface BPHomebrewFormulaeListCallOutdated : BPHomebrewFormulaeListCall
@end

@interface BPHomebrewFormulaeListCallSearch : BPHomebrewFormulaeListCall
@end

@interface BPHomebrewFormulaeListCallRepositories: BPHomebrewFormulaeListCall
@end
