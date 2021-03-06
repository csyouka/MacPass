//
//  MPFileWatcher.m
//  MacPass
//
//  Created by Michael Starke on 17/12/14.
//  Copyright (c) 2014 HicknHack Software GmbH. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "MPFileWatcher.h"

@interface MPFileWatcher ()

@property (copy) NSURL *URL;
@property (copy) MPFileWatcherBlock block;
@property (assign) int fileDescriptor;
@property (strong) dispatch_queue_t queue;
@property (strong) dispatch_source_t source;

@end

@implementation MPFileWatcher

+ (instancetype)fileWatcherWithURL:(NSURL *)url changeBlock:(MPFileWatcherBlock)block {
  return [[MPFileWatcher alloc] initWithURL:url changeBlock:block];
}

- (instancetype)initWithURL:(NSURL *)url changeBlock:(MPFileWatcherBlock)block {
  NSAssert([url isFileURL], @"URL needs to be a valid file URL");
  self = [super init];
  if(self) {
    _block = [block copy];
    _URL = [url copy];
    _queue = dispatch_queue_create("MPFileMonitor Queue", 0);
  }
  return self;
}

- (void)startMonitoring
{
  @synchronized(self) {
    if(self.source) {
      return;
    }
    
    self.fileDescriptor = open([self.URL.path fileSystemRepresentation], O_EVTONLY);
    
    if(!self.fileDescriptor) {
      return;
    }
    
    // watch the file descriptor for writes
    self.source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, self.fileDescriptor, DISPATCH_VNODE_WRITE, self.queue);
    
    // call the passed block if the source is modified
    
    /*   dispatch_source_set_event_handler(source, ^{
     unsigned long flags = dispatch_source_get_data(source);
     if(flags & DISPATCH_VNODE_DELETE) {
     dispatch_source_cancel(source);
     [blockSelf watchFileAtURL:url];
     }
     }); */
    
    dispatch_source_set_event_handler(self.source, self.block);
    
    // close the file descriptor when the dispatch source is canceled
    dispatch_source_set_cancel_handler(self.source, ^{
      
      close(self.fileDescriptor);
    });
    
    // at this point the dispatch source is paused, so start watching
    dispatch_resume(self.source);
  }
}

- (void)stopMonitoring {
  @synchronized(self) {
    if(!self.source) {
      return;
    }
    dispatch_source_cancel(self.source);
    self.source = nil;
  }
}
@end
