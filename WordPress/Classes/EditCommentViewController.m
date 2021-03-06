//
//  EditCommentViewController.m
//  WordPress
//
//  Created by John Bickerstaff on 1/24/10.
//  
//

#import "EditCommentViewController.h"
#import "CommentViewController.h"
#import "IOS7CorrectedTextView.h"

@interface EditCommentViewController() {
    CGRect _keyboardFrame;
}

@end

@implementation EditCommentViewController

@synthesize commentViewController, comment, hasChanges, textViewText, textView, isTransitioning, isEditing;

- (void)dealloc {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil)
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(cancelView:)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"Save button label (saving content, ex: Post, Page, Comment).")
                                                                              style:[WPStyleGuide barButtonStyleForDone]
                                                                             target:self
                                                                             action:@selector(initiateSaveCommentReply:)];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleKeyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleKeyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    self.hasChanges = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    WPFLogMethod();
	[super viewWillAppear:animated];
	
	self.textView.text = self.comment.content;
    
	//foo = textView.text;
    //so we can compare to set hasChanges correctly
	self.textViewText = [[NSString alloc] initWithString:self.textView.text];
	[self.textView becomeFirstResponder];

	self.isEditing = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    WPFLogMethod();
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

#pragma mark -
#pragma mark KeyboardNotification Methods

- (void)handleKeyboardDidShow:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    _keyboardFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _keyboardFrame = [self.view convertRect:_keyboardFrame fromView:self.view.window];
    float animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    [UIView animateWithDuration:animationDuration animations:^{
        CGRect frm = self.textView.frame;
        frm.size.height = CGRectGetMinY(_keyboardFrame);
        self.textView.frame = frm;
    }];
}

- (void)handleKeyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    float animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    [UIView animateWithDuration:animationDuration animations:^{
        CGRect frm = self.textView.frame;
        frm.size.height = CGRectGetMaxY(self.view.bounds);
        self.textView.frame = frm;
    }];
}

#pragma mark -
#pragma mark Helper Methods

- (void)endTextEnteringButtonAction:(id)sender {
    [textView resignFirstResponder];
	if (IS_IPAD == NO) {
		UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
		if(UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
			self.isTransitioning = YES;
			UIViewController *garbageController = [[UIViewController alloc] init]; 
			[self.navigationController pushViewController:garbageController animated:NO];
			[self.navigationController popViewControllerAnimated:NO];
			self.isTransitioning = NO;
			[textView resignFirstResponder];
		}
	}
	self.isEditing = NO;
}

#pragma mark -
#pragma mark Text View Delegate Methods

- (void)textViewDidBeginEditing:(UITextView *)aTextView {
	if (IS_IPAD == NO) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"")
                                                                                 style:[WPStyleGuide barButtonStyleForDone]
                                                                                target:self
                                                                                action:@selector(endTextEnteringButtonAction:)];
	}
	self.isEditing = YES;
}

- (void)textViewDidEndEditing:(UITextView *)aTextView {
	if (![self.textView.text isEqualToString:textViewText]) {
		self.hasChanges = YES;
	}
	self.isEditing = NO;
	if (IS_IPAD == NO) {
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"")
                                                                                 style:[WPStyleGuide barButtonStyleForBordered]
                                                                                target:self
                                                                                action:@selector(cancelView:)];
	}
}

#pragma mark -
#pragma mark Comment Handling Methods

- (BOOL)isConnectedToHost {
    WordPressAppDelegate  *appDelegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate.currentBlogAvailable == NO) {
        UIAlertView *connectionFailAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No connection to host.", @"")
																	  message:NSLocalizedString(@"Operation is not supported now.", @"")
																	 delegate:nil
                                                            cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                                            otherButtonTitles:nil];
        [connectionFailAlert show];
        return NO;
    }
    return YES;
}

- (void)initiateSaveCommentReply:(id)sender {
	[self endTextEnteringButtonAction: sender];
	if(self.hasChanges == NO) {
        [commentViewController cancelView:self];
		return;
	}
	self.comment.content = self.textView.text;
	commentViewController.wasLastCommentPending = YES;
	[commentViewController showComment:comment];
	[self.navigationController popViewControllerAnimated:YES];
	
    self.textView.editable = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.navigationItem.leftBarButtonItem.enabled = NO;
    [self.comment uploadWithSuccess:^{
        self.hasChanges = NO;
        [commentViewController cancelView:self];
    } failure:^(NSError *error) {
        self.textView.editable = YES;
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.navigationItem.leftBarButtonItem.enabled = YES;
        NSString *message = NSLocalizedString(@"Sorry, something went wrong editing the comment. Please try again.", @"");
        if (error.code == 405) {
            // XML-RPC is disabled.
            message = error.localizedDescription;
        }
		[[NSNotificationCenter defaultCenter] postNotificationName:@"CommentUploadFailed" object:message];
    }];
}

#pragma mark -
#pragma mark Button Override Methods

- (void)cancelView:(id)sender {
    if (![self.textView.text isEqualToString:self.textViewText]) {
		self.hasChanges = YES;
	}
    [commentViewController cancelView:sender];
}

@end