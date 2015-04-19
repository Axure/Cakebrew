//
//  BPHomebrewInterfaceListCall.m
//  Cakebrew
//
//  Created by Bruno Philipe on 4/19/15.
//  Copyright (c) 2015 Bruno Philipe. All rights reserved.
//

#import "BPHomebrewFormulaeListCall.h"

@implementation BPHomebrewFormulaeListCall

- (instancetype)initWithArguments:(NSArray *)arguments
{
	self = [super init];
	if (self) {
		_arguments = arguments;
	}
	return self;
}

- (NSArray *)parseData:(NSString *)data
{
	NSMutableArray *array = [[data componentsSeparatedByString:@"\n"] mutableCopy];
	[array removeLastObject];
	
	NSMutableArray *formulae = [NSMutableArray arrayWithCapacity:array.count];
	
	for (NSString *item in array) {
		BPFormula *formula = [self parseFormulaItem:item];
		if (formula) {
			[formulae addObject:formula];
		}
	}
	return formulae;
}

- (BPFormula *)parseFormulaItem:(NSString *)item
{
	return [BPFormula formulaWithName:item];
}

@end

@implementation BPHomebrewFormulaeListCallInstalled

- (instancetype)init
{
	return (BPHomebrewFormulaeListCallInstalled *)[super initWithArguments:@[@"list", @"--versions"]];
}

- (BPFormula *)parseFormulaItem:(NSString *)item
{
	NSArray *aux = [item componentsSeparatedByString:@" "];
	return [BPFormula formulaWithName:[aux firstObject] andVersion:[aux lastObject]];
}

@end

@implementation BPHomebrewFormulaeListCallAll

- (instancetype)init
{
	return (BPHomebrewFormulaeListCallAll *)[super initWithArguments:@[@"search"]];
}

@end

@implementation BPHomebrewFormulaeListCallLeaves

- (instancetype)init
{
	return (BPHomebrewFormulaeListCallLeaves *)[super initWithArguments:@[@"leaves"]];
}

@end

@implementation BPHomebrewFormulaeListCallOutdated

- (instancetype)init
{
	return (BPHomebrewFormulaeListCallOutdated *)[super initWithArguments:@[@"outdated", @"--verbose"]];
}

- (BPFormula *)parseFormulaItem:(NSString *)item
{
	static NSString *regexString = @"(\\S+)\\s\\((.*)\\)";
	
	BPFormula __block *formula = nil;
	NSError *error = nil;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString options:NSRegularExpressionCaseInsensitive error:&error];
	
	[regex enumerateMatchesInString:item options:0 range:NSMakeRange(0, [item length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
		if (result.resultType == NSTextCheckingTypeRegularExpression)
		{
			NSRange lastRange = [result rangeAtIndex:[result numberOfRanges]-1];
			NSArray *versionsTuple = [[[[item substringWithRange:lastRange] componentsSeparatedByString:@","] lastObject] componentsSeparatedByString:@"<"];
			formula = [BPFormula formulaWithName:[item substringWithRange:[result rangeAtIndex:1]]
										 version:[[versionsTuple firstObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
								andLatestVersion:[[versionsTuple lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		}
	}];
	
	if (!formula) {
		formula = [BPFormula formulaWithName:item];
	}
	
	return formula;
}

@end

@implementation BPHomebrewFormulaeListCallSearch

- (instancetype)initWithSearchParameter:(NSString*)param
{
	return (BPHomebrewFormulaeListCallSearch *)[super initWithArguments:@[@"search", param]];
}

@end

@implementation BPHomebrewFormulaeListCallRepositories

- (instancetype)init
{
	return (BPHomebrewFormulaeListCallRepositories *)[super initWithArguments:@[@"tap"]];
}

@end
