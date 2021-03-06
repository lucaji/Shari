//
//    LibraryViewController.m
//    Viewer v1.2.0
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
#import "LibraryViewController.h"
#import "LibraryDirectoryView.h"
#import "LibraryDocumentsView.h"
#import "ReaderViewController.h"
#import "ReaderThumbCache.h"
#import "CoreDataManager.h"
#import "DocumentsUpdate.h"
#import "DocumentFolder.h"
#import "ReaderDocument.h"
#import "CGPDFDocument.h"

@interface LibraryViewController () <LibraryDirectoryDelegate, LibraryDocumentsDelegate, ReaderViewControllerDelegate, UIScrollViewDelegate>

@end

@implementation LibraryViewController {
    UIScrollView *theScrollView;
    LibraryDirectoryView *directoryView;
    LibraryDocumentsView *documentsView;
    ReaderViewController *readerViewController;
    LibraryUpdatingView *updatingView;

    NSMutableArray *contentViews;
    NSInteger visibleViewTag;
    CGSize lastAppearSize;
    BOOL isVisible;
}

#pragma mark Constants

#define DIRECTORY_TAG 1
#define DOCUMENTS_TAG 2

#define STATUS_HEIGHT 20.0f

#define DEFAULT_DURATION 0.3

#pragma mark Support methods

- (void)updateScrollViewContentSize {
    NSInteger count = contentViews.count;
    assert(count != 0);
    CGFloat contentHeight = theScrollView.bounds.size.height;
    CGFloat contentWidth = (theScrollView.bounds.size.width * count);
    theScrollView.contentSize = CGSizeMake(contentWidth, contentHeight);
}

- (void)updateScrollViewContentViews {
    [self updateScrollViewContentSize]; // Update content size
    CGPoint contentOffset = CGPointZero; // Content offset for visible view
    CGRect viewRect = CGRectZero;
    viewRect.size = theScrollView.bounds.size;
    for (UIView *contentView in contentViews) {
        contentView.frame = viewRect; // Update content view frame
        if (contentView.tag == visibleViewTag) { contentOffset = viewRect.origin; }
        viewRect.origin.x += viewRect.size.width; // Next position
    }

    if (CGPointEqualToPoint(theScrollView.contentOffset, contentOffset) == false) {
        theScrollView.contentOffset = contentOffset; // Update content offset
    }
}


- (void)showReaderDocument:(ReaderDocument *)document {
    if (document.fileExistsAndValid) {
        CFURLRef fileURL = (__bridge CFURLRef)document.fileURL; // Document file URL
        if (CGPDFDocumentUrlNeedsPassword(fileURL, document.password) == NO) {
            if (self.presentedViewController != nil) // Check for active view controller(s)
            {
                [self dismissViewControllerAnimated:NO completion:NULL]; // Dismiss any view controller(s)
            }

            readerViewController = nil; // Release any old ReaderViewController first
            readerViewController = [[ReaderViewController alloc] initWithReaderDocument:document];
            readerViewController.delegate = self; // Set the ReaderViewController delegate to self

            readerViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            readerViewController.modalPresentationStyle = UIModalPresentationFullScreen;

            [self presentViewController:readerViewController animated:NO completion:NULL];
        }
    }
}

