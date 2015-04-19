//
//	BrewInterface.m
//	Cakebrew – The Homebrew GUI App for OS X
//
//	Created by Vincent Saluzzo on 06/12/11.
//	Copyright (c) 2014 Bruno Philipe. All rights reserved.
//
//	This program is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	This program is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "BPHomebrewInterface.h"
#import "BPHomebrewFormulaeListCall.h"

static NSString *cakebrewOutputIdentifier = @"+++++Cakebrew+++++";

@interface BPHomebrewInterface ()

@property BOOL systemHasAppNap;
@property (getter=isCaskroomInstalled) BOOL caskroomInstalled;

@property (strong) NSString *path_cellar;
@property (strong) NSString *path_shell;

@end

@implementation BPHomebrewInterface
{
	void (^operationUpdateBlock)(NSString*);
}

+ (BPHomebrewInterface *)sharedInterface
{
	@synchronized(self)
	{
		static dispatch_once_t once;
		static BPHomebrewInterface *instance;
		dispatch_once(&once, ^ { instance = [[BPHomebrewInterface alloc] init]; });
		return instance;
	}
}

- (id)init
{
	self = [super init];
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatedFileHandle:) name:NSFileHandleDataAvailableNotification object:nil];
		[self setTask:nil];
		[self setSystemHasAppNap:[[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:reason:)]];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)checkForHomebrew
{
	if (!self.path_shell) return NO;
	
	self.task = [[NSTask alloc] init];
	[self.task setLaunchPath:self.path_shell];
	[self.task setArguments:@[@"-l", @"-c", @"which brew"]];
	
	NSPipe *pipe_output = [NSPipe pipe];
	NSPipe *pipe_error = [NSPipe pipe];
	[self.task setStandardOutput:pipe_output];
	[self.task setStandardInput:[NSPipe pipe]];
	[self.task setStandardError:pipe_error];
	
	[self.task launch];
	[self.task waitUntilExit];
	
	NSString *string_output;
	string_output = [[NSString alloc] initWithData:[[pipe_output fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	string_output = [self removeLoginShellOutputFromString:string_output];
	
	NSLog(@"`which brew` returned \"%@\"", string_output);
	
	[self checkForCaskroom];
	
	return string_output.length != 0;
}

- (void)setDelegate:(id<BPHomebrewInterfaceDelegate>)delegate
{
	if (_delegate != delegate) {
		_delegate = delegate;
		
		[self setPath_shell:[self getValidUserShellPath]];
		
		if (![self checkForHomebrew])
			[self showHomebrewNotInstalledMessage];
		else
		{
			[self setPath_cellar:[self getUserCellarPath]];
			
			NSLog(@"Cellar Path: %@", self.path_cellar);
		}
	}
}

#pragma mark - Private Methods

- (NSString *)getValidUserShellPath
{
	NSString *userShell = [[[NSProcessInfo processInfo] environment] objectForKey:@"SHELL"];
	
	// avoid executing stuff like /sbin/nologin as a shell
	BOOL isValidShell = NO;
	for (NSString *validShell in [[NSString stringWithContentsOfFile:@"/etc/shells" encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		if ([[validShell stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:userShell]) {
			isValidShell = YES;
			break;
		}
	}
	
	if (!isValidShell)
	{
		static NSAlert *alert = nil;
		if (!alert)
			alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Message_Shell_Invalid_Title", nil)
									defaultButton:NSLocalizedString(@"Generic_OK", nil)
								  alternateButton:nil
									  otherButton:nil
						informativeTextWithFormat:NSLocalizedString(@"Message_Shell_Invalid_Body", nil), userShell];
		[alert performSelectorOnMainThread:@selector(runModal) withObject:nil waitUntilDone:YES];
		
		NSLog(@"No valid shell found...");
		return nil;
	}
	
	return userShell;
}

- (NSString *)getUserCellarPath
{
	NSString __block *path = [[NSUserDefaults standardUserDefaults] objectForKey:@"BPBrewCellarPath"];
	
	if (!path) {
		NSString *brew_config = [self performBrewCommandWithArguments:@[@"config"]];
		
		[brew_config enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
			if ([line hasPrefix:@"HOMEBREW_CELLAR"]) {
				path = [line substringFromIndex:17];
			}
		}];
		
		[[NSUserDefaults standardUserDefaults] setObject:path forKey:@"BPBrewCellarPath"];
	}
	
	return path;
}

- (NSArray *)formatArguments:(NSArray *)extraArguments sendOutputId:(BOOL)sendOutputID
{
	NSString *command = nil;
	if (sendOutputID) {
		command = [NSString stringWithFormat:@"echo \"%@\";brew %@", cakebrewOutputIdentifier, [extraArguments componentsJoinedByString:@" "]];
	} else {
		command = [NSString stringWithFormat:@"brew %@", [extraArguments componentsJoinedByString:@" "]];
	}
	NSArray *arguments = @[@"-l", @"-c", command];
	
	return arguments;
}

- (void)showHomebrewNotInstalledMessage
{
	static BOOL isShowing = NO;
	if (!isShowing) {
		isShowing = YES;
		if (self.delegate) {
			id delegate = self.delegate;
			dispatch_async(dispatch_get_main_queue(), ^{
				[delegate homebrewInterfaceShouldDisplayNoBrewMessage:YES];
			});
		}
	}
}

- (BOOL)performBrewCommandWithArguments:(NSArray*)arguments dataReturnBlock:(void (^)(NSString*))block
{
	NSString *taskDoneString = NSLocalizedString(@"Homebrew_Task_Finished", nil);
	
	arguments = [self formatArguments:arguments sendOutputId:NO];
	
	if (!self.path_shell || !arguments) return NO;
	
	operationUpdateBlock = block;
	
	id activity;
	if (self.systemHasAppNap)
		activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated reason:NSLocalizedString(@"Homebrew_AppNap_Task_Reason", nil)];
	
	self.task = [[NSTask alloc] init];
	
	[self.task setLaunchPath:self.path_shell];
	[self.task setArguments:arguments];
	
	NSPipe *pipe_output = [NSPipe pipe];
	NSPipe *pipe_error = [NSPipe pipe];
	[self.task setStandardOutput:pipe_output];
	[self.task setStandardInput:[NSPipe pipe]];
	[self.task setStandardError:pipe_error];
	
	NSFileHandle *handle_output = [pipe_output fileHandleForReading];
	[handle_output waitForDataInBackgroundAndNotify];
	
	NSFileHandle *handle_error = [pipe_error fileHandleForReading];
	[handle_error waitForDataInBackgroundAndNotify];
	
#ifdef DEBUG
	block([NSString stringWithFormat:@"User Shell: %@\nCommand: %@\nThe outputs are going to be different if run from Xcode!!\nInstalling and upgrading formulas is not advised in DEBUG mode!\n\n", self.path_shell, [arguments componentsJoinedByString:@" "]]);
#endif
	
	[self.task launch];
	[self.task waitUntilExit];
	
	block([NSString stringWithFormat:taskDoneString, [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle]]);
	
	if (self.systemHasAppNap)
		[[NSProcessInfo processInfo] endActivity:activity];
	
	return YES;
}

- (void)updatedFileHandle:(NSNotification*)n
{
	NSFileHandle *fh = [n object];
	NSData *data = [fh availableData];
	[fh waitForDataInBackgroundAndNotify];
	if (data && data.length > 0) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			operationUpdateBlock([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
		});
	}
}

- (NSString*)performBrewCommandWithArguments:(NSArray*)arguments
{
	return [self performBrewCommandWithArguments:arguments captureError:NO];
}

- (NSString*)performBrewCommandWithArguments:(NSArray*)arguments captureError:(BOOL)captureError
{
	arguments = [self formatArguments:arguments sendOutputId:YES];
	
	if (!self.path_shell || !arguments) return nil;
	
	id activity;
	if (self.systemHasAppNap)
		activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated reason:NSLocalizedString(@"Homebrew_AppNap_Task_Reason", nil)];
	
	self.task = [[NSTask alloc] init];
	
	[self.task setLaunchPath:self.path_shell];
	[self.task setArguments:arguments];
	
	NSPipe *pipe_output = [NSPipe pipe];
	NSPipe *pipe_error = [NSPipe pipe];
	[self.task setStandardOutput:pipe_output];
	[self.task setStandardInput:[NSPipe pipe]];
	[self.task setStandardError:pipe_error];
	
	[self.task launch];
	[self.task waitUntilExit];
	
	NSString *string_output, *string_error;
	string_output = [[NSString alloc] initWithData:[[pipe_output fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	string_error = [[NSString alloc] initWithData:[[pipe_error fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	
	string_output = [self removeLoginShellOutputFromString:string_output];
	
	if (self.systemHasAppNap)
		[[NSProcessInfo processInfo] endActivity:activity];
	
	if (!captureError) {
		return string_output;
	} else {
		string_error = [self removeLoginShellOutputFromString:string_error];
		return [NSString stringWithFormat:@"%@\n%@", string_output, string_error];
	}
}

#pragma mark - Operations that return on finish

- (NSArray*)listFormulaeMode:(BPListMode)mode
{
	BPHomebrewFormulaeListCall *listCall = nil;
	
	switch (mode) {
		case kBPListInstalled:
			listCall = [[BPHomebrewFormulaeListCallInstalled alloc] init];
			break;
			
		case kBPListAll:
			listCall = [[BPHomebrewFormulaeListCallAll alloc] init];
			break;
			
		case kBPListLeaves:
			listCall = [[BPHomebrewFormulaeListCallLeaves alloc] init];
			break;
			
		case kBPListOutdated:
			listCall = [[BPHomebrewFormulaeListCallOutdated alloc] init];
			break;
			
		case kBPListRepositories:
			listCall = [[BPHomebrewFormulaeListCallRepositories alloc] init];
			break;
			
		default:
			return nil;
	}
	
	NSString *string = [self performBrewCommandWithArguments:listCall.arguments];
	
	if (string) {
		return [listCall parseData:string];
	} else {
		return nil;
	}
}

- (NSArray*)listCasksMode:(BPListMode)mode
{
	
}

- (NSString*)informationForFormula:(NSString*)formula
{
	return [self performBrewCommandWithArguments:@[@"info", formula]];
}

- (void)checkForCaskroom
{
	NSString *result = [[self performBrewCommandWithArguments:@[@"cask"] captureError:YES] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[self setCaskroomInstalled:[result hasPrefix:@"brew-cask"]];
	
	NSLog(@"Caskroom was %@ on this system!", self.isCaskroomInstalled ? @"detected" : @"NOT DETECTED");
	
	if ([self.delegate respondsToSelector:@selector(homebrewInterfaceDidUpdateCaskroomStatus)])
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate homebrewInterfaceDidUpdateCaskroomStatus];
		});
	}
}

- (NSString*)removeLoginShellOutputFromString:(NSString*)string {
	if (string) {
		NSRange range = [string rangeOfString:cakebrewOutputIdentifier];
		if (range.location != NSNotFound) {
			return [string substringFromIndex:range.location + range.length+1];
		} else {
			return string;
		}
	}
	//If all else fails...
	return nil;
}

#pragma mark - Operations with live data callback block

- (BOOL)updateWithReturnBlock:(void (^)(NSString*output))block
{
	BOOL val = [self performBrewCommandWithArguments:@[@"update"] dataReturnBlock:block];
	[self sendDelegateFormulaeUpdatedCall];
	return val;
}

- (BOOL)upgradeFormulae:(NSArray*)formulae withReturnBlock:(void (^)(NSString*output))block
{
	BOOL val = [self performBrewCommandWithArguments:[@[@"upgrade"] arrayByAddingObjectsFromArray:formulae] dataReturnBlock:block];
	[self sendDelegateFormulaeUpdatedCall];
	return val;
}

- (BOOL)installFormula:(NSString*)formula withOptions:(NSArray*)options andReturnBlock:(void (^)(NSString*output))block
{
	NSArray *params = @[@"install", formula];
	if (options) {
		params = [params arrayByAddingObjectsFromArray:options];
	}
	BOOL val = [self performBrewCommandWithArguments:params dataReturnBlock:block];
	[self sendDelegateFormulaeUpdatedCall];
	return val;
}

- (BOOL)uninstallFormula:(NSString*)formula withReturnBlock:(void (^)(NSString*output))block
{
	BOOL val = [self performBrewCommandWithArguments:@[@"uninstall", formula] dataReturnBlock:block];
	[self sendDelegateFormulaeUpdatedCall];
	return val;
}

- (BOOL)tapRepository:(NSString *)repository withReturnsBlock:(void (^)(NSString *))block
{
	BOOL val = [self performBrewCommandWithArguments:@[@"tap", repository] dataReturnBlock:block];
	[self sendDelegateFormulaeUpdatedCall];
	return val;
}

- (BOOL)untapRepository:(NSString *)repository withReturnsBlock:(void (^)(NSString *))block
{
	BOOL val = [self performBrewCommandWithArguments:@[@"untap", repository] dataReturnBlock:block];
	[self sendDelegateFormulaeUpdatedCall];
	return val;
}

- (BOOL)runDoctorWithReturnBlock:(void (^)(NSString*output))block
{
	BOOL val = [self performBrewCommandWithArguments:@[@"doctor"] dataReturnBlock:block];
	[self sendDelegateFormulaeUpdatedCall];
	return val;
}

- (void)sendDelegateFormulaeUpdatedCall
{
	if (self.delegate) {
		id delegate = self.delegate;
		dispatch_async(dispatch_get_main_queue(), ^{
			[delegate homebrewInterfaceDidUpdateFormulae];
		});
	}
}

@end
