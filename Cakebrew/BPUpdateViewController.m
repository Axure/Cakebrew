//
//  BPUpdateViewController.m
//  Cakebrew
//
//  Created by Marek Hrusovsky on 21/08/14.
//	Copyright (c) 2014 Bruno Philipe. All rights reserved.
//
//	This program is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	This program is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with this program.	If not, see <http://www.gnu.org/licenses/>.
//

#import "BPUpdateViewController.h"
#import "BPHomebrewInterface.h"
#import "NSFont+Appearance.h"

@interface BPUpdateViewController ()

@property (unsafe_unretained, nonatomic) IBOutlet NSTextView *updateTextView;
@property (unsafe_unretained, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign) BOOL isPerformingUpdate;

@end

@implementation BPUpdateViewController

- (void)awakeFromNib {
	NSFont *font = [NSFont bp_defaultFixedWidthFont];
	[self.updateTextView setFont:font];
	self.isPerformingUpdate = NO;
}

- (NSString *)nibName {
	return @"BPUpdateView";
}

- (IBAction)runStopUpdate:(id)sender {
	BPAppDelegate *appDelegate = BPAppDelegateRef;
	
	NSLog(@"Starting Update Process...");
	
	if (appDelegate.isRunningBackgroundTask)
	{
		[appDelegate displayBackgroundWarning];
		return;
	}
	[appDelegate setRunningBackgroundTask:YES];
	
	[self.updateTextView setString:@""];
	self.isPerformingUpdate = YES;
	[self.progressIndicator startAnimation:sender];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NSLog(@"Updating...");
		[[BPHomebrewInterface sharedInterface] updateWithReturnBlock:^(NSString *output) {
			NSLog(@"Got feedback from shell!");
			[self.updateTextView performSelectorOnMainThread:@selector(setString:)
												  withObject:[self.updateTextView.string stringByAppendingString:output]
											   waitUntilDone:YES];
		}];
		NSLog(@"Setting up finalization task callback...");
		dispatch_async(dispatch_get_main_queue(), ^{
			NSLog(@"Finalization callback called!");
			[self.progressIndicator stopAnimation:sender];
			self.isPerformingUpdate = NO;
			[appDelegate setRunningBackgroundTask:NO];
			NSLog(@"Update Process Finished!");
		});
	});
}

- (IBAction)clearLogUpdate:(id)sender {
	self.updateTextView.string = @"";
}

@end
