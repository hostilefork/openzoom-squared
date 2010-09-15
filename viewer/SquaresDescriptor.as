/**
 * SquaresDescriptor.as
 * Grid metrics and per-square information for the OpenZoom-Squared grid
 *
 *     http://hostilefork.com/openzoom-squared/
 *
 * Hacked together by The Hostile Fork (http://hostilefork.com)
 * License: MPL 1.1/GPL 3/LGPL 3
 * 
 * The description of the information for each square is stored in an XML
 * file, which provides some parameters about the file (square size, rows
 * and columns) as well as a label for each square and the hyperlink to
 * activate when you click a certain square.
 *
 * For insights and debate on the format choice, check this StackOverflow
 * question:
 *
 *     http://stackoverflow.com/questions/3692553/defining-an-xml-format-for-a-2d-array-grid-of-items
 *
 * SquaresDescriptor is a class which reads in the XML file, and answers
 * various questions mapping image coordinates into the rows and columns.
 */

package
{
	
import flash.geom.Point
import flash.geom.Rectangle
import flash.events.MouseEvent

import flash.events.Event

import flash.net.URLLoader
import flash.net.URLRequest

import org.openzoom.flash.utils.IDisposable

import org.openzoom.flash.components.MultiScaleImage
import org.openzoom.flash.descriptors.IMultiScaleImageDescriptor

public class SquaresDescriptor implements IDisposable
{	
    private var _source:String
	private var xmlRoot:XML
	
	private var url:String
    private var urlLoader:URLLoader

	
	/**
	 * INITIALIZATION
	 *
	 * Currently the constructor makes a "blank" object.  Instead you assign a 
	 * URL to the "source" property and that triggers the load.  I just followed
	 * the precedent set in the OpenZoom SDK itself:
	 *
	 *     http://github.com/openzoom/sdk/blob/master/src/org/openzoom/flash/components/MultiScaleImage.as
	 *
	 * Revisit if not appropriate for this simple descriptor.
	 */
	
	public function SquaresDescriptor()
	{
	}

    public function get source():String
    {
        return _source
    }

    public function set source(value:String):void
    {
    	if (String(value) === url)
        	return

        url = String(value)

        urlLoader = new URLLoader(new URLRequest(url))

        urlLoader.addEventListener(Event.COMPLETE,
								   urlLoader_completeHandler,
								   false, 0, true)

        if (_source)
        {
            _source = null
			xmlRoot = null
        }
    }
	
	
	/**
	 * IMAGE COORDINATE TRANSFORMATIONS
	 *
	 * Note that transforming from viewport coordinates to image coordinates came from this
	 * code:
	 * 
	 *     http://github.com/openzoom/sdk/raw/fc0923325c446b8395bc522b08328b788614c686/examples/flex/coordinates/src/Coordinates.mxml
	 *
	 * There is a discussion about the topic here:
	 *
	 *     http://community.openzoom.org/openzoom/topics/how_can_i_convert_mouse_click_coordinates_into_image_coordinates
	 */
	
	public function getImagePointFromMouseEvent(image:MultiScaleImage,event:MouseEvent):Point
	{
		var componentPoint:Point = image.globalToLocal(new Point(event.stageX, event.stageY))
		var scenePoint:Point = image.localToScene(componentPoint)
	
		// Remember: Scene dimensions != image dimensions (scene currently
		// has largest dimension == 16384 (2^14) for best rendering in Flash
		// Player, might change in the future, though).
		// Always normalize (map to [0, 1]) to scene through division by
		// scene dimensions (scene.sceneWidth & scene.sceneHeight) and
		// then map to image coordinates through multiplication with
		// descriptor dimensions (image.source.width & image.source.height)
	
		var descriptor:IMultiScaleImageDescriptor = image.source as IMultiScaleImageDescriptor
		if (!descriptor)
			return null
					
		var imagePoint:Point = scenePoint.clone()
		imagePoint.x /= image.sceneWidth
		imagePoint.y /= image.sceneHeight
		imagePoint.x *= descriptor.width
		imagePoint.y *= descriptor.height
	
		if (0 <= imagePoint.x && imagePoint.x <= descriptor.width &&
			0 <= imagePoint.y && imagePoint.y <= descriptor.height)
		{
			return imagePoint
		}
		
		// This routine returns null if mouse event did not happen inside of the image
		return null
	}
	
	public function getColumnFromImagePoint(imagePoint:Point):Number
	{
		var result:Number = 1 + Math.floor(imagePoint.x / (squareWidth + horizontalSpacing))
		if (result > numColumns)
			return numColumns // TODO: review why this ever happens
		return result
	}
	
	public function getRowFromImagePoint(imagePoint:Point):Number
	{
		var result:Number = 1 + Math.floor(imagePoint.y / (squareHeight + horizontalSpacing))
		if (result > numRows)
			return numRows // TODO: review why this ever happens
		return result
	}
	
	
	/**
	 * PER-SQUARE PROPERTY EXTRACTION
	 *
	 * These are public routines.  Note that the rows and columns are 1-based and
	 * passed in by the column first with the row second.
	 */

	public function getRectangleForColumnAndRow(column:Number, row:Number):Rectangle
	{
		return new Rectangle(
						(column - 1) * (squareWidth + horizontalSpacing),
						(row - 1) * (squareHeight + verticalSpacing),
						squareWidth,
						squareHeight
		)
	}
	
	private function getSquareElementForColumnAndRow(column:Number, row:Number):XML
	{
		if (xmlRoot == null)
			return null
	
		var columnElement:XML = xmlRoot.column[column - 1]
		var squareElement:XML = columnElement.square[row - 1]
		return squareElement
	}
	
	public function getLabelForColumnAndRow(column:Number, row:Number):String
	{
		var squareElement:XML = getSquareElementForColumnAndRow(column, row);
		if (squareElement == null)
			return "" // assigning null would coerce to ""
		return squareElement.@label
	}
	
	public function getUrlForColumnAndRow(column:Number, row:Number):String
	{
		var squareElement:XML = getSquareElementForColumnAndRow(column, row);
		if (squareElement == null)
			return "" // assigning null would coerce to "" 
		return squareElement.@url
	}
	
	
	/*
	 * OVERALL GRID PROPERTIES
	 *
	 * These are properties of the whole grid.  Currently they are private methods,
	 * because you can use the per-square property extractions instead.
	 */
	
	private function get squareWidth():Number
	{
		if (xmlRoot == null)
			return 1
		return xmlRoot.@squareWidth
	}
	
	private function get squareHeight():Number
	{
		if (xmlRoot == null)
			return 1
		return xmlRoot.@squareHeight
	}
	
	private function get horizontalSpacing():Number
	{
		if (xmlRoot == null)
			return 1
		return xmlRoot.@horizontalSpacing
	}
	
	private function get verticalSpacing():Number
	{
		if (xmlRoot == null)
			return 1
		return xmlRoot.@verticalSpacing
	}
	
	private function get numRows():Number
	{
		if (xmlRoot == null)
			return 0
		return xmlRoot.@numRows
	}
	
	private function get numColumns():Number
	{
		if (xmlRoot == null)
			return 0
		return xmlRoot.@numColumns
	}

	
	/**
	 * EVENT HANDLERS
	 *
	 * ActionScript3's "XML" type is different from ActionScript2's "XML" type
	 * (which had its own load method).  Instead you are supposed to use the
	 * UrlLoader for asynchronous loading of data from a URL, and then create
	 * the XML data in the completion handler.
	 *
	 * At first I was following precedent from the SDK, which seems to have 
	 * more sophisticated error handling with "urlLoader_ioErrorHandler" and
	 * "urlLoader_securityErrorHandler":
	 *
	 *     http://github.com/openzoom/sdk/blob/master/src/org/openzoom/flash/components/MultiScaleImage.as
	 *
	 * But I'm not sure quite what that buys you, and also "dispatchEvent" is
	 * not available in non-GUI classes like this one.  So if there's an
	 * error in the XML, this will just crash out with the default handler.
	 */
	
    private function urlLoader_completeHandler(event:Event):void
    {
        if (!urlLoader || !urlLoader.data)
            return

        xmlRoot = new XML(urlLoader.data)

        _source = url
    }

	
	/**
	 * DISPOSAL
	 *
	 * It seems that if you have an object which may have an outstanding
	 * UrlLoader request, it's good to cancel it.  Precedent from OpenZoom SDK:
	 *
	 *      http://github.com/openzoom/sdk/blob/master/src/org/openzoom/flash/components/MultiScaleImage.as
	 *
	 * Note that dispose() is only called if your object implements IDisposable
     */
	
    public function dispose():void
    {
    	try
    	{
	    	urlLoader.close()
    	}
    	catch(error:Error)
    	{
    		// Do nothing
    	}
    	
    	urlLoader = null
    }	
}

}