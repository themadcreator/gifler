{GifReader} = require 'omggif'

# http://www.w3.org/Graphics/GIF/spec-gif89a.txt

###
Load and animate the gif.

Arguments:
  url      - The URL of the gif to be loaded with an XMLHttpRequest.
  callback - Predicate argument than can be any one of the following:
              - function - called with a new instance of Animator
              - string - a query selector for a canvas element
              - canvas - a canvas element
###
gifler = (url) ->
  # Prepare XHR
  xhr = new XMLHttpRequest()
  xhr.open('GET', url, aync = true)
  xhr.responseType = 'arraybuffer'

  return {
    xhr
    get : (callback) ->
      xhr.onload = wrapXhrCallback(callback)
      xhr.send()
      return @
    animate : (selector) ->
      canvas = getCanvasElement(selector)
      xhr.onload = wrapXhrCallback((animator) -> return animator.animateInCanvas(canvas))
      xhr.send()
      return @
    frames : (selector, onDrawFrame, setCanvasDimesions = false) ->
      canvas = getCanvasElement(selector)
      xhr.onload = wrapXhrCallback((animator) ->
        animator.onDrawFrame = onDrawFrame
        return animator.animateInCanvas(canvas, setCanvasDimesions)
      )
      xhr.send()
      return @
  }

wrapXhrCallback = (callback) ->
  return (e) -> callback new Animator(new GifReader(new Uint8Array(@response)))

getCanvasElement = (selector) ->
  if typeof selector is 'string' and (element = document.querySelector(selector))?.tagName is 'CANVAS'
    return element
  else if selector?.tagName is 'CANVAS'
    return selector
  else
    throw new Error('Unexpected selector type. Valid types are query-selector-string/canvas-element')

###
Creates a buffer canvas element since it is much faster to putImage than
putImageData.

The omggif library decodes the pixels into the full gif dimensions. We only
need to store the frame dimensions, so we offset the putImageData call.
###
createBufferCanvas = (frame, width, height) ->
  # Create empty buffer
  bufferCanvas        = document.createElement('canvas')
  bufferContext       = bufferCanvas.getContext('2d')
  bufferCanvas.width  = frame.width
  bufferCanvas.height = frame.height

  # Create image date from pixels
  imageData = bufferContext.createImageData(width, height)
  imageData.data.set(frame.pixels)

  # Fill canvas with image data
  bufferContext.putImageData(imageData, -frame.x, -frame.y)
  return bufferCanvas

###
Decodes the pixels for each frame (decompressing and de-interlacing) into a
Uint8ClampedArray, which is suitable for canvas ImageData.
###
decodeFrames = (reader, frameIndex) ->
  return [0...reader.numFrames()].map (frameIndex) =>
    frameInfo = reader.frameInfo(frameIndex)
    frameInfo.pixels = new Uint8ClampedArray(reader.width * reader.height * 4)
    reader.decodeAndBlitFrameRGBA(frameIndex, frameInfo.pixels)
    return frameInfo

class Animator
  constructor : (@_reader) ->
    {@width, @height} = @_reader
    @_frames     = decodeFrames(@_reader)
    @_loopCount  = @_reader.loopCount()
    @_loops      = 0
    @_frameIndex = 0
    @_running    = false

  start : ->
    @_lastTime = new Date().valueOf()
    @_delayCompensation = 0
    @_running = true

    setTimeout(@_nextFrame, 0)
    return @

  stop : ->
    @_running = false
    return @

  reset : ->
    @_frameIndex = 0
    @_loops = 0
    return @

  _nextFrame : =>
    requestAnimationFrame(@_nextFrameRender)
    return

  _nextFrameRender : =>
    return unless @_running

    # Render frame with callback.
    frame = @_frames[@_frameIndex]
    @onFrame?.apply(@, [frame, @_frameIndex])

    @_enqueueNextFrame()

  _advanceFrame : =>
    # If we are at the end of the animation, either loop or stop.
    @_frameIndex += 1
    if @_frameIndex >= @_frames.length
      if @_loopCount isnt 0 and @_loopCount is @_loops
        @stop()
      else
        @_frameIndex = 0
        @_loops += 1
    return

  _enqueueNextFrame : ->
    @_advanceFrame()

    while @_running
      frame = @_frames[@_frameIndex]

      # Perform frame delay compensation to make sure each frame is drawn at
      # the right time. This helps canvas GIFs match native img GIFs timing.
      delta = new Date().valueOf() - @_lastTime
      @_lastTime += delta
      @_delayCompensation += delta

      frameDelay  = frame.delay * 10
      actualDelay = frameDelay - @_delayCompensation
      @_delayCompensation -= frameDelay

      # Skip frames while our frame timeout is negative. This is necessary
      # because browsers such as Chrome will disable javascript while the
      # window is not in focus. When we re-focus the window, it would attempt
      # render all the missed frames as fast as possible.
      if actualDelay < 0
        @_advanceFrame()
        continue
      else
        setTimeout(@_nextFrame, actualDelay)
        break
    return

  animateInCanvas : (canvas, setDimension = true) ->
    if setDimension
      canvas.width  = @width
      canvas.height = @height

    ctx = canvas.getContext('2d')

    @onDrawFrame ?= (ctx, frame, i) ->
      ctx.drawImage(frame.buffer, frame.x, frame.y)

    @onFrame ?= (frame, i) =>
      # Lazily create canvas buffer.
      frame.buffer ?= createBufferCanvas(frame, @width, @height)

      # Handle frame disposal.
      @disposeFrame?()
      switch frame.disposal
        when 2
          @disposeFrame = -> ctx.clearRect(0, 0, canvas.width, canvas.height)
        when 3
          saved = ctx.getImageData(0, 0, canvas.width, canvas.height)
          @disposeFrame = -> ctx.putImageData(saved, 0, 0)
        else
          @disposeFrame = null

      # Draw current frame.
      @onDrawFrame?.apply(@, [ctx, frame, i])

    # Start animation.
    @start()
    return @

# Return gifler function as main entry point
gifler.Animator           = Animator
gifler.decodeFrames       = decodeFrames
gifler.createBufferCanvas = createBufferCanvas

# Export
window?.gifler  = gifler
module?.exports = gifler
