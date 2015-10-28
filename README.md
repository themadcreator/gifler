Animate GIFs in canvas.

- Loads GIF contents with XHR
- Decodes GIF frames and pixels with omggif
- Prepares canvas buffer for fast rendering
- Frame-by-frame animator

# Usage

```html
<canvas class="example"></canvas>
<script src="gifler.js"></script>
<script>gifler('image.gif').animate('.example')</script>
```