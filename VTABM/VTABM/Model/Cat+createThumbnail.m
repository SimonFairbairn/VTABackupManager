//
//  Cat+createThumbnail.m
//  VTABM
//
//  Created by Simon Fairbairn on 08/10/2013.
//  Copyright (c) 2013 Simon Fairbairn. All rights reserved.
//

#import "Cat+createThumbnail.h"

@implementation Cat (createThumbnail)

-(void)setThumbnailDataFromImage:(UIImage *)image {
    
    CGSize originalSize = image.size;
    
    CGRect newRect = CGRectMake(0, 0, 40, 40);
    
    float ratio = MAX(newRect.size.width / originalSize.width, newRect.size.height / originalSize.height);
    
    UIGraphicsBeginImageContextWithOptions(newRect.size, YES, 0.0);
    
    CGRect projectRect;
    projectRect.size.width = ratio * originalSize.width;
    projectRect.size.height = ratio * originalSize.height;
    projectRect.origin.x = (newRect.size.width - projectRect.size.width) / 2.0f;
    projectRect.origin.y = (newRect.size.height - projectRect.size.height) / 2.0f;
    
    [image drawInRect:projectRect];
    
    UIImage *smallImage = UIGraphicsGetImageFromCurrentImageContext();
    
    self.thumbnail = UIImagePNGRepresentation(smallImage);
    
    UIGraphicsEndImageContext();
}

@end
