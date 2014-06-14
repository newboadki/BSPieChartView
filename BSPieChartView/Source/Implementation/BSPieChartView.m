//
//  BSPieChartView.m
//  PathLayers
//
//  Created by Borja Arias Drake on 17/05/2014.
//  Copyright (c) 2014 Borja Arias Drake. All rights reserved.
//

#import "BSPieChartView.h"
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CALayer.h>
#import <math.h>
#import "BSPieChartSectionInfo.h"



@interface BSPieChartSectionInfoInternal : BSPieChartSectionInfo
@property (nonatomic, assign) CGFloat initialAngle;
@property (nonatomic, assign) CGFloat finalAngle;
@property (nonatomic, strong) NSArray *animationFrames;
@property (nonatomic, strong) CAShapeLayer *layer;

- (instancetype)initWithInfoWithPublicInfo:(BSPieChartSectionInfo *)publicSectionInfo;

@end

@implementation BSPieChartSectionInfoInternal

- (instancetype)initWithInfoWithPublicInfo:(BSPieChartSectionInfo *)publicSectionInfo
{
    self = [super init];
    
    if (self) {
        self.name = publicSectionInfo.name;
        self.percentage = publicSectionInfo.percentage;
        self.color = publicSectionInfo.color;
    }
    
    return self;
}


@end

@interface BSPieChartView ()

@property (nonatomic, copy)   NSString *animationName;

@property (nonatomic, assign) CGFloat internalRadius;

@property (nonatomic, assign) CGFloat externalRadius;

@property (nonatomic, assign) BOOL  firstTime;


// cache the delegate and data source values
@property (nonatomic, assign) CGFloat cachedSectionsWidth;
@property (nonatomic, assign) CGFloat cachedInitialAngle;
@property (nonatomic, assign) NSUInteger cachedNumberOfSections;// This does not always match cachedSections.count
@property (nonatomic, strong) NSMutableArray *cachedSections;

@property (nonatomic, strong) NSMutableArray *labels;


@end

@implementation BSPieChartView



#pragma mark - Initialisers

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        [self commonInit];
    }
    
    return self;
}


- (void)commonInit
{
    _cachedSections = [NSMutableArray array];
    _labels = [NSMutableArray array];
    _firstTime = YES;
}


- (void)awakeFromNib
{
    [super awakeFromNib];

}


- (CGFloat)internalRadius
{
    return ([self externalRadius] - self.cachedSectionsWidth);
}


- (CGFloat)externalRadius
{
    return CGRectGetHeight(self.bounds) / 2.0;
}



#pragma mark - Animations

- (void)animate
{
    if ([self.delegate animatable])
    {
        [self animateLayerAtIndex:0];
    }
}


- (void)animateLayerAtIndex:(NSUInteger)initialIndex
{
    
    if (initialIndex >= [self.cachedSections count]) {
        [self showLabels];
        [[self delegate] animationDidFinish];
        return;
    }
    
    BSPieChartSectionInfoInternal *sectionInfo = self.cachedSections[initialIndex];
    CAAnimation *animation = [self animationForLayer:sectionInfo.layer values:sectionInfo.animationFrames duration:0.2];
    [CATransaction setCompletionBlock:^{
        [self animateLayerAtIndex:(initialIndex + 1)];
    }];
    
    [sectionInfo.layer addAnimation:animation forKey:[NSString stringWithFormat:@"pathAnimation_%ld", (unsigned long)initialIndex]];
}


- (CAAnimation *)animationForLayer:(CALayer *)layer values:(NSArray*)values duration:(CGFloat)duration
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"path"];
    animation.values = values;
    animation.duration = duration;
    [layer.modelLayer setPath:(CGPathRef)[values lastObject]];
    
    return animation;
}



#pragma mark - Interpolation of paths

- (NSArray *)interpolatedToroidalPathsWithInitialAngle:(CGFloat)initialAngle
                                                  finalAngle:(CGFloat)finalAngle
                                              externalRadius:(CGFloat)externalRadius
                                              internalRadius:(CGFloat)internalRadius
                                                     centerX:(CGFloat)x
                                                     centerY:(CGFloat)y
{
    NSMutableArray *result = [NSMutableArray arrayWithObject:(id)[self toroidWithInitialAngle:initialAngle finalAngle:initialAngle externalRadius:externalRadius internalRadius:internalRadius centerX:x centerY:y]];

    CGFloat increment = 0.01;
    CGFloat angle = initialAngle;
    
    while (angle < finalAngle) {
        [result addObject:(id)[self toroidWithInitialAngle:initialAngle finalAngle:angle externalRadius:externalRadius internalRadius:internalRadius centerX:x centerY:y]];
        angle += increment;
    }
    
    return result;
}

