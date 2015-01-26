//
//  FilmRollViewController.h
//  DisposableCamera
//
//  Created by Bobby Ren on 1/25/15.
//  Copyright (c) 2015 Bobby Ren Tech. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FilmRollViewController : UIViewController <UINavigationControllerDelegate>
{
    IBOutlet UIScrollView *scrollView;
}

@property (weak, nonatomic) NSArray *images;
@end
