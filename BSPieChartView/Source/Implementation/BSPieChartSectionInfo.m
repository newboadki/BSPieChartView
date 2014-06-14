//
//  BSPieChartSectionInfo.m
//  BSPieChartView
//
//  Created by Borja Arias Drake on 29/05/2014.
//  Copyright (c) 2014 Borja Arias Drake. All rights reserved.
//

#import "BSPieChartSectionInfo.h"

@implementation BSPieChartSectionInfo

- (instancetype)initWithName:(NSString *)name percentage:(CGFloat)percentage color:(UIColor *)color
{
    self = [super init];
    
    if (self)
    {
        _name = [name copy];
        _percentage = percentage;
        _color = color;
    }
    
    return self;
}

@end