- (CGMutablePathRef)toroidWithInitialAngle:(CGFloat)initialAngle
                                finalAngle:(CGFloat)finalAngle
                            externalRadius:(CGFloat)externalRadius
                            internalRadius:(CGFloat)internalRadius
                                   centerX:(CGFloat)x
                                   centerY:(CGFloat)y
{
    
    CGMutablePathRef pathRef = CGPathCreateMutable();
    CGPoint initialPoint = CGPointMake(x + externalRadius * cos(initialAngle), y + externalRadius * sin(initialAngle));
    
    CGPathMoveToPoint(pathRef, NULL, initialPoint.x, initialPoint.y);
    
    // interpolate external arc
    CGFloat increment = 0.01;
    CGFloat angle = initialAngle;
    
    while (angle < finalAngle) {
        CGPathAddLineToPoint(pathRef, NULL, x + externalRadius * cos(angle), y + externalRadius * sin(angle));
        angle += increment;
    }
    
    // interpolate internal arc
    CGPoint initialInternalPoint = CGPointMake(x + internalRadius * cos(finalAngle), y + internalRadius * sin(finalAngle));
    CGPathAddLineToPoint(pathRef, NULL, initialInternalPoint.x, initialInternalPoint.y);
    while (angle > initialAngle)
    {
        CGPathAddLineToPoint(pathRef, NULL, x + internalRadius * cos(angle), y + internalRadius * sin(angle));
        angle -= increment;
    }
    
    // close the path
    CGPathAddLineToPoint(pathRef, NULL, initialPoint.x, initialPoint.y);
    
    return pathRef;
}



#pragma mark - Maths helpers

- (CGFloat)angleFrom:(CGFloat)angleOffsetInRadians andPercentage:(CGFloat)percentage
{
    CGFloat percentageAngleInRadians = (2 * M_PI  * percentage);
    return angleOffsetInRadians + percentageAngleInRadians;
}



#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.firstTime)
    {
        // Invalidate the cache
        [self invalidateCache];
        self.firstTime = NO;
    }
    
    // Create and position layers as needed
    [self setupSections];
}

- (void)setupSections
{
    
    // Setup
    NSUInteger numberOfSections = self.cachedNumberOfSections;
    
    for (int index=0; index< numberOfSections; index++)
    {
        BSPieChartSectionInfo *sectionInfo = [self.dataSource sectionInfoForIndex:index];
        
        // Creates a new layer if needed, otherwise returns an existing one
        BSPieChartSectionInfoInternal *internalSectionInfo = [self internalSectionInfoForSectionInfoAtIndex:index];
        CAShapeLayer *layer = internalSectionInfo.layer;
        [self.layer addSublayer:layer];
        
        // Position the layer
        layer.bounds = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        layer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        layer.fillColor = sectionInfo.color.CGColor;
        
        // Prepare for presentation
        [self setupSectionForPresentationWithSectionInfo:internalSectionInfo];
        
        // Setup the labels
        [self setupLabelForSectionInfo:internalSectionInfo];
    }
    
    // Remove extra layers
    [self removeExtraLAyerWithNumberOfSections:numberOfSections];
    
}

- (void)removeExtraLAyerWithNumberOfSections:(NSUInteger)numberOfSections
{
    NSUInteger numberOfLayersToRemove = ([self.cachedSections count] - numberOfSections);
    for (NSUInteger i = numberOfSections; i<numberOfLayersToRemove; i ++)
    {
        // TODO: REMOVE THE LAYER from the superlayer!!!!
        [self.cachedSections removeObjectAtIndex:i];
    }
    
    
}