#pragma mark UIViewController methods

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserverForName:DocumentsUpdateOpenNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults]; // User defaults
            NSString *documentURL = [userDefaults objectForKey:kReaderSettingsCurrentDocument]; // Document
            
            if (documentURL != nil) {
                // Show default document saved in user defaults
                NSManagedObjectContext *mainMOC = CoreDataManager.singleton.mainManagedObjectContext;
                NSURL *documentURI = [NSURL URLWithString:documentURL];
                NSManagedObjectID *objectID = [CoreDataManager.singleton objectIDForURL:documentURI];
                
                if (objectID != nil) {
                    // We have a valid NSManagedObjectID to request a fetch of
                    ReaderDocument *document = (id)[mainMOC existingObjectWithID:objectID error:NULL];
                    if ((document != nil) && ([document isKindOfClass:[ReaderDocument class]])) {
                        [self showReaderDocument:document]; // Show the document
                    }
                }
            }

        }];
        [notificationCenter addObserverForName:DocumentsUpdateBeganNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            dispatch_async(dispatch_get_main_queue(), ^{
                               [self->updatingView animateShow];
            });

        }];
        [notificationCenter addObserverForName:DocumentsUpdateEndedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (NSEC_PER_SEC / 2)), dispatch_get_main_queue(), ^{
                               [self->updatingView animateHide];
                               
            });

        }];

        [ReaderThumbCache purgeThumbCachesOlderThan:(86400.0 * 30.0)]; // Purge thumb caches older than 30 days
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    CGRect scrollViewRect = self.view.bounds;
    UIView *fakeStatusBar = nil;
    
    if (self.prefersStatusBarHidden == NO) {
        // Visible status bar
        CGRect statusBarRect = self.view.bounds; // Status bar frame
        statusBarRect.size.height = STATUS_HEIGHT; // Default status height
        fakeStatusBar = [[UIView alloc] initWithFrame:statusBarRect]; // UIView
        fakeStatusBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        fakeStatusBar.backgroundColor = [UIColor blackColor];
        fakeStatusBar.contentMode = UIViewContentModeRedraw;
        fakeStatusBar.userInteractionEnabled = NO;
        
        scrollViewRect.origin.y += STATUS_HEIGHT; scrollViewRect.size.height -= STATUS_HEIGHT;
    }

    theScrollView = [[UIScrollView alloc] initWithFrame:scrollViewRect]; // UIScrollView
    theScrollView.autoresizesSubviews = NO; theScrollView.contentMode = UIViewContentModeRedraw;
    theScrollView.showsHorizontalScrollIndicator = NO; theScrollView.showsVerticalScrollIndicator = NO;
    theScrollView.scrollsToTop = NO; theScrollView.delaysContentTouches = NO; theScrollView.pagingEnabled = YES;
    theScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    theScrollView.backgroundColor = [UIColor clearColor]; theScrollView.bounces = NO;
    theScrollView.delegate = self; // UIScrollViewDelegate
    [self.view addSubview:theScrollView];

    updatingView = [[LibraryUpdatingView alloc] initWithFrame:scrollViewRect]; // LibraryUpdatingView
    [self.view addSubview:updatingView];

    if (fakeStatusBar != nil) {
        // Add status bar background view
        [self.view addSubview:fakeStatusBar];
    }
    contentViews = [NSMutableArray new];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (CGSizeEqualToSize(lastAppearSize, CGSizeZero) == NO) {
        if (CGSizeEqualToSize(lastAppearSize, self.view.bounds.size) == NO) {
            [self updateScrollViewContentViews]; // Update content views
        }
        lastAppearSize = CGSizeZero; // Reset view size tracking
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL reload = NO; isVisible = YES;

    if (contentViews.count == 0) {
        // Add content views
        CGRect viewRect = theScrollView.bounds; // Initial view frame
        directoryView = [[LibraryDirectoryView alloc] initWithFrame:viewRect];
        directoryView.delegate = self; directoryView.ownViewController = self;
        directoryView.tag = DIRECTORY_TAG;

        [theScrollView addSubview:directoryView];
        [contentViews addObject:directoryView]; // Add
        viewRect.origin.x += viewRect.size.width; // Next view frame position

        documentsView = [[LibraryDocumentsView alloc] initWithFrame:viewRect];
        documentsView.delegate = self; documentsView.ownViewController = self;
        documentsView.tag = DOCUMENTS_TAG;

        [theScrollView addSubview:documentsView]; [contentViews addObject:documentsView]; // Add

        viewRect.origin.x += viewRect.size.width; // Next view frame position
        visibleViewTag = directoryView.tag; // Set the visible view tag
        reload = YES; // Reload content views
    }

    if (CGSizeEqualToSize(theScrollView.contentSize, CGSizeZero)) {
        [self updateScrollViewContentSize]; // Set the content size
    }

    if (reload == YES) {
        [directoryView reloadDirectory];
        DocumentFolder *folder = nil;

        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults]; // User defaults
        NSManagedObjectContext *mainMOC = CoreDataManager.singleton.mainManagedObjectContext;
        NSPersistentStoreCoordinator *mainPSC = mainMOC.persistentStoreCoordinator; // Main PSC
        NSString *folderURL = [userDefaults objectForKey:kReaderSettingsCurrentFolder]; // Folder

        if (folderURL != nil) {
            // Show default folder saved in settings
            NSURL *folderURI = [NSURL URLWithString:folderURL]; // Folder URI
            NSManagedObjectID *objectID = [mainPSC managedObjectIDForURIRepresentation:folderURI];
            if (objectID != nil) folder = (id)[mainMOC existingObjectWithID:objectID error:NULL];
        }

        if (folder == nil) {
            // Show default documents folder
            folder = [DocumentFolder folderInMOC:mainMOC type:DocumentFolderTypeDefault];
            NSString *folderURI = [folder.objectID URIRepresentation].absoluteString; // Folder URI
            [userDefaults setObject:folderURI forKey:kReaderSettingsCurrentFolder]; // Default folder
        }

        assert(folder != nil);
        [documentsView reloadDocumentsWithFolder:folder]; // Show folder contents

        NSString *documentURL = [userDefaults objectForKey:kReaderSettingsCurrentDocument]; // Document

        if (documentURL != nil) {
            // Show default document saved in user defaults
            NSURL *documentURI = [NSURL URLWithString:documentURL]; // Document URI
            NSManagedObjectID *objectID = [mainPSC managedObjectIDForURIRepresentation:documentURI];
            if (objectID != nil) {
                // We have a valid NSManagedObjectID to request a fetch of
                ReaderDocument *document = (id)[mainMOC existingObjectWithID:objectID error:NULL];
                if ((document != nil) && ([document isKindOfClass:[ReaderDocument class]]))
                {
                    [self showReaderDocument:document]; // Show the document
                }
            }
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    lastAppearSize = self.view.bounds.size; // Track view size
}



- (BOOL)prefersStatusBarHidden {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kReaderSettingsHideStatusBar];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
        return UIInterfaceOrientationIsPortrait(interfaceOrientation);
    else
        return YES;
}

