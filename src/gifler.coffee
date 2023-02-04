{GifReader} = require 'omggif'
Promise     = require 'bluebird'

# For more on the file format for GIFs
# http://www.w3.org/Graphics/GIF/spec-gif89a.txt

###---
head : 'gifler()'
text :
  - This is the main entrypoint to the library.
  - Prepares and sends an XHR request to load the GIF file.
  - Returns a <b>Gif</b> instance for interacting with the library.
args : 
  url : 'URL to .gif file'
return : 'a Gif instance object'
###
gifler = (url) ->
  # Prepare XHR
  xhr = new XMLHttpRequest()
  xhr.open('GET', url, aync = true)
  xhr.responseType = 'arraybuffer'

  promise = new Promise((resolve, reject) ->
    xhr.onload = (e) -> resolve(@response)
  )
  xhr.send()
  return new Gif(promise)

class Gif
  @getCanvasElement : (selector) ->
    if typeof selector is 'string' and (element = document.querySelector(selector))?.tagName is 'CANVAS'
      return element
    else if selector?.tagName is 'CANVAS'
      return selector
    else
      throw new Error('Unexpected selector type. Valid types are query-selector-string/canvas-element')

  constructor : (dataPromise) ->
    @_animatorPromise = dataPromise.then (data) ->
      reader = new GifReader(new Uint8Array(data))
      return Decoder.decodeFramesAsync(reader).then (frames) ->
        return new Animator(reader, frames)

  ###---
  head : 'gif.animate()'
  text :
    - >
      Animates the loaded GIF, drawing each frame into the canvas.
      This matches the look of an &lt;img&gt; tag.
  args : 
    selector : 'A <canvas> element or query selector for a <canvas> element.'
  ###
  animate : (selector) ->
    canvas = Gif.getCanvasElement(selector)
    return @_animatorPromise.then (animator) -> animator.animateInCanvas(canvas)

  ###---
  head : 'gif.frames()'
  text :
    - >
      Runs the animation on the loaded GIF, but passes the
      canvas context and GIF frame to the <b>onDrawFrame</b>
      callback for rendering.
    - >
      This gives you complete control of how the frame is drawn
      into the canvas context.
  args : 
    selector     : 'A <canvas> element or query selector for a <canvas> element.'
    onDrawFrame  : 'A callback that will be invoked when each frame should be drawn into the canvas. see Animator.onDrawFrame.'
    setDimesions : 'OPTIONAL. If true, the canvas''s width/height will be set to the dimension of the loaded GIF. default: false.'
  ###
  frames : (selector, onDrawFrame, setCanvasDimesions = false) ->
    canvas = Gif.getCanvasElement(selector)
    return @_animatorPromise.then (animator) ->
      animator.onDrawFrame = onDrawFrame
      animator.animateInCanvas(canvas, setCanvasDimesions)

  ###---
  head : 'gif.get()'
  text :
    - >
      To get even more control, and for your convenience,
      this method returns a promise that will be fulfilled with
      an <b>Animator</b> instance. The animator will be in an unstarted state,
      but can be started with a call to <b>animator.animateInCanvas()</b>
  ###
  get : (callback) ->
    return @_animatorPromise

###
These methods decode the pixels for each frame (decompressing and de-interlacing)
into a Uint8ClampedArray, which is suitable for canvas ImageData.
###
class Decoder
  @decodeFramesSync : (reader) ->
    return [0...reader.numFrames()].map (frameIndex) ->
      return Decoder.decodeFrame(reader, frameIndex)

  @decodeFramesAsync : (reader) ->
    return Promise.map([0...reader.numFrames()], ((i) -> Decoder.decodeFrame(reader, i)), concurrency = 1)

  @decodeFrame : (reader, frameIndex) ->
    frameInfo = reader.frameInfo(frameIndex)
    frameInfo.pixels = new Uint8ClampedArray(reader.width * reader.height * 4)
    reader.decodeAndBlitFrameRGBA(frameIndex, frameInfo.pixels)
    return frameInfo

class Animator
  ###---
  head : 'animator::createBufferCanvas()'
  text :
    - >
      Creates a buffer canvas element since it is much faster
      to call <b>.putImage()</b> than <b>.putImageData()</b>.
    - >
      The omggif library decodes the pixels into the full gif
      dimensions. We only need to store the frame dimensions,
      so we offset the putImageData call.
  args :
    frame  : A frame of the GIF (from the omggif library)
    width  : width of the GIF (not the frame)
    height : height of the GIF
  return : A <canvas> element containing the frame's image.
  ###
  @createBufferCanvas : (frame, width, height) ->
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

  constructor : (@_reader, @_frames) ->
    {@width, @height} = @_reader
    @_loopCount  = @_reader.loopCount()
    @_loops      = 0
    @_frameIndex = 0
    @_running    = false

  ###---
  head : 'animator.start()'
  text :
    - Starts running the GIF animation loop.
  ###
  start : ->
    @_lastTime = new Date().valueOf()
    @_delayCompensation = 0
    @_running = true

    setTimeout(@_nextFrame, 0)
    return @

  ###---
  head : 'animator.stop()'
  text :
    - Stops running the GIF animation loop.
  ###
  stop : ->
    @_running = false
    return @

  ###---
  head : 'animator.reset()'
  text :
    - Resets the animation loop to the first frame.
    - Does not stop the animation from running.
  ###
  reset : ->
    @_frameIndex = 0
    @_loops = 0
    return @

  ###---
  head : 'animator.running()'
  return : A boolean indicating whether or not the animation is running.
  ###
  running : ->
    return @_running

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

  ###---
  head : 'animator.animateInCanvas()'
  text :
    - >
      This method prepares the canvas to be drawn into and sets up
      the callbacks for each frame while the animation is running.
    - >
      To change how each frame is drawn into the canvas, override
      <b>animator.onDrawFrame()</b> before calling this method.
      If <b>animator.onDrawFrame()</b> is not set, we simply draw
      the frame directly into the canvas as is.
    - >
      You may also override <b>animator.onFrame()</b> before calling
      this method. onFrame handles the lazy construction of canvas
      buffers for each frame as well as the disposal method for each frame.
  args :
    canvas        : A canvas element.
    setDimensions : 'OPTIONAL. If true, the canvas width/height will be set to match the GIF. default: true.'
  ###
  animateInCanvas : (canvas, setDimensions = true) ->
    if setDimensions
      canvas.width  = @width
      canvas.height = @height

    ctx = canvas.getContext('2d')

    @onDrawFrame ?= (ctx, frame, i) ->
      ctx.drawImage(frame.buffer, frame.x, frame.y)

    @onFrame ?= (frame, i) =>
      # Lazily create canvas buffer.
      frame.buffer ?= Animator.createBufferCanvas(frame, @width, @height)

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
      @onDrawFrame?.apply(@, [ctx, frame, i, @])

    # Start animation.
    @start()
    return @

# Attach classes to API function
gifler.Gif      = Gif
gifler.Decoder  = Decoder
gifler.Animator = Animator

# Export
window?.gifler  = gifler
module?.exports = gifler