- (void)setupSectionForPresentationWithSectionInfo:(BSPieChartSectionInfoInternal *)internalSectionInfo
{
    if ([self.delegate animatable])
    {
        internalSectionInfo.animationFrames = [self interpolatedToroidalPathsWithInitialAngle:internalSectionInfo.initialAngle
                                                                                   finalAngle:internalSectionInfo.finalAngle
                                                                               externalRadius:[self externalRadius]
                                                                               internalRadius:[self internalRadius]
                                                                                      centerX:internalSectionInfo.layer.position.x
                                                                                      centerY:internalSectionInfo.layer.position.y];
    }
    else
    {
        internalSectionInfo.layer.path = [self toroidWithInitialAngle:internalSectionInfo.initialAngle
                                                           finalAngle:internalSectionInfo.finalAngle
                                                       externalRadius:[self externalRadius]
                                                       internalRadius:[self internalRadius]
                                                              centerX:internalSectionInfo.layer.position.x
                                                              centerY:internalSectionInfo.layer.position.y];
    }
}


- (BSPieChartSectionInfoInternal *)internalSectionInfoForSectionInfoAtIndex:(NSUInteger)index
{
    NSInteger numberOfExistingLayers = [self.cachedSections count];
    CGFloat angleOffsetInRadians = 0;
    CAShapeLayer *layer = nil;
    BSPieChartSectionInfoInternal *internalSection = nil;
    
    if (index >= numberOfExistingLayers)
    {
        // CREATE THE LAYER
        BSPieChartSectionInfo *sectionInfo = [self.dataSource sectionInfoForIndex:index];
        internalSection = [[BSPieChartSectionInfoInternal alloc] initWithInfoWithPublicInfo:sectionInfo];
        
        // Calculate angleOffset (initialAngle)
        if (index == 0)
        {
            angleOffsetInRadians = self.cachedInitialAngle;
        }
        else
        {
            BSPieChartSectionInfoInternal *previousSection = self.cachedSections[index-1];
            angleOffsetInRadians = previousSection.finalAngle;
        }
        
        // Set angles
        internalSection.initialAngle = angleOffsetInRadians;
        internalSection.finalAngle = [self angleFrom:angleOffsetInRadians andPercentage:internalSection.percentage];
        
        // Create the layer
        layer = [[CAShapeLayer alloc] init];
        
        // Cache the layer
        internalSection.layer = layer;
        [self.cachedSections addObject:internalSection];
        
    }
    else
    {
        // Just retrieve an existing section info
        internalSection = (BSPieChartSectionInfoInternal *)self.cachedSections[index];

    }
    
    return internalSection;
}


- (void)setupLabelForSectionInfo:(BSPieChartSectionInfoInternal *)internalSectionInfo
{
    CGFloat labelRadius = ((self.externalRadius - self.internalRadius) / 2.0) + self.internalRadius;
    NSUInteger index = [self.cachedSections indexOfObject:internalSectionInfo];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    label.alpha = [self.delegate animatable] ? 0 : 1;
    label.textColor = [UIColor whiteColor];
    label.text = [NSString stringWithFormat:@"%.0f", internalSectionInfo.percentage * 100];
    label.font = [UIFont boldSystemFontOfSize:8];
    
    if (internalSectionInfo.percentage <= 0.01)
    {
        label.textColor = [UIColor blackColor];
        if (index%2 == 0)
        {
            labelRadius = self.externalRadius + 20;
        }
        else
        {
            labelRadius = self.externalRadius + 10;
        }
    } else if (internalSectionInfo.percentage == 1)
    {
        label.frame = CGRectMake(0, 0, 15, 10);
    }
    
    CGFloat middleAngle = (internalSectionInfo.initialAngle + internalSectionInfo.finalAngle) / 2.0;
    CGPoint textLabelCenter = CGPointMake(internalSectionInfo.layer.position.x  + labelRadius * cos(middleAngle), internalSectionInfo.layer.position.y + labelRadius * sin(middleAngle));
    
    
    label.textAlignment = NSTextAlignmentCenter;
    label.center = textLabelCenter;

    [self.labels addObject:label];
    [self addSubview:label];

    
}

- (void)showLabels
{
    for (UILabel *label in self.labels)
    {
        [UIView animateWithDuration:0.3 animations:^{
            label.alpha = 1.0;
        }];
    }
}

#pragma mark - Reloading

- (void)invalidateCache
{
    // Invalidate cache
    self.cachedInitialAngle = [self.dataSource initialAngle];
    self.cachedNumberOfSections = [self.dataSource numberOfSections];
    self.cachedSectionsWidth = [[self dataSource] sectionsWidth];
    // copy the sections
}


- (void)reloadSections
{
    [self invalidateCache];
    [self setupSections];
}

@end