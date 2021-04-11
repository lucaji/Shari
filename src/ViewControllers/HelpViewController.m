//
//    HelpViewController.m
//    Viewer v1.2.1
//
//    Created by Julius Oklamcak on 2012-09-01.
//    Copyright © 2011-2014 Julius Oklamcak. All rights reserved.
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights to
//    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//    of the Software, and to permit persons to whom the Software is furnished to
//    do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderConstants.h"
#import "HelpViewController.h"
#import "UIXToolbarView.h"
#import "SGQRCodeGenerateManager.h"
#import "WebServer.h"

@interface HelpViewController () <UIWebViewDelegate>

@end

@implementation HelpViewController {
    UIXToolbarView *theToolbar;
    UILabel *theTitleLabel;
    UIWebView *theWebView;
    UIImageView*qrCodeImageView;
    BOOL htmlLoaded;
}

#pragma mark Constants

#define BUTTON_Y 7.0f
#define BUTTON_SPACE 8.0f
#define BUTTON_HEIGHT 30.0f

#define TITLE_Y 8.0f
#define TITLE_HEIGHT 28.0f

#define CLOSE_BUTTON_WIDTH 56.0f

#define STATUS_HEIGHT 20.0f

#define TOOLBAR_HEIGHT 44.0f

#define MAXIMUM_HELP_WIDTH 512.0f
#define MAXIMUM_HELP_HEIGHT 648.0f

#pragma mark Properties

@synthesize delegate;

#pragma mark UIViewController methods