/*
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    //if (isVisible == NO) return; // iOS present modal bodge
}
*/

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
    if (isVisible == NO) return; // iOS present modal bodge
    [self updateScrollViewContentViews]; // Update content views
    lastAppearSize = CGSizeZero; // Reset view size tracking
}

/*
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    //if (isVisible == NO) return; // iOS present modal bodge

    //if (fromInterfaceOrientation == self.interfaceOrientation) return;
}
*/

- (void)didReceiveMemoryWarning {
    [documentsView handleMemoryWarning];
    [directoryView handleMemoryWarning];
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver:self name:DocumentsUpdateOpenNotification object:nil];
    [notificationCenter removeObserver:self name:DocumentsUpdateBeganNotification object:nil];
    [notificationCenter removeObserver:self name:DocumentsUpdateEndedNotification object:nil];
    [notificationCenter removeObserver:self];
    
    lastAppearSize = CGSizeZero;
    visibleViewTag = 0;
    theScrollView = nil;
    documentsView = nil;
    directoryView = nil;
    updatingView = nil;
    contentViews = nil;
    isVisible = NO;

}

#pragma mark UIScrollViewDelegate methods

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat contentOffsetX = scrollView.contentOffset.x;
    for (UIView *contentView in contentViews) {
        if (contentView.frame.origin.x == contentOffsetX) {
            visibleViewTag = contentView.tag; break;
        }
    }
}

- (void)enableContainerScrollView:(BOOL)enabled {
    theScrollView.scrollEnabled = enabled;
}

#pragma mark LibraryDirectoryDelegate methods

- (void)tappedInToolbar:(UIXToolbarView *)toolbar infoButton:(UIButton *)button {
    if ([_delegate respondsToSelector:@selector(dismissLibraryViewController:)]) {
        [_delegate dismissLibraryViewController:self]; // Dismiss the view controller
    }
}

- (void)directoryView:(LibraryDirectoryView *)directoryView didSelectDocumentFolder:(DocumentFolder *)folder {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults]; // User defaults
    NSString *folderURI = [folder.objectID URIRepresentation].absoluteString; // Folder URI
    [userDefaults setObject:folderURI forKey:kReaderSettingsCurrentFolder]; // Default folder
    [documentsView reloadDocumentsWithFolder:folder]; // Reload documents view

    for (UIView *contentView in contentViews) {
        if (contentView.tag == DOCUMENTS_TAG) {
            CGPoint contentOffset = contentView.frame.origin; // Get origin
            [theScrollView setContentOffset:contentOffset animated:YES];
            visibleViewTag = contentView.tag; break;
        }
    }
}

