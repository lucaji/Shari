//
//    UIXTextEntry.h
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

#import <UIKit/UIKit.h>

typedef NS_ENUM(unsigned int, UIXTextEntryType) {
    UIXTextEntryTypeURL,
    UIXTextEntryTypeText,
    UIXTextEntryTypeSecure
};

@class UIXTextEntry;

@protocol UIXTextEntryDelegate <NSObject>

@required // Delegate protocols

- (BOOL)textEntryShouldReturn:(UIXTextEntry *)textEntry text:(NSString *)text;

- (void)doneButtonTappedInTextEntry:(UIXTextEntry *)textEntry text:(NSString *)text;

- (void)cancelButtonTappedInTextEntry:(UIXTextEntry *)textEntry;

@end

@interface UIXTextEntry : UIView

@property (nonatomic, weak, readwrite) id <UIXTextEntryDelegate> delegate;

- (void)setStatus:(NSString *)text;

- (void)setTextField:(NSString *)text;

- (void)setTitle:(NSString *)text withType:(UIXTextEntryType)type;

- (void)animateHide;
- (void)animateShow;

@end
