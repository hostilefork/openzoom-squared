﻿/*
 * CustomMouseController.as 
 * Custom click and SquaresDescriptor-aware variant of MouseController.as
 * 
 *	   http://hostilefork.com/openzoom-squared/
 * 
 * Hacked together by The Hostile Fork (http://hostilefork.com)
 * License: MPL 1.1/GPL 3/LGPL 3
 *
 * The source from which this is derived is a file in the OpenZoom SDK:
 * 
 *	   http://github.com/openzoom/sdk/blob/master/src/org/openzoom/flash/viewport/controllers/MouseController.as
 *
 *	"OpenZoom SDK
 *	 http://openzoom.org/
 *
 *	 Developed by Daniel Gasienica <daniel@gasienica.ch>
 *	 License: MPL 1.1/GPL 3/LGPL 3"
 * 
 * The default MouseController in the SDK did not provide a hook for giving 
 * your own response to a click.  Since the mouse methods were private and not
 * possible to override, it seemed the best way to implement alternative 
 * functionality was to copy the code into a new class and edit the controller
 * directly.
 */

package
{

import flash.events.Event
import flash.events.MouseEvent
import flash.events.TimerEvent
import flash.geom.Point
import flash.geom.Rectangle
import flash.utils.Timer

import org.openzoom.flash.core.openzoom_internal
import org.openzoom.flash.utils.math.clamp
import org.openzoom.flash.viewport.IViewportController
import org.openzoom.flash.viewport.controllers.ViewportControllerBase

import org.openzoom.flash.components.MultiScaleImage
import SquaresDescriptor

use namespace openzoom_internal

import flash.net.navigateToURL
import flash.net.URLRequest

/**
 * Mouse controller for viewports.
 */
public final class CustomMouseController extends ViewportControllerBase
								   implements IViewportController
{

	
	//--------------------------------------------------------------------------
	//
	//	Class constants
	//
	//--------------------------------------------------------------------------

	private static const CLICK_THRESHOLD_DURATION:Number = 500 // milliseconds
	private static const CLICK_THRESHOLD_DISTANCE:Number = 8 // pixels

	private static const DEFAULT_CLICK_ZOOM_IN_FACTOR:Number = 2.0
	private static const DEFAULT_CLICK_ZOOM_OUT_FACTOR:Number = 0.3

	private static const DEFAULT_MOUSE_WHEEL_ZOOM_FACTOR:Number = 1.11

	private var image:MultiScaleImage
	private var squares:SquaresDescriptor
	
	//--------------------------------------------------------------------------
	//
	//	Constructor
	//
	//--------------------------------------------------------------------------

	/**
	 *	Constructor.
	 */
	public function CustomMouseController(imageParam:MultiScaleImage, squaresParam:SquaresDescriptor)
	{
		image = imageParam
		squares = squaresParam
		createClickTimer()		
	}

	//--------------------------------------------------------------------------
	//
	//	Variables
	//
	//--------------------------------------------------------------------------

	private var clickTimer:Timer
	private var click:Boolean = false
	private var mouseDownPosition:Point

	private var viewDragVector:Rectangle = new Rectangle()
	private var viewportDragVector:Rectangle = new Rectangle()
	private var panning:Boolean = false

	//----------------------------------
	//	minMouseWheelZoomInFactor
	//----------------------------------

	public var minMouseWheelZoomInFactor:Number = 1

	//----------------------------------
	//	minMouseWheelZoomOutFactor
	//----------------------------------

	public var minMouseWheelZoomOutFactor:Number = 1

	//----------------------------------
	//	smoothPanning
	//----------------------------------

	public var smoothPanning:Boolean = true

	//----------------------------------
	//	clickEnabled
	//----------------------------------

	public var clickEnabled:Boolean = true

	//----------------------------------
	//	clickZoomInFactor
	//----------------------------------

	private var _clickZoomInFactor:Number = DEFAULT_CLICK_ZOOM_IN_FACTOR

	/**
	 * Factor for zooming into the scene through clicking.
	 *
	 * @default 2.0
	 */
	public function get clickZoomInFactor():Number
	{
		return _clickZoomInFactor
	}

	public function set clickZoomInFactor(value:Number):void
	{
		_clickZoomInFactor = value
	}

	//----------------------------------
	//	clickZoomOutFactor
	//----------------------------------

	private var _clickZoomOutFactor:Number = DEFAULT_CLICK_ZOOM_OUT_FACTOR

	/**
	 * Factor for zooming out of the scene through Shift-/Ctrl-clicking.
	 *
	 * @default 0.3
	 */
	public function get clickZoomOutFactor():Number
	{
		return _clickZoomOutFactor
	}

	public function set clickZoomOutFactor(value:Number):void
	{
		_clickZoomOutFactor = value
	}

	//----------------------------------
	//	mouseWheelZoomFactor
	//----------------------------------

	private var _mouseWheelZoomFactor:Number = DEFAULT_MOUSE_WHEEL_ZOOM_FACTOR

	/**
	 * Factor for zooming the scene through the mouse wheel.
	 *
	 * @default 0.05
	 */
	public function get mouseWheelZoomFactor():Number
	{
		return _mouseWheelZoomFactor
	}

	public function set mouseWheelZoomFactor(value:Number):void
	{
		_mouseWheelZoomFactor = value
	}

	//--------------------------------------------------------------------------
	//
	//	Methods: Internal
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	private function createClickTimer():void
	{
		clickTimer = new Timer(CLICK_THRESHOLD_DURATION, 1)
		clickTimer.addEventListener(TimerEvent.TIMER_COMPLETE,
									clickTimer_completeHandler,
									false, 0, true)
	}

	//--------------------------------------------------------------------------
	//
	//	Overridden methods: ViewportControllerBase
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	override protected function view_addedToStageHandler(event:Event):void
	{
		// panning listeners
		view.addEventListener(MouseEvent.MOUSE_DOWN,
							  view_mouseDownHandler,
							  false, 0, true)
		view.addEventListener(MouseEvent.ROLL_OUT,
							  view_rollOutHandler,
							  false, 0, true)
		view.stage.addEventListener(Event.MOUSE_LEAVE,
									stage_mouseLeaveHandler,
									false, 0, true)

		// zooming listeners
		view.addEventListener(MouseEvent.MOUSE_WHEEL,
							  view_mouseWheelHandler,
							  false, 0, true)
	}

	/**
	 * @private
	 */
	override protected function view_removedFromStageHandler(event:Event):void
	{
		if (view)
		{
			// panning listeners
			view.removeEventListener(MouseEvent.MOUSE_DOWN,
									 view_mouseDownHandler)
			view.removeEventListener(MouseEvent.ROLL_OUT,
									 view_rollOutHandler)
									 
			if (view.stage) 
				view.stage.removeEventListener(Event.MOUSE_LEAVE,
											   stage_mouseLeaveHandler)
	
			// zooming listeners
			view.removeEventListener(MouseEvent.MOUSE_WHEEL,
									 view_mouseWheelHandler)
		}
	}

	//--------------------------------------------------------------------------
	//
	//	Event Handlers: Zooming
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	private function view_mouseWheelHandler(event:MouseEvent):void
	{
		// prevent zooming when panning
		if (panning)
			return

		// FIXME: Supposedly prevents unwanted scrolling in browsers
		// Though it doesn't seem to work http://www.actionscript.org/forums/showthread.php3?t=145307
		// Perhaps JavaScript could detect if the mouse is over the flash control and stop it?
		event.stopPropagation()

		// TODO: React appropriately to different platforms and/or browsers,
		// as they at times report completely different mouse wheel deltas.
		var factor:Number = clamp(Math.pow(mouseWheelZoomFactor, event.delta), 0.5, 3)

		// TODO: Refactor
		if (factor < 1)
			factor = Math.min(factor, minMouseWheelZoomOutFactor)
		else
			factor = Math.max(factor, minMouseWheelZoomInFactor)

		// compute normalized origin of mouse relative to viewport.
		var originX:Number = view.mouseX / view.width
		var originY:Number = view.mouseY / view.height

		// transform viewport
		viewport.zoomBy(factor, originX, originY)

		// TODO
		event.updateAfterEvent()
	}

	//--------------------------------------------------------------------------
	//
	//	Event Handlers: Panning
	//
	//--------------------------------------------------------------------------

	/**
	 * @private
	 */
	private function clickTimer_completeHandler(event:TimerEvent):void
	{
		click = false
		clickTimer.reset()
	}

	/**
	 * @private
	 */
	private function view_mouseDownHandler(event:MouseEvent):void
	{
		view.addEventListener(MouseEvent.MOUSE_UP,
							  view_mouseUpHandler,
							  false, 0, true)

		// remember mouse position
		mouseDownPosition = new Point(view.mouseX, view.mouseY)

		// assume mouse down is a click
		click = true

		// start click timer
		clickTimer.reset()
		clickTimer.start()

		// register where we are in the view as well as in the viewport
		viewDragVector.topLeft = new Point(view.mouseX, view.mouseY)
		viewportDragVector.topLeft = new Point(viewport.transformer.target.x,
											   viewport.transformer.target.y)

		beginPanning()
	}

	/**
	 * @private
	 */
	private function view_mouseMoveHandler(event:MouseEvent):void
	{
		if (!panning)
			return

		// update view drag vector
		viewDragVector.bottomRight = new Point(view.mouseX, view.mouseY)

		var distanceX:Number
		var distanceY:Number
		var targetX:Number
		var targetY:Number

		distanceX = viewDragVector.width / viewport.viewportWidth
		distanceY = viewDragVector.height / viewport.viewportHeight

		targetX = viewportDragVector.x - (distanceX * viewport.width)
		targetY = viewportDragVector.y - (distanceY * viewport.height)

		// FIXME: Zoom skipping when smoothPanning = false
		viewport.panTo(targetX, targetY, !smoothPanning)
	}

	// click action broken out into its own code so that it may be overridden
	protected function view_clickAction(imagePoint:Point):void
	{
		var column = squares.getColumnFromImagePoint(imagePoint);
		var row = squares.getRowFromImagePoint(imagePoint);
		
		var url:String = squares.getUrlForColumnAndRow(column, row)
		if (url == null)
			return
		
		var urlRequest:URLRequest = new URLRequest(url);
		navigateToURL(urlRequest, "_blank");
	}
	
	/**
	 * @private
	 */
	private function view_mouseUpHandler(event:MouseEvent):void
	{
		view.removeEventListener(MouseEvent.MOUSE_UP, view_mouseUpHandler)

		var mouseUpPosition:Point = new Point(view.mouseX, view.mouseY)
		var dx:Number = mouseUpPosition.x - mouseDownPosition.x
		var dy:Number = mouseUpPosition.y - mouseDownPosition.y

		var distance:Number = Math.sqrt(dx * dx + dy * dy)

		if (clickEnabled && click && distance < CLICK_THRESHOLD_DISTANCE)
		{
			var imagePoint:Point = squares.getImagePointFromMouseEvent(image, event)
			if (imagePoint != null)
			{
				if (event.shiftKey)
				{
					// Just keeping this here as a behavior for shift-click
					viewport.zoomBy(clickZoomInFactor,
								view.mouseX / view.width,
								view.mouseY / view.height)
				}
				else
				{
					view_clickAction(imagePoint)
				}
			}
		}

		click = false
		clickTimer.reset()

		stopPanning()
	}

	/**
	 * @private
	 */
	private function beginPanning():void
	{
		// begin panning
		panning = true

		// register for mouse move events
		view.addEventListener(MouseEvent.MOUSE_MOVE,
							  view_mouseMoveHandler,
							  false, 0, true)
	}

	/**
	 * @private
	 */
	private function stopPanning():void
	{
		// unregister from mouse move events
		// FIXME
		if (view)
			view.removeEventListener(MouseEvent.MOUSE_MOVE,
									 view_mouseMoveHandler)

		panning = false
	}

	/**
	 * @private
	 */
	private function stage_mouseLeaveHandler(event:Event):void
	{
		stopPanning()
	}

	/**
	 * @private
	 */
	private function view_rollOutHandler(event:MouseEvent):void
	{
		stopPanning()
	}
}

}
