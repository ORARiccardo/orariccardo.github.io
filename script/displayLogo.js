// title animation
window.addEventListener('DOMContentLoaded', (event) => {
	// https://tobiasahlin.com/moving-letters/#7

	  // Wrap every letter in a span
var textWrapper = document.querySelector('.ml11 .letters');
textWrapper.innerHTML = textWrapper.textContent.replace(/([^\x00-\x80]|\w)/g, "<span class='letter'>$&</span>");

var letter_width = document.querySelector('.ml11 .letter').getBoundingClientRect().width;

var line_anime = anime.timeline()
  .add({
    targets: '.ml11 .line',
    scaleY: [0,1],
    opacity: [0.5,1],
    easing: "easeOutExpo",
    duration: 700
  })
  .add({
    targets: '.ml11 .line', 
    keyframes: [
      {opacity: 0},
      {opacity: 1},
      {opacity: 0},
      {opacity: 1}
    ],
    easing: "easeOutBack",
    duration: 2400
  })
  .add({
    targets: '.ml11 .line',
    keyframes: [
      {translateX: letter_width},
      {translateX: letter_width*2},
      {translateX: letter_width*3},
      {translateX: letter_width*4},
      {translateX: letter_width*5},
      {translateX: letter_width*6 + 5}
    ],
    easing: "easeOutExpo",
    duration: 3600,
    delay: 60
  });

  line_anime.finished.then(function(){
    anime({
      targets: '.ml11 .line',
      keyframes: [
        {opacity: 0},
        {opacity: 1}
      ],
      duration: 1200,
      easing: "easeOutBack",
      loop: true
    });
  });

  anime.timeline()
    .add({
        targets: '.ml11 .letter',
        opacity: [0,1],
        easing: "easeOutBack",
        duration: 3860,
        delay: anime.stagger(600)
      }, 3100);
});



