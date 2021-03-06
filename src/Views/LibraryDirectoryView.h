//
//	LibraryDirectoryView.h
//	Viewer v1.2.0
//
//	Created by Julius Oklamcak on 2012-09-01.
//	Copyright © 2011-2014 Julius Oklamcak. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <UIKit/UIKit.h>

#import "ReaderThumbsView.h"

@class LibraryDirectoryView;
@class DocumentFolder;
@class UIXToolbarView;

@protocol LibraryDirectoryDelegate <NSObject>

@required

- (void)tappedInToolbar:(UIXToolbarView *)toolbar infoButton:(UIButton *)button;

- (void)directoryView:(LibraryDirectoryView *)directoryView didSelectDocumentFolder:(DocumentFolder *)folder;

- (void)enableContainerScrollView:(BOOL)enabled;

@end

@interface LibraryDirectoryView : UIView

@property (nonatomic, weak, readwrite) id <LibraryDirectoryDelegate> delegate;

@property (nonatomic, weak, readwrite) UIViewController *ownViewController;

- (void)handleMemoryWarning;

- (void)reloadDirectory;

@end

#pragma mark -

//
//	LibraryDirectoryCell class interface
//

@interface LibraryDirectoryCell : ReaderThumbView

- (void)showText:(NSString *)text;

- (void)showCheck:(BOOL)checked;

@end
