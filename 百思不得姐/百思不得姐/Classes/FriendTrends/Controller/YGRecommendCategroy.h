//
//  YGRecommendCategroy.h
//  百思不得姐
//
//  Created by 刘勇刚 on 16/2/17.
//  Copyright © 2016年 liu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YGRecommendCategroy : NSObject
/**
 *  id
 */
@property (assign, nonatomic) NSInteger id;
/**
 *  总数
 */
@property (assign, nonatomic) NSInteger count;
/**
 *  名字
 */
@property (copy, nonatomic) NSString *name;
@end
