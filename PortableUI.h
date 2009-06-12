/*
 *  PortableUI.h
 *  Xstrument
 *
 *  Created by Robert Fielding on 6/11/09.
 *  Copyright 2009 Check Point Software. All rights reserved.
 *
 */

#import "MusicTheory.h"



/*
   Initialize the user interface
 */
void portableui_init();

/*
   The OpenGL part of painting
 */
void portableui_repaint();

/*
   Invoke this in response to host window size changes.  Standard OpenGL stuff.
 */
void portableui_reshape(float width,float height);