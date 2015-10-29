Animate GIFs in canvas.

<http://themadcreator.github.io/gifler/>

- Loads GIF contents with XHR
- Decodes GIF frames and pixels with omggif
- Prepares canvas buffer for fast rendering
- Frame-by-frame animator

# Usage

```html
<canvas class="example"></canvas>
<script src="gifler.min.js"></script>
<script>gifler('image.gif').animate('.example')</script>
```