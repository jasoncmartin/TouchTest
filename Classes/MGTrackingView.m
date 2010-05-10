//
//  MGTrackingView.m
//  TouchTest
//
//  Created by Matt Gemmell on 08/05/2010.
//

#import "MGTrackingView.h"
#import "MGTouchView.h"
#import <QuartzCore/QuartzCore.h>

#import "SoundEngine.h"

#define MG_ANIMATION_APPEAR		@"Appear"
#define MG_ANIMATION_DISAPPEAR	@"Disappear"

#define MG_ANIMATE_ARROWS		YES


@interface MGTrackingView (MGPrivateMethods)

- (void)setup;
- (UIColor *)nextColor;

@end



@implementation MGTrackingView


#pragma mark Setup and teardown


- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
		[self setup];
    }
    return self;
}


- (void)awakeFromNib
{
	[self setup];
}


- (void)setup
{
	// Ensure we receive multiple touch events.
	self.multipleTouchEnabled = YES;
	
	// Array of views to display the touches.
	touchViews = [[NSMutableArray arrayWithCapacity:0] retain];
	
	// Create the colors we'll cycle through for new touch-views. Colors taken from: http://www.angelfire.com/trek/amsguy/LCARS.html
	colors = [[NSArray arrayWithObjects:
			  [UIColor colorWithRed:255.0/255.0 green:153.0/255.0 blue:0.0 alpha:1.0],
			  [UIColor colorWithRed:204.0/255.0 green:153.0/255.0 blue:204.0/255.0 alpha:1.0],
			  [UIColor colorWithRed:153.0/255.0 green:153.0/255.0 blue:204.0/255.0 alpha:1.0],
			  [UIColor colorWithRed:204.0/255.0 green:102.0/255.0 blue:102.0/255.0 alpha:1.0],
			  [UIColor colorWithRed:255.0/255.0 green:204.0/255.0 blue:153.0/255.0 alpha:1.0],
			  [UIColor colorWithRed:153.0/255.0 green:153.0/255.0 blue:255.0/255.0 alpha:1.0],
			  [UIColor colorWithRed:255.0/255.0 green:153.0/255.0 blue:102.0/255.0 alpha:1.0],
			  [UIColor colorWithRed:204.0/255.0 green:102.0/255.0 blue:153.0/255.0 alpha:1.0],
			  nil] retain];
	lastColor = [colors count];
	
	// Create map to associate touch-events with views.
	touchMap = CFDictionaryCreateMutable(NULL, // use the default allocator
										 0,		// unlimited size
										 NULL,	// key callbacks - none, just do pointer comparison
										 NULL); // value callbacks - same.
	
	SoundEngine_Initialize(0);
	
	SoundEngine_LoadEffect([[[NSBundle mainBundle] pathForResource:@"207" ofType:@"caf"] UTF8String], &effectID);
	SoundEngine_LoadEffect([[[NSBundle mainBundle] pathForResource:@"transporter" ofType:@"caf"] UTF8String], &transEffectID);
	SoundEngine_LoadBackgroundMusicTrack([[[NSBundle mainBundle] pathForResource:@"bridge2.loop" ofType:@"caf"] UTF8String], true, true);
	
	SoundEngine_StartBackgroundMusic();
}


- (void)dealloc
{
	SoundEngine_UnloadEffect(transEffectID);
	SoundEngine_UnloadEffect(effectID);
	
	SoundEngine_UnloadBackgroundMusicTrack();
	
	SoundEngine_Teardown();
	
	[touchViews release];
	touchViews = nil;
	[colors release];
	colors = nil;
	
	CFRelease(touchMap);
	
	[super dealloc];
}


#pragma mark Drawing


- (void)drawRect:(CGRect)rect
{
	// Draw background.
	UIImage *img = [UIImage imageNamed:@"instinctivecode_logo.png"];
	CGSize imgSize = img.size;
	CGSize viewSize = [self bounds].size;
	CGPoint pt = CGPointMake((viewSize.width - imgSize.width) / 2.0, (viewSize.height - imgSize.height) / 2.0);
	[img drawAtPoint:pt blendMode:kCGBlendModeNormal alpha:0.5];
	
	// Draw axial markers.
	float width = 3.0;
	CGPoint center;
	CGRect axis;
	for (MGTouchView *view in touchViews) {
		center = view.center;
		axis = CGRectMake(center.x - (width / 2.0), 0, width, viewSize.height);
		[view.color set];
		UIRectFill(axis);
		axis = CGRectMake(0, center.y - (width / 2.0), viewSize.width, width);
		UIRectFill(axis);
	}
	
	// Draw number of touches.
	[[UIColor whiteColor] set];
	pt = CGPointMake(5, 5);
	int numViews = [touchViews count];
	NSString *label = [NSString stringWithFormat:@"%d %@", numViews, ((numViews == 1) ? @"touch" : @"touches")];
	[label drawAtPoint:pt withFont:[UIFont boldSystemFontOfSize:20.0]];
	pt = CGPointMake(5, 30);
	label = [NSString stringWithFormat:@"Height: %f", height];
	[label drawAtPoint:pt withFont:[UIFont boldSystemFontOfSize:20.0]];
}


