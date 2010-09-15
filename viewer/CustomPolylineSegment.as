/**
 * The MIT License	
 * 
 * Copyright (c) 2009 Ghost Interactive
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 * ghostinteractive@gmail.com
 */

package
{
	import flash.display.JointStyle;
	import flash.geom.Point;
	
	import net.ghostinteractive.overlays.PolylineSegment;

	public class CustomPolylineSegment extends PolylineSegment
	{
		/**
		 * Constructor
		 * CustomPolylineSegment defines line properties, this class nor it's 
		 * super-class actually draw the line, it only stores properties 
		 * that inform a PolyLine layer of what to draw
		 * 
		 * @param startPos	The start point of a line segment relative to the 
		 *					original size of the source image 
		 * 
		 * @param endPos	The end point of a line segment relative to the 
		 *					original size of the source image
		 */
		public function CustomPolylineSegment( startPos:Point, endPos:Point )
		{
			super();
			_thickness	= 2;
			_start		= startPos;
			_end		= endPos;
			_color		= Math.random() * 0xFFFFFF;
		}
	}
}