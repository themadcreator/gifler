# Gifler
Animate GIFs in canvas.

- Loads GIF contents with XHR
- Decodes GIF frames and pixels with omggif
- Prepares canvas buffer for fast rendering
- Animates each frame and compensates for render delays
- API enables fully custom canvas rendering

### Examples & Docs

<http://themadcreator.github.io/gifler/>

### Usage

```html
<canvas class="example"></canvas>
<script src="gifler.min.js"></script>
<script>gifler('image.gif').animate('.example')</script>
```

### License
Apache-2.0