#pragma mark Interaction


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Create new MGTouchView(s) at appropriate coordinates, and begin tracking them.
	for (UITouch *touch in touches) {
		// Create view for this touch.
		float viewWidth = 120.0;
		MGTouchView *view = [[MGTouchView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, viewWidth)];
		view.center = [touch locationInView:self];
		view.color = [self nextColor];
		[touchViews addObject:view];
		[view release];
		
		// Apply an animation to fade and scale the view onto the screen.
		CALayer *layer = view.layer;
		layer.opacity = 0.0;
		[self addSubview:view];
		layer.transform = CATransform3DMakeScale(0.5, 0.5, 0.5);
		[UIView beginAnimations:MG_ANIMATION_APPEAR context:view];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
		[UIView setAnimationDelegate:self];
		layer.opacity = 1.0;
		layer.transform = CATransform3DIdentity;
		[UIView commitAnimations];
		
		// Add view to the map for this touch.
		CFDictionarySetValue(touchMap, touch , view);
	}
	
	[self setNeedsDisplay];
	
	if([[event touchesForView:self] count] == 3) {
		height = 0;
		play = YES;
	}
	
	SoundEngine_StartEffect(effectID);
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Update relevant MGTouchViews and status display.
	for (UITouch *touch in touches) {
		// Obtain view corresponding to this touch event.
		UIView *view = (UIView*)CFDictionaryGetValue(touchMap, touch);
		if (view) {
			// Update center to track the change to the touch.
			view.center = [touch locationInView:self];
		}
	}
	
	if([[event touchesForView:self] count] == 3) {
		NSSet *allTouches = [event touchesForView:self];
		
		CGFloat tempHeight = 0.0;
		
		for(UITouch *aTouch in [allTouches allObjects]) {
			CGPoint aPoint = [aTouch locationInView:self];
			CGPoint anotherPoint = [aTouch previousLocationInView:self];
			
			tempHeight += anotherPoint.y - aPoint.y;
		}
		
		height += tempHeight;
		
		if(height >= 900 && play) {
			SoundEngine_StartEffect(transEffectID);
			
			play = NO;
		}
	}
	
	[self setNeedsDisplay];
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Destroy relevant MGTouchViews.

	for (UITouch *touch in touches) {
		MGTouchView *view = (MGTouchView*)CFDictionaryGetValue(touchMap, touch);
		if (view) {
			// Update center in case it's moved since the last change.
			view.center = [touch locationInView:self];
			
			// Fade out.
			view.showArrows = NO;
			[UIView beginAnimations:MG_ANIMATION_DISAPPEAR context:view];
			[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
			[UIView setAnimationDelegate:self];
			CALayer *layer = view.layer;
			layer.opacity = 0.0;
			layer.transform = CATransform3DMakeScale(0.5, 0.5, 0.5);
			[UIView commitAnimations];
		
			// Remove view from the map immediately.
			CFDictionaryRemoveValue(touchMap, touch);
		}

	}
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self touchesEnded:touches withEvent:event];
}


- (IBAction)clearAllTouches:(id)sender
{
	NSArray *views = [NSArray arrayWithArray:touchViews];
	for (MGTouchView *view in views) {
		[touchViews removeObject:view];
		[view removeFromSuperview];
	}
	[self setNeedsDisplay];
}


#pragma mark Utilities


- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	MGTouchView *view = context;
	if (view && [touchViews containsObject:view]) {
		if ([finished boolValue] && [animationID isEqualToString:MG_ANIMATION_DISAPPEAR]) {
			// Remove view.
			[touchViews removeObject:view];
			[view removeFromSuperview];
			
			// Clean up orphans.
			NSArray *views = [NSArray arrayWithArray:touchViews];
			for (view in views) {
				if (view.layer.opacity == 0.0) {
					[touchViews removeObject:view];
					[view removeFromSuperview];
				}
			}
			
			[self setNeedsDisplay];
			
		} else if ([animationID isEqualToString:MG_ANIMATION_APPEAR] && MG_ANIMATE_ARROWS) {
			view.showArrows = YES;
			CAKeyframeAnimation *rotation = [CAKeyframeAnimation animation];
			rotation.repeatCount = 1000;
			rotation.values = [NSArray arrayWithObjects:
							   [NSValue valueWithCATransform3D:CATransform3DMakeRotation(0.0f, 0.0f, 0.0f, 1.0f)],
							   [NSValue valueWithCATransform3D:CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 1.0f)],
							   [NSValue valueWithCATransform3D:CATransform3DMakeRotation(M_PI * 2.0, 0.0f, 0.0f, 1.0f)],
							   nil];
			rotation.duration = 1.5;
			[view.layer addAnimation:rotation forKey:@"transform"];
		}
	}
}


- (UIColor *)nextColor
{
	if (lastColor >= [colors count] - 1) {
		lastColor = 0;
	} else {
		lastColor++;
	}
	
	return [colors objectAtIndex:lastColor];
}


@end
