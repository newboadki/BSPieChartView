//
//  BSPieChartView.h
//  PathLayers
//
//  Created by Borja Arias Drake on 17/05/2014.
//  Copyright (c) 2014 Borja Arias Drake. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BSPieChartSectionInfo;


@protocol BSPieChartDelegate <NSObject>

/*! Tell the view to prepare for being animated. Has an impact on performance as this flag will cause animation keyframes to be calculated.*/
- (BOOL)animatable;

- (BOOL)clockWise;

- (void)animationDidFinish;

@end



@protocol BSPieChartDataSource <NSObject>

@required
- (NSUInteger)numberOfSections;

- (BSPieChartSectionInfo *)sectionInfoForIndex:(NSUInteger)index;

- (CGFloat)sectionsWidth;

- (CGFloat)initialAngle;

@end





@interface BSPieChartView : UIView

@property (nonatomic, weak) IBOutlet id <BSPieChartDelegate> delegate;

@property (nonatomic, weak) IBOutlet id <BSPieChartDataSource> dataSource;

/*! Performs the animation.*/
- (void)animate;

/*! Forces the data to be reloaded from the data source methods*/
- (void)reloadSections;


@end






