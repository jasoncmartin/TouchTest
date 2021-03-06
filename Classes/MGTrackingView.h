//
//  MGTrackingView.h
//  TouchTest
//
//  Created by Matt Gemmell on 08/05/2010.
//

#import <UIKit/UIKit.h>


@interface MGTrackingView : UIView {
	NSMutableArray *touchViews;
	int lastColor;
	NSArray *colors;
	
	UInt32 effectID;
	UInt32 transEffectID;
	
	CGFloat height;
	BOOL play;
	
	// CFDictionary to map touche events to touch-views.
	CFMutableDictionaryRef touchMap;
}

- (IBAction)clearAllTouches:(id)sender;

@end
