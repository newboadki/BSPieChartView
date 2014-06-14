//
//  BSPieChartSectionInfo.h
//  BSPieChartView
//
//  Created by Borja Arias Drake on 29/05/2014.
//  Copyright (c) 2014 Borja Arias Drake. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BSPieChartSectionInfo : NSObject

@property (nonatomic, copy)   NSString *name;

@property (nonatomic, assign) CGFloat percentage;

@property (nonatomic, strong) UIColor *color;

- (instancetype)initWithName:(NSString *)name percentage:(CGFloat)percentage color:(UIColor *)color;

@end