#pragma mark LibraryDocumentsDelegate methods

- (void)documentsView:(LibraryDocumentsView *)documentsView didSelectReaderDocument:(ReaderDocument *)document {
    if (document.fileExistsAndValid) {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults]; // User defaults
        if (document.password == nil) {
            // Only remember default documents that do not require a password
            NSString *documentURI = [document.objectID URIRepresentation].absoluteString; // Document URI
            [userDefaults setObject:documentURI forKey:kReaderSettingsCurrentDocument]; // Default document
        }

        readerViewController = nil; // Release any old ReaderViewController first
        readerViewController = [[ReaderViewController alloc] initWithReaderDocument:document];
        readerViewController.delegate = self; // Set the ReaderViewController delegate to self
        readerViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        readerViewController.modalPresentationStyle = UIModalPresentationFullScreen;

        [self presentViewController:readerViewController animated:NO completion:NULL];
    }
}

#pragma mark ReaderViewControllerDelegate methods

- (void)dismissReaderViewController:(ReaderViewController *)viewController {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults]; // User defaults
    [userDefaults removeObjectForKey:kReaderSettingsCurrentDocument]; // Clear default document
    [self dismissViewControllerAnimated:NO completion:NULL]; readerViewController = nil; // Release ReaderViewController
    [documentsView refreshRecentDocuments]; // Refresh if recent folder is visible
}


@end

#pragma mark -

//
//    LibraryUpdatingView class implementation
//

@implementation LibraryUpdatingView {
    UIActivityIndicatorView *activityView;
    UILabel *titleLabel;
}

#pragma mark Constants

#define TITLE_X 6.0f
#define TITLE_Y 52.0f
#define TITLE_WIDTH 128.0f
#define TITLE_HEIGHT 28.0f

#pragma mark LibraryDirectoryCell instance methods

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.autoresizesSubviews = YES;
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.5f]; // View tint
        self.hidden = YES; self.alpha = 0.0f; // Start off hidden

        NSInteger centerX = (self.bounds.size.width / 2.0f); // Center X
        NSInteger offsetY = (self.bounds.size.height / 3.0f); // Offset Y

        UIViewAutoresizing resizingMask = UIViewAutoresizingNone;
        resizingMask |= (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
        resizingMask |= (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);

        activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];

        CGRect activityFrame = activityView.frame;
        NSInteger activityX = (centerX - (activityFrame.size.width / 2.0f));
        NSInteger activityY = (offsetY - (activityFrame.size.height / 2.0f));
        activityFrame.origin = CGPointMake(activityX, activityY);
        activityView.frame = activityFrame;

        activityView.autoresizingMask = resizingMask;

        [self addSubview:activityView]; // Add to view

        NSString *labelText = NSLocalizedString(@"Updating", "text");

        NSInteger labelX = (centerX - (TITLE_WIDTH / 2.0f) + TITLE_X);
        NSInteger labelY = (offsetY - (TITLE_HEIGHT / 2.0f) + TITLE_Y);
        CGRect labelFrame = CGRectMake(labelX, labelY, TITLE_WIDTH, TITLE_HEIGHT);

        titleLabel = [[UILabel alloc] initWithFrame:labelFrame];

        titleLabel.font = [UIFont systemFontOfSize:17.0f];
        titleLabel.text = [labelText stringByAppendingString:@"..."];
        titleLabel.textColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;

        titleLabel.autoresizingMask = resizingMask;

        [self addSubview:titleLabel]; // Add to view
    }

    return self;
}

- (void)animateHide {
    if (!self.hidden) {
        [activityView stopAnimating];
        [UIView animateWithDuration:DEFAULT_DURATION delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^(void) {
                self.alpha = 0.0f;
            } completion:^(BOOL finished) {
                self.userInteractionEnabled = NO;
                self.hidden = YES;
            } ];
    }
}

- (void)animateShow {
    if (self.hidden) {
        [activityView startAnimating];
        [UIView animateWithDuration:DEFAULT_DURATION delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^(void) {
                self.hidden = NO;
                self.alpha = 1.0f;
        } completion:^(BOOL finished) {
                self.userInteractionEnabled = YES;
        }];
    }
}

@end
