gifler('assets/gif/run.gif')
  .animate('canvas.play-pause')
  .then(function(animator) {
    $('canvas.play-pause').click(function(){
      if(animator.running()){
        animator.stop();
      } else {
        animator.start();
      }
    });
  });