var frames = 0;

function onDrawFrame(ctx, frame) {
  // Match width/height to remove distortion
  ctx.canvas.width  = ctx.canvas.offsetWidth;
  ctx.canvas.height = ctx.canvas.offsetHeight;

  // Determine how many pikachus will fit on screen
  var n = Math.floor((ctx.canvas.width)/150)

  for(var x = 0; x < n; x++) {
    // Draw a pikachu
    var left = x * 150;
    ctx.globalCompositeOperation = 'source-over';
    ctx.drawImage(frame.buffer, frame.x + left, frame.y, 150, 100);

    // Composite a color
    var hue = (frames * 10 + x * 50) % 360;
    ctx.globalCompositeOperation = 'source-atop';
    ctx.fillStyle = 'hsla(' + hue + ', 100%, 50%, 0.5)';
    ctx.fillRect(left, 0, 150, this.height);
  }
  frames++;
}

// Load and parse the GIF, returning an Animator
gifler('assets/gif/run.gif')
  .frames('canvas.rainbow-pikachus', onDrawFrame);