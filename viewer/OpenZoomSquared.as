﻿/**
 * OpenZoomSquared.as
 * Clickable-square variation of OpenZoom's MultiScaleImageFlashCS3Example.as
 * 
 *	   http://hostilefork.com/openzoom-squared/
 *
 * Hacked together by The Hostile Fork (http://hostilefork.com)
 * License: MPL 1.1/GPL 3/LGPL 3
 *
 * The source from which this is derived is a file in the OpenZoom SDK:
 * 
 *	   http://github.com/openzoom/sdk/raw/master/examples/flash/cs3/multiscaleimage/MultiScaleImageFlashCS3Example.as
 * 
 *	"MultiScaleImage Component
 *	 OpenZoom SDK Example
 *	 http://openzoom.org/
 *
 *	 Developed by Daniel Gasienica <daniel@gasienica.ch>
 *	 License: MPL 1.1/GPL 3/LGPL 3"
 * 
 * This variant incorporates the ability to let the user hover and move a
 * rectangle around the Deep Zoom image, and to launch a URL when someone
 * performs a "click" operation.  Note this is not the same as a MOUSE_DOWN 
 * because if the mouse is pressed and then dragged some amount, the gesture
 * is interpreted as panning the image instead of clicking it.
 *
 * In order to layer a rectangle on top of the zoomable image which would
 * adapt its size as the user zoomed in and out, I tried out using the 
 * overlays component for OpenZoom by ghostinteractive:
 * 
 *	   http://labs.ghostinteractive.net/overlay-extension/
 *
 * Although the provided layers did not have a specific "rectangle" layer, the 
 * creation of four connected line segments in a PolyLine layer served for this
 * project at the moment, and gives a test case to feed back into the design of
 * a generalized overlay mechanism.
 */