- (void)viewDidLoad {
    [super viewDidLoad];
    assert(delegate != nil);
    self.view.backgroundColor = [UIColor grayColor];
    UIUserInterfaceIdiom userInterfaceIdiom = [UIDevice currentDevice].userInterfaceIdiom;
    CGRect viewRect = self.view.bounds;
    UIView *fakeStatusBar = nil;
    if (userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        if (self.prefersStatusBarHidden == NO) {
            CGRect statusBarRect = self.view.bounds; // Status bar frame
            statusBarRect.size.height = STATUS_HEIGHT; // Default status height
            fakeStatusBar = [[UIView alloc] initWithFrame:statusBarRect]; // UIView
            fakeStatusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            fakeStatusBar.backgroundColor = [UIColor blackColor];
            fakeStatusBar.contentMode = UIViewContentModeRedraw;
            fakeStatusBar.userInteractionEnabled = NO;
            viewRect.origin.y += STATUS_HEIGHT;
            viewRect.size.height -= STATUS_HEIGHT;
        }
        
    }

    CGRect toolbarRect = viewRect; toolbarRect.size.height = TOOLBAR_HEIGHT;
    theToolbar = [[UIXToolbarView alloc] initWithFrame:toolbarRect]; // UIXToolbarView
    [self.view addSubview:theToolbar]; // Add toolbar to view controller view

    CGFloat toolbarWidth = theToolbar.bounds.size.width; // Toolbar width
    CGFloat titleX = BUTTON_SPACE; CGFloat titleWidth = (toolbarWidth - (BUTTON_SPACE + BUTTON_SPACE));

    if (userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        UIImage *imageH = [UIImage imageNamed:@"Reader-Button-H"];
        UIImage *imageN = [UIImage imageNamed:@"Reader-Button-N"];

        UIImage *buttonH = [imageH stretchableImageWithLeftCapWidth:5 topCapHeight:0];
        UIImage *buttonN = [imageN stretchableImageWithLeftCapWidth:5 topCapHeight:0];

        titleWidth -= (CLOSE_BUTTON_WIDTH + BUTTON_SPACE); // Adjust title width

        CGFloat rightButtonX = (toolbarWidth - (CLOSE_BUTTON_WIDTH + BUTTON_SPACE)); // X

        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom]; // Close button
        closeButton.frame = CGRectMake(rightButtonX, BUTTON_Y, CLOSE_BUTTON_WIDTH, BUTTON_HEIGHT);
        [closeButton setTitle:NSLocalizedString(@"Close", @"button") forState:UIControlStateNormal];
        [closeButton setTitleColor:[UIColor colorWithWhite:0.0f alpha:1.0f] forState:UIControlStateNormal];
        [closeButton setTitleColor:[UIColor colorWithWhite:1.0f alpha:1.0f] forState:UIControlStateHighlighted];
        [closeButton addTarget:self action:@selector(closeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [closeButton setBackgroundImage:buttonH forState:UIControlStateHighlighted];
        [closeButton setBackgroundImage:buttonN forState:UIControlStateNormal];
        closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        closeButton.titleLabel.font = [UIFont systemFontOfSize:14.0f];
        closeButton.exclusiveTouch = YES;
        [theToolbar addSubview:closeButton]; // Add button to toolbar
    } else {
        self.preferredContentSize = CGSizeMake(MAXIMUM_HELP_WIDTH, MAXIMUM_HELP_HEIGHT);
    }

    NSDictionary *infoDictionary = [NSBundle mainBundle].infoDictionary;
    NSString *name = infoDictionary[(NSString *)kCFBundleNameKey];
    NSString *version = infoDictionary[(NSString *)kCFBundleVersionKey];

    CGRect titleRect = CGRectMake(titleX, TITLE_Y, titleWidth, TITLE_HEIGHT);
    theTitleLabel = [[UILabel alloc] initWithFrame:titleRect];
    theTitleLabel.textAlignment = NSTextAlignmentCenter;
    theTitleLabel.font = [UIFont systemFontOfSize:17.0f];
    theTitleLabel.textColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
    theTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    theTitleLabel.backgroundColor = [UIColor clearColor];
#if (READER_FLAT_UI == FALSE) // Option
    theTitleLabel.shadowColor = [UIColor colorWithWhite:0.65f alpha:1.0f];
    theTitleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
#endif // end of READER_FLAT_UI Option
    theTitleLabel.text = [NSString stringWithFormat:@"%@ v%@", name, version];
    [theToolbar addSubview:theTitleLabel];

    NSString*serverIpAddress = WebServer.sharedWebServer.ipAddress;
    BOOL published = serverIpAddress != nil;
    if (published) {
        qrCodeImageView = [[UIImageView alloc] init];
        CGFloat imageViewW = 150.0;
        CGFloat imageViewH = imageViewW;
        CGFloat imageViewX = 10.0;
        CGFloat imageViewY = TOOLBAR_HEIGHT;
        CGRect qrRect = CGRectMake(imageViewX, imageViewY, imageViewW, imageViewH);
        qrCodeImageView.frame = qrRect;
        [self.view addSubview:qrCodeImageView];
        qrCodeImageView.image = [SGQRCodeGenerateManager generateWithDefaultQRCodeData:WebServer.sharedWebServer.ipAddress imageViewWidth:imageViewW];
    }
    
    CGRect helpRect = viewRect;
    helpRect.origin.y += TOOLBAR_HEIGHT + (published?180:0);
    helpRect.size.height -= TOOLBAR_HEIGHT - (published?180:0);
    theWebView = [[UIWebView alloc] initWithFrame:helpRect]; // UIWebView
    theWebView.dataDetectorTypes = UIDataDetectorTypeNone; theWebView.scalesPageToFit = NO;
    theWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    theWebView.delegate = self; // UIWebViewDelegate
    [self.view insertSubview:theWebView belowSubview:theToolbar];

    if (userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        if (fakeStatusBar != nil) {
            [self.view addSubview:fakeStatusBar];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (htmlLoaded == NO) {
        NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"help.html" ofType:nil]; // Help HTML file
        NSString *htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
        NSURL *baseURLPath = [NSURL fileURLWithPath:htmlFile.stringByDeletingLastPathComponent isDirectory:YES];
        [theWebView loadHTMLString:htmlString baseURL:baseURLPath]; htmlLoaded = YES;
    }
}

- (BOOL)prefersStatusBarHidden {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kReaderSettingsHideStatusBar];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationIsPortrait(interfaceOrientation);
    } else {
        return YES;
    }
}

- (void)dealloc {
    theWebView.delegate = nil;
    theWebView = nil;
    theTitleLabel = nil;
    theToolbar = nil;
}

#pragma mark UIWebViewDelegate methods

/*
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}
*/

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type {
    BOOL should = YES;
    if (type == UIWebViewNavigationTypeLinkClicked) {
        should = NO;
        [UIApplication.sharedApplication openURL:request.URL options:@{} completionHandler:^(BOOL success) {
            
        }];
    }
    return should;
}

/*
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
}
*/

#pragma mark UIButton action methods

- (void)closeButtonTapped:(UIButton *)button {
    [delegate dismissHelpViewController:self];
}

@end