package
{
	
import fl.controls.Button
import flash.display.MovieClip

import flash.events.Event
import flash.events.MouseEvent
import flash.display.Sprite
import flash.display.StageScaleMode
import flash.display.StageAlign

import flash.geom.Point
import flash.geom.Rectangle

import flash.net.navigateToURL
import flash.net.URLRequest

import org.openzoom.flash.components.MultiScaleImage
import org.openzoom.flash.descriptors.IMultiScaleImageDescriptor
import org.openzoom.flash.viewport.constraints.CenterConstraint
import org.openzoom.flash.viewport.constraints.CompositeConstraint
import org.openzoom.flash.viewport.constraints.ScaleConstraint
import org.openzoom.flash.viewport.constraints.VisibilityConstraint
import org.openzoom.flash.viewport.constraints.ZoomConstraint
import org.openzoom.flash.viewport.controllers.ContextMenuController
import org.openzoom.flash.viewport.controllers.KeyboardController
/* import org.openzoom.flash.viewport.controllers.MouseController */
import CustomMouseController
import org.openzoom.flash.viewport.transformers.TweenerTransformer

import org.openzoom.flash.utils.ExternalMouseWheel

import net.ghostinteractive.overlays.PolylineSegment
import CustomPolylineSegment 
import net.ghostinteractive.overlays.PolylineLayer

import SquaresDescriptor

public class OpenZoomSquared extends Sprite
{
	private var mouseController:CustomMouseController
	private var hoverLayer:PolylineLayer
	private var hoverRow:Number
	private var hoverColumn:Number

	private var leftEdgeSegment:CustomPolylineSegment
	private var rightEdgeSegment:CustomPolylineSegment
	private var topEdgeSegment:CustomPolylineSegment
	private var bottomEdgeSegment:CustomPolylineSegment
	
	private var squares:SquaresDescriptor
	
	public function OpenZoomSquared()
	{	
	// Setup stage
	stage.align = StageAlign.TOP_LEFT
	stage.scaleMode = StageScaleMode.NO_SCALE
	stage.addEventListener(Event.RESIZE, stage_resizeHandler)
	
	// This is supposed to make the mouse wheel work in Firefox on Mac, etc
	// but it doesn't seem to be doing any good
	// yet some other projects use this and seem to have it working (IsThisMyLuggage)
	// while some other projects use it and don't work (GigaPan)
	// ...?
	ExternalMouseWheel.initialize(stage)
	
	squares = new SquaresDescriptor();
	squares.source = "allsquares/squaresdescriptor.xml"
	
	// Create MultiScaleImage component
	image = new MultiScaleImage()
	
	hoverLayer = new PolylineLayer(image)
	// does not seem to get events if we add to polyline layer
	image.addEventListener(MouseEvent.MOUSE_MOVE, hover_mouseMoveHandler)
	image.addEventListener(MouseEvent.MOUSE_OUT, hover_mouseLeaveHandler);
																	 
	// Listen for complete event that marks that the
	// loading of the image descriptor has finished
	image.addEventListener(Event.COMPLETE, image_completeHandler)

	// Add transformer for smooth zooming
	// This effect is a little bit superfluous, but not as bad as the "Elastic"
	// Possibilities http://hosted.zeh.com.br/tweener/docs/en-us/
	var transformer:TweenerTransformer = new TweenerTransformer()
	transformer.easing = "easeOutQuint"
	transformer.duration = 0.5 // seconds
	image.transformer = transformer

	// Mouse Controller does event-to-image coordinate transformations for clicks
	// Thus it needs the MultiScaleImage and SquaresDescriptor to do so
	mouseController = new CustomMouseController(image, squares);
	
	// Add controllers for interactivity
	image.controllers = [mouseController,
						 new KeyboardController(),
						 new ContextMenuController()]

	// Create a composite constraint that can group
	// multiple constraint since the API of the MultiScaleImage
	// component only allows us to assign one constraint
	var constraint:CompositeConstraint = new CompositeConstraint()

	// Constrain the zoom to always show
	// the image at least at half its size
	var zoomConstraint:ZoomConstraint = new ZoomConstraint()
	zoomConstraint.minZoom = 0.5

	// Prepare a scale constraint that allows us to prevent
	// zooming in beyond the original scale of the image.
	// Note that we can only set the right maximum scale
	// after the image descriptor has loaded
	scaleConstraint = new ScaleConstraint()

	// Constrain the image to be centered when zooming out
	var centerConstraint:CenterConstraint = new CenterConstraint()

	// Ensure that at least 60% of the image
	// in both dimension is always visible
	var visibilityConstraint:VisibilityConstraint = new VisibilityConstraint()
	visibilityConstraint.visibilityRatio = 0.6

	// Group all the constraints in the composite constraint
	constraint.constraints = [zoomConstraint,
							  scaleConstraint,
							  centerConstraint,
							  visibilityConstraint]

	// Apply composite constraint to component
	image.constraint = constraint

	// Set the source image
	// TODO: Get parameter from invoker, ie web page like OpenZoom.swf does
	//image.source = "../../../../resources/images/deepzoom/billions.xml"
	image.source = "allsquares/allsquares.dzi"

	// Configure buttons
	showAllButton.addEventListener(MouseEvent.CLICK, showAllButton_clickHandler)
	zoomInButton.addEventListener(MouseEvent.CLICK, zoomInButton_clickHandler)
	zoomOutButton.addEventListener(MouseEvent.CLICK, zoomOutButton_clickHandler)
	hostileForkButton.addEventListener(MouseEvent.CLICK, hostileForkButton_clickHandler)
	
	// Layout the component
	layout()
	addChild(image)
	addChild(hoverLayer)

	// Set the child index to 0 so the image appears
	// as background, behind the buttons
	setChildIndex(image, 0)
	}

	private var image:MultiScaleImage
	private var scaleConstraint:ScaleConstraint

	public var showAllButton:Button
	public var zoomInButton:Button
	public var zoomOutButton:Button
	public var labelButton:Button
	public var hostileForkButton:Button
	public var hostileForkLogo:MovieClip
	
	private function eraseAnyHoverBoxWithoutValidating():void
	{
		if (leftEdgeSegment != null) // also matches undefined, use !=== if distinction is important
		{
			hoverLayer.removeSegment(leftEdgeSegment)
			leftEdgeSegment = null
			hoverLayer.removeSegment(rightEdgeSegment)
			rightEdgeSegment = null
			hoverLayer.removeSegment(topEdgeSegment)
			topEdgeSegment = null
			hoverLayer.removeSegment(bottomEdgeSegment)
			bottomEdgeSegment = null
		}
	}
	
	private function hover_mouseLeaveHandler(event:Event):void
	{
		eraseAnyHoverBoxWithoutValidating()
		hoverLayer.validateNow()
	}
	
	private function hover_mouseMoveHandler(event:MouseEvent):void
	{
		eraseAnyHoverBoxWithoutValidating();
		
		var imagePoint:Point = squares.getImagePointFromMouseEvent(image, event);
		
		if (imagePoint != null) 
		{
			// 1-based columns/rows from original art installation terminology
			var currentColumn:Number = squares.getColumnFromImagePoint(imagePoint)
			var currentRow:Number = squares.getRowFromImagePoint(imagePoint)
			
			var labelForSquare:String = squares.getLabelForColumnAndRow(currentColumn, currentRow);
			if (labelForSquare != "")
			{
				labelButton.label = labelForSquare
				labelButton.visible = true
				
				var hoverRectangle:Rectangle = squares.getRectangleForColumnAndRow(currentColumn, currentRow);
				
				// Flash leaves out topRight and bottomLeft properties.	 Sigh.
				var topRightPoint:Point = hoverRectangle.topLeft.add(new Point(hoverRectangle.width, 0))
				var bottomLeftPoint:Point = hoverRectangle.topLeft.add(new Point(0, hoverRectangle.height))
				
				// Currently using polyline layer in order to draw a hover rectangle
				leftEdgeSegment = new CustomPolylineSegment(hoverRectangle.topLeft, bottomLeftPoint)
				rightEdgeSegment = new CustomPolylineSegment(topRightPoint, hoverRectangle.bottomRight)
				topEdgeSegment = new CustomPolylineSegment(hoverRectangle.topLeft, topRightPoint)
				bottomEdgeSegment = new CustomPolylineSegment(bottomLeftPoint, hoverRectangle.bottomRight)
		
				hoverLayer.addSegment(leftEdgeSegment)
				hoverLayer.addSegment(rightEdgeSegment)
				hoverLayer.addSegment(topEdgeSegment)
				hoverLayer.addSegment(bottomEdgeSegment)
				labelButton.mouseEnabled = false
			}
			else
			{
				labelButton.visible = false
			}
		}
		else
		{
			labelButton.visible = false
		}

		hoverLayer.validateNow()
	}
	
	// Event handlers
	private function stage_resizeHandler(event:Event):void
	{
		layout()
	}

	private function image_completeHandler(event:Event):void
	{
		labelButton.visible = false
		
		var descriptor:IMultiScaleImageDescriptor = image.source as IMultiScaleImageDescriptor

		if (descriptor)
		{
			scaleConstraint.maxScale = descriptor.width / image.sceneWidth
								 // or descriptor.height / image.sceneHeight,
								 // as they're supposed to be the same
		}
	}

	private function zoomOutButton_clickHandler(event:Event):void
	{
		// Zoom out by a factor of 2
		image.zoom /= 2
	}

	private function zoomInButton_clickHandler(event:Event):void
	{
		// Zoom in by a factor of 1.8
		image.zoom *= 1.8
	}

	private function showAllButton_clickHandler(event:Event):void
	{
		image.showAll()
	}
	
	private function hostileForkButton_clickHandler(event:Event):void
	{
		var urlRequest:URLRequest = new URLRequest("http://hostilefork.com/openzoom-squared/");
		navigateToURL(urlRequest, "_blank");
	}


	// Layout
	private function layout():void
	{
		if (image)
		{
			image.width = stage.stageWidth
			image.height = stage.stageHeight
			
			// This line is copied from code that is in the PolylineLayer
			// constructor.	 But if you don't do it every time the image
			// is resized, then this gets out of sync and it won't draw
			// some of the polylines.
			hoverLayer.setActualSize( image.viewport.viewportWidth, image.viewport.viewportHeight );
		}

		zoomInButton.x = stage.stageWidth - zoomInButton.width - 10
		zoomInButton.y = stage.stageHeight - zoomInButton.height - 10

		zoomOutButton.x = zoomInButton.x - zoomOutButton.width - 4
		zoomOutButton.y = zoomInButton.y

		showAllButton.x = zoomOutButton.x - showAllButton.width - 4
		showAllButton.y = zoomOutButton.y
		
		hostileForkButton.x = showAllButton.x - hostileForkButton.width - 4
		hostileForkButton.y = showAllButton.y
		
		hostileForkLogo.x = hostileForkButton.x + (hostileForkButton.width - hostileForkLogo.width) / 2
		hostileForkLogo.y = hostileForkButton.y + (hostileForkButton.height - hostileForkLogo.height) / 2
		hostileForkLogo.mouseEnabled = false
		
		labelButton.x = 10
		labelButton.y = stage.stageHeight - labelButton.height - 10
	}

}

